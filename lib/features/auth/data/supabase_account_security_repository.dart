import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'account_security_repository.dart';

class SupabaseAccountSecurityRepository implements AccountSecurityRepository {
  const SupabaseAccountSecurityRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Stream<void> get passwordRecoveryRequests => _client.auth.onAuthStateChange
      .where(
        (event) => event.event == supabase.AuthChangeEvent.passwordRecovery,
      )
      .map((_) {});

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? Uri.base.origin : 'comboreel://auth-callback',
      );

  @override
  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(supabase.UserAttributes(password: newPassword));
}
