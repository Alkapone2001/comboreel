# ComboReel

ComboReel is a Flutter vertical short-drama platform targeting iOS, Android, and web. The current build includes the branded discovery experience, functional navigation, series and locked-episode flows, a vertical-player prototype, Supabase schema, and authentication foundations.

## Requirements

- Flutter 3.47 or a compatible stable release
- Dart 3.13 or compatible
- Chrome for web development
- A Supabase project when testing live backend features
- A Cloudflare Stream account and deployed playback Edge Function for live video
- An AdMob account and deployed rewarded SSV callback for production ad unlocks
- App Store Connect and Google Play products plus server API credentials for mobile purchases
- Stripe products, Checkout, webhook, and Billing Portal configuration for web purchases
- App Store Server Notifications V2 and authenticated Google Play RTDN configuration
- A Cloudflare Stream API token with Stream edit access for Creator Studio uploads
- A Firebase project, APNs key, Web Push certificate, and service account for notifications

## Run the UI prototype

The app intentionally runs without credentials using deterministic demo content:

```powershell
flutter run -d chrome
```

## Run with Supabase staging

Use only the public project URL and publishable key in the client:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Never add secret keys, service-role keys, payment secrets, or webhook secrets to Dart source, build arguments used in public logs, or committed files.

Set the public canonical origin with `--dart-define=PUBLIC_APP_URL=https://...`.
Apple and Google subscription-management pages default to their official HTTPS
account URLs. Release builds may override them with
`APPLE_SUBSCRIPTION_MANAGEMENT_URL` and
`GOOGLE_PLAY_SUBSCRIPTION_MANAGEMENT_URL`; insecure or malformed values are
disabled instead of being opened.
Share sheets use that HTTPS origin and embed a validated `comboreel://` destination;
native builds register the custom scheme for cold and warm deep links.

Android production builds require Java 17+, the Android SDK, and an ignored
`android/key.properties` based on `android/key.properties.example`. Release
configuration never falls back to the debug signing key.

For mobile rewarded ads, provide `ADMOB_ANDROID_REWARDED_AD_UNIT_ID` and
`ADMOB_IOS_REWARDED_AD_UNIT_ID` as Dart defines. The committed manifests contain
Google's development app IDs; replace them with ComboReel's AdMob app IDs before
release, and use only Google's test ad units during development.

Mobile store product IDs are defined in the database migration and native client:
`comboreel.coins.50`, `comboreel.coins.120`, `comboreel.coins.300`,
`comboreel.premium.monthly`, and `comboreel.premium.annual`. Create matching
products in App Store Connect and Play Console before device testing. Store
callbacks are not trusted; `verify-mobile-purchase` must accept a transaction
before Flutter completes it.

Configured web builds use Stripe-hosted Checkout and the Billing Portal. Create
matching Stripe Products and Prices, supply their IDs through `STRIPE_PRICE_MAP`,
and register the public `stripe-webhook` URL for the documented event list. Coin
or premium value is granted only by the signature-verified webhook.

## Creator Studio

Authenticated profiles with the `editor` or `admin` role see **Creator Studio**
in Profile. The responsive web workspace manages series and episodes, verifies
publishing requirements, uploads video directly to Cloudflare with resumable TUS
chunks, and polls encoding status. The browser never receives a Cloudflare API
token; `admin-stream` provisions a one-time upload URL after checking the role.

Deploy `admin-stream` with the existing Supabase secrets plus
`CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_STREAM_API_TOKEN`, and `ALLOWED_ORIGINS`.
Apply `202608190007_admin_content.sql` before deployment. Assign the first admin
through a trusted service-role environment; ordinary authenticated users and
editors cannot change roles.

Creator Studio also exposes consented operations analytics and push campaigns.
Apply `202608190008_analytics_push.sql`, deploy `push-device` and
`send-push-campaign`, and provide the Firebase client values as Dart defines:

```powershell
--dart-define=FIREBASE_API_KEY=... `
--dart-define=FIREBASE_APP_ID=... `
--dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
--dart-define=FIREBASE_PROJECT_ID=... `
--dart-define=FIREBASE_WEB_VAPID_KEY=...
```

The client values are public Firebase identifiers, not service credentials.
Firebase service-account credentials remain only in Edge Function secrets.
Upload an APNs authentication key in Firebase and enable Push Notifications plus
Background Modes for the production App ID before testing iOS delivery.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

## Project layout

- `lib/app`: application shell and navigation ownership
- `lib/core`: configuration, services, and design system
- `lib/features`: feature-first data, domain, and presentation code
- `supabase/migrations`: authoritative database changes
- `test`: widget and domain model tests
- `PROJECT_PLAN.md`: living delivery scope and milestone status
- `docs/ACCESSIBILITY_AUDIT.md`: accessibility findings and release-device checklist

See `supabase/README.md` for database deployment and security guidance.

## Continuous delivery

Every pull request and `main` push runs formatting, analysis, all Flutter tests,
the release/store audits, an optimized web build, all migrations on clean
PostgreSQL 16, and SQL contract tests. The resulting web artifact is retained for
14 days. Staging deployment is an explicitly dispatched, protected-environment
workflow for Cloudflare Pages. See `docs/DEPLOYMENT.md` for variables, least-
privilege secrets, backend ordering, smoke tests, and rollback.
