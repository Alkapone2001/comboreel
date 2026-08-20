class PlaybackSession {
  const PlaybackSession({
    required this.hlsUrl,
    required this.expiresAt,
    required this.subtitles,
    this.format = PlaybackMediaFormat.hls,
    this.clipStart = Duration.zero,
    this.clipEnd,
  });

  final Uri? hlsUrl;
  final DateTime? expiresAt;
  final List<SubtitleTrack> subtitles;
  final PlaybackMediaFormat format;
  final Duration clipStart;
  final Duration? clipEnd;

  bool get hasVideo => hlsUrl != null;

  Duration? get clipDuration => switch (clipEnd) {
    final end? when end > clipStart => end - clipStart,
    _ => null,
  };
}

enum PlaybackMediaFormat { hls, mp4 }

class SubtitleTrack {
  const SubtitleTrack({
    required this.languageCode,
    required this.label,
    required this.vttUrl,
    required this.isDefault,
  });

  final String languageCode;
  final String label;
  final Uri vttUrl;
  final bool isDefault;
}
