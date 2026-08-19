import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/home/data/demo_series.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:comboreel/features/monetization/presentation/coins_screen.dart';
import 'package:comboreel/features/series/presentation/series_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coin unlock is idempotent and debits once', () async {
    final repository = OfflineMonetizationRepository();

    final first = await repository.unlockEpisodeWithCoins(
      episodeId: 'series-episode-6',
      idempotencyKey: 'test-request-0001',
    );
    final replay = await repository.unlockEpisodeWithCoins(
      episodeId: 'series-episode-6',
      idempotencyKey: 'test-request-0001',
    );

    expect(first.balance, 20);
    expect(replay.balance, 20);
    expect((await repository.wallet('viewer')).transactions.length, 2);
  });

  testWidgets('Coins screen renders balance and server-owned purchase state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoinsScreen(
            repository: OfflineMonetizationRepository(),
            viewerId: 'viewer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('available coins'), findsOneWidget);
    expect(find.text('Store setup pending'), findsNWidgets(3));
  });

  testWidgets('locked episode unlock spends coins and grants playback', (
    tester,
  ) async {
    final monetization = OfflineMonetizationRepository();
    CatalogueEpisode? openedEpisode;
    await tester.pumpWidget(
      MaterialApp(
        home: SeriesDetailScreen(
          series: featuredSeries,
          catalogueRepository: const OfflineCatalogueRepository(),
          viewerLibraryRepository: OfflineViewerLibraryRepository(),
          monetizationRepository: monetization,
          viewerId: 'viewer',
          onWatch: (episode) => openedEpisode = episode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -750));
    await tester.pumpAndSettle();
    final lockedEpisode = find.textContaining('Episode 6:');
    expect(lockedEpisode, findsOneWidget);
    await tester.tap(lockedEpisode);
    await tester.pumpAndSettle();

    expect(find.text('Unlock Episode 6'), findsOneWidget);
    await tester.tap(find.text('Use 5 coins'));
    await tester.pumpAndSettle();

    expect(openedEpisode?.episodeNumber, 6);
    expect((await monetization.wallet('viewer')).balance, 20);
  });
}
