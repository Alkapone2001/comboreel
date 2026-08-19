# Accessibility audit

Audit target: ComboReel Flutter viewer experience on web, iOS, and Android.
Baseline: WCAG 2.2 AA interaction and contrast expectations, with platform
screen-reader conventions preserved through Material semantics.

## Findings and remediation

- Discovery, navigation, catalogue cards, playback controls, favourites,
  authentication fields, season selectors, and purchase actions use native
  buttons, links, list tiles, form fields, chips, or explicit button semantics.
- Decorative artwork icons are excluded from the semantics tree. Catalogue cards
  expose one concise action label instead of announcing every decorative child.
- Search and notification shortcuts have explicit labels and are reachable in
  logical keyboard order. Keyboard activation is covered by a widget test.
- Loading indicators and error/retry states include spoken context rather than
  relying on animation or colour alone.
- Series metadata uses wrapping layouts. Home hero and card sections expand for
  large text, Discover cards grow with text scale, and the critical Home → Series
  journey is tested at 200% text on a 390 × 844 logical-pixel viewport without
  clipped or overflowing content.
- Body/muted text (`#9D9DA8`) on the primary background (`#09090C`) exceeds the
  4.5:1 normal-text threshold. Coral, gold, and white status/action treatments
  also exceed 4.5:1 on primary dark surfaces. Information is not encoded by
  colour alone; status text, icons, or control state accompany it.
- Touch controls are Material controls with at least the platform minimum target
  size. Player controls include tooltips and state-specific labels.
- Fake engagement counts and inactive viewer controls were removed. Save,
  share, episode-return, search, and notification shortcuts now perform their
  described actions, preventing misleading assistive announcements.

## Automated evidence

`test/accessibility_test.dart` verifies meaningful semantics, keyboard traversal
and activation, 200% dynamic text, season selection, and absence of Flutter
layout exceptions. The complete test suite also covers authentication, locked
episodes, subtitles, purchases, navigation, and My List interactions.

## Release-device confirmation

Before store submission, repeat the critical journey on the final signed builds
with VoiceOver and TalkBack, hardware keyboard focus indicators, iOS Larger Text,
Android largest font/display size, and browser zoom at 200%. Record device/OS
versions and any provider-native purchase or ad surfaces in the release QA log.
