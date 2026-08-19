import '../domain/catalogue_episode.dart';
import '../domain/catalogue_series.dart';
import 'catalogue_repository.dart';

class OfflineCatalogueRepository implements CatalogueRepository {
  const OfflineCatalogueRepository();

  static const _series = [
    CatalogueSeries(
      id: 'demo-bound-by-a-secret',
      slug: 'bound-by-a-secret',
      title: 'Bound by a Secret',
      synopsis: 'A guarded heiress and the stranger hired to protect her uncover a secret that ties their families together.',
      posterUrl: null,
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: true,
    ),
    CatalogueSeries(
      id: 'demo-stolen-vows',
      slug: 'stolen-vows',
      title: 'Stolen Vows',
      synopsis: 'Two rivals are trapped in an agreement neither expected.',
      posterUrl: null,
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: false,
    ),
    CatalogueSeries(
      id: 'demo-the-alibi',
      slug: 'the-alibi',
      title: 'The Alibi',
      synopsis: 'One lie pulls a detective into a dangerous conspiracy.',
      posterUrl: null,
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: false,
    ),
    CatalogueSeries(
      id: 'demo-second-chance-ceo',
      slug: 'second-chance-ceo',
      title: 'Second Chance CEO',
      synopsis: 'A broken promise returns with a powerful new identity.',
      posterUrl: null,
      heroUrl: null,
      originalLanguage: 'en',
      releaseYear: 2026,
      isFeatured: false,
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
}
