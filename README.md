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

See `supabase/README.md` for database deployment and security guidance.
