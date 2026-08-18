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
}
