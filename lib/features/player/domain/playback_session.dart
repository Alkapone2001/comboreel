class PlaybackSession {
  const PlaybackSession({
    required this.hlsUrl,
    required this.expiresAt,
    required this.subtitles,
  });

  final Uri? hlsUrl;
  final DateTime? expiresAt;
  final List<SubtitleTrack> subtitles;

  bool get hasVideo => hlsUrl != null;
}

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
