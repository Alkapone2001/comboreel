import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/core/config/app_config.dart';
import 'package:comboreel/core/services/app_services.dart';
import 'package:comboreel/features/auth/data/offline_auth_repository.dart';
import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/library/data/viewer_library_repository.dart';
import 'package:comboreel/features/library/domain/viewer_progress.dart';
import 'package:comboreel/features/player/presentation/episode_player_screen.dart';
import 'package:comboreel/features/player/data/offline_playback_repository.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline viewer library mutates favourites and progress', () async {
    final repository = OfflineViewerLibraryRepository();

    await repository.addFavourite(userId: 'viewer', seriesId: 'series-1');
    expect(await repository.favouriteSeriesIds('viewer'), contains('series-1'));

    await repository.removeFavourite(userId: 'viewer', seriesId: 'series-1');
    expect(
      await repository.favouriteSeriesIds('viewer'),
      isNot(contains('series-1')),
    );

    await repository.saveProgress(
      userId: 'viewer',
      episodeId: 'demo-bound-by-a-secret-episode-1',
      positionSeconds: 44,
      completed: false,
    );
    final progress = await repository.recentProgress('viewer');
    expect(progress.first.positionSeconds, 44);
  });

  testWidgets('bookmarking a series makes it appear in My List', (
    tester,
  ) async {
    final library = OfflineViewerLibraryRepository();
    final services = AppServices(
      config: const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
      authRepository: const OfflineAuthRepository(),
      catalogueRepository: const OfflineCatalogueRepository(),
      viewerLibraryRepository: library,
      monetizationRepository: OfflineMonetizationRepository(),
    );
    await tester.pumpWidget(ComboReelApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My List'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to My List'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview My List'));
    await tester.pumpAndSettle();

    expect(find.text('Bound by a Secret'), findsOneWidget);
  });

  testWidgets('pausing the player persists the resume position', (
    tester,
  ) async {
    final repository = _RecordingLibraryRepository();
    const episode = CatalogueEpisode(
      id: 'episode-7',
      seriesId: 'series-1',
      episodeNumber: 7,
      title: 'The Warning',
      durationSeconds: 100,
      thumbnailUrl: null,
      isFree: true,
      coinPrice: 5,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          initialPositionSeconds: 37,
          viewerLibraryRepository: repository,
          playbackRepository: const OfflinePlaybackRepository(),
          viewerId: 'viewer-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(repository.savedEpisodeId, 'episode-7');
    expect(repository.savedPosition, 37);
  });
}

class _RecordingLibraryRepository implements ViewerLibraryRepository {
  String? savedEpisodeId;
  int? savedPosition;

  @override
  Future<void> addFavourite({
    required String userId,
    required String seriesId,
  }) async {}
  @override
  Future<Set<String>> favouriteSeriesIds(String userId) async => {};
  @override
  Future<List<ViewerProgress>> recentProgress(
    String userId, {
    int limit = 20,
  }) async => [];
  @override
  Future<void> removeFavourite({
    required String userId,
    required String seriesId,
  }) async {}
  @override
  Future<void> saveProgress({
    required String userId,
    required String episodeId,
    required int positionSeconds,
    required bool completed,
  }) async {
    savedEpisodeId = episodeId;
    savedPosition = positionSeconds;
  }
}
