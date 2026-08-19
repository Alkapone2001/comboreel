class CatalogueSeries {
  const CatalogueSeries({
    required this.id,
    required this.slug,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.heroUrl,
    required this.originalLanguage,
    required this.releaseYear,
    required this.isFeatured,
    this.ageRating,
    this.genres = const [],
    this.episodeCount = 0,
  });

  factory CatalogueSeries.fromJson(Map<String, dynamic> json) =>
      CatalogueSeries(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        synopsis: json['synopsis'] as String? ?? '',
        posterUrl: json['poster_url'] as String?,
        heroUrl: json['hero_url'] as String?,
        originalLanguage: json['original_language'] as String? ?? 'en',
        releaseYear: json['release_year'] as int?,
        isFeatured: json['is_featured'] as bool? ?? false,
        ageRating: json['age_rating'] as String?,
        genres: _genres(json),
        episodeCount: _episodeCount(json),
      );

  final String id;
  final String slug;
  final String title;
  final String synopsis;
  final String? posterUrl;
  final String? heroUrl;
  final String originalLanguage;
  final int? releaseYear;
  final bool isFeatured;
  final String? ageRating;
  final List<String> genres;
  final int episodeCount;

  static List<String> _genres(Map<String, dynamic> json) {
    final rows = json['series_genres'] as List? ?? const [];
    return rows
        .map((row) => (row as Map)['genres'])
        .whereType<Map>()
        .map((genre) => genre['name'] as String?)
        .whereType<String>()
        .toList();
  }

  static int _episodeCount(Map<String, dynamic> json) {
    final rows = json['episodes'] as List? ?? const [];
    if (rows.isEmpty) return json['episode_count'] as int? ?? 0;
    final first = rows.first;
    return first is Map ? first['count'] as int? ?? 0 : 0;
  }
}
