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
