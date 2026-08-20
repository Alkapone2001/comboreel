import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/analytics/data/analytics_repository.dart';
import 'package:comboreel/features/library/data/viewer_library_repository.dart';
import 'package:comboreel/features/library/domain/viewer_progress.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:comboreel/features/monetization/data/rewarded_ad_service.dart';
import 'package:comboreel/features/player/data/playback_repository.dart';
import 'package:comboreel/features/player/domain/playback_session.dart';
import 'package:comboreel/features/player/presentation/episode_player_screen.dart';
import 'package:comboreel/features/preferences/data/viewer_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('player exposes available subtitle tracks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: const _SubtitlePlaybackRepository(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('locked playback session presents an access error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: const _LockedPlaybackRepository(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This episode is locked'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('locked player spends coins and retries the same episode', (
    tester,
  ) async {
    final monetization = OfflineMonetizationRepository();
    final playback = _EntitlementPlaybackRepository(monetization);
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: playback,
          monetizationRepository: monetization,
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This episode is locked'), findsOneWidget);
    await tester.tap(find.text('Unlock with 5 coins'));
    await tester.pumpAndSettle();

    expect(find.text('This episode is locked'), findsNothing);
    expect(playback.requests, 2);
    expect((await monetization.wallet('viewer')).balance, 20);
  });

  testWidgets('locked player verifies a rewarded ad before retrying', (
    tester,
  ) async {
    final monetization = OfflineMonetizationRepository();
    final playback = _EntitlementPlaybackRepository(monetization);
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: playback,
          monetizationRepository: monetization,
          rewardedAdService: const DemoRewardedAdService(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This episode is locked'), findsOneWidget);
    await tester.tap(find.text('Watch an ad'));
    await tester.pumpAndSettle();

    expect(find.text('This episode is locked'), findsNothing);
    expect(playback.requests, 2);
    expect((await monetization.wallet('viewer')).balance, 25);
  });

  testWidgets('failed session retries without losing the resume position', (
    tester,
  ) async {
    final playback = _RecoveringPlaybackRepository();
    final library = _NoopLibrary();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          initialPositionSeconds: 24,
          viewerLibraryRepository: library,
          playbackRepository: playback,
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Video could not load'), findsOneWidget);
    expect(find.text('0:24 / 1:30'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Video could not load'), findsNothing);
    expect(find.text('0:24 / 1:30'), findsOneWidget);
    expect(playback.requests, 2);
    expect(library.savedEpisodeIds, contains('episode-6'));
  });

  testWidgets('expiring playback session refreshes before it expires', (
    tester,
  ) async {
    final playback = _ExpiringPlaybackRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: playback,
          preferencesRepository: OfflineViewerPreferencesRepository(
            initialLanguage: 'es',
          ),
          viewerId: 'viewer',
          sessionRefreshLeadTime: const Duration(seconds: 30),
        ),
      ),
    );
    await tester.pump();

    expect(playback.requests, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(playback.requests, 2);
    expect(find.text('Video could not load'), findsNothing);
    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    final group = tester.widget<RadioGroup<SubtitleTrack?>>(
      find.byType(RadioGroup<SubtitleTrack?>),
    );
    expect(group.groupValue?.languageCode, 'es');
  });

  testWidgets('failed session refresh retries without interrupting playback', (
    tester,
  ) async {
    final playback = _RetryingRefreshPlaybackRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: playback,
          viewerId: 'viewer',
          sessionRefreshLeadTime: const Duration(seconds: 30),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(playback.requests, 2);
    expect(find.text('Video could not load'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(playback.requests, 3);
    expect(find.text('Video could not load'), findsNothing);
  });

  testWidgets('seek control updates and persists playback position', (
    tester,
  ) async {
    final library = _NoopLibrary();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: library,
          playbackRepository: const _SubtitlePlaybackRepository(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final seek = find.byKey(const ValueKey('playback-seek'));
    expect(seek, findsOneWidget);
    final rect = tester.getRect(seek);
    await tester.tapAt(Offset(rect.left + rect.width * 0.5, rect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('0:45 / 1:30'), findsOneWidget);
    expect(library.savedPositions.last, 45);
  });

  testWidgets('completed progress emits one completion event per episode', (
    tester,
  ) async {
    final analytics = _RecordingAnalyticsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: const _SubtitlePlaybackRepository(),
          analyticsRepository: analytics,
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final seek = find.byKey(const ValueKey('playback-seek'));
    final rect = tester.getRect(seek);
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();

    expect(analytics.events, ['episode_completed']);
    expect(analytics.episodeIds, ['episode-6']);
    expect(analytics.positions, [90]);
  });

  testWidgets('player honors the preferred subtitle language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: const _MultipleSubtitlePlaybackRepository(),
          preferencesRepository: OfflineViewerPreferencesRepository(
            initialLanguage: 'es',
          ),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    final group = tester.widget<RadioGroup<SubtitleTrack?>>(
      find.byType(RadioGroup<SubtitleTrack?>),
    );

    expect(group.groupValue?.languageCode, 'es');
  });

  testWidgets('vertical swipe advances the queue and persists progress', (
    tester,
  ) async {
    final library = _NoopLibrary();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          episodes: const [episode, nextEpisode],
          viewerLibraryRepository: library,
          playbackRepository: const _SubtitlePlaybackRepository(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EP 6'), findsOneWidget);
    expect(find.textContaining('Episode 6 • The Warning'), findsOneWidget);

    await tester.fling(find.byType(Scaffold), const Offset(0, -600), 1200);
    await tester.pumpAndSettle();

    expect(find.textContaining('Episode 7 • The Discovery'), findsOneWidget);
    expect(library.savedEpisodeIds, contains('episode-6'));

    await tester.tap(find.text('Episodes'));
    await tester.pumpAndSettle();
    final previousOption = find.byKey(
      const ValueKey('episode-option-episode-6'),
      skipOffstage: false,
    );
    expect(previousOption, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('episode-option-episode-7'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(previousOption);
    await tester.tap(previousOption);
    await tester.pumpAndSettle();
    expect(find.textContaining('Episode 6 • The Warning'), findsOneWidget);
  });

  testWidgets('backgrounding pauses, persists, and resumes active playback', (
    tester,
  ) async {
    final library = _NoopLibrary();
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          initialPositionSeconds: 24,
          viewerLibraryRepository: library,
          playbackRepository: const _SubtitlePlaybackRepository(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pause'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byTooltip('Play'), findsOneWidget);
    expect(library.savedEpisodeIds, contains('episode-6'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('backgrounding preserves a viewer-initiated pause', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EpisodePlayerScreen(
          episode: episode,
          viewerLibraryRepository: _NoopLibrary(),
          playbackRepository: const _SubtitlePlaybackRepository(),
          viewerId: 'viewer',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byTooltip('Play'), findsOneWidget);
  });
}

const episode = CatalogueEpisode(
  id: 'episode-6',
  seriesId: 'series-1',
  episodeNumber: 6,
  title: 'The Warning',
  durationSeconds: 90,
  thumbnailUrl: null,
  isFree: false,
  coinPrice: 5,
);

const nextEpisode = CatalogueEpisode(
  id: 'episode-7',
  seriesId: 'series-1',
  episodeNumber: 7,
  title: 'The Discovery',
  durationSeconds: 95,
  thumbnailUrl: null,
  isFree: false,
  coinPrice: 5,
);

class _SubtitlePlaybackRepository implements PlaybackRepository {
  const _SubtitlePlaybackRepository();

  @override
  Future<PlaybackSession> createSession(String episodeId) async =>
      PlaybackSession(
        hlsUrl: null,
        expiresAt: null,
        subtitles: [
          SubtitleTrack(
            languageCode: 'en',
            label: 'English',
            vttUrl: Uri.parse('https://example.com/en.vtt'),
            isDefault: true,
          ),
        ],
      );
}

class _LockedPlaybackRepository implements PlaybackRepository {
  const _LockedPlaybackRepository();

  @override
  Future<PlaybackSession> createSession(String episodeId) =>
      Future.error(const PlaybackAccessException('episode_locked'));
}

class _RecoveringPlaybackRepository implements PlaybackRepository {
  int requests = 0;

  @override
  Future<PlaybackSession> createSession(String episodeId) async {
    requests++;
    if (requests == 1) throw StateError('network_unavailable');
    return const PlaybackSession(hlsUrl: null, expiresAt: null, subtitles: []);
  }
}

class _EntitlementPlaybackRepository implements PlaybackRepository {
  _EntitlementPlaybackRepository(this.monetization);

  final OfflineMonetizationRepository monetization;
  int requests = 0;

  @override
  Future<PlaybackSession> createSession(String episodeId) async {
    requests++;
    if (!await monetization.hasEpisodeAccess(episodeId)) {
      throw const PlaybackAccessException('episode_locked');
    }
    return const PlaybackSession(hlsUrl: null, expiresAt: null, subtitles: []);
  }
}

class _ExpiringPlaybackRepository implements PlaybackRepository {
  int requests = 0;

  @override
  Future<PlaybackSession> createSession(String episodeId) async {
    requests++;
    return PlaybackSession(
      hlsUrl: null,
      expiresAt: requests == 1
          ? DateTime.now().toUtc().add(const Duration(seconds: 31))
          : null,
      subtitles: [
        SubtitleTrack(
          languageCode: 'en',
          label: 'English',
          vttUrl: Uri.parse('https://example.com/en.vtt'),
          isDefault: true,
        ),
        SubtitleTrack(
          languageCode: 'es',
          label: 'Spanish',
          vttUrl: Uri.parse('https://example.com/es.vtt'),
          isDefault: false,
        ),
      ],
    );
  }
}

class _RetryingRefreshPlaybackRepository implements PlaybackRepository {
  int requests = 0;

  @override
  Future<PlaybackSession> createSession(String episodeId) async {
    requests++;
    if (requests == 2) throw StateError('temporary_network_failure');
    return PlaybackSession(
      hlsUrl: null,
      expiresAt: requests == 1
          ? DateTime.now().toUtc().add(const Duration(seconds: 31))
          : null,
      subtitles: const [],
    );
  }
}

class _MultipleSubtitlePlaybackRepository implements PlaybackRepository {
  const _MultipleSubtitlePlaybackRepository();

  @override
  Future<PlaybackSession> createSession(String episodeId) async =>
      PlaybackSession(
        hlsUrl: null,
        expiresAt: null,
        subtitles: [
          SubtitleTrack(
            languageCode: 'en',
            label: 'English',
            vttUrl: Uri.parse('https://example.com/en.vtt'),
            isDefault: true,
          ),
          SubtitleTrack(
            languageCode: 'es',
            label: 'Spanish',
            vttUrl: Uri.parse('https://example.com/es.vtt'),
            isDefault: false,
          ),
        ],
      );
}

class _NoopLibrary implements ViewerLibraryRepository {
  final List<String> savedEpisodeIds = [];
  final List<int> savedPositions = [];

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
    savedEpisodeIds.add(episodeId);
    savedPositions.add(positionSeconds);
  }
}

class _RecordingAnalyticsRepository extends NoopAnalyticsRepository {
  final List<String> events = [];
  final List<String?> episodeIds = [];
  final List<int?> positions = [];

  @override
  Future<void> track(
    String event, {
    String? seriesId,
    String? episodeId,
    Map<String, Object?> properties = const {},
  }) async {
    events.add(event);
    episodeIds.add(episodeId);
    positions.add(properties['position_seconds'] as int?);
  }
}
