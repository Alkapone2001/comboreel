import 'package:flutter/material.dart';

const privacyVersion = '2026-08-19';
const termsVersion = '2026-08-19';

enum LegalDocument { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final privacy = document == LegalDocument.privacy;
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? 'Privacy Policy' : 'Terms of Use')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            Text(
              'Effective ${privacy ? privacyVersion : termsVersion}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 18),
            ..._sections(context, privacy ? _privacySections : _termsSections),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    List<(String, String)> sections,
  ) => [
    for (final section in sections) ...[
      Text(section.$1, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(section.$2, style: const TextStyle(height: 1.55)),
      const SizedBox(height: 22),
    ],
  ];
}

const _privacySections = <(String, String)>[
  (
    'Who operates ComboReel',
    'ComboReel is the controller of account and viewing data. The legal operator name, postal address, privacy contact, and public policy URL must be supplied in the release configuration before public launch.',
  ),
  (
    'Data we use',
    'We use account details, profile preferences, favourites, watch progress, entitlements, coin ledger entries, purchase and subscription status, consent history, device notification registration, and optional first-party usage events. Payment card details stay with the payment provider. We do not sell personal data.',
  ),
  (
    'Why we use it',
    'We process data to create and secure accounts, deliver and remember content, fulfil purchases, prevent fraud, provide support, meet legal obligations, and—with separate opt-in consent—measure product use or send story notifications.',
  ),
  (
    'Providers and transfers',
    'Supabase hosts authentication and application data; Cloudflare delivers video; Apple, Google, Stripe, Firebase, and AdMob support purchases, messaging, and advertising where enabled. These providers process limited data under their own terms and may process it outside your country using applicable safeguards.',
  ),
  (
    'Control and retention',
    'Analytics and story notifications are off until enabled and can be withdrawn in Profile. Account data is retained while the account exists, then deleted except narrowly required fraud, transaction, tax, or legal records. Backups expire on the hosting provider’s schedule.',
  ),
  (
    'Your choices',
    'The Privacy Center provides a portable JSON copy and account deletion. Depending on your location, you may also request access, correction, restriction, objection, portability, or erasure. Deleting ComboReel does not cancel Apple or Google subscriptions; cancel those with the relevant store.',
  ),
  (
    'Security, age, and changes',
    'We use access controls, encrypted transport, short-lived playback access, and server verification. No service is risk-free. ComboReel is not directed to children under 13; local digital-consent ages may be higher. Material policy changes will be identified by a new version and effective date.',
  ),
];

const _termsSections = <(String, String)>[
  (
    'Using ComboReel',
    'You must provide accurate account information, protect your credentials, meet the minimum age required where you live, and use the service only lawfully. You may not copy, scrape, redistribute, bypass access controls, interfere with the service, or misuse another person’s account.',
  ),
  (
    'Content licence',
    'ComboReel grants a personal, limited, non-exclusive, non-transferable, revocable licence to stream available content for private use. ComboReel and its licensors retain all intellectual-property rights.',
  ),
  (
    'Purchases, coins, and subscriptions',
    'Prices and renewal terms are shown before purchase. Coins are a limited in-service licence: they have no cash value, cannot be transferred, and are not redeemable outside ComboReel except where law requires. Mobile billing, cancellation, and refunds are handled under Apple or Google rules; web billing is handled through Stripe and applicable law.',
  ),
  (
    'Availability and termination',
    'Titles, features, and availability can change. We may suspend access for security, fraud, unlawful use, or material breach. You can delete your account at any time, but account deletion does not itself cancel an Apple or Google subscription.',
  ),
  (
    'Disclaimers and liability',
    'The service is provided with reasonable care but without guarantees of uninterrupted availability. Nothing in these terms excludes consumer rights or liability that cannot legally be excluded. Any limitation applies only to the maximum extent permitted by law.',
  ),
  (
    'Governing details and contact',
    'The governing entity, jurisdiction, support email, postal address, and public Terms URL must be completed in the release configuration before public launch. If translated terms conflict, the designated governing-language version will control where legally permitted.',
  ),
];
