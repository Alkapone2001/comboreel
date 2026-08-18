import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/domain/series.dart';

class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({
    super.key,
    required this.series,
    required this.onWatch,
  });

  final DramaSeries series;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar.large(
          expandedHeight: 360,
          pinned: true,
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.bookmark_border_rounded),
              tooltip: 'Add to My List',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Share',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(series.title),
            background: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: series.colors,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: 240,
                    color: Colors.white.withValues(alpha: .06),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xDD09090C)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  const _MetadataPill(
                    label: '9.2',
                    icon: Icons.star_rounded,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 8),
                  _MetadataPill(label: series.genre),
                  const SizedBox(width: 8),
                  const _MetadataPill(label: '2026'),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'A guarded heiress and the stranger hired to protect her uncover a secret that ties their families together—and puts both their hearts at risk.',
                style: TextStyle(color: Color(0xFFD0D0D7), height: 1.55),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onWatch,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start watching — Episode 1'),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Text(
                    'Episodes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  Text(
                    series.episodeLabel,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          sliver: SliverList.separated(
            itemCount: 12,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final episode = index + 1;
              final isFree = episode <= 5;
              return ListTile(
                onTap: isFree
                    ? onWatch
                    : () => _showUnlockSheet(context, episode),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 7,
                ),
                leading: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: series.colors.take(2).toList(),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$episode',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  'Episode $episode',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  isFree ? 'Free • 1m 42s' : 'Locked • 1m 38s',
                  style: TextStyle(
                    color: isFree ? AppColors.coral : AppColors.muted,
                  ),
                ),
                trailing: Icon(
                  isFree ? Icons.play_circle_fill_rounded : Icons.lock_rounded,
                  color: isFree ? Colors.white : AppColors.gold,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  void _showUnlockSheet(BuildContext context, int episode) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unlock Episode $episode',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to keep watching.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              _UnlockChoice(
                icon: Icons.smart_display_rounded,
                title: 'Watch an ad',
                subtitle: 'Unlock this episode free',
                onTap: () {},
              ),
              _UnlockChoice(
                icon: Icons.monetization_on_rounded,
                title: 'Use 5 coins',
                subtitle: 'Balance: 25 coins',
                color: AppColors.gold,
                onTap: () {},
              ),
              _UnlockChoice(
                icon: Icons.workspace_premium_rounded,
                title: 'Go Premium',
                subtitle: 'Unlimited episodes, no ads',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.label, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _UnlockChoice extends StatelessWidget {
  const _UnlockChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.coral,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .15),
      child: Icon(icon, color: color),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}
