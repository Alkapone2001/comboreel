import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalogue/domain/catalogue_episode.dart';
import '../../library/data/viewer_library_repository.dart';

class EpisodePlayerScreen extends StatefulWidget {
  const EpisodePlayerScreen({
    super.key,
    required this.episode,
    required this.viewerLibraryRepository,
    required this.viewerId,
    this.initialPositionSeconds = 0,
  });

  final CatalogueEpisode episode;
  final ViewerLibraryRepository viewerLibraryRepository;
  final String? viewerId;
  final int initialPositionSeconds;

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen> {
  bool _isPlaying = true;
  bool _isLiked = false;
  late int _positionSeconds;

  @override
  void initState() {
    super.initState();
    _positionSeconds = widget.initialPositionSeconds.clamp(
      0,
      widget.episode.durationSeconds,
    );
  }

  @override
  void dispose() {
    unawaited(_saveProgress());
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final viewerId = widget.viewerId;
    if (viewerId == null) return;
    await widget.viewerLibraryRepository.saveProgress(
      userId: viewerId,
      episodeId: widget.episode.id,
      positionSeconds: _positionSeconds,
      completed:
          widget.episode.durationSeconds > 0 &&
          _positionSeconds >= widget.episode.durationSeconds - 3,
    );
  }

  Future<void> _close() async {
    await _saveProgress();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _togglePlayback() async {
    setState(() => _isPlaying = !_isPlaying);
    if (!_isPlaying) await _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.episode.durationSeconds;
    final fraction = duration <= 0 ? 0.0 : _positionSeconds / duration;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4A1933), Color(0xFF160D15), Colors.black],
              ),
            ),
          ),
          Center(
            child: IconButton.filledTonal(
              onPressed: _togglePlayback,
              iconSize: 42,
              icon: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              tooltip: _isPlaying ? 'Pause' : 'Play',
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _close,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        tooltip: 'Close player',
                      ),
                      const Spacer(),
                      _EpisodeChip(number: widget.episode.episodeNumber),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () {},
                        icon: const Icon(Icons.closed_caption_rounded),
                        tooltip: 'Subtitles',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bound by a Secret',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Episode ${widget.episode.episodeNumber} • ${widget.episode.title}',
                              style: const TextStyle(color: Color(0xFFD0D0D6)),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Every clue changes the story. Keep watching to reveal the next secret.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PlayerAction(
                            icon: _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: '12.4K',
                            color: _isLiked ? AppColors.coral : Colors.white,
                            onTap: () => setState(() => _isLiked = !_isLiked),
                          ),
                          _PlayerAction(
                            icon: Icons.bookmark_border_rounded,
                            label: 'Save',
                            onTap: () {},
                          ),
                          _PlayerAction(
                            icon: Icons.ios_share_rounded,
                            label: 'Share',
                            onTap: () {},
                          ),
                          _PlayerAction(
                            icon: Icons.list_rounded,
                            label: 'Episodes',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: fraction,
                    minHeight: 3,
                    color: AppColors.coral,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_positionSeconds),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Next episode'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'EP $number / 42',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
