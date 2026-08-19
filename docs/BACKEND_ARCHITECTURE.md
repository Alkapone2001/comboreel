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
