class PlaybackPreferences {
  const PlaybackPreferences({
    this.subtitleLanguage = 'en',
    this.subtitlesEnabled = true,
    this.muted = false,
    this.speed = 1,
  });

  final String subtitleLanguage;
  final bool subtitlesEnabled;
  final bool muted;
  final double speed;

  PlaybackPreferences copyWith({
    String? subtitleLanguage,
    bool? subtitlesEnabled,
    bool? muted,
    double? speed,
  }) => PlaybackPreferences(
    subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
    subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    muted: muted ?? this.muted,
    speed: speed ?? this.speed,
  );
}

abstract interface class ViewerPreferencesRepository {
  Future<PlaybackPreferences> playbackPreferences();
  Future<String> preferredSubtitleLanguage();
  Future<void> setPreferredSubtitleLanguage(String languageCode);
  Future<void> setSubtitlePreference({
    required bool enabled,
    String? languageCode,
  });
  Future<void> setPlaybackControls({
    required bool muted,
    required double speed,
  });
}

class OfflineViewerPreferencesRepository
    implements ViewerPreferencesRepository {
  OfflineViewerPreferencesRepository({
    String initialLanguage = 'en',
    bool subtitlesInitiallyEnabled = true,
    bool initiallyMuted = false,
    double initialSpeed = 1,
  }) : _preferences = PlaybackPreferences(
         subtitleLanguage: initialLanguage,
         subtitlesEnabled: subtitlesInitiallyEnabled,
         muted: initiallyMuted,
         speed: initialSpeed,
       );

  PlaybackPreferences _preferences;

  @override
  Future<PlaybackPreferences> playbackPreferences() async => _preferences;

  @override
  Future<String> preferredSubtitleLanguage() async =>
      _preferences.subtitleLanguage;

  @override
  Future<void> setPreferredSubtitleLanguage(String languageCode) async {
    _preferences = _preferences.copyWith(
      subtitleLanguage: languageCode,
      subtitlesEnabled: true,
    );
  }

  @override
  Future<void> setSubtitlePreference({
    required bool enabled,
    String? languageCode,
  }) async {
    _preferences = _preferences.copyWith(
      subtitleLanguage: languageCode,
      subtitlesEnabled: enabled,
    );
  }

  @override
  Future<void> setPlaybackControls({
    required bool muted,
    required double speed,
  }) async {
    _preferences = _preferences.copyWith(muted: muted, speed: speed);
  }
}

class UnavailableViewerPreferencesRepository
    implements ViewerPreferencesRepository {
  const UnavailableViewerPreferencesRepository();

  @override
  Future<PlaybackPreferences> playbackPreferences() async =>
      const PlaybackPreferences();

  @override
  Future<String> preferredSubtitleLanguage() async => 'en';

  @override
  Future<void> setPreferredSubtitleLanguage(String languageCode) async {}

  @override
  Future<void> setSubtitlePreference({
    required bool enabled,
    String? languageCode,
  }) async {}

  @override
  Future<void> setPlaybackControls({
    required bool muted,
    required double speed,
  }) async {}
}
