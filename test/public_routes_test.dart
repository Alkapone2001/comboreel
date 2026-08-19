import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/features/auth/data/auth_repository.dart';
import 'package:comboreel/features/auth/domain/auth_user.dart';
import 'package:comboreel/features/privacy/data/privacy_repository.dart';
import 'package:comboreel/features/privacy/presentation/account_deletion_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only known public paths become initial routes', () {
    expect(
      initialAppRoute(Uri.parse('https://comboreel.example/privacy')),
      '/privacy',
    );
    expect(
      initialAppRoute(Uri.parse('https://comboreel.example/terms')),
      '/terms',
    );
    expect(
      initialAppRoute(Uri.parse('https://comboreel.example/delete-account')),
      '/delete-account',
    );
    expect(
      initialAppRoute(Uri.parse('https://comboreel.example/unknown')),
      '/',
    );
  });

  testWidgets('public deletion route gives signed-out users a secure login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionEntryScreen(
          authRepository: _SignedOutAuthRepository(),
          privacyRepository: const UnavailablePrivacyRepository(),
          backendConfigured: true,
        ),
      ),
    );
    expect(find.text('Delete ComboReel account'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Sign in securely'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}

class _SignedOutAuthRepository implements AuthRepository {
  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();
  @override
  AuthUser? get currentUser => null;
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {}
}
