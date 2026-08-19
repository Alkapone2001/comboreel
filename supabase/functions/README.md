# Edge Functions

## playback-session

Authorizes a published episode, checks entitlements for locked content, requests a short-lived Cloudflare Stream token, and returns a non-cacheable HLS manifest URL plus subtitle tracks.

Required secrets:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_STREAM_API_TOKEN` scoped only to the required Stream permissions
- `CLOUDFLARE_STREAM_CUSTOMER_CODE`
- `ALLOWED_ORIGINS` as a comma-separated staging/production allowlist

Supabase provides its URL, anon key, and service-role key to hosted Edge Functions. Never expose the Cloudflare token or service-role key to Flutter.

Deploy with JWT verification enabled. Private episodes require an authenticated user; free published episodes may receive a playback session without a user entitlement.
