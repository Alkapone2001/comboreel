import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'privacy_repository.dart';

class SupabasePrivacyRepository implements PrivacyRepository {
  SupabasePrivacyRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<String> exportData() async {
    final response = await _client.functions.invoke(
      'account-data',
      body: {'action': 'export'},
    );
    if (response.status != 200) throw StateError(_error(response.data));
    return const JsonEncoder.withIndent('  ').convert(response.data);
  }

  @override
  Future<AccountDeletionPreview> deletionPreview() async {
    final response = await _client.functions.invoke(
      'account-data',
      body: {'action': 'deletion_preview'},
    );
    if (response.status != 200) throw StateError(_error(response.data));
    final platforms =
        (response.data['active_subscription_platforms'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false);
    return AccountDeletionPreview(activePlatforms: platforms);
  }

  @override
  Future<void> deleteAccount({
    required String password,
    required bool acknowledgedSubscriptions,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw StateError('Sign in again before deleting your account.');
    }
    await _client.auth.signInWithPassword(email: email, password: password);
    final response = await _client.functions.invoke(
      'account-data',
      body: {
        'action': 'delete',
        'acknowledge_active_subscriptions': acknowledgedSubscriptions,
      },
    );
    if (response.status != 200) throw StateError(_error(response.data));
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  String _error(dynamic data) => data is Map && data['error'] != null
      ? data['error'].toString().replaceAll('_', ' ')
      : 'The privacy request could not be completed.';
}
