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

  late Future<String> _selection;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selection = widget.repository.preferredSubtitleLanguage();
  }

  Future<void> _select(String languageCode) async {
    setState(() => _saving = true);
    try {
      await widget.repository.setPreferredSubtitleLanguage(languageCode);
      if (mounted) {
        setState(() => _selection = Future.value(languageCode));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtitle preference saved.')),
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Language & subtitles')),
    body: FutureBuilder<String>(
      future: _selection,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
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
              child: RadioGroup<String>(
                groupValue: snapshot.data,
                onChanged: (value) {
                  if (!_saving && value != null) _select(value);
                },
                child: Column(
                  children: languages.entries
                      .map(
                        (entry) => RadioListTile<String>(
                          value: entry.key,
                          title: Text(entry.value),
                          subtitle: Text(entry.key.toUpperCase()),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
