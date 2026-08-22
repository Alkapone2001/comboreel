# Edge Functions

All functions use Supabase's publishable and secret API key dictionaries through
`_shared/supabase_keys.ts`; legacy JWT-based `anon` and `service_role` keys are
unsupported. New API keys are not JWTs, so every function is deployed with
gateway JWT verification disabled. Viewer-facing functions validate the caller's
bearer token with `auth.getUser()`; provider callbacks independently verify the
provider signature or OIDC identity.

## playback-session

Authorizes a published episode, checks entitlements for locked content, requests a short-lived Cloudflare Stream token, and returns a non-cacheable HLS manifest URL plus subtitle tracks.

Required secrets:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_STREAM_API_TOKEN` scoped only to the required Stream permissions
- `CLOUDFLARE_STREAM_CUSTOMER_CODE`
- `ALLOWED_ORIGINS` as a comma-separated staging/production allowlist

Supabase provides its URL and named publishable/secret key dictionaries to hosted Edge Functions. Never expose the Cloudflare token or secret key to Flutter.

Deploy with gateway JWT verification disabled; the function validates any caller token itself. Private episodes require an authenticated user; free published episodes may receive a playback session without a user entitlement.

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
Deploy with gateway JWT verification disabled; the function authenticates the viewer with `auth.getUser()`.

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
sessions. Deploy with gateway JWT verification disabled and explicit `auth.getUser()` validation. Set `STRIPE_SECRET_KEY`,
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

## apple-store-notifications

Receives App Store Server Notifications V2 and verifies the outer notification,
transaction, and renewal JWS values with Apple's official server library. Deploy
without gateway JWT verification. Set `APPLE_BUNDLE_ID`, production numeric
`APPLE_APP_ID`, and `APPLE_ROOT_CA_CERTIFICATES_BASE64`, a JSON array containing
base64 DER Apple root certificates downloaded from Apple PKI. Online certificate
checks remain enabled. Configure this public URL for both sandbox and production
notifications in App Store Connect.

## google-play-notifications

Receives authenticated Google Cloud Pub/Sub push messages for Play RTDN. Deploy
without gateway JWT verification. Configure the push subscription with OIDC and
set `GOOGLE_PUBSUB_AUDIENCE` and `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL` to the
exact configured values. The function validates the Google-signed identity,
deduplicates Pub/Sub `messageId`, and queries Play Developer API before changing
value. It reuses the Google service-account and package secrets documented above.

## push-device

Registers, refreshes, or disables Firebase device tokens for the authenticated
viewer. Deploy with gateway JWT verification disabled and explicit `auth.getUser()` validation. Supabase-provided keys are
sufficient; token rows remain service-owned and unreadable to Flutter.

## send-push-campaign

Claims one reviewed draft and delivers it to currently opted-in devices through
FCM HTTP v1. Deploy with gateway JWT verification disabled and explicit `auth.getUser()` validation; set
`FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_EMAIL`, and
`FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY`. Use a dedicated service account granted
only the Firebase Cloud Messaging send permission.

## account-data

Authenticates the viewer and provides a portable JSON export, active-subscription
deletion preview, and irreversible account deletion. Deletion requires a JWT
issued within ten minutes, disables push devices, deletes a linked Stripe customer
when configured, and removes the Supabase Auth user so cascading application data
is erased. Deploy with gateway JWT verification disabled and explicit `auth.getUser()` validation; set `ALLOWED_ORIGINS` to the
exact staging/production web origins, and set `STRIPE_SECRET_KEY` when web billing
is enabled.
