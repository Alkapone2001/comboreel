# Release security, performance, and device QA

Run the automated local gate from the repository root:

```powershell
$env:PATH="$env:LOCALAPPDATA\FlutterSDK\flutter\bin;$env:PATH"
flutter pub get
dart run tool/release_audit.dart
flutter analyze
flutter test
flutter build web --release
dart run tool/release_audit.dart
```

The audit rejects cleartext Android networking, debug release signing, committed
keystores, server-secret names in Flutter, wildcard CORS on account export/deletion,
missing recent-login deletion enforcement, missing public-route rewrites/security
headers, and a release JavaScript bundle over 4 MiB.

## Security review status

- Android release networking explicitly requests `INTERNET` and disables cleartext.
- Android release signing reads ignored `android/key.properties`; it never falls
  back to the debug key. Production key generation and secure CI secret injection
  remain release-operator tasks.
- iOS uses App Transport Security defaults; no arbitrary-load exception is present.
- Secrets remain in Edge Function environments. Flutter contains only public
  Supabase/Firebase identifiers supplied at build time.
- Account export/deletion web CORS is restricted by `ALLOWED_ORIGINS`, and deletion
  requires password reauthentication plus a JWT issued within ten minutes.
- Web hosting metadata supplies no-sniff, referrer, permissions, framing, and
  entry/service-worker cache controls on compatible hosts.
- The resumable upload client is on `tusc` 4.x and is explicitly closed after use;
  version 4 adds transport retries and fixes resume/corruption edge cases.

## Signed-device matrix required before checking the milestone complete

| Area | iPhone/iPad | Android phone/tablet | Web |
|---|---|---|---|
| Install, cold/warm launch, rotation, background/resume | Required | Required | Desktop/mobile browsers |
| VoiceOver/TalkBack, keyboard, 200% text | Required | Required | Keyboard/screen reader |
| HLS startup, seek, subtitles, network loss/recovery | Required | Required | Chrome/Safari/Firefox/Edge |
| Apple/Google/Stripe purchase, restore, refund lifecycle | Apple sandbox | Play license tester | Stripe test mode |
| Rewarded ad grant, dismissal, replay protection | Test device | Test device | Not applicable |
| Push opt-in/out, token refresh, deep link | APNs sandbox | FCM test | Supported browser |
| Export, deletion, active-subscription warning | Required | Required | Direct `/delete-account` |

Record device model, OS/browser version, build SHA, expected/actual result,
screenshots or video, and provider transaction/event IDs. Do not use production
payments or real customer data for QA.

Android release compilation is enforced in CI with Java 17 and the hosted
Android SDK. Each run generates an isolated, two-day CI-only signing key, builds
both an APK and App Bundle, verifies the APK signature with `apksigner`, and
uploads immutable SHA-named artifacts for 14 days. These artifacts prove release
compilation and permit internal installation, but must never be uploaded to a
store. Store submission still requires the protected production upload key via
ignored `android/key.properties` and signed-device execution of the matrix above.

The current Windows workstation exposes Java 8 and no Android SDK. Local device
claims must not be signed off here until the operator installs the supported
toolchain and personally accepts the Android SDK license agreement.

## Performance evidence required on release hardware

- Capture Flutter DevTools performance traces for cold launch, home scrolling,
  opening details, player startup, and vertical episode transitions.
- Target no sustained jank: 16.7 ms frame budget at 60 Hz and 8.3 ms at 120 Hz.
- Record p50/p95 playback-session latency and video time-to-first-frame on Wi-Fi,
  4G/5G, and constrained networking.
- Verify memory stabilizes after repeatedly opening/closing ten episodes and after
  a resumable upload; confirm players, upload HTTP clients, and subscriptions close.
- Run Lighthouse against the deployed web origin and retain the report. The local
  4 MiB JavaScript ceiling is a regression guard, not proof of field performance.
