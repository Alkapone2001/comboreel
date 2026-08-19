# Store review notes — replace every `REQUIRED_` value

## Review contact and account

- Contact name: `REQUIRED_REVIEW_CONTACT_NAME`
- Email: `REQUIRED_REVIEW_CONTACT_EMAIL`
- Phone: `REQUIRED_REVIEW_CONTACT_PHONE`
- Demo email: `REQUIRED_NONEXPIRING_REVIEW_ACCOUNT_EMAIL`
- Demo password: enter only in the private store portal, never commit it here.
- Admin demo account, if Creator Studio is submitted for review: provision an
  Editor-role account separately and enter it only in the private review portal.

## Reviewer path

1. Sign in with the non-expiring review account. The home catalogue and free
   episodes are available immediately.
2. Open a series and play its first free episode. Player controls include pause,
   episode selection, favourite, share, and available subtitles.
3. Open Coins to inspect consumable coin packs and premium subscriptions. Use
   sandbox/test products only. Purchases are verified on ComboReel servers before
   coins or premium access is granted.
4. For a locked episode, test a coin unlock. Where the rewarded-ad test placement
   is available, the grant occurs only after provider server-side verification.
5. Open Profile → Privacy & account to test analytics/push withdrawal, data
   export, and deletion. Active Apple/Google subscriptions display a warning and
   continue until cancelled in the relevant store.
6. Public legal/deletion routes are `REQUIRED_PUBLIC_ORIGIN/privacy`, `/terms`,
   and `/delete-account`.

## Content and provider notes

- Test HLS stream URL: `REQUIRED_REVIEW_TEST_STREAM_URL`
- All submitted series artwork/video must be original or licensed and available
  throughout review. Do not submit the current offline/demo catalogue as evidence
  of licensed production content.
- Apple notification URL: `REQUIRED_APPLE_NOTIFICATION_URL`
- Google RTDN topic/subscription: `REQUIRED_GOOGLE_RTDN_REFERENCE`
- Support can reproduce provider events using the private transaction/event ID;
  never put store credentials or secret API keys in review notes.

## Monetization disclosure

Coins have no cash value and are used only for eligible in-app episode access.
Premium is an auto-renewable subscription where offered. The exact price,
duration, renewal terms, and localized product text are shown by Apple/Google
before purchase. Restore Purchases re-verifies owned subscriptions.
