import { createClient } from "npm:@supabase/supabase-js@2";

const encoder = new TextEncoder();

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

function hex(bytes: ArrayBuffer) {
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

async function verify(rawBody: string, signatureHeader: string) {
  const values = signatureHeader.split(",").map((part) => part.split("=", 2));
  const timestamp = values.find(([key]) => key === "t")?.[1];
  const signatures = values.filter(([key]) => key === "v1").map(([, value]) => value);
  if (!timestamp || signatures.length === 0) return false;
  const seconds = Number(timestamp);
  if (!Number.isFinite(seconds) || Math.abs(Date.now() / 1000 - seconds) > 300) return false;
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(Deno.env.get("STRIPE_WEBHOOK_SECRET")!),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const expected = hex(await crypto.subtle.sign(
    "HMAC", key, encoder.encode(`${timestamp}.${rawBody}`),
  ));
  return signatures.some((candidate) => constantTimeEqual(expected, candidate));
}

async function stripe(path: string) {
  const result = await fetch(`https://api.stripe.com/v1${path}`, {
    headers: { authorization: `Bearer ${Deno.env.get("STRIPE_SECRET_KEY")}` },
  });
  const data = await result.json();
  if (!result.ok) throw new Error(data?.error?.message ?? `stripe_${result.status}`);
  return data;
}

function identifier(value: unknown): string {
  if (typeof value === "string") return value;
  if (value && typeof value === "object" && "id" in value) return String((value as any).id);
  return "";
}

function isoFromSeconds(value: unknown): string | null {
  const seconds = Number(value);
  return Number.isFinite(seconds) && seconds > 0
    ? new Date(seconds * 1000).toISOString()
    : null;
}

function subscriptionFields(subscription: Record<string, any>) {
  const item = subscription.items?.data?.[0] ?? {};
  const prices = JSON.parse(Deno.env.get("STRIPE_PRICE_MAP") ?? "{}") as Record<string, string>;
  const priceId = identifier(item.price);
  const mappedProduct = Object.entries(prices).find(([, value]) => value === priceId)?.[0];
  return {
    customerId: identifier(subscription.customer),
    subscriptionId: String(subscription.id ?? ""),
    productId: String(mappedProduct ?? subscription.metadata?.product_id ?? ""),
    status: String(subscription.status ?? "expired"),
    periodStart: isoFromSeconds(subscription.current_period_start ?? item.current_period_start),
    periodEnd: isoFromSeconds(subscription.current_period_end ?? item.current_period_end),
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const rawBody = await request.text();
  if (!await verify(rawBody, request.headers.get("stripe-signature") ?? "")) {
    return json(400, { error: "invalid_signature" });
  }
  try {
    const event = JSON.parse(rawBody) as {
      id: string; type: string; created: number; data: { object: Record<string, any> };
    };
    const service = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const object = event.data.object;
    if (event.type === "checkout.session.completed") {
      const userId = String(object.client_reference_id ?? object.metadata?.user_id ?? "");
      const productId = String(object.metadata?.product_id ?? "");
      const customerId = identifier(object.customer);
      const subscriptionId = identifier(object.subscription);
      let expiresAt: string | null = null;
      let status = String(object.payment_status ?? "unpaid");
      if (subscriptionId) {
        const subscription = await stripe(`/subscriptions/${encodeURIComponent(subscriptionId)}`);
        const fields = subscriptionFields(subscription);
        expiresAt = fields.periodEnd;
        status = fields.status;
        if (!["active", "trialing"].includes(status)) {
          return json(409, { error: "subscription_not_active" });
        }
      } else if (object.payment_status !== "paid") {
        return json(409, { error: "checkout_not_paid" });
      }
      const { data, error } = await service.rpc("fulfill_stripe_checkout_server", {
        p_event_id: event.id, p_user_id: userId, p_session_id: object.id,
        p_customer_id: customerId, p_subscription_id: subscriptionId || null,
        p_product_id: productId,
        p_purchased_at: new Date(event.created * 1000).toISOString(),
        p_expires_at: expiresAt, p_raw_status: status,
      });
      if (error) throw error;
      if ((data as Array<Record<string, unknown>>)[0]?.accepted !== true) {
        return json(409, { error: "checkout_ownership_conflict" });
      }
      return json(200, { received: true });
    }

    const subscriptionTypes = new Set([
      "customer.subscription.created", "customer.subscription.updated",
      "customer.subscription.deleted", "customer.subscription.paused",
      "customer.subscription.resumed",
    ]);
    let subscription: Record<string, any> | null = null;
    if (subscriptionTypes.has(event.type)) subscription = object;
    if (["invoice.paid", "invoice.payment_failed"].includes(event.type)) {
      const subscriptionId = identifier(
        object.subscription ?? object.parent?.subscription_details?.subscription,
      );
      if (subscriptionId) {
        subscription = await stripe(`/subscriptions/${encodeURIComponent(subscriptionId)}`);
      }
    }
    if (subscription) {
      const fields = subscriptionFields(subscription);
      const { data, error } = await service.rpc("reconcile_stripe_subscription_server", {
        p_event_id: event.id, p_event_type: event.type,
        p_customer_id: fields.customerId, p_subscription_id: fields.subscriptionId,
        p_product_id: fields.productId, p_raw_status: fields.status,
        p_period_start: fields.periodStart, p_period_end: fields.periodEnd,
      });
      if (error) throw error;
      if (data !== true) return json(409, { error: "subscription_not_mapped" });
    }
    return json(200, { received: true });
  } catch (error) {
    console.error("Stripe webhook processing failed", error);
    return json(500, { error: "webhook_processing_failed" });
  }
});
