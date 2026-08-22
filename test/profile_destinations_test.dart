import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/library/presentation/watch_history_screen.dart';
import 'package:comboreel/features/preferences/data/viewer_preferences_repository.dart';
import 'package:comboreel/features/preferences/presentation/playback_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('watch history resumes the selected episode at saved position', (
    tester,
  ) async {
    String? resumedEpisode;
    int? resumedPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: WatchHistoryScreen(
          catalogueRepository: const OfflineCatalogueRepository(),
          viewerLibraryRepository: OfflineViewerLibraryRepository(),
          viewerId: 'demo-viewer',
          onResume: (episode, position) {
            resumedEpisode = episode.id;
            resumedPosition = position;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bound by a Secret'), findsOneWidget);
    expect(find.textContaining('The Unexpected Guest'), findsOneWidget);
    await tester.tap(find.text('Bound by a Secret'));
    await tester.pumpAndSettle();

    expect(resumedEpisode, 'demo-bound-by-a-secret-episode-1');
    expect(resumedPosition, 29);
  });

  testWidgets('subtitle preference selection is persisted', (tester) async {
    final repository = OfflineViewerPreferencesRepository();
    await tester.pumpWidget(
      MaterialApp(home: PlaybackPreferencesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spanish'));
    await tester.pumpAndSettle();

    expect(await repository.preferredSubtitleLanguage(), 'es');
  });

  testWidgets('playback defaults are configurable from profile settings', (
    tester,
  ) async {
    final repository = OfflineViewerPreferencesRepository();
    await tester.pumpWidget(
      MaterialApp(home: PlaybackPreferencesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subtitles-enabled')));
    await tester.pumpAndSettle();
    expect((await repository.playbackPreferences()).subtitlesEnabled, isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    final muted = find.byKey(const ValueKey('start-muted'));
    await tester.tap(muted);
    await tester.pumpAndSettle();

    final speed = find.byKey(const ValueKey('default-speed-1.5'));
    await tester.ensureVisible(speed);
    await tester.tap(speed);
    await tester.pumpAndSettle();

    final preferences = await repository.playbackPreferences();
    expect(preferences.muted, isTrue);
    expect(preferences.speed, 1.5);
  });
}
