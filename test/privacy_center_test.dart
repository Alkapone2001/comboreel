import 'package:comboreel/features/privacy/data/privacy_repository.dart';
import 'package:comboreel/features/privacy/presentation/privacy_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('privacy center exposes policy, export, and deletion controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyCenterScreen(repository: _FakePrivacyRepository()),
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
    expect(find.text('Delete permanently'), findsOneWidget);
  });
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
