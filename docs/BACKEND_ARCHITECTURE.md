# Backend Architecture

## Trust boundaries

The Flutter app is an untrusted public client. It may hold a Supabase publishable key, but it must never hold a secret/service-role key, Cloudflare API token, Stripe secret, AdMob server credential, Apple shared secret, or Google service-account credential.

Supabase row-level security protects direct client access. Trusted mutations—coin grants/spends, purchase verification, subscription lifecycle, rewarded-ad verification, signed video playback, and admin role assignment—must run in Edge Functions or another controlled backend.

## Data ownership

- Public catalogue: published series, seasons, episodes, genres, and subtitles.
- Viewer-owned: profile-safe fields, favourites, and watch progress.
- Server-owned: roles, wallets, coin transactions, subscriptions, entitlements, stream identifiers, and publishing state.
- Admin-managed: catalogue and subtitle metadata. Editors and admins use protected role checks.

## Access decisions

An episode is playable when at least one condition is true:

1. The episode is marked free.
2. The viewer has a non-expired episode entitlement.
3. The viewer has a non-expired series entitlement.
4. The viewer has an active premium entitlement/subscription.
5. A trusted admin preview policy applies.

The client may display a predicted access state, but the backend that creates a signed Cloudflare playback token must make the authoritative decision.

## Monetary integrity

Wallet balance changes and coin transaction insertion are intentionally unavailable to ordinary clients. A server transaction must lock the wallet row, verify idempotency, validate sufficient balance for spends, update the balance, insert the immutable ledger record, and grant the matching entitlement atomically.

Provider webhooks must verify signatures and use stable provider event/transaction IDs as idempotency keys. Replayed events must return success without duplicating value.

The client-facing `unlock_episode_with_coins` RPC derives the user from the authenticated JWT, locks the wallet row, checks existing access and idempotency, debits once, writes the ledger, and grants the entitlement in one transaction. Server-only credit and rewarded-unlock RPCs are revoked from public/anonymous/authenticated roles and granted only to `service_role`.

## Environments

Use separate local, staging, and production environments. Schema changes originate as reviewed migrations and are promoted in order. App builds receive environment-specific public URL/key pairs through CI configuration. Secrets stay in the backend platform's encrypted secret store.

## Video access

Published Cloudflare Stream videos must have signed URLs required. Flutter requests an episode session from the `playback-session` Edge Function. The function checks free status or calls the entitlement RPC as the authenticated viewer, then obtains a short-lived Cloudflare token and returns the direct HLS manifest URL with `Cache-Control: no-store`.

The Cloudflare account ID, scoped Stream API token, customer code, and Supabase service-role key exist only in Edge Function secrets. HLS manifests are read directly from Cloudflare and must not be cached or proxied. Production and staging web origins are allowlisted separately.

## Rewarded-ad integrity

An authenticated viewer requests a short-lived claim tied to exactly one locked,
published episode. Flutter passes the opaque claim ID as AdMob SSV `custom_data`
and the authenticated user ID as `user_id`. The public callback verifies Google's
ECDSA/SHA-256 signature over the untouched query string, enforces the ad unit,
reward, timestamp, claim owner, and expiry, then atomically records the globally
unique transaction and grants one entitlement. Client callbacks cannot grant
access; they only move the interface into a verification wait state.

## Mobile purchases

The Flutter purchase stream starts with the app shell, loads localized prices
from StoreKit/Google Play, attaches the authenticated UUID as the store account
token, and sends only pending completed/restored transactions to the verification
function. The function checks the server-owned product catalogue and verifies
the purchase directly through App Store Server API or Google Play Developer API.

The database owns fulfillment. Provider transaction IDs are globally unique per
platform, consumable coin credits reuse that ID as the ledger reference, and
subscription transactions upsert one premium entitlement with the provider
expiry. A transaction tied to a different viewer or product is rejected. Flutter
finishes or consumes the store transaction only after server acceptance. Restore
Purchases replays owned non-consumables/subscriptions through the same verifier;
consumable balances are restored from ComboReel's server ledger, not the store.

## Stripe web billing

Configured web builds load products through the authenticated `stripe-checkout`
function. Stripe secrets and Price IDs remain server-side. Checkout uses hosted
payment pages; its client redirect never grants value. The raw-body webhook
validates Stripe's timestamped HMAC before an atomic RPC credits coins or updates
a premium entitlement.

Stripe event IDs and Checkout Session IDs are separate idempotency boundaries.
Customer IDs have one immutable ComboReel owner. Subscription lifecycle and
invoice events reconcile access while the app is closed. Billing Portal sessions
are created for the authenticated viewer without accepting a client customer ID.
