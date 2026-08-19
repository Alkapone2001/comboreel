import { createClient } from "npm:@supabase/supabase-js@2";

type RequestBody = {
  action?: "create_upload" | "status";
  episode_id?: string;
  file_name?: string;
  max_duration_seconds?: number;
};

function json(body: unknown, status = 200, origin?: string | null) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
      "vary": "origin",
      ...(origin ? { "access-control-allow-origin": origin } : {}),
    },
  });
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean);
  const responseOrigin = origin && allowedOrigins.includes(origin) ? origin : null;

  if (request.method === "OPTIONS") {
    if (origin && !responseOrigin) return new Response(null, { status: 403 });
    return new Response(null, {
      status: 204,
      headers: {
        ...(responseOrigin ? { "access-control-allow-origin": responseOrigin } : {}),
        "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
        "access-control-allow-methods": "POST, OPTIONS",
        "access-control-max-age": "86400",
      },
    });
  }
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405, responseOrigin);
  if (origin && !responseOrigin) return json({ error: "origin_not_allowed" }, 403);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const accountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const apiToken = Deno.env.get("CLOUDFLARE_STREAM_API_TOKEN");
  if (!supabaseUrl || !anonKey || !serviceKey || !accountId || !apiToken) {
    return json({ error: "server_not_configured" }, 503, responseOrigin);
  }

  const authorization = request.headers.get("authorization");
  if (!authorization) return json({ error: "authentication_required" }, 401, responseOrigin);
  const viewer = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData } = await viewer.auth.getUser();
  if (!userData.user) return json({ error: "authentication_required" }, 401, responseOrigin);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: profile } = await admin.from("profiles").select("role")
    .eq("id", userData.user.id).maybeSingle();
  if (!profile || !["editor", "admin"].includes(profile.role)) {
    return json({ error: "content_editor_required" }, 403, responseOrigin);
  }

  let body: RequestBody;
  try { body = await request.json(); } catch {
    return json({ error: "invalid_json" }, 400, responseOrigin);
  }
  if (!body.episode_id) return json({ error: "episode_id_required" }, 400, responseOrigin);
  const { data: episode } = await admin.from("episodes").select("id, title, stream_uid")
    .eq("id", body.episode_id).maybeSingle();
  if (!episode) return json({ error: "episode_not_found" }, 404, responseOrigin);

  if (body.action === "create_upload") {
    const maxDuration = Math.min(Math.max(body.max_duration_seconds ?? 3600, 1), 36000);
    const cfResponse = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/direct_upload`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${apiToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          maxDurationSeconds: maxDuration,
          creator: userData.user.id,
          requireSignedURLs: true,
          meta: { name: body.file_name ?? episode.title, episode_id: episode.id },
        }),
      },
    );
    const cf = await cfResponse.json();
    const uid = cf?.result?.uid as string | undefined;
    const uploadUrl = cf?.result?.uploadURL as string | undefined;
    if (!cfResponse.ok || !uid || !uploadUrl) {
      console.error("Cloudflare direct upload failed", cfResponse.status, cf?.errors);
      return json({ error: "upload_provision_failed" }, 502, responseOrigin);
    }
    const { error } = await admin.from("stream_uploads").upsert({
      episode_id: episode.id,
      stream_uid: uid,
      status: "waiting_upload",
      percent_complete: 0,
      error_reason: null,
      created_by: userData.user.id,
    }, { onConflict: "episode_id" });
    if (error) return json({ error: "upload_state_failed" }, 500, responseOrigin);
    await admin.from("episodes").update({ status: "processing", stream_uid: uid })
      .eq("id", episode.id);
    return json({ upload_url: uploadUrl, stream_uid: uid }, 200, responseOrigin);
  }

  if (body.action === "status") {
    if (!episode.stream_uid) return json({ error: "upload_not_started" }, 409, responseOrigin);
    const cfResponse = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${episode.stream_uid}`,
      { headers: { authorization: `Bearer ${apiToken}` } },
    );
    const cf = await cfResponse.json();
    const video = cf?.result;
    if (!cfResponse.ok || !video) return json({ error: "stream_status_failed" }, 502, responseOrigin);
    const state = String(video.status?.state ?? "processing").toLowerCase();
    const ready = video.readyToStream === true && state === "ready";
    const failed = state === "error";
    const percent = Number(video.status?.pctComplete ?? (ready ? 100 : 0));
    await admin.from("stream_uploads").update({
      status: ready ? "ready" : failed ? "error" : "processing",
      percent_complete: Number.isFinite(percent) ? percent : 0,
      error_reason: failed ? String(video.status?.errorReasonText ?? "Processing failed") : null,
    }).eq("episode_id", episode.id);
    if (ready) {
      await admin.from("episodes").update({
        status: "draft",
        duration_seconds: Math.max(1, Math.round(Number(video.duration ?? 0))),
        thumbnail_url: video.thumbnail ?? null,
      }).eq("id", episode.id);
    }
    return json({
      state: ready ? "ready" : failed ? "error" : "processing",
      percent_complete: percent,
      duration_seconds: video.duration ?? null,
      thumbnail_url: video.thumbnail ?? null,
      error_reason: video.status?.errorReasonText ?? null,
    }, 200, responseOrigin);
  }

  return json({ error: "unsupported_action" }, 400, responseOrigin);
});
