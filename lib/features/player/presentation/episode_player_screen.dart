import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EpisodePlayerScreen extends StatefulWidget {
  const EpisodePlayerScreen({super.key});

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen> {
  bool _isPlaying = true;
  bool _isLiked = false;

  @override
  Widget build(BuildContext context) => Scaffold(
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
            onPressed: () => setState(() => _isPlaying = !_isPlaying),
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      tooltip: 'Close player',
                    ),
                    const Spacer(),
                    const _EpisodeChip(),
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
                    const Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bound by a Secret',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Episode 1 • The unexpected guest',
                            style: TextStyle(color: Color(0xFFD0D0D6)),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Ava discovers the stranger at her engagement party knows more than he should.',
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
                const LinearProgressIndicator(
                  value: .28,
                  minHeight: 3,
                  color: AppColors.coral,
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      '0:29',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
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

class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'EP 1 / 42',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
