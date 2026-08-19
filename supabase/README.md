# ComboReel Supabase

The migration in `migrations/` is the authoritative database definition. Do not create production tables manually in the dashboard.

## Local setup (when Supabase CLI is installed)

1. Run `supabase init` only if no local config exists.
2. Run `supabase start`.
3. Run `supabase db reset` to apply every migration to the local stack.
4. On Windows, run `pwsh -File tool/run_local_supabase_smoke.ps1` from the
   repository root. The smoke test creates disposable local users/content and
   verifies Auth, public catalogue visibility, profile/favourite isolation,
   protected role assignment, preferences, signup consent, and non-enumerating
   password recovery through the Auth/PostgREST APIs. It also audits branded
   recovery, email-change, and password-change messages delivered to Mailpit.

The local dashboard is available at `http://127.0.0.1:54323`. Local keys are
development-only and are read from `supabase status`; never copy them into a
hosted environment or commit hosted project secrets.
5. Copy the local API URL and anon key into Flutter `--dart-define` values.

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

`202608190006_mobile_lifecycle.sql` adds mobile provider-event idempotency,
subscription reconciliation, and coin-purchase reversals. Deploy both Apple and
Google notification functions without gateway JWT verification; each authenticates
its provider using the mechanism documented in `functions/README.md`.

## Private video playback

Deploy `functions/playback-session` after setting its documented secrets. Mark every licensed Stream video `requireSignedURLs: true`. The function authorizes the episode before requesting a temporary token; clients never receive the Cloudflare API token or service-role key.

## Analytics and push

`202608190008_analytics_push.sql` adds consent flags, allowlisted first-party
events, protected aggregate reporting, server-owned device registrations, and
campaign drafts. Run `tests/analytics_push_contract.sql` after migrations.
Deploy `push-device` and `send-push-campaign` with JWT verification enabled.
Authenticated clients cannot write device tokens or delivery results directly.
