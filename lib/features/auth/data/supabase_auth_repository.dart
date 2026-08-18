import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/auth_user.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  AuthUser? _mapUser(supabase.User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  Stream<AuthUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
