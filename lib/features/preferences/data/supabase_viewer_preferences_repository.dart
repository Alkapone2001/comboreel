import 'package:supabase_flutter/supabase_flutter.dart';

import 'viewer_preferences_repository.dart';

class SupabaseViewerPreferencesRepository
    implements ViewerPreferencesRepository {
  const SupabaseViewerPreferencesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> preferredSubtitleLanguage() async {
    final user = _client.auth.currentUser;
    if (user == null) return 'en';
    final profile = await _client
        .from('profiles')
        .select('preferred_language')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['preferred_language'] as String? ?? 'en';
  }

  @override
  Future<void> setPreferredSubtitleLanguage(String languageCode) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to save this preference.');
    await _client
        .from('profiles')
        .update({'preferred_language': languageCode})
        .eq('id', user.id);
  }
}
