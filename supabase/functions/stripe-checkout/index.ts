import { createClient } from "npm:@supabase/supabase-js@2";
import { supabasePublishableKey, supabaseSecretKey } from "../_shared/supabase_keys.ts";

const stripeRoot = "https://api.stripe.com/v1";

function cors(origin: string | null): Record<string, string> {
  const allowed = Deno.env.get("WEB_APP_ORIGIN") ?? "";
  return origin && origin === allowed
    ? { "access-control-allow-origin": origin, "vary": "origin" }
    : {};
}

function json(status: number, body: Record<string, unknown>, origin: string | null) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json", "cache-control": "no-store",
      ...cors(origin),
    },
  });
}

function priceMap(): Record<string, string> {
  const parsed = JSON.parse(Deno.env.get("STRIPE_PRICE_MAP") ?? "{}") as Record<string, string>;
  if (Object.keys(parsed).length === 0) throw new Error("stripe_prices_not_configured");
  return parsed;
}

async function stripe(path: string, options: RequestInit = {}) {
  const result = await fetch(`${stripeRoot}${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${Deno.env.get("STRIPE_SECRET_KEY")}`,
      ...(options.headers ?? {}),
    },
  });
  const data = await result.json();
  if (!result.ok) throw new Error(data?.error?.message ?? `stripe_${result.status}`);
  return data;
}

async function ensureCustomer(
  service: any,
  user: { id: string; email?: string },
) {
  const { data: existing } = await service.from("stripe_customers")
    .select("customer_id").eq("user_id", user.id).maybeSingle();
  const existingCustomer = existing as { customer_id?: string } | null;
  if (existingCustomer?.customer_id) return existingCustomer.customer_id;
  const body = new URLSearchParams({ "metadata[user_id]": user.id });
  if (user.email) body.set("email", user.email);
  const customer = await stripe("/customers", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" }, body,
  });
  const { data, error } = await service.rpc("register_stripe_customer_server", {
    p_user_id: user.id, p_customer_id: customer.id,
  });
  if (error || data !== true) throw new Error("stripe_customer_ownership_conflict");
  return customer.id as string;
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    if (Object.keys(cors(origin)).length === 0) return new Response(null, { status: 403 });
    return new Response(null, {
      status: 204,
      headers: {
        ...cors(origin),
        "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
        "access-control-allow-methods": "POST, OPTIONS",
      },
    });
  }
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" }, origin);
  if (origin && Object.keys(cors(origin)).length === 0) {
    return json(403, { error: "origin_not_allowed" }, origin);
  }
  try {
    const authorization = request.headers.get("authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(supabaseUrl, supabasePublishableKey(), {
      global: { headers: { authorization } }, auth: { persistSession: false },
    });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json(401, { error: "authentication_required" }, origin);
    const service = createClient(supabaseUrl, supabaseSecretKey(), {
      auth: { persistSession: false },
    });
    const body = await request.json() as { action?: string; product_id?: string };
    const prices = priceMap();
    if (body.action === "catalog") {
      const entries = await Promise.all(Object.entries(prices).map(async ([productId, priceId]) => {
        const price = await stripe(`/prices/${encodeURIComponent(priceId)}?expand[]=product`);
        if (price.active !== true) return null;
        return {
          id: productId,
          title: typeof price.product === "object" ? price.product.name : productId,
          description: typeof price.product === "object" ? price.product.description ?? "" : "",
          unit_amount: price.unit_amount,
          currency: price.currency,
          recurring_interval: price.recurring?.interval ?? null,
        };
      }));
      return json(200, { products: entries.filter(Boolean) }, origin);
    }
    const appUrl = Deno.env.get("WEB_APP_URL")!;
    if (body.action === "portal") {
      const { data: mapping } = await service.from("stripe_customers")
        .select("customer_id").eq("user_id", user.id).maybeSingle();
      if (!mapping?.customer_id) return json(409, { error: "no_stripe_customer" }, origin);
      const portal = await stripe("/billing_portal/sessions", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ customer: mapping.customer_id, return_url: appUrl }),
      });
      return json(200, { url: portal.url }, origin);
    }
    if (body.action !== "checkout" || !body.product_id || !prices[body.product_id]) {
      return json(400, { error: "invalid_checkout_request" }, origin);
    }
    const { data: product } = await service.from("store_products")
      .select("kind").eq("platform", "stripe").eq("product_id", body.product_id)
      .eq("active", true).maybeSingle();
    if (!product) return json(400, { error: "unknown_store_product" }, origin);
    const customerId = await ensureCustomer(service, { id: user.id, email: user.email });
    const subscription = product.kind === "premium_subscription";
    const form = new URLSearchParams({
      mode: subscription ? "subscription" : "payment",
      customer: customerId,
      "line_items[0][price]": prices[body.product_id],
      "line_items[0][quantity]": "1",
      success_url: `${appUrl}?checkout=success`,
      cancel_url: `${appUrl}?checkout=cancelled`,
      client_reference_id: user.id,
      "metadata[user_id]": user.id,
      "metadata[product_id]": body.product_id,
    });
    if (subscription) {
      form.set("subscription_data[metadata][user_id]", user.id);
      form.set("subscription_data[metadata][product_id]", body.product_id);
    } else {
      form.set("payment_intent_data[metadata][user_id]", user.id);
      form.set("payment_intent_data[metadata][product_id]", body.product_id);
    }
    const session = await stripe("/checkout/sessions", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" }, body: form,
    });
    return json(200, { url: session.url }, origin);
  } catch (error) {
    console.error("Stripe checkout failed", error);
    return json(502, {
      error: error instanceof Error ? error.message : "stripe_unavailable",
    }, origin);
  }
});
