import '../domain/catalogue_episode.dart';
import '../domain/catalogue_series.dart';
import '../domain/catalogue_season.dart';

abstract interface class CatalogueRepository {
  Future<List<CatalogueSeries>> featuredSeries();
  Future<List<CatalogueSeries>> latestSeries({int limit = 20});
  Future<List<CatalogueSeries>> searchSeries(String query);
  Future<CatalogueSeries?> seriesBySlug(String slug);
  Future<List<CatalogueEpisode>> episodesForSeries(String seriesId);
}

abstract interface class SeasonCatalogueRepository {
  Future<List<CatalogueSeason>> seasonsForSeries(String seriesId);
}
