import '../domain/viewer_progress.dart';

abstract interface class ViewerLibraryRepository {
  Future<void> addFavourite({required String userId, required String seriesId});
  Future<void> removeFavourite({
    required String userId,
    required String seriesId,
  });
  Future<Set<String>> favouriteSeriesIds(String userId);
  Future<List<ViewerProgress>> recentProgress(String userId, {int limit = 20});
  Future<void> saveProgress({
    required String userId,
    required String episodeId,
    required int positionSeconds,
    required bool completed,
  });
}
