# ComboReel staging and release deployment

Deployments are intentionally split into application code, database migrations,
Edge Functions/provider webhooks, and client artifacts. Never put service-role,
payment, store, Cloudflare Stream, or service-account credentials in Flutter
build definitions.

## GitHub environments

Create a protected `staging` environment in the GitHub repository. Require a
reviewer before deployment and restrict it to `main` or signed release tags.

Environment variables (public configuration):

| Name | Purpose |
|---|---|
| `SUPABASE_URL` | Staging project HTTPS URL |
| `FIREBASE_APP_ID` | Firebase web application ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Public messaging sender ID |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `CLOUDFLARE_PAGES_PROJECT` | Existing Pages project name |
| `PUBLIC_APP_URL` | Canonical staging HTTPS origin used in shared links |

Environment secrets:

| Name | Scope |
|---|---|
| `SUPABASE_PUBLISHABLE_KEY` | Public-client key, kept in environment for controlled configuration |
| `FIREBASE_API_KEY` | Firebase public client identifier |
| `FIREBASE_WEB_VAPID_KEY` | Web Push public key |
| `CLOUDFLARE_ACCOUNT_ID` | Pages deployment account |
| `CLOUDFLARE_API_TOKEN` | Pages Edit only; do not grant DNS/account-wide access |

The staging workflow is manual. Supply a reviewed commit SHA or tag; do not deploy
an unreviewed moving branch by habit. The build runs analysis/tests again before
deploying `build/web`. `_headers` and `_redirects` are included in the artifact.

## Supabase deployment order

1. Create separate staging and production projects. Never test destructive
   lifecycle or purchase events against production customer data.
2. Link the CLI to staging and run `supabase db push`. Migrations are ordered and
   CI proves they apply cleanly to PostgreSQL 16 before merge.
3. Configure function secrets from `supabase/functions/README.md`. Use a separate,
   least-privilege credential for every provider where supported.
4. Deploy authenticated functions with gateway JWT verification enabled:
   `playback-session`, `verify-mobile-purchase`, `stripe-checkout`, `admin-stream`,
   `push-device`, `send-push-campaign`, and `account-data`.
5. Deploy provider callbacks with gateway verification disabled only where the
   function independently authenticates the provider: `rewarded-ad-callback`,
   `stripe-webhook`, `apple-store-notifications`, and
   `google-play-notifications`.
6. Set `ALLOWED_ORIGINS` to exact staging/production origins. Never use `*` on
   account, admin, playback, or purchase operations.
7. Register callback URLs in AdMob, Stripe, App Store Connect, Google Cloud Pub/Sub,
   and Firebase, then retain provider test event IDs as evidence.

Database migrations are forward-only. Before production migration, take a
provider backup/PITR checkpoint, review lock/runtime impact, and rehearse on a
production-shaped staging copy. Correct a failed released migration with a new
migration; never edit an already-applied migration.

## Staging smoke test

After deployment, record the commit SHA and verify:

- `/`, `/privacy`, `/terms`, and `/delete-account` return successful HTTPS pages
  with security headers and no mixed content.
- A shared HTTPS episode link opens the matching story on web; `comboreel://home`,
  `comboreel://series/{id}`, and episode links open the installed iOS/Android app.
- Create and confirm an account; verify legal-consent rows, sign-in, sign-out, and
  password reauthentication.
- Load catalogue artwork, a signed HLS stream, subtitles, progress, favourites,
  search, seasons, and the next-episode transition.
- Verify a coin purchase/unlock replay, rewarded-ad SSV, premium purchase/restore,
  Stripe webhook/portal, and provider refund/renewal notifications in test modes.
- Verify push opt-in/out/token refresh/deep link, analytics opt-in/out, Creator
  Studio role enforcement, upload processing, campaign review/send, export, and
  account deletion with and without an active subscription.
- Run Lighthouse and the signed-device matrix in `docs/RELEASE_QA.md`.

## Rollback

For a web regression, stop traffic by promoting the previously known-good
Cloudflare Pages deployment, then preserve the failing deployment and logs for
diagnosis. Do not rebuild an old commit with new dependency resolution; redeploy
its immutable artifact where available.

For an Edge Function regression, redeploy the last known-good function commit.
If a new schema is backward compatible, leave it in place. If data integrity may
be affected, disable the affected operation/provider callback, preserve event
payload IDs, and apply a reviewed forward repair. Restore a database checkpoint
only as an incident decision because it can discard valid post-checkpoint writes.

For mobile, halt phased rollout in App Store Connect/Play Console. Server-side
feature/provider disablement must preserve already-purchased entitlements. Submit
a corrected build with a higher build number; released binaries cannot be replaced.
