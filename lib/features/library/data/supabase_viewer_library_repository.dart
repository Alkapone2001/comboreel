import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/viewer_progress.dart';
import 'viewer_library_repository.dart';

class SupabaseViewerLibraryRepository implements ViewerLibraryRepository {
  SupabaseViewerLibraryRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> addFavourite({
    required String userId,
    required String seriesId,
  }) => _client.from('favourites').upsert({
    'user_id': userId,
    'series_id': seriesId,
  });

  @override
  Future<void> removeFavourite({
    required String userId,
    required String seriesId,
  }) => _client
      .from('favourites')
      .delete()
      .eq('user_id', userId)
      .eq('series_id', seriesId);

  @override
  Future<Set<String>> favouriteSeriesIds(String userId) async {
    final rows = await _client
        .from('favourites')
        .select('series_id')
        .eq('user_id', userId);
    return rows.map((row) => row['series_id'] as String).toSet();
  }

  @override
  Future<List<ViewerProgress>> recentProgress(
    String userId, {
    int limit = 20,
  }) async {
    final rows = await _client
        .from('watch_progress')
        .select(
          'position_seconds, completed, last_watched_at, '
          'episodes!inner(id, series_id, episode_number, title, duration_seconds, '
          'series!inner(id, title))',
        )
        .eq('user_id', userId)
        .eq('completed', false)
        .order('last_watched_at', ascending: false)
        .limit(limit);
    return rows.map((row) {
      final episode = row['episodes'] as Map<String, dynamic>;
      final series = episode['series'] as Map<String, dynamic>;
      return ViewerProgress(
        episodeId: episode['id'] as String,
        seriesId: episode['series_id'] as String,
        seriesTitle: series['title'] as String,
        episodeTitle: episode['title'] as String,
        episodeNumber: episode['episode_number'] as int,
        positionSeconds: row['position_seconds'] as int? ?? 0,
        durationSeconds: episode['duration_seconds'] as int? ?? 0,
        completed: row['completed'] as bool? ?? false,
        lastWatchedAt: DateTime.parse(row['last_watched_at'] as String),
      );
    }).toList();
  }

  @override
  Future<void> saveProgress({
    required String userId,
    required String episodeId,
    required int positionSeconds,
    required bool completed,
  }) => _client.from('watch_progress').upsert({
    'user_id': userId,
    'episode_id': episodeId,
    'position_seconds': positionSeconds,
    'completed': completed,
    'last_watched_at': DateTime.now().toUtc().toIso8601String(),
  });
}
