class ViewerProgress {
  const ViewerProgress({
    required this.episodeId,
    required this.seriesId,
    required this.seriesTitle,
    required this.episodeTitle,
    required this.episodeNumber,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.completed,
    required this.lastWatchedAt,
  });

  final String episodeId;
  final String seriesId;
  final String seriesTitle;
  final String episodeTitle;
  final int episodeNumber;
  final int positionSeconds;
  final int durationSeconds;
  final bool completed;
  final DateTime lastWatchedAt;

  double get fraction => durationSeconds <= 0
      ? 0
      : (positionSeconds / durationSeconds).clamp(0, 1);
}
