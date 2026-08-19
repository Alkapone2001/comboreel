# ComboReel Supabase

The migration in `migrations/` is the authoritative database definition. Do not create production tables manually in the dashboard.

## Local setup (when Supabase CLI is installed)

1. Run `supabase init` only if no local config exists.
2. Run `supabase start`.
3. Apply migrations with `supabase db reset`.
4. Copy the local API URL and anon key into Flutter `--dart-define` values.

## Production setup

1. Create separate Supabase projects for staging and production.
2. Link staging with `supabase link --project-ref <staging-ref>`.
3. Review the migration with `supabase db diff` and apply using `supabase db push`.
4. Use the publishable key in Flutter. Never ship the secret/service-role key; it belongs only in trusted server or Edge Function environments.
5. Promote the same reviewed migrations to production; do not edit production schema by hand.

## Security model

- Anonymous clients can only read published catalogue metadata.
- Authenticated viewers can update only their own profile-safe fields, favourites, and progress.
- Wallet balances, coin transactions, subscriptions, and entitlements cannot be granted by normal clients.
- Editors/admins are recognized by a server-protected role and manage catalogue records.
- Payment, rewarded-ad, and coin-spend mutations must be implemented as server-side functions with idempotency and provider verification.

## Monetization verification

`202608190002_monetization_functions.sql` adds authoritative access checks, atomic coin spends, and service-role-only credit/reward grants. `202608190003_rewarded_ads.sql` adds short-lived episode claims and atomic AdMob fulfillment. Run `tests/monetization_contract.sql` after migrations in a disposable database to prove that coin and rewarded-ad replays cannot duplicate value or entitlements.

The `credit_coins_server` and `grant_rewarded_episode_server` functions are intentionally executable only by `service_role`. Call them only after a trusted webhook or Edge Function has verified the payment/ad provider event.

Deploy `functions/rewarded-ad-callback` without gateway JWT verification, set its documented ad-unit allowlist, and configure its public URL as the AdMob SSV callback. The function independently verifies Google's signature before using any service-role mutation.

`202608190004_mobile_purchases.sql` defines the allowlisted mobile product
catalogue, immutable provider events, and replay-safe coin/subscription
fulfillment. Deploy `functions/verify-mobile-purchase` with JWT verification and
the documented least-privilege Apple/Google credentials. Never grant purchases
from Flutter's purchase callback alone.

`202608190005_stripe_web.sql` adds one-to-one Stripe customer ownership,
webhook idempotency, web coin fulfillment, and subscription reconciliation.
Deploy `stripe-checkout` with JWT verification and `stripe-webhook` without it;
the webhook authenticates Stripe against the raw request body and signing secret.

## Private video playback

Deploy `functions/playback-session` after setting its documented secrets. Mark every licensed Stream video `requireSignedURLs: true`. The function authorizes the episode before requesting a temporary token; clients never receive the Cloudflare API token or service-role key.
