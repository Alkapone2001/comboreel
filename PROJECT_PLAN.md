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
- [ ] Connect home, series, seasons, and episodes to live repositories
- [x] Build the vertical player interface foundation
- [ ] Connect the player to Cloudflare Stream
- [ ] Store watch progress and Continue Watching state
- [ ] Add subtitles and accessibility controls

### 3. Monetization

- [ ] Define entitlements and a server-verified coin ledger
- [ ] Add locked episode flow and rewarded-ad unlocks
- [ ] Add mobile in-app purchases and subscriptions
- [ ] Add Stripe Checkout and webhooks for web purchases
- [ ] Add restore-purchases and entitlement reconciliation

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

Create a staging Supabase project, apply the reviewed migration, configure authentication URLs, and connect the home catalogue to live repository data with offline/error/loading states.

## Implementation status notes

- Home catalogue content and progress are currently deterministic demo data.
- Series artwork is currently an original abstract gradient treatment, not final licensed artwork.
- The episode player currently demonstrates the intended controls and interaction hierarchy; it does not stream video yet.
- Episode 1–5 free and later episodes locked is represented in the UI, but entitlements are not yet persisted or server verified.
- Discover, Coins, and Profile are functional navigation destinations with intentional placeholders for their upcoming feature milestones.
- Supabase initialization is opt-in through compile-time definitions; no credentials or secret keys are stored in the repository.
- The schema migration has been executed successfully against a clean PostgreSQL 16 container. Live Supabase Auth/RLS integration still requires a staging project.
