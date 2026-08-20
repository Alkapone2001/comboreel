import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/library/data/viewer_library_repository.dart';
import 'package:comboreel/features/library/domain/viewer_progress.dart';
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
