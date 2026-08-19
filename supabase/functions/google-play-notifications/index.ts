import { createClient } from "npm:@supabase/supabase-js@2";

const encoder = new TextEncoder();

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

function base64Url(input: Uint8Array | string) {
  const bytes = typeof input === "string" ? encoder.encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemBytes(pem: string) {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  return Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
}

async function googleAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL"),
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY")!.replace(/\\n/g, "\n")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned),
  );
  const result = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64Url(new Uint8Array(signature))}`,
    }),
  });
  if (!result.ok) throw new Error(`google_auth_${result.status}`);
  return (await result.json() as { access_token: string }).access_token;
}

async function verifyPushIdentity(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return false;
  const token = authorization.slice(7);
  const result = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(token)}`,
  );
  if (!result.ok) return false;
  const claims = await result.json() as Record<string, string>;
  return claims.aud === Deno.env.get("GOOGLE_PUBSUB_AUDIENCE") &&
    claims.email === Deno.env.get("GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL") &&
    claims.email_verified === "true";
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!await verifyPushIdentity(request)) return json(401, { error: "invalid_push_identity" });
  try {
    const envelope = await request.json() as {
      message?: { messageId?: string; data?: string };
    };
    const eventId = envelope.message?.messageId;
    const encodedData = envelope.message?.data;
    if (!eventId || !encodedData) return json(400, { error: "invalid_pubsub_envelope" });
    const notification = JSON.parse(atob(encodedData)) as Record<string, any>;
    const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")!;
    if (notification.packageName !== packageName) {
      return json(403, { error: "package_mismatch" });
    }
    if (notification.testNotification) return json(200, { received: true, test: true });
    const service = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const { data: priorEvent } = await service.from("mobile_provider_events")
      .select("provider_event_id").eq("platform", "google")
      .eq("provider_event_id", eventId).maybeSingle();
    if (priorEvent) return json(200, { received: true, replay: true });
    const accessToken = await googleAccessToken();
    const root = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}`;

    const reconcileSubscription = async (purchaseToken: string, eventType: string) => {
      const result = await fetch(
        `${root}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
        { headers: { authorization: `Bearer ${accessToken}` } },
      );
      if (!result.ok) throw new Error(`google_subscription_${result.status}`);
      const purchase = await result.json() as Record<string, any>;
      const line = purchase.lineItems?.[0];
      const productId = String(line?.productId ?? "");
      let userId = purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId as string | undefined;
      if (!userId) {
        const { data: existing } = await service.from("mobile_purchase_events")
          .select("user_id").eq("platform", "google")
          .eq("original_transaction_id", purchaseToken).maybeSingle();
        userId = existing?.user_id;
      }
      if (!userId || !productId || !line?.expiryTime) {
        throw new Error("google_subscription_mapping_missing");
      }
      const state = String(purchase.subscriptionState ?? "");
      const status = state === "SUBSCRIPTION_STATE_ACTIVE" ? "active"
        : state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ? "grace"
        : state === "SUBSCRIPTION_STATE_PAUSED" ? "paused"
        : state === "SUBSCRIPTION_STATE_ON_HOLD" ? "past_due"
        : state === "SUBSCRIPTION_STATE_CANCELED" && Date.parse(line.expiryTime) > Date.now()
        ? "active" : "expired";
      const { data, error } = await service.rpc("reconcile_mobile_subscription_server", {
        p_platform: "google", p_provider_event_id: eventId, p_event_type: eventType,
        p_user_id: userId, p_subscription_id: purchaseToken,
        p_product_id: productId, p_raw_status: status,
        p_period_start: purchase.startTime ?? null, p_period_end: line.expiryTime,
      });
      if (error) throw error;
      if (data !== true) throw new Error("google_subscription_rejected");
    };

    if (notification.subscriptionNotification) {
      const update = notification.subscriptionNotification;
      await reconcileSubscription(
        String(update.purchaseToken), `subscription:${update.notificationType}`,
      );
      return json(200, { received: true });
    }
    if (notification.oneTimeProductNotification) {
      const update = notification.oneTimeProductNotification;
      const purchaseToken = String(update.purchaseToken);
      if (Number(update.notificationType) === 2) {
        const { data, error } = await service.rpc("reverse_mobile_coin_purchase_server", {
          p_platform: "google", p_provider_event_id: eventId,
          p_event_type: "one_time_product_cancelled",
          p_provider_transaction_id: purchaseToken,
        });
        if (error) throw error;
        if (data !== true) return json(409, { error: "purchase_not_mapped" });
        return json(200, { received: true });
      }
      const productId = String(update.sku);
      const result = await fetch(
        `${root}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`,
        { headers: { authorization: `Bearer ${accessToken}` } },
      );
      if (!result.ok) throw new Error(`google_product_${result.status}`);
      const purchase = await result.json() as Record<string, any>;
      if (purchase.purchaseState !== 0 || !purchase.obfuscatedExternalAccountId) {
        throw new Error("google_product_not_owned");
      }
      const { data, error } = await service.rpc("fulfill_mobile_purchase_server", {
        p_user_id: purchase.obfuscatedExternalAccountId, p_platform: "google",
        p_provider_transaction_id: String(purchase.orderId ?? purchaseToken),
        p_original_transaction_id: purchaseToken, p_product_id: productId,
        p_purchased_at: purchase.purchaseTimeMillis
          ? new Date(Number(purchase.purchaseTimeMillis)).toISOString() : null,
        p_expires_at: null, p_environment: "google_play_rtdn",
        p_raw_status: "PURCHASED",
      });
      if (error) throw error;
      if ((data as Array<Record<string, unknown>>)[0]?.accepted !== true) {
        throw new Error("google_product_rejected");
      }
      if (purchase.consumptionState === 0) {
        const consumed = await fetch(
          `${root}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:consume`,
          { method: "POST", headers: { authorization: `Bearer ${accessToken}` } },
        );
        if (!consumed.ok) throw new Error(`google_consume_${consumed.status}`);
      }
      const { error: recordError } = await service.rpc(
        "record_mobile_provider_event_server",
        { p_platform: "google", p_provider_event_id: eventId, p_event_type: "one_time_product_purchased" },
      );
      if (recordError) throw recordError;
      return json(200, { received: true });
    }
    if (notification.voidedPurchaseNotification) {
      const update = notification.voidedPurchaseNotification;
      const purchaseToken = String(update.purchaseToken);
      if (Number(update.productType) === 1) {
        await reconcileSubscription(purchaseToken, "voided_subscription");
      } else {
        const { data, error } = await service.rpc("reverse_mobile_coin_purchase_server", {
          p_platform: "google", p_provider_event_id: eventId,
          p_event_type: "voided_purchase", p_provider_transaction_id: purchaseToken,
        });
        if (error) throw error;
        if (data !== true) return json(409, { error: "purchase_not_mapped" });
      }
      return json(200, { received: true });
    }
    return json(200, { received: true, ignored: true });
  } catch (error) {
    console.error("Google Play notification processing failed", error);
    return json(500, { error: "notification_processing_failed" });
  }
});
