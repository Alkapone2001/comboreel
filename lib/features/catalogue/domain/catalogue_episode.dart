class CatalogueEpisode {
  const CatalogueEpisode({
    required this.id,
    required this.seriesId,
    required this.episodeNumber,
    required this.title,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.isFree,
    required this.coinPrice,
  });

  factory CatalogueEpisode.fromJson(Map<String, dynamic> json) =>
      CatalogueEpisode(
        id: json['id'] as String,
        seriesId: json['series_id'] as String,
        episodeNumber: json['episode_number'] as int,
        title: json['title'] as String,
        durationSeconds: json['duration_seconds'] as int? ?? 0,
        thumbnailUrl: json['thumbnail_url'] as String?,
        isFree: json['is_free'] as bool? ?? false,
        coinPrice: json['coin_price'] as int? ?? 5,
      );

  final String id;
  final String seriesId;
  final int episodeNumber;
  final String title;
  final int durationSeconds;
  final String? thumbnailUrl;
  final bool isFree;
  final int coinPrice;
}
