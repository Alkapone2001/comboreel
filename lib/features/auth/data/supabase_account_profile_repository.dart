import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/account_profile.dart';
import 'account_profile_repository.dart';

class SupabaseAccountProfileRepository implements AccountProfileRepository {
  const SupabaseAccountProfileRepository(this._client);

  final supabase.SupabaseClient _client;

  String get _redirectTo =>
      kIsWeb ? Uri.base.origin : 'comboreel://auth-callback';

  supabase.User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to manage your profile.');
    return user;
  }

  @override
  Future<AccountProfile> currentProfile() async {
    final user = _user;
    final row = await _client
        .from('profiles')
        .select('display_name, avatar_url')
        .eq('id', user.id)
        .single();
    return _map(user, row);
  }

  @override
  Future<AccountProfile> updateDisplayName(String displayName) async {
    final user = _user;
    final value = displayName.trim();
    if (value.isEmpty || value.length > 60) {
      throw StateError('Display name must be between 1 and 60 characters.');
    }
    final row = await _client
        .from('profiles')
        .update({'display_name': value})
        .eq('id', user.id)
        .select('display_name, avatar_url')
        .single();
    return _map(user, row);
  }

  @override
  Future<void> requestEmailChange(String email) async {
    await _client.auth.updateUser(
      supabase.UserAttributes(email: email.trim()),
      emailRedirectTo: _redirectTo,
    );
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    await _client.auth.resend(
      type: supabase.OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _redirectTo,
    );
  }

  AccountProfile _map(supabase.User user, Map<String, dynamic> row) =>
      AccountProfile(
        displayName: row['display_name'] as String? ?? '',
        email: user.email,
        emailConfirmed: user.emailConfirmedAt != null,
        avatarUrl: row['avatar_url'] as String?,
        pendingEmail: user.newEmail,
      );
}
