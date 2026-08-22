import { createClient } from "npm:@supabase/supabase-js@2";
import { supabasePublishableKey, supabaseSecretKey } from "../_shared/supabase_keys.ts";

type PlaybackRequest = { episode_id?: string };

const json = (body: unknown, status: number, origin: string | null) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
      "vary": "origin",
      ...(origin ? { "access-control-allow-origin": origin } : {}),
    },
  });

Deno.serve(async (request) => {
  const requestOrigin = request.headers.get("origin");
  const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  const responseOrigin = requestOrigin && allowedOrigins.includes(requestOrigin)
    ? requestOrigin
    : null;

  if (request.method === "OPTIONS") {
    if (requestOrigin && !responseOrigin) return new Response(null, { status: 403 });
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
  if (requestOrigin && !responseOrigin) return json({ error: "origin_not_allowed" }, 403, null);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = supabasePublishableKey();
  const serviceRoleKey = supabaseSecretKey();
  const accountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const apiToken = Deno.env.get("CLOUDFLARE_STREAM_API_TOKEN");
  const customerCode = Deno.env.get("CLOUDFLARE_STREAM_CUSTOMER_CODE");
  if (!supabaseUrl || !publishableKey || !serviceRoleKey || !accountId || !apiToken || !customerCode) {
    return json({ error: "server_not_configured" }, 503, responseOrigin);
  }

  let payload: PlaybackRequest;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400, responseOrigin);
  }
  const episodeId = payload.episode_id;
  if (!episodeId) return json({ error: "episode_id_required" }, 400, responseOrigin);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: episode, error: episodeError } = await admin
    .from("episodes")
    .select("id, stream_uid, status, is_free")
    .eq("id", episodeId)
    .maybeSingle();
  if (episodeError) return json({ error: "catalogue_lookup_failed" }, 500, responseOrigin);
  if (!episode || episode.status !== "published" || !episode.stream_uid) {
    return json({ error: "episode_not_ready" }, 404, responseOrigin);
  }

  if (!episode.is_free) {
    const authorization = request.headers.get("authorization");
    if (!authorization) return json({ error: "authentication_required" }, 401, responseOrigin);
    const viewer = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await viewer.auth.getUser();
    if (userError || !userData.user) return json({ error: "authentication_required" }, 401, responseOrigin);
    const { data: hasAccess, error: accessError } = await viewer.rpc(
      "has_episode_access",
      { p_episode_id: episodeId },
    );
    if (accessError) return json({ error: "access_check_failed" }, 500, responseOrigin);
    if (!hasAccess) return json({ error: "episode_locked" }, 403, responseOrigin);
  }

  const tokenResponse = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${episode.stream_uid}/token`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${apiToken}` },
    },
  );
  const tokenPayload = await tokenResponse.json();
  const token = tokenPayload?.result?.token as string | undefined;
  if (!tokenResponse.ok || !token) {
    console.error("Cloudflare token request failed", tokenResponse.status, tokenPayload?.errors);
    return json({ error: "playback_token_failed" }, 502, responseOrigin);
  }

  const { data: subtitles, error: subtitleError } = await admin
    .from("episode_subtitles")
    .select("language_code, label, vtt_url, is_default")
    .eq("episode_id", episodeId)
    .order("is_default", { ascending: false });
  if (subtitleError) return json({ error: "subtitle_lookup_failed" }, 500, responseOrigin);

  return json(
    {
      hls_url: `https://customer-${customerCode}.cloudflarestream.com/${token}/manifest/video.m3u8`,
      expires_at: new Date(Date.now() + 55 * 60 * 1000).toISOString(),
      subtitles: subtitles ?? [],
    },
    200,
    responseOrigin,
  );
});
