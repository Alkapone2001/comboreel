import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/viewer_preferences_repository.dart';

class PlaybackPreferencesScreen extends StatefulWidget {
  const PlaybackPreferencesScreen({super.key, required this.repository});

  final ViewerPreferencesRepository repository;

  @override
  State<PlaybackPreferencesScreen> createState() =>
      _PlaybackPreferencesScreenState();
}

class _PlaybackPreferencesScreenState extends State<PlaybackPreferencesScreen> {
  static const languages = <String, String>{
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
  };

  PlaybackPreferences? _preferences;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await widget.repository.playbackPreferences();
    if (mounted) setState(() => _preferences = preferences);
  }

  Future<void> _save(
    PlaybackPreferences next,
    Future<void> Function() persist,
  ) async {
    final previous = _preferences;
    setState(() => _saving = true);
    try {
      await persist();
      if (mounted) {
        setState(() => _preferences = next);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playback preferences saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
      if (mounted && previous != null) setState(() => _preferences = previous);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectLanguage(String languageCode) async {
    final current = _preferences;
    if (current == null) return;
    await _save(
      current.copyWith(subtitleLanguage: languageCode, subtitlesEnabled: true),
      () => widget.repository.setPreferredSubtitleLanguage(languageCode),
    );
  }

  Future<void> _setSubtitlesEnabled(bool enabled) async {
    final current = _preferences;
    if (current == null) return;
    await _save(
      current.copyWith(subtitlesEnabled: enabled),
      () => widget.repository.setSubtitlePreference(
        enabled: enabled,
        languageCode: current.subtitleLanguage,
      ),
    );
  }

  Future<void> _setPlaybackControls({bool? muted, double? speed}) async {
    final current = _preferences;
    if (current == null) return;
    final next = current.copyWith(muted: muted, speed: speed);
    await _save(
      next,
      () => widget.repository.setPlaybackControls(
        muted: next.muted,
        speed: next.speed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Playback preferences')),
    body: _preferences == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text('Subtitles', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                color: AppColors.surface,
                child: SwitchListTile.adaptive(
                  key: const ValueKey('subtitles-enabled'),
                  value: _preferences!.subtitlesEnabled,
                  onChanged: _saving ? null : _setSubtitlesEnabled,
                  title: const Text('Show subtitles automatically'),
                  subtitle: const Text(
                    'Uses your preferred language whenever it is available.',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Preferred subtitle language',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'ComboReel selects this language automatically when a story provides it. You can still change or turn off subtitles in the player.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              Card(
                color: AppColors.surface,
                child: Opacity(
                  opacity: _preferences!.subtitlesEnabled ? 1 : 0.5,
                  child: RadioGroup<String>(
                    groupValue: _preferences!.subtitleLanguage,
                    onChanged: (value) {
                      if (!_saving && value != null) _selectLanguage(value);
                    },
                    child: Column(
                      children: languages.entries
                          .map(
                            (entry) => RadioListTile<String>(
                              value: entry.key,
                              enabled:
                                  !_saving && _preferences!.subtitlesEnabled,
                              title: Text(entry.value),
                              subtitle: Text(entry.key.toUpperCase()),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Video playback',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'These defaults apply whenever you open an episode. You can still change them inside the player.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              Card(
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile.adaptive(
                      key: const ValueKey('start-muted'),
                      value: _preferences!.muted,
                      onChanged: _saving
                          ? null
                          : (value) => _setPlaybackControls(muted: value),
                      title: const Text('Start videos muted'),
                      subtitle: const Text(
                        'You can unmute at any time in the player.',
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Default playback speed',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final speed in const [
                                0.75,
                                1.0,
                                1.25,
                                1.5,
                                2.0,
                              ])
                                ChoiceChip(
                                  key: ValueKey('default-speed-$speed'),
                                  label: Text(_formatSpeed(speed)),
                                  selected: _preferences!.speed == speed,
                                  onSelected: _saving
                                      ? null
                                      : (_) =>
                                            _setPlaybackControls(speed: speed),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );

  String _formatSpeed(double speed) =>
      '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2).replaceFirst(RegExp(r'0$'), '')}×';
}
