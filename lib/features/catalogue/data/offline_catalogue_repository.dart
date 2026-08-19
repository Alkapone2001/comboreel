import '../domain/catalogue_episode.dart';
import '../domain/catalogue_series.dart';
import '../domain/catalogue_season.dart';
import 'catalogue_repository.dart';

class OfflineCatalogueRepository
    implements CatalogueRepository, SeasonCatalogueRepository {
  const OfflineCatalogueRepository();

  static const _series = [
    CatalogueSeries(
      id: 'demo-bound-by-a-secret',
      slug: 'bound-by-a-secret',
      title: 'Bound by a Secret',
      synopsis: 'A guarded heiress and the stranger hired to protect her uncover a secret that ties their families together.',
      posterUrl: 'assets/artwork/bound-by-a-secret-poster.jpg',
      heroUrl: 'assets/artwork/bound-by-a-secret-hero.jpg',
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: true,
      ageRating: '16+',
      genres: ['Romance', 'Mystery'],
      episodeCount: 42,
    ),
    CatalogueSeries(
      id: 'demo-stolen-vows',
      slug: 'stolen-vows',
      title: 'Stolen Vows',
      synopsis: 'Two rivals are trapped in an agreement neither expected.',
      posterUrl: 'assets/artwork/stolen-vows-poster.jpg',
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: false,
      ageRating: '13+',
      genres: ['Romance', 'Drama'],
      episodeCount: 36,
    ),
    CatalogueSeries(
      id: 'demo-the-alibi',
      slug: 'the-alibi',
      title: 'The Alibi',
      synopsis: 'One lie pulls a detective into a dangerous conspiracy.',
      posterUrl: 'assets/artwork/the-alibi-poster.jpg',
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: false,
      ageRating: '16+',
      genres: ['Crime', 'Thriller'],
      episodeCount: 36,
    ),
    CatalogueSeries(
      id: 'demo-second-chance-ceo',
      slug: 'second-chance-ceo',
      title: 'Second Chance CEO',
      synopsis: 'A broken promise returns with a powerful new identity.',
      posterUrl: 'assets/artwork/second-chance-ceo-poster.jpg',
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: false,
      ageRating: '13+',
      genres: ['Romance', 'Family Drama'],
      episodeCount: 40,
    ),
  ];

  @override
  Future<List<CatalogueSeries>> featuredSeries() async =>
      _series.where((item) => item.isFeatured).toList();

  @override
  Future<List<CatalogueSeries>> latestSeries({int limit = 20}) async =>
      _series.take(limit).toList();

  @override
  Future<List<CatalogueSeries>> searchSeries(String query) async {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return latestSeries();
    return _series
        .where((item) => item.title.toLowerCase().contains(value))
        .toList();
  }

  @override
  Future<CatalogueSeries?> seriesBySlug(String slug) async {
    for (final item in _series) {
      if (item.slug == slug) return item;
    }
    return null;
  }

  @override
  Future<List<CatalogueEpisode>> episodesForSeries(String seriesId) async =>
      List.generate(
        42,
        (index) => CatalogueEpisode(
          id: '$seriesId-episode-${index + 1}',
          seriesId: seriesId,
          episodeNumber: index + 1,
          title: _episodeTitle(index + 1),
          durationSeconds: 92 + (index % 18),
          thumbnailUrl: null,
          isFree: index < 5,
          coinPrice: 5,
          seasonId: '$seriesId-season-${(index ~/ 14) + 1}',
          seasonNumber: (index ~/ 14) + 1,
          seriesTitle: _series
              .where((series) => series.id == seriesId)
              .firstOrNull
              ?.title,
          synopsis: _episodeSynopsis(index + 1),
        ),
      );

  @override
  Future<List<CatalogueSeason>> seasonsForSeries(String seriesId) async =>
      List.generate(
        3,
        (index) => CatalogueSeason(
          id: '$seriesId-season-${index + 1}',
          seriesId: seriesId,
          number: index + 1,
          title: switch (index) {
            0 => 'The Secret',
            1 => 'The Reckoning',
            _ => 'The Choice',
          },
        ),
      );

  static String _episodeTitle(int episode) => switch (episode) {
    1 => 'The Unexpected Guest',
    2 => 'A Dangerous Promise',
    3 => 'What Ava Saw',
    4 => 'The Hidden Photograph',
    5 => 'No Way Back',
    _ => 'The Secret Deepens',
  };

  static String _episodeSynopsis(int episode) => switch (episode) {
    1 => 'A late-night arrival forces Ava to question everything she knows.',
    2 => 'A promise made under pressure binds two unlikely allies.',
    3 => 'Ava follows a clue that was meant to stay hidden.',
    4 => 'An old photograph reveals a connection between both families.',
    5 => 'The truth closes in, leaving no safe way back.',
    _ => 'A new clue raises the stakes and draws the secret closer to the surface.',
  };
}
