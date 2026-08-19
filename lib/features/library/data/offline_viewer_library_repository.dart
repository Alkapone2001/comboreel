import '../domain/viewer_progress.dart';
import 'viewer_library_repository.dart';

class OfflineViewerLibraryRepository implements ViewerLibraryRepository {
  final Set<String> _favourites = {};
  final Map<String, ViewerProgress> _progress = {
    'demo-bound-by-a-secret-episode-1': ViewerProgress(
      episodeId: 'demo-bound-by-a-secret-episode-1',
      seriesId: 'demo-bound-by-a-secret',
      seriesTitle: 'Bound by a Secret',
      episodeTitle: 'The Unexpected Guest',
      episodeNumber: 1,
      positionSeconds: 29,
      durationSeconds: 92,
      completed: false,
      lastWatchedAt: DateTime.fromMillisecondsSinceEpoch(1787090000000),
    ),
  };

  @override
  Future<void> addFavourite({
    required String userId,
    required String seriesId,
  }) async {
    _favourites.add(seriesId);
  }

  @override
  Future<void> removeFavourite({
    required String userId,
    required String seriesId,
  }) async {
    _favourites.remove(seriesId);
  }

  @override
  Future<Set<String>> favouriteSeriesIds(String userId) async =>
      Set.unmodifiable(_favourites);

  @override
  Future<List<ViewerProgress>> recentProgress(
    String userId, {
    int limit = 20,
  }) async {
    final rows = _progress.values.where((item) => !item.completed).toList()
      ..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return rows.take(limit).toList();
  }

  @override
  Future<void> saveProgress({
    required String userId,
    required String episodeId,
    required int positionSeconds,
    required bool completed,
  }) async {
    final existing = _progress[episodeId];
    _progress[episodeId] = ViewerProgress(
      episodeId: episodeId,
      seriesId: existing?.seriesId ?? 'demo-bound-by-a-secret',
      seriesTitle: existing?.seriesTitle ?? 'Bound by a Secret',
      episodeTitle: existing?.episodeTitle ?? 'The Unexpected Guest',
      episodeNumber: existing?.episodeNumber ?? 1,
      positionSeconds: positionSeconds,
      durationSeconds: existing?.durationSeconds ?? 92,
      completed: completed,
      lastWatchedAt: DateTime.now().toUtc(),
    );
  }
}
