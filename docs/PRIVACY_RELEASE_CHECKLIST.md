# Privacy and account lifecycle release checklist

ComboReel now includes versioned Privacy Policy and Terms screens, mandatory
registration acceptance, append-only consent history, opt-in preference records,
authenticated JSON export, recent-login account deletion, subscription warnings,
push-device shutdown, Stripe customer cleanup, and cascading application-data
deletion.

## Required before public release

- Replace the legal-document operator placeholders with the registered entity,
  postal address, privacy/support email, governing jurisdiction, and governing
  language. Have qualified counsel approve the final text for every launch market.
- Publish the same versioned Privacy Policy and Terms at stable HTTPS URLs and put
  the privacy URL in App Store Connect and Play Console.
- Deploy the web build with SPA rewrites and publish `/privacy`, `/terms`, and
  `/delete-account`. The repository's `web/_redirects` supports Cloudflare Pages
  and Netlify; other hosts must rewrite those routes to `index.html`. Google Play
  requires the functional external deletion resource in addition to the in-app
  flow.
- [x] Add safe Apple and Google subscription-management links to the release UX,
  plus an authenticated Stripe Billing Portal action.
- Configure production URL overrides where needed and verify cancellation wording
  and redirect behavior with Apple, Google, and Stripe sandbox subscriptions.
- Deploy `account-data` with gateway JWT verification enabled. Confirm
  `SUPABASE_SERVICE_ROLE_KEY` is platform-managed and `STRIPE_SECRET_KEY` exists
  only where Stripe billing is enabled.
- Apply migration `202608190009_privacy_lifecycle.sql`, then test new signup,
  preference withdrawal, export, deletion with no subscription, and deletion with
  each active subscription platform against staging.
- Complete Play Data safety and App Store privacy nutrition labels from the actual
  production SDK/configuration inventory. Recheck whenever an SDK or data purpose
  changes.
- Document statutory transaction/fraud retention with counsel. The current app
  database is cascade-deleted; processor backups expire under provider schedules.

## Review evidence to retain

- Screen recording of in-app deletion and the external web route.
- Export fixture demonstrating only the authenticated account is returned.
- Database evidence that profile-linked rows cascade after deletion.
- Consent-history rows for grant and withdrawal, with document versions.
- Screenshots of subscription warning and store cancellation path.
