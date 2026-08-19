import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/core/config/app_config.dart';
import 'package:comboreel/core/services/app_services.dart';
import 'package:comboreel/features/auth/data/auth_repository.dart';
import 'package:comboreel/features/auth/domain/auth_user.dart';
import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('configured backend presents sign in and registration forms', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final services = AppServices(
      config: const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'test-publishable-key',
      ),
      authRepository: repository,
      catalogueRepository: const OfflineCatalogueRepository(),
      viewerLibraryRepository: OfflineViewerLibraryRepository(),
      monetizationRepository: OfflineMonetizationRepository(),
    );

    await tester.pumpWidget(ComboReelApp(services: services));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Join ComboReel'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(repository.signUpCalls, 0);
  });
}

class _FakeAuthRepository implements AuthRepository {
  int signUpCalls = 0;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

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
  }) async {
    signUpCalls++;
  }
}
