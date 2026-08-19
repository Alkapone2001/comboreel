import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/playback_session.dart';
import 'playback_repository.dart';

class SupabasePlaybackRepository implements PlaybackRepository {
  SupabasePlaybackRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<PlaybackSession> createSession(String episodeId) async {
    final response = await _client.functions.invoke(
      'playback-session',
      body: {'episode_id': episodeId},
    );
    final data = response.data as Map<String, dynamic>;
    if (response.status != 200) {
      throw PlaybackAccessException(
        data['error'] as String? ?? 'playback_failed',
      );
    }
    final subtitleRows = data['subtitles'] as List<dynamic>? ?? const [];
    return PlaybackSession(
      hlsUrl: Uri.parse(data['hls_url'] as String),
      expiresAt: DateTime.parse(data['expires_at'] as String),
      subtitles: subtitleRows.map((value) {
        final row = value as Map<String, dynamic>;
        return SubtitleTrack(
          languageCode: row['language_code'] as String,
          label: row['label'] as String,
          vttUrl: Uri.parse(row['vtt_url'] as String),
          isDefault: row['is_default'] as bool? ?? false,
        );
      }).toList(),
    );
  }
}
