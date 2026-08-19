import 'dart:async';

import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/core/config/app_config.dart';
import 'package:comboreel/core/services/app_services.dart';
import 'package:comboreel/features/auth/data/account_security_repository.dart';
import 'package:comboreel/features/auth/data/account_profile_repository.dart';
import 'package:comboreel/features/auth/data/offline_auth_repository.dart';
import 'package:comboreel/features/auth/domain/account_profile.dart';
import 'package:comboreel/features/auth/presentation/update_password_screen.dart';
import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign-in screen sends a non-enumerating reset request', (
    tester,
  ) async {
    final security = _FakeAccountSecurityRepository();
    await tester.pumpWidget(ComboReelApp(services: _services(security)));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Account email'),
      'viewer@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(security.requestedEmail, 'viewer@example.com');
    expect(find.textContaining('If an account exists'), findsOneWidget);
  });

  testWidgets('recovery auth event opens the reset-password flow', (
    tester,
  ) async {
    final security = _FakeAccountSecurityRepository();
    addTearDown(security.close);
    await tester.pumpWidget(ComboReelApp(services: _services(security)));
    await tester.pumpAndSettle();

    security.beginRecovery();
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Save new password'), findsOneWidget);
  });

  testWidgets('signed-out viewer can resend email verification', (
    tester,
  ) async {
    final security = _FakeAccountSecurityRepository();
    final profile = _FakeAccountProfileRepository();
    await tester.pumpWidget(
      ComboReelApp(services: _services(security, profile: profile)),
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'pending@example.com',
    );
    await tester.tap(find.text('Resend verification email'));
    await tester.pump();

    expect(profile.resentEmail, 'pending@example.com');
  });

  testWidgets('new password requires length and matching confirmation', (
    tester,
  ) async {
    final security = _FakeAccountSecurityRepository();
    await tester.pumpWidget(
      MaterialApp(home: UpdatePasswordScreen(repository: security)),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'short',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'different',
    );
    await tester.tap(find.text('Save new password'));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(security.updatedPassword, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewSecurePassword!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'NewSecurePassword!',
    );
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(security.updatedPassword, 'NewSecurePassword!');
  });
}

AppServices _services(
  AccountSecurityRepository security, {
  AccountProfileRepository profile =
      const UnavailableAccountProfileRepository(),
}) => AppServices(
  config: const AppConfig(
    supabaseUrl: 'https://example.supabase.co',
    supabasePublishableKey: 'test-publishable-key',
  ),
  authRepository: const OfflineAuthRepository(),
  catalogueRepository: const OfflineCatalogueRepository(),
  viewerLibraryRepository: OfflineViewerLibraryRepository(),
  monetizationRepository: OfflineMonetizationRepository(),
  accountSecurityRepository: security,
  accountProfileRepository: profile,
);

class _FakeAccountSecurityRepository implements AccountSecurityRepository {
  final _recovery = StreamController<void>.broadcast();
  String? requestedEmail;
  String? updatedPassword;

  @override
  Stream<void> get passwordRecoveryRequests => _recovery.stream;

  void beginRecovery() => _recovery.add(null);
  Future<void> close() => _recovery.close();

  @override
  Future<void> requestPasswordReset(String email) async {
    requestedEmail = email;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPassword = newPassword;
  }
}

class _FakeAccountProfileRepository implements AccountProfileRepository {
  String? resentEmail;

  @override
  Future<AccountProfile> currentProfile() async => const AccountProfile(
    displayName: 'Viewer',
    email: 'viewer@example.com',
    emailConfirmed: false,
  );

  @override
  Future<void> requestEmailChange(String email) async {}

  @override
  Future<void> resendEmailConfirmation(String email) async {
    resentEmail = email;
  }

  @override
  Future<AccountProfile> updateDisplayName(String displayName) =>
      currentProfile();
}
