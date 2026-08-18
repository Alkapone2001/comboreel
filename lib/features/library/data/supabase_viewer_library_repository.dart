import 'package:supabase_flutter/supabase_flutter.dart';

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
