import 'package:supabase_flutter/supabase_flutter.dart';

import 'viewer_preferences_repository.dart';

class SupabaseViewerPreferencesRepository
    implements ViewerPreferencesRepository {
  const SupabaseViewerPreferencesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PlaybackPreferences> playbackPreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) return const PlaybackPreferences();
    final profile = await _client
        .from('profiles')
        .select(
          'preferred_language, subtitles_enabled, playback_muted, playback_speed',
        )
        .eq('id', user.id)
        .maybeSingle();
    return PlaybackPreferences(
      subtitleLanguage: profile?['preferred_language'] as String? ?? 'en',
      subtitlesEnabled: profile?['subtitles_enabled'] as bool? ?? true,
      muted: profile?['playback_muted'] as bool? ?? false,
      speed: (profile?['playback_speed'] as num?)?.toDouble() ?? 1,
    );
  }

  @override
  Future<String> preferredSubtitleLanguage() async =>
      (await playbackPreferences()).subtitleLanguage;

  @override
  Future<void> setPreferredSubtitleLanguage(String languageCode) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to save this preference.');
    await _client
        .from('profiles')
        .update({'preferred_language': languageCode, 'subtitles_enabled': true})
        .eq('id', user.id);
  }

  @override
  Future<void> setSubtitlePreference({
    required bool enabled,
    String? languageCode,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to save this preference.');
    await _client
        .from('profiles')
        .update({
          'subtitles_enabled': enabled,
          'preferred_language': ?languageCode,
        })
        .eq('id', user.id);
  }

  @override
  Future<void> setPlaybackControls({
    required bool muted,
    required double speed,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to save this preference.');
    await _client
        .from('profiles')
        .update({'playback_muted': muted, 'playback_speed': speed})
        .eq('id', user.id);
  }
}
