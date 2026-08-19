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
  }) async {}
}
