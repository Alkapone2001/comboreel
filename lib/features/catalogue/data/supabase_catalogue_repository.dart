import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalogue_episode.dart';
import '../domain/catalogue_series.dart';
import 'catalogue_repository.dart';

class SupabaseCatalogueRepository implements CatalogueRepository {
  SupabaseCatalogueRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<CatalogueSeries>> featuredSeries() async {
    final rows = await _client
        .from('series')
        .select()
        .eq('is_featured', true)
        .order('published_at', ascending: false)
        .limit(10);
    return rows.map(CatalogueSeries.fromJson).toList();
  }

  @override
  Future<List<CatalogueSeries>> latestSeries({int limit = 20}) async {
    final rows = await _client
        .from('series')
        .select()
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
        .select()
        .ilike('title', '%$normalized%')
        .order('published_at', ascending: false)
        .limit(30);
    return rows.map(CatalogueSeries.fromJson).toList();
  }

  @override
  Future<CatalogueSeries?> seriesBySlug(String slug) async {
    final row = await _client
        .from('series')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : CatalogueSeries.fromJson(row);
  }

  @override
  Future<List<CatalogueEpisode>> episodesForSeries(String seriesId) async {
    final rows = await _client
        .from('episodes')
        .select()
        .eq('series_id', seriesId)
        .order('episode_number');
    return rows.map(CatalogueEpisode.fromJson).toList();
  }
}
