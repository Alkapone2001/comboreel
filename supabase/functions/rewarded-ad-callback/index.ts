import { createClient } from "npm:@supabase/supabase-js@2";

const keyUrl = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const encoder = new TextEncoder();

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

function base64Url(value: string) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function derToP1363(der: Uint8Array, size = 32) {
  if (der[0] !== 0x30) throw new Error("invalid_signature");
  let offset = der[1] < 0x80 ? 2 : 2 + (der[1] & 0x7f);
  const parts: Uint8Array[] = [];
  for (let index = 0; index < 2; index++) {
    if (der[offset++] !== 0x02) throw new Error("invalid_signature");
    let length = der[offset++];
    if (length & 0x80) {
      const bytes = length & 0x7f;
      length = 0;
      for (let i = 0; i < bytes; i++) length = length * 256 + der[offset++];
    }
    let integer = der.slice(offset, offset + length);
    offset += length;
    while (integer.length > size && integer[0] === 0) integer = integer.slice(1);
    if (integer.length > size) throw new Error("invalid_signature");
    const fixed = new Uint8Array(size);
    fixed.set(integer, size - integer.length);
    parts.push(fixed);
  }
  const result = new Uint8Array(size * 2);
  result.set(parts[0], 0);
  result.set(parts[1], size);
  return result;
}

async function verifySignature(rawQuery: string, signature: string, keyId: string) {
  const marker = "&signature=";
  const markerIndex = rawQuery.indexOf(marker);
  const suffix = rawQuery.slice(markerIndex);
  if (markerIndex < 0 || !/^&signature=[^&]+&key_id=[^&]+$/.test(suffix)) return false;
  const keysResponse = await fetch(keyUrl, { headers: { accept: "application/json" } });
  if (!keysResponse.ok) throw new Error("key_fetch_failed");
  const payload = await keysResponse.json() as { keys?: Array<{ keyId: number; base64: string }> };
  const selected = payload.keys?.find((key) => String(key.keyId) === keyId);
  if (!selected) return false;
  const key = await crypto.subtle.importKey(
    "spki", Uint8Array.from(atob(selected.base64), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
  );
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, key,
    derToP1363(base64Url(signature)), encoder.encode(rawQuery.slice(0, markerIndex)),
  );
}

Deno.serve(async (request) => {
  if (request.method !== "GET") return json(405, { error: "method_not_allowed" });
  try {
    const url = new URL(request.url);
    const queryIndex = request.url.indexOf("?");
    if (queryIndex < 0) return json(400, { error: "missing_parameters" });
    const rawQuery = request.url.slice(queryIndex + 1);
    const params = url.searchParams;
    const required = ["ad_unit", "custom_data", "key_id", "reward_amount", "reward_item", "signature", "timestamp", "transaction_id", "user_id"];
    if (required.some((name) => !params.get(name))) return json(400, { error: "missing_parameters" });

    const allowedUnits = (Deno.env.get("ADMOB_REWARDED_AD_UNIT_IDS") ?? "").split(",").map((v) => v.trim()).filter(Boolean);
    if (!allowedUnits.includes(params.get("ad_unit")!)) return json(403, { error: "unexpected_ad_unit" });
    if (params.get("reward_item") !== "episode_unlock" || params.get("reward_amount") !== "1") {
      return json(403, { error: "unexpected_reward" });
    }
    const timestamp = Number(params.get("timestamp"));
    const age = Date.now() - timestamp;
    if (!Number.isFinite(timestamp) || age < -300_000 || age > 3_600_000) {
      return json(403, { error: "stale_callback" });
    }
    if (!await verifySignature(rawQuery, params.get("signature")!, params.get("key_id")!)) {
      return json(403, { error: "invalid_signature" });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const { data, error } = await supabase.rpc("complete_rewarded_ad_claim_server", {
      p_claim_id: params.get("custom_data"),
      p_user_id: params.get("user_id"),
      p_provider_transaction_id: params.get("transaction_id"),
    });
    if (error) throw error;
    if (data !== true) return json(409, { error: "claim_rejected" });
    return json(200, { ok: true });
  } catch (error) {
    console.error("Rewarded callback failed", error);
    return json(500, { error: "verification_unavailable" });
  }
});
