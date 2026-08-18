import '../domain/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> get authStateChanges;
  AuthUser? get currentUser;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signOut();
}

class BackendNotConfiguredException implements Exception {
  const BackendNotConfiguredException();
}
