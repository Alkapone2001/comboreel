import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/domain/catalogue_episode.dart';
import '../data/viewer_library_repository.dart';
import '../domain/viewer_progress.dart';

typedef ResumeEpisode = void Function(
  CatalogueEpisode episode,
  int positionSeconds,
);

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({
    super.key,
    required this.catalogueRepository,
    required this.viewerLibraryRepository,
    required this.viewerId,
    required this.onResume,
  });

  final CatalogueRepository catalogueRepository;
  final ViewerLibraryRepository viewerLibraryRepository;
  final String viewerId;
  final ResumeEpisode onResume;

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  late Future<List<ViewerProgress>> _history;
  String? _openingEpisodeId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = widget.viewerLibraryRepository.recentProgress(
      widget.viewerId,
      limit: 50,
    );
  }

  Future<void> _resume(ViewerProgress progress) async {
    setState(() => _openingEpisodeId = progress.episodeId);
    try {
      final episodes = await widget.catalogueRepository.episodesForSeries(
        progress.seriesId,
      );
      final episode = episodes
          .where((item) => item.id == progress.episodeId)
          .firstOrNull;
      if (episode == null) throw StateError('Episode unavailable');
      if (mounted) widget.onResume(episode, progress.positionSeconds);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This episode is no longer available.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingEpisodeId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Watch history')),
    body: FutureBuilder<List<ViewerProgress>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _HistoryMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load watch history',
            actionLabel: 'Try again',
            onAction: () => setState(_reload),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const _HistoryMessage(
            icon: Icons.history_toggle_off_rounded,
            title: 'Nothing watched yet',
            message: 'Episodes you start will appear here so you can continue.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _history;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final opening = _openingEpisodeId == item.episodeId;
              return Card(
                color: AppColors.surface,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: opening ? null : () => _resume(item),
                  leading: CircleAvatar(
                    child: opening
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                  ),
                  title: Text(
                    item.seriesTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Episode ${item.episodeNumber} · ${item.episodeTitle}',
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: item.fraction),
                        const SizedBox(height: 5),
                        Text(
                          '${_time(item.positionSeconds)} of ${_time(item.durationSeconds)}',
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.muted),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
