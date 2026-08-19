import { createClient } from "npm:@supabase/supabase-js@2";

const encoder = new TextEncoder();
const json = (status: number, body: Record<string, unknown>) => new Response(
  JSON.stringify(body),
  { status, headers: {
    "content-type": "application/json", "cache-control": "no-store",
    "access-control-allow-origin": "*",
  } },
);
const b64 = (value: Uint8Array | string) => {
  const bytes = typeof value === "string" ? encoder.encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
};
const pemBytes = (pem: string) => Uint8Array.from(
  atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "")),
  (character) => character.charCodeAt(0),
);

async function accessToken(email: string, privateKey: string) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64(JSON.stringify({
    iss: email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemBytes(privateKey.replace(/\\n/g, "\n")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned));
  const result = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64(new Uint8Array(signature))}`,
    }),
  });
  if (!result.ok) throw new Error(`firebase_auth_${result.status}`);
  return (await result.json() as { access_token: string }).access_token;
}

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
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const serviceEmail = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey || !projectId || !serviceEmail || !privateKey) {
    return json(503, { error: "server_not_configured" });
  }
  const authorization = request.headers.get("authorization");
  if (!authorization) return json(401, { error: "authentication_required" });
  const viewer = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData } = await viewer.auth.getUser();
  if (!userData.user) return json(401, { error: "authentication_required" });
  const service = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: profile } = await service.from("profiles").select("role")
    .eq("id", userData.user.id).maybeSingle();
  if (!profile || !["editor", "admin"].includes(profile.role)) {
    return json(403, { error: "content_editor_required" });
  }
  let body: { campaign_id?: string };
  try { body = await request.json(); } catch { return json(400, { error: "invalid_json" }); }
  if (!body.campaign_id) return json(400, { error: "campaign_id_required" });
  const { data: claimed } = await service.from("push_campaigns")
    .update({ status: "sending", error_summary: null })
    .eq("id", body.campaign_id).eq("status", "draft").select().maybeSingle();
  if (!claimed) return json(409, { error: "campaign_not_sendable" });

  try {
    const { data: devices, error } = await service.from("push_devices")
      .select("id, token, profiles!inner(push_opt_in)").eq("enabled", true)
      .eq("profiles.push_opt_in", true);
    if (error) throw error;
    const token = await accessToken(serviceEmail, privateKey);
    let succeeded = 0;
    let failed = 0;
    for (const device of devices ?? []) {
      const result = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
        {
          method: "POST",
          headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
          body: JSON.stringify({ message: {
            token: device.token,
            notification: { title: claimed.title, body: claimed.body },
            data: { campaign_id: claimed.id, deep_link: claimed.deep_link ?? "comboreel://home" },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
          } }),
        },
      );
      if (result.ok) {
        succeeded++;
      } else {
        failed++;
        const response = await result.text();
        if (result.status === 404 || response.includes("UNREGISTERED")) {
          await service.from("push_devices").update({ enabled: false }).eq("id", device.id);
        }
      }
    }
    await service.from("push_campaigns").update({
      status: "sent", sent_at: new Date().toISOString(),
      target_count: (devices ?? []).length, success_count: succeeded, failure_count: failed,
    }).eq("id", claimed.id);
    return json(200, { sent: succeeded, failed, targets: (devices ?? []).length });
  } catch (error) {
    console.error("Push campaign failed", error);
    await service.from("push_campaigns").update({
      status: "failed", error_summary: "Campaign delivery failed; inspect function logs.",
    }).eq("id", claimed.id);
    return json(502, { error: "campaign_delivery_failed" });
  }
});
