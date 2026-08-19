import { Buffer } from "node:buffer";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@3";
import { createClient } from "npm:@supabase/supabase-js@2";

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

function decodePayload(jws: string) {
  const part = jws.split(".")[1] ?? "";
  const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=")));
}

function verifier(environment: Environment) {
  const roots = JSON.parse(
    Deno.env.get("APPLE_ROOT_CA_CERTIFICATES_BASE64") ?? "[]",
  ) as string[];
  if (roots.length === 0) throw new Error("apple_root_certificates_missing");
  const appIdValue = Deno.env.get("APPLE_APP_ID") ?? "";
  const appAppleId = environment === Environment.PRODUCTION
    ? Number(appIdValue)
    : undefined;
  if (environment === Environment.PRODUCTION &&
    (!appIdValue || !Number.isFinite(appAppleId))) {
    throw new Error("apple_app_id_missing");
  }
  return new SignedDataVerifier(
    roots.map((certificate) => Buffer.from(certificate, "base64")),
    true,
    environment,
    Deno.env.get("APPLE_BUNDLE_ID")!,
    appAppleId,
  );
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  try {
    const body = await request.json() as { signedPayload?: string };
    if (!body.signedPayload) return json(400, { error: "signed_payload_required" });
    const hint = decodePayload(body.signedPayload);
    const environment = String(hint.data?.environment ?? "").toLowerCase() === "production"
      ? Environment.PRODUCTION
      : Environment.SANDBOX;
    const signedDataVerifier = verifier(environment);
    const notification = await signedDataVerifier.verifyAndDecodeNotification(
      body.signedPayload,
    );
    if (notification.notificationType === "TEST") {
      return json(200, { received: true, test: true });
    }
    const eventId = notification.notificationUUID;
    const eventType = notification.notificationType;
    const transactionJws = notification.data?.signedTransactionInfo;
    if (!eventId || !eventType || !transactionJws) {
      return json(200, { received: true, ignored: true });
    }
    const transaction = await signedDataVerifier.verifyAndDecodeTransaction(transactionJws);
    const productId = transaction.productId;
    const transactionId = transaction.transactionId;
    if (!productId || !transactionId) throw new Error("apple_transaction_fields_missing");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const { data: product } = await supabase.from("store_products")
      .select("kind").eq("platform", "apple").eq("product_id", productId)
      .eq("active", true).maybeSingle();
    if (!product) throw new Error("unknown_apple_product");
    if (product.kind === "coin_pack") {
      if (!["REFUND", "REVOKE"].includes(String(eventType))) {
        return json(200, { received: true, ignored: true });
      }
      const { data, error } = await supabase.rpc("reverse_mobile_coin_purchase_server", {
        p_platform: "apple", p_provider_event_id: eventId,
        p_event_type: eventType, p_provider_transaction_id: transactionId,
      });
      if (error) throw error;
      if (data !== true) return json(409, { error: "purchase_not_mapped" });
      return json(200, { received: true });
    }
    let graceEnd: number | undefined;
    if (notification.data?.signedRenewalInfo) {
      const renewal = await signedDataVerifier.verifyAndDecodeRenewalInfo(
        notification.data.signedRenewalInfo,
      );
      graceEnd = renewal.gracePeriodExpiresDate;
    }
    const now = Date.now();
    const revoked = transaction.revocationDate != null ||
      ["REFUND", "REVOKE", "EXPIRED", "GRACE_PERIOD_EXPIRED"].includes(String(eventType));
    const inGrace = !revoked && graceEnd != null && graceEnd > now;
    const active = !revoked && transaction.expiresDate != null && transaction.expiresDate > now;
    const status = inGrace ? "grace"
      : active ? "active"
      : eventType === "DID_FAIL_TO_RENEW" ? "past_due" : "expired";
    const periodEnd = inGrace ? graceEnd : transaction.expiresDate;
    const userId = transaction.appAccountToken;
    if (!userId || !transaction.originalTransactionId) {
      throw new Error("apple_subscription_owner_missing");
    }
    const { data, error } = await supabase.rpc("reconcile_mobile_subscription_server", {
      p_platform: "apple", p_provider_event_id: eventId, p_event_type: eventType,
      p_user_id: userId, p_subscription_id: transaction.originalTransactionId,
      p_product_id: productId, p_raw_status: status,
      p_period_start: transaction.purchaseDate
        ? new Date(transaction.purchaseDate).toISOString() : null,
      p_period_end: periodEnd ? new Date(periodEnd).toISOString() : null,
    });
    if (error) throw error;
    if (data !== true) return json(409, { error: "subscription_not_mapped" });
    return json(200, { received: true });
  } catch (error) {
    console.error("Apple notification processing failed", error);
    return json(500, { error: "notification_processing_failed" });
  }
});
