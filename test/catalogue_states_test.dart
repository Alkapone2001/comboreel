import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/core/config/app_config.dart';
import 'package:comboreel/core/services/app_services.dart';
import 'package:comboreel/features/auth/data/offline_auth_repository.dart';
import 'package:comboreel/features/catalogue/data/catalogue_repository.dart';
import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/catalogue/domain/catalogue_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalogue failure presents a retry state', (tester) async {
    await tester.pumpWidget(
      ComboReelApp(services: _services(_FailingCatalogueRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stories could not load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('empty catalogue presents a deliberate empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ComboReelApp(
        services: AppServices(
          config: AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
          authRepository: OfflineAuthRepository(),
          catalogueRepository: _EmptyCatalogueRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New stories are coming soon.'), findsOneWidget);
  });
}

AppServices _services(CatalogueRepository catalogue) => AppServices(
  config: const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
  authRepository: const OfflineAuthRepository(),
  catalogueRepository: catalogue,
);

class _EmptyCatalogueRepository implements CatalogueRepository {
  const _EmptyCatalogueRepository();

  @override
  Future<List<CatalogueEpisode>> episodesForSeries(String seriesId) async => [];
  @override
  Future<List<CatalogueSeries>> featuredSeries() async => [];
  @override
  Future<List<CatalogueSeries>> latestSeries({int limit = 20}) async => [];
  @override
  Future<List<CatalogueSeries>> searchSeries(String query) async => [];
  @override
  Future<CatalogueSeries?> seriesBySlug(String slug) async => null;
}

class _FailingCatalogueRepository implements CatalogueRepository {
  Future<T> _fail<T>() => Future.error(StateError('network unavailable'));

  @override
  Future<List<CatalogueEpisode>> episodesForSeries(String seriesId) => _fail();
  @override
  Future<List<CatalogueSeries>> featuredSeries() => _fail();
  @override
  Future<List<CatalogueSeries>> latestSeries({int limit = 20}) => _fail();
  @override
  Future<List<CatalogueSeries>> searchSeries(String query) => _fail();
  @override
  Future<CatalogueSeries?> seriesBySlug(String slug) => _fail();
}
