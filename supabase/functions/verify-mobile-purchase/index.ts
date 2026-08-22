import { createClient } from "npm:@supabase/supabase-js@2";
import { supabasePublishableKey, supabaseSecretKey } from "../_shared/supabase_keys.ts";

type ProductKind = "coin_pack" | "premium_subscription";
type VerifiedPurchase = {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  purchasedAt: string | null;
  expiresAt: string | null;
  environment: string;
  rawStatus: string;
};

const encoder = new TextEncoder();

function response(status: number, body: Record<string, unknown>) {
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

function decodeJwtPayload(jws: string) {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("invalid_store_jws");
  const normalized = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=")));
}

function pemBytes(pem: string) {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  return Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
}

async function signedJwt(
  algorithm: "RS256" | "ES256",
  privateKeyPem: string,
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
) {
  const encoded = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claims))}`;
  const cryptoAlgorithm = algorithm === "RS256"
    ? { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }
    : { name: "ECDSA", namedCurve: "P-256", hash: "SHA-256" };
  const key = await crypto.subtle.importKey(
    "pkcs8", pemBytes(privateKeyPem), cryptoAlgorithm, false, ["sign"],
  );
  const signature = await crypto.subtle.sign(
    algorithm === "RS256"
      ? { name: "RSASSA-PKCS1-v1_5" }
      : { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(encoded),
  );
  return `${encoded}.${base64Url(new Uint8Array(signature))}`;
}

async function googleAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signedJwt(
    "RS256",
    Deno.env.get("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY")!.replace(/\\n/g, "\n"),
    { alg: "RS256", typ: "JWT" },
    {
      iss: Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL"),
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
  );
  const result = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!result.ok) throw new Error(`google_auth_${result.status}`);
  return (await result.json() as { access_token: string }).access_token;
}

async function verifyGoogle(
  token: string,
  productId: string,
  kind: ProductKind,
  userId: string,
): Promise<VerifiedPurchase> {
  const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")!;
  const accessToken = await googleAccessToken();
  const root = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}`;
  const url = kind === "coin_pack"
    ? `${root}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`
    : `${root}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const storeResponse = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!storeResponse.ok) throw new Error(`google_verify_${storeResponse.status}`);
  const data = await storeResponse.json() as Record<string, any>;
  if (kind === "coin_pack") {
    if (data.purchaseState !== 0) throw new Error("google_purchase_not_completed");
    if (data.obfuscatedExternalAccountId !== userId) throw new Error("purchase_owner_mismatch");
    return {
      transactionId: String(data.orderId ?? token),
      originalTransactionId: token,
      productId,
      purchasedAt: data.purchaseTimeMillis ? new Date(Number(data.purchaseTimeMillis)).toISOString() : null,
      expiresAt: null,
      environment: "google_play",
      rawStatus: "PURCHASED",
    };
  }
  const line = (data.lineItems as Array<Record<string, any>> | undefined)
    ?.find((item) => item.productId === productId);
  if (!line?.expiryTime) throw new Error("google_subscription_product_mismatch");
  if (data.externalAccountIdentifiers?.obfuscatedExternalAccountId !== userId) {
    throw new Error("purchase_owner_mismatch");
  }
  const activeStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);
  if (!activeStates.has(String(data.subscriptionState))) {
    throw new Error("google_subscription_inactive");
  }
  return {
    transactionId: token,
    originalTransactionId: token,
    productId,
    purchasedAt: data.startTime ?? null,
    expiresAt: line.expiryTime,
    environment: "google_play",
    rawStatus: String(data.subscriptionState),
  };
}

async function appleApiToken() {
  const now = Math.floor(Date.now() / 1000);
  return signedJwt(
    "ES256",
    Deno.env.get("APPLE_PRIVATE_KEY")!.replace(/\\n/g, "\n"),
    { alg: "ES256", kid: Deno.env.get("APPLE_KEY_ID"), typ: "JWT" },
    {
      iss: Deno.env.get("APPLE_ISSUER_ID"), iat: now, exp: now + 900,
      aud: "appstoreconnect-v1", bid: Deno.env.get("APPLE_BUNDLE_ID"),
    },
  );
}

async function verifyApple(
  transactionId: string,
  expectedProductId: string,
  userId: string,
): Promise<VerifiedPurchase> {
  if (!transactionId) throw new Error("apple_transaction_required");
  const token = await appleApiToken();
  const environments = [
    ["production", "https://api.storekit.itunes.apple.com"],
    ["sandbox", "https://api.storekit-sandbox.itunes.apple.com"],
  ] as const;
  for (const [environment, host] of environments) {
    const result = await fetch(
      `${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      { headers: { authorization: `Bearer ${token}` } },
    );
    if (result.status === 404) continue;
    if (!result.ok) throw new Error(`apple_verify_${result.status}`);
    const body = await result.json() as { signedTransactionInfo?: string };
    const data = decodeJwtPayload(body.signedTransactionInfo ?? "");
    if (data.bundleId !== Deno.env.get("APPLE_BUNDLE_ID")) throw new Error("apple_bundle_mismatch");
    if (data.productId !== expectedProductId) throw new Error("apple_product_mismatch");
    if (data.appAccountToken !== userId) throw new Error("purchase_owner_mismatch");
    if (data.revocationDate) throw new Error("apple_purchase_revoked");
    return {
      transactionId: String(data.transactionId),
      originalTransactionId: String(data.originalTransactionId ?? data.transactionId),
      productId: String(data.productId),
      purchasedAt: data.purchaseDate ? new Date(Number(data.purchaseDate)).toISOString() : null,
      expiresAt: data.expiresDate ? new Date(Number(data.expiresDate)).toISOString() : null,
      environment,
      rawStatus: data.expiresDate && Number(data.expiresDate) <= Date.now() ? "EXPIRED" : "ACTIVE",
    };
  }
  throw new Error("apple_transaction_not_found");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return response(405, { error: "method_not_allowed" });
  try {
    const authorization = request.headers.get("authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(supabaseUrl, supabasePublishableKey(), {
      global: { headers: { authorization } }, auth: { persistSession: false },
    });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return response(401, { error: "authentication_required" });
    const body = await request.json() as {
      source?: string; product_id?: string; verification_data?: string; purchase_id?: string;
    };
    const platform = body.source === "google_play" ? "google"
      : body.source === "app_store" ? "apple" : null;
    if (!platform || !body.product_id || !body.verification_data) {
      return response(400, { error: "invalid_purchase_payload" });
    }
    const service = createClient(supabaseUrl, supabaseSecretKey(), {
      auth: { persistSession: false },
    });
    const { data: product, error: productError } = await service.from("store_products")
      .select("kind").eq("platform", platform).eq("product_id", body.product_id)
      .eq("active", true).maybeSingle();
    if (productError || !product) return response(400, { error: "unknown_store_product" });
    const kind = product.kind as ProductKind;
    const appleTransactionId = platform === "apple" && !body.purchase_id
      ? String(decodeJwtPayload(body.verification_data).transactionId ?? "")
      : body.purchase_id;
    const verified = platform === "google"
      ? await verifyGoogle(body.verification_data, body.product_id, kind, user.id)
      : await verifyApple(appleTransactionId ?? "", body.product_id, user.id);
    if (kind === "premium_subscription" && !verified.expiresAt) {
      return response(409, { error: "subscription_expiry_missing" });
    }
    const { data, error } = await service.rpc("fulfill_mobile_purchase_server", {
      p_user_id: user.id, p_platform: platform,
      p_provider_transaction_id: verified.transactionId,
      p_original_transaction_id: verified.originalTransactionId,
      p_product_id: verified.productId, p_purchased_at: verified.purchasedAt,
      p_expires_at: verified.expiresAt, p_environment: verified.environment,
      p_raw_status: verified.rawStatus,
    });
    if (error) throw error;
    const fulfillment = (data as Array<Record<string, unknown>>)[0];
    if (fulfillment?.accepted !== true) return response(409, { error: "purchase_already_claimed" });
    return response(200, { ok: true, ...fulfillment });
  } catch (error) {
    console.error("Mobile purchase verification failed", error);
    const message = error instanceof Error ? error.message : "verification_failed";
    const clientErrors = ["mismatch", "inactive", "revoked", "not_completed", "not_found", "required"];
    return response(clientErrors.some((value) => message.includes(value)) ? 403 : 502, {
      error: message,
    });
  }
});
