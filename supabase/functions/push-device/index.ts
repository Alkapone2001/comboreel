import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: Record<string, unknown>) => new Response(
  JSON.stringify(body),
  { status, headers: {
    "content-type": "application/json", "cache-control": "no-store",
    "access-control-allow-origin": "*",
  } },
);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, {
    status: 204,
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
      "access-control-allow-methods": "POST, OPTIONS",
      "access-control-max-age": "86400",
    },
  });
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) return json(503, { error: "server_not_configured" });
  const authorization = request.headers.get("authorization");
  if (!authorization) return json(401, { error: "authentication_required" });
  const viewer = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData } = await viewer.auth.getUser();
  if (!userData.user) return json(401, { error: "authentication_required" });

  let body: { action?: string; token?: string; platform?: string; locale?: string };
  try { body = await request.json(); } catch { return json(400, { error: "invalid_json" }); }
  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (body.action === "disable_all") {
    await service.from("profiles").update({ push_opt_in: false }).eq("id", userData.user.id);
    await service.from("push_devices").update({ enabled: false }).eq("user_id", userData.user.id);
    return json(200, { enabled: false });
  }
  if (body.action !== "register" || !body.token || body.token.length < 20 || body.token.length > 4096) {
    return json(400, { error: "invalid_registration" });
  }
  if (!["android", "ios", "web"].includes(body.platform ?? "")) {
    return json(400, { error: "invalid_platform" });
  }
  const locale = (body.locale ?? "en").toLowerCase().slice(0, 12);
  const { error } = await service.from("push_devices").upsert({
    user_id: userData.user.id,
    token: body.token,
    platform: body.platform,
    locale,
    enabled: true,
    last_seen_at: new Date().toISOString(),
  }, { onConflict: "token" });
  if (error) return json(500, { error: "registration_failed" });
  await service.from("profiles").update({ push_opt_in: true }).eq("id", userData.user.id);
  return json(200, { enabled: true });
});
