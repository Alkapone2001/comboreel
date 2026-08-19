import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/home/data/demo_series.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:comboreel/features/monetization/data/demo_store_purchase_service.dart';
import 'package:comboreel/features/monetization/data/rewarded_ad_service.dart';
import 'package:comboreel/features/monetization/domain/rewarded_ad_claim.dart';
import 'package:comboreel/features/monetization/domain/store_purchase.dart';
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

  test('offline rewarded claim becomes verified and grants access', () async {
    final repository = OfflineMonetizationRepository();
    final claim = await repository.createRewardedEpisodeClaim(
      'series-episode-6',
    );

    expect(
      await repository.rewardedEpisodeClaimStatus(claim.id),
      RewardedAdClaimStatus.verified,
    );
    expect(await repository.hasEpisodeAccess('series-episode-6'), isTrue);
  });

  test('premium purchase verification returns a durable expiry', () async {
    final repository = OfflineMonetizationRepository();
    final result = await repository.verifyMobilePurchase(
      const StorePurchaseUpdate(
        id: 'premium-test-1',
        productId: 'comboreel.premium.monthly',
        status: StorePurchaseStatus.purchased,
        source: 'demo_store',
        verificationData: 'demo-token',
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.premiumUntil, isNotNull);
    expect(result.premiumUntil!.isAfter(DateTime.now().toUtc()), isTrue);
  });

  testWidgets('Coins screen renders localized store products', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoinsScreen(
            repository: OfflineMonetizationRepository(),
            store: DemoStorePurchaseService(),
            viewerId: 'viewer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('available coins'), findsOneWidget);
    expect(find.text(r'$1.99'), findsOneWidget);
    expect(find.text('Premium monthly'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
  });

  testWidgets('verified coin purchase refreshes the wallet once', (
    tester,
  ) async {
    final repository = OfflineMonetizationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoinsScreen(
            repository: repository,
            store: DemoStorePurchaseService(),
            viewerId: 'viewer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$1.99'));
    await tester.pumpAndSettle();

    expect(find.text('75'), findsOneWidget);
    expect(find.text('Coins added to your wallet.'), findsOneWidget);
    expect((await repository.wallet('viewer')).transactions.length, 2);
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
          rewardedAdService: const DemoRewardedAdService(),
          viewerId: 'viewer',
          onWatch: (episode) => openedEpisode = episode,
          onOpenPremium: () {},
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

  testWidgets('rewarded ad verification unlocks a locked episode', (
    tester,
  ) async {
    CatalogueEpisode? openedEpisode;
    await tester.pumpWidget(
      MaterialApp(
        home: SeriesDetailScreen(
          series: featuredSeries,
          catalogueRepository: const OfflineCatalogueRepository(),
          viewerLibraryRepository: OfflineViewerLibraryRepository(),
          monetizationRepository: OfflineMonetizationRepository(),
          rewardedAdService: const DemoRewardedAdService(),
          viewerId: 'viewer',
          onWatch: (episode) => openedEpisode = episode,
          onOpenPremium: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -750));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Episode 6:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch an ad'));
    await tester.pumpAndSettle();

    expect(openedEpisode?.episodeNumber, 6);
  });
}
