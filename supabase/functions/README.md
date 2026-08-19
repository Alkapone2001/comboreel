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

## rewarded-ad-callback

Receives AdMob rewarded SSV callbacks, preserves the original query ordering,
verifies Google's ECDSA signature with the matching rotating public key, checks
the configured ad unit/reward/timestamp, and atomically fulfills a short-lived
claim. Deploy with JWT verification disabled because Google calls it directly.

Set `ADMOB_REWARDED_AD_UNIT_IDS` to a comma-separated allowlist of production
Android and iOS rewarded ad unit IDs. Configure its public URL in AdMob with
reward amount `1` and reward item `episode_unlock`.

## verify-mobile-purchase

Authenticates the ComboReel viewer, looks up the server-owned product mapping,
and verifies the transaction directly with Google Play Developer API or Apple
App Store Server API before calling the service-role-only fulfillment RPC.
Deploy with JWT verification enabled.

Required secrets:

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`
- `APPLE_ISSUER_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`
- `APPLE_BUNDLE_ID`

Grant the Google service account only the Play Console financial/order access
needed for purchase verification. Use a dedicated App Store Connect In-App
Purchase key. Store PEM newlines either literally or as escaped `\\n` values.

## stripe-checkout

Provides the authenticated web catalogue, creates Stripe-hosted Checkout
Sessions, creates/owns Stripe Customers, and creates short-lived Billing Portal
sessions. Deploy with JWT verification enabled. Set `STRIPE_SECRET_KEY`,
`STRIPE_PRICE_MAP`, `WEB_APP_ORIGIN`, and `WEB_APP_URL`.

## stripe-webhook

Reads the untouched body, validates `Stripe-Signature` with HMAC-SHA256 and a
five-minute tolerance, then atomically fulfills Checkout or reconciles
subscriptions. Deploy with JWT verification disabled and set `STRIPE_SECRET_KEY`,
`STRIPE_WEBHOOK_SECRET`, and `STRIPE_PRICE_MAP`.

Subscribe it to `checkout.session.completed`, `customer.subscription.created`,
`customer.subscription.updated`, `customer.subscription.deleted`,
`customer.subscription.paused`, `customer.subscription.resumed`, `invoice.paid`,
and `invoice.payment_failed`. Configure the Billing Portal separately in test
and live modes.
