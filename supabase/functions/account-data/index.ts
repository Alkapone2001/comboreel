import { createClient } from "npm:@supabase/supabase-js@2";
import { supabasePublishableKey, supabaseSecretKey } from "../_shared/supabase_keys.ts";

const cors = (request: Request) => {
  const origin = request.headers.get("origin");
  const allowed = [
    ...(Deno.env.get("ALLOWED_ORIGINS") ?? "").split(","),
    Deno.env.get("WEB_APP_ORIGIN") ?? "",
  ].map((value) => value.trim()).filter(Boolean);
  return origin && allowed.includes(origin)
    ? { "access-control-allow-origin": origin, "vary": "origin" }
    : {};
};
const json = (request: Request, status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...cors(request) } });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: { ...cors(request), "access-control-allow-headers": "authorization, apikey, content-type, x-client-info", "access-control-allow-methods": "POST, OPTIONS", "access-control-max-age": "86400" } });
  if (request.method !== "POST") return json(request, 405, { error: "method_not_allowed" });
  const url = Deno.env.get("SUPABASE_URL"), anon = supabasePublishableKey(), serviceKey = supabaseSecretKey();
  const authorization = request.headers.get("authorization");
  if (!url || !anon || !serviceKey) return json(request, 503, { error: "server_not_configured" });
  if (!authorization) return json(request, 401, { error: "authentication_required" });
  const viewer = createClient(url, anon, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData } = await viewer.auth.getUser();
  const user = authData.user;
  if (!user) return json(request, 401, { error: "authentication_required" });
  const service = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  let body: { action?: string; acknowledge_active_subscriptions?: boolean };
  try { body = await request.json(); } catch { return json(request, 400, { error: "invalid_json" }); }

  const { data: active } = await service.from("subscriptions").select("platform, product_id, status, current_period_end")
    .eq("user_id", user.id).in("status", ["trialing", "active", "past_due", "paused"]);
  const platforms = [...new Set((active ?? []).map((row: any) => row.platform as string))];
  if (body.action === "deletion_preview") return json(request, 200, { active_subscription_platforms: platforms });

  if (body.action === "export") {
    const tables = ["profiles", "favourites", "watch_progress", "subscriptions", "entitlements", "wallets", "coin_transactions", "mobile_purchase_events", "rewarded_ad_claims", "analytics_events", "privacy_consents"];
    const records: Record<string, unknown> = {};
    for (const table of tables) {
      const column = table === "profiles" ? "id" : "user_id";
      const { data, error } = await service.from(table).select("*").eq(column, user.id);
      if (error) return json(request, 500, { error: "export_failed", table });
      records[table] = data;
    }
    return json(request, 200, { format: "comboreel-account-export", version: 1, exported_at: new Date().toISOString(), account: { id: user.id, email: user.email, created_at: user.created_at }, records });
  }

  if (body.action !== "delete") return json(request, 400, { error: "invalid_action" });
  const token = authorization.replace(/^Bearer\s+/i, "");
  const encodedPayload = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  const payload = JSON.parse(atob(encodedPayload.padEnd(Math.ceil(encodedPayload.length / 4) * 4, "=")));
  if (!payload.iat || Date.now() / 1000 - Number(payload.iat) > 600) return json(request, 401, { error: "recent_sign_in_required" });
  if (platforms.length && body.acknowledge_active_subscriptions !== true) return json(request, 409, { error: "active_subscription_acknowledgement_required", active_subscription_platforms: platforms });

  const { data: stripeCustomer } = await service.from("stripe_customers").select("customer_id").eq("user_id", user.id).maybeSingle();
  if (stripeCustomer?.customer_id && Deno.env.get("STRIPE_SECRET_KEY")) {
    const response = await fetch(`https://api.stripe.com/v1/customers/${encodeURIComponent(stripeCustomer.customer_id)}`, { method: "DELETE", headers: { authorization: `Bearer ${Deno.env.get("STRIPE_SECRET_KEY")}` } });
    if (!response.ok) return json(request, 502, { error: "stripe_account_cleanup_failed" });
  }
  await service.from("push_devices").update({ enabled: false }).eq("user_id", user.id);
  const { error } = await service.auth.admin.deleteUser(user.id);
  if (error) return json(request, 500, { error: "account_deletion_failed" });
  return json(request, 200, { deleted: true });
});
