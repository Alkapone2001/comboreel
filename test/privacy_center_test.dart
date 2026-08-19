import 'package:comboreel/features/privacy/data/privacy_repository.dart';
import 'package:comboreel/features/privacy/data/subscription_management_service.dart';
import 'package:comboreel/features/privacy/presentation/privacy_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('subscription provider aliases normalize to safe destinations', () {
    expect(SupabaseSubscriptionManagementService.normalize('ios'), 'apple');
    expect(
      SupabaseSubscriptionManagementService.normalize('google_play'),
      'google',
    );
    expect(SupabaseSubscriptionManagementService.normalize('web'), 'stripe');
    expect(SupabaseSubscriptionManagementService.normalize('unknown'), '');
  });

  test('subscription manager rejects insecure configured destinations', () {
    final service = SupabaseSubscriptionManagementService(
      SupabaseClient('https://example.supabase.co', 'public-test-key'),
      appleUrl: 'http://apps.example.test/subscriptions',
      googlePlayUrl: 'javascript:alert(1)',
    );
    expect(service.supports('apple'), isFalse);
    expect(service.supports('google'), isFalse);
    expect(service.supports('stripe'), isTrue);
    expect(service.supports('unknown'), isFalse);
  });

  testWidgets('privacy center exposes policy, export, and deletion controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyCenterScreen(
          repository: _FakePrivacyRepository(),
          subscriptionManagementService: _FakeSubscriptionManager(),
        ),
      ),
    );
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Permanently delete account?'), findsOneWidget);
    expect(find.textContaining('google'), findsOneWidget);
    expect(find.text('Manage in Google Play'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);

    await tester.tap(find.text('Manage in Google Play'));
    await tester.pump();
    expect(_FakeSubscriptionManager.managedPlatform, 'google');
  });
}

class _FakeSubscriptionManager implements SubscriptionManagementService {
  static String? managedPlatform;

  @override
  String labelFor(String platform) => 'Manage in Google Play';

  @override
  Future<void> manage(String platform) async => managedPlatform = platform;

  @override
  bool supports(String platform) => platform == 'google';
}

class _FakePrivacyRepository implements PrivacyRepository {
  @override
  Future<AccountDeletionPreview> deletionPreview() async =>
      const AccountDeletionPreview(activePlatforms: ['google']);
  @override
  Future<void> deleteAccount({
    required String password,
    required bool acknowledgedSubscriptions,
  }) async {}
  @override
  Future<String> exportData() async => '{}';
}
