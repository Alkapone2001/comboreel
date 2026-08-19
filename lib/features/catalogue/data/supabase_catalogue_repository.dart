import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalogue_episode.dart';
import '../domain/catalogue_series.dart';
import '../domain/catalogue_season.dart';
import 'catalogue_repository.dart';

class SupabaseCatalogueRepository
    implements CatalogueRepository, SeasonCatalogueRepository {
  SupabaseCatalogueRepository(this._client);
  final SupabaseClient _client;
  static const _seriesSelect =
      '*, series_genres(genres(name)), episodes(count)';

  @override
  Future<List<CatalogueSeries>> featuredSeries() async {
    final rows = await _client
        .from('series')
        .select(_seriesSelect)
        .eq('is_featured', true)
        .order('published_at', ascending: false)
        .limit(10);
    return rows.map(CatalogueSeries.fromJson).toList();
  }

  @override
  Future<List<CatalogueSeries>> latestSeries({int limit = 20}) async {
    final rows = await _client
        .from('series')
        .select(_seriesSelect)
        .order('published_at', ascending: false)
        .limit(limit);
    return rows.map(CatalogueSeries.fromJson).toList();
  }

  @override
  Future<List<CatalogueSeries>> searchSeries(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return latestSeries();
    final rows = await _client
        .from('series')
        .select(_seriesSelect)
        .ilike('title', '%$normalized%')
        .order('published_at', ascending: false)
        .limit(30);
    return rows.map(CatalogueSeries.fromJson).toList();
  }

  @override
  Future<CatalogueSeries?> seriesBySlug(String slug) async {
    final row = await _client
        .from('series')
        .select(_seriesSelect)
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : CatalogueSeries.fromJson(row);
  }

  @override
  Future<List<CatalogueEpisode>> episodesForSeries(String seriesId) async {
    final rows = await _client
        .from('episodes')
        .select('*, seasons(season_number), series(title)')
        .eq('series_id', seriesId)
        .order('episode_number');
    return rows.map(CatalogueEpisode.fromJson).toList();
  }

  @override
  Future<List<CatalogueSeason>> seasonsForSeries(String seriesId) async {
    final rows = await _client
        .from('seasons')
        .select()
        .eq('series_id', seriesId)
        .order('season_number');
    return rows.map(CatalogueSeason.fromJson).toList();
  }
}
