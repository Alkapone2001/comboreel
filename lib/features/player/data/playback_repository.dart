import '../domain/playback_session.dart';

abstract interface class PlaybackRepository {
  Future<PlaybackSession> createSession(String episodeId);
}

class PlaybackAccessException implements Exception {
  const PlaybackAccessException(this.code);
  final String code;
}
