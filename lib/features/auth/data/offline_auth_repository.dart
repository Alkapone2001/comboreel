import '../domain/auth_user.dart';
import 'auth_repository.dart';

class OfflineAuthRepository implements AuthRepository {
  const OfflineAuthRepository();

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(const BackendNotConfiguredException());

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => Future.error(const BackendNotConfiguredException());
}
