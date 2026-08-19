# ComboReel Project Plan

## Product vision

ComboReel is an original vertical short-drama streaming service for iOS, Android, and web. It combines cinematic discovery with short episodes, rewarded unlocks, coins, and premium access.

## Technical direction

- Client: Flutter with feature-first modules
- Authentication and data: Supabase
- Video delivery: Cloudflare Stream with signed playback URLs
- Mobile monetization: AdMob rewarded ads and Apple/Google in-app purchases
- Web monetization: Stripe
- Notifications: Firebase Cloud Messaging
- Product analytics: PostHog or Firebase Analytics
- Admin: Flutter web, sharing domain models and Supabase services where practical

## Architecture

Features are separated into `data`, `domain`, and `presentation` layers. Shared styling, configuration, networking, and reusable components live under `lib/core`. External services will sit behind repositories so screens remain testable and vendors can be changed deliberately.

## Delivery milestones

### 1. Foundation and visual prototype — in progress

- [x] Initialize Flutter for Android, iOS, and web
- [x] Establish the dark cinematic design system
- [x] Build a responsive branded home/discovery screen
- [x] Add initial widget coverage
- [ ] Replace abstract demo artwork with licensed or original assets
- [x] Add functional bottom navigation and screen shells

### 2. Catalogue and playback

- [x] Define the initial Supabase schema, indexes, triggers, and RLS policies
- [x] Add environment-based Supabase bootstrap and authentication repository
- [x] Build sign-in, registration, signed-in, and offline profile states
- [x] Define typed catalogue and viewer-library repositories
- [x] Connect home and episode lists to offline/Supabase repository composition
- [x] Build repository-backed Discover search with loading, empty, and error states
- [ ] Add seasons and replace all remaining demo-only presentation metadata
- [x] Build the vertical player interface foundation
- [x] Add the signed Cloudflare HLS session boundary and Flutter video lifecycle
- [ ] Verify Cloudflare Stream playback against the staging account
- [x] Store watch progress and drive Continue Watching through viewer repositories
- [x] Add favourite toggles and a repository-backed My List screen
- [x] Add selectable WebVTT subtitle tracks and player loading/error states
- [ ] Complete screen-reader, focus, contrast, and dynamic-text accessibility audit

### 3. Monetization

- [x] Define entitlements and a server-verified coin ledger
- [x] Add atomic, idempotent coin-based episode unlocks
- [x] Connect rewarded-ad verification and unlocks
- [x] Add mobile in-app purchases and subscriptions
- [x] Add Stripe Checkout and webhooks for web purchases
- [ ] Add provider notifications and full refund/renewal reconciliation

### 4. Admin and operations

- [ ] Build role-protected series and episode management
- [ ] Add upload workflow and Cloudflare processing status
- [ ] Add catalogue publishing controls
- [ ] Add analytics dashboards and push campaigns

### 5. Release readiness

- [ ] Privacy policy, terms, consent, and account deletion
- [ ] Performance, security, and device testing
- [ ] Store assets and review preparation
- [ ] Web deployment followed by iOS and Android release

## MVP boundaries

The MVP includes accounts, catalogue/search, vertical playback, favourites, watch history, free/locked episodes, rewarded unlocks, coins, premium subscriptions, subtitles, basic admin, analytics, and notifications. Comments, creator uploads, offline downloads, and algorithmic recommendations remain post-MVP.

## Immediate next step

Provision staging Supabase, Cloudflare, and AdMob resources; deploy both Edge Functions, configure private test streams and the AdMob SSV callback, then run signed-stream and rewarded-unlock tests on real iOS/Android devices.

## Implementation status notes

- Offline mode uses deterministic catalogue/progress data; configured builds query Supabase repositories.
- Series artwork is currently an original abstract gradient treatment, not final licensed artwork.
- The episode player streams signed HLS sessions when providers are configured and uses a deterministic visual fallback offline.
- Episode 1–5 free and later episodes locked is represented in the UI; coin and rewarded-ad entitlements are persisted and server verified.
- Discover, Profile, wallet history, coin unlocks, rewarded unlocks, localized mobile products, subscription purchases, and restore have repository-backed flows. Live store validation awaits provider provisioning.
- Supabase initialization is opt-in through compile-time definitions; no credentials or secret keys are stored in the repository.
- The schema migration has been executed successfully against a clean PostgreSQL 16 container. Live Supabase Auth/RLS integration still requires a staging project.
- Home and series episode lists now load through repository contracts and include loading, empty, and failure behavior. Offline mode supplies deterministic content; configured builds query published Supabase rows.
- Favourites, My List, player progress saves, and Continue Watching now share one viewer-library contract with offline and Supabase implementations.
- Coin spends and entitlement grants are atomic database operations with idempotency. SQL contract coverage proves coin and rewarded-ad replay safety. Live rewards remain disabled until AdMob and the SSV callback are configured.
- Rewarded ads use short-lived episode claims and wait for a Google-signed SSV callback before granting access. The app uses development identifiers until production AdMob resources and consent handling are configured.
- Mobile purchases use Apple/Google server APIs and a replay-safe fulfillment RPC; Flutter consumes/completes transactions only after verification. Product creation, agreements, tax/banking setup, and sandbox-device validation remain provider tasks.
- Restore Purchases re-verifies owned subscriptions; App Store Server Notifications and Google RTDN are still required for immediate refund, revocation, and renewal reconciliation while the app is closed.
- Web purchases use authenticated Stripe Checkout, a raw-body signature-verified webhook, event/session idempotency, and the Stripe Billing Portal. Live products and endpoints still require provider provisioning.
- Playback sessions are authorized server-side and return short-lived, non-cacheable signed Cloudflare HLS URLs. Flutter includes HLS lifecycle, resume persistence, subtitles, and offline/error behavior; provider staging verification is still required.
