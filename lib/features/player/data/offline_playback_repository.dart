import '../domain/playback_session.dart';
import 'playback_repository.dart';

class OfflinePlaybackRepository implements PlaybackRepository {
  const OfflinePlaybackRepository();

  static final _sintelMaster = Uri.parse(
    'https://peach.themazzone.com/durian/movies/sintel-1024-surround.mp4',
  );
  static const _sintelBoundaries = [
    0,
    101,
    196,
    287,
    350,
    434,
    543,
    684,
    744,
    888,
  ];

  @override
  Future<PlaybackSession> createSession(String episodeId) async {
    const prefix = 'demo-sintel-episode-';
    if (episodeId.startsWith(prefix)) {
      final episodeNumber = int.tryParse(episodeId.substring(prefix.length));
      if (episodeNumber != null &&
          episodeNumber > 0 &&
          episodeNumber < _sintelBoundaries.length) {
        return PlaybackSession(
          hlsUrl: _sintelMaster,
          expiresAt: null,
          format: PlaybackMediaFormat.mp4,
          clipStart: Duration(seconds: _sintelBoundaries[episodeNumber - 1]),
          clipEnd: Duration(seconds: _sintelBoundaries[episodeNumber]),
          subtitles: [
            SubtitleTrack(
              languageCode: 'en',
              label: 'English',
              vttUrl: Uri.parse('asset:///assets/subtitles/sintel_en.vtt'),
              isDefault: true,
            ),
          ],
        );
      }
    }
    return const PlaybackSession(hlsUrl: null, expiresAt: null, subtitles: []);
  }
}
