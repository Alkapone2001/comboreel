import '../domain/playback_session.dart';
import 'playback_repository.dart';

class OfflinePlaybackRepository implements PlaybackRepository {
  const OfflinePlaybackRepository();

  @override
  Future<PlaybackSession> createSession(String episodeId) async =>
      const PlaybackSession(hlsUrl: null, expiresAt: null, subtitles: []);
}
