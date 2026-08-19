import 'package:comboreel/features/auth/data/account_profile_repository.dart';
import 'package:comboreel/features/auth/domain/account_profile.dart';
import 'package:comboreel/features/auth/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile details saves the display name', (tester) async {
    final repository = _FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfileScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Display name'),
      'Drama Fan',
    );
    await tester.tap(find.text('Save display name'));
    await tester.pumpAndSettle();

    expect(repository.savedDisplayName, 'Drama Fan');
  });

  testWidgets('unverified profile can resend and request an email change', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfileScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verification required'), findsOneWidget);
    await tester.tap(find.text('Resend verification'));
    await tester.pump();
    expect(repository.resendCalls, 1);

    await tester.tap(find.text('Change email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'New email address'),
      'new@example.com',
    );
    await tester.tap(find.text('Send confirmation'));
    await tester.pumpAndSettle();

    expect(repository.requestedEmail, 'new@example.com');
  });
}

class _FakeProfileRepository implements AccountProfileRepository {
  String? savedDisplayName;
  String? requestedEmail;
  int resendCalls = 0;

  AccountProfile profile = const AccountProfile(
    displayName: 'Viewer',
    email: 'viewer@example.com',
    emailConfirmed: false,
  );

  @override
  Future<AccountProfile> currentProfile() async => profile;

  @override
  Future<void> requestEmailChange(String email) async {
    requestedEmail = email;
    profile = AccountProfile(
      displayName: profile.displayName,
      email: profile.email,
      emailConfirmed: profile.emailConfirmed,
      pendingEmail: email,
    );
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    resendCalls++;
  }

  @override
  Future<AccountProfile> updateDisplayName(String displayName) async {
    savedDisplayName = displayName;
    profile = AccountProfile(
      displayName: displayName,
      email: profile.email,
      emailConfirmed: profile.emailConfirmed,
      pendingEmail: profile.pendingEmail,
    );
    return profile;
  }
}
