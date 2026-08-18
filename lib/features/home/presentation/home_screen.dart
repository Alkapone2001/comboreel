import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/demo_series.dart';
import '../domain/series.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSeries,
    required this.onPlay,
  });

  final VoidCallback onOpenSeries;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _TopBar()),
        SliverToBoxAdapter(
          child: _HeroBanner(onOpenSeries: onOpenSeries, onPlay: onPlay),
        ),
        SliverToBoxAdapter(
          child: _SeriesSection(
            title: 'Continue Watching',
            width: 210,
            height: 132,
            series: continueWatching,
            builder: (item) => _ContinueCard(series: item, onTap: onPlay),
          ),
        ),
        SliverToBoxAdapter(
          child: _SeriesSection(
            title: 'Trending Now',
            width: 148,
            height: 238,
            series: trendingSeries,
            builder: (item) => _PosterCard(series: item, onTap: onOpenSeries),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.coral, AppColors.magenta],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_arrow_rounded, size: 27),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) =>
              const LinearGradient(colors: [AppColors.coral, AppColors.magenta])
                  .createShader(bounds),
          child: const Text(
            'ComboReel',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
      ],
    ),
  );
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onOpenSeries, required this.onPlay});

  final VoidCallback onOpenSeries;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Container(
    height: 440,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 28),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: featuredSeries.colors,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x443E1328),
          blurRadius: 34,
          offset: Offset(0, 18),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -42,
          top: 12,
          child: Icon(
            Icons.favorite_rounded,
            size: 230,
            color: Colors.white.withValues(alpha: .055),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(label: featuredSeries.badge!),
                const SizedBox(height: 14),
                Text(
                  featuredSeries.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  featuredSeries.genre,
                  style: const TextStyle(
                    color: Color(0xFFE8BDC9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  featuredSeries.episodeLabel,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlay,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Watch free'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenSeries,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x66FFFFFF)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('My List'),
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

class _SeriesSection extends StatelessWidget {
  const _SeriesSection({
    required this.title,
    required this.width,
    required this.height,
    required this.series,
    required this.builder,
  });

  final String title;
  final double width;
  final double height;
  final List<DramaSeries> series;
  final Widget Function(DramaSeries) builder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('See all')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: series.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                SizedBox(width: width, child: builder(series[index])),
          ),
        ),
      ],
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.series, required this.onTap});
  final DramaSeries series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: _Artwork(
      series: series,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              series.episodeLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCECED5)),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: series.progress,
              minHeight: 3,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: Colors.white24,
              color: AppColors.coral,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.series, required this.onTap});
  final DramaSeries series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Artwork(
            series: series,
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 10,
                  child: _Badge(label: series.badge!),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 44,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          series.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          series.genre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.series, required this.child});
  final DramaSeries series;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: series.colors,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.coral, AppColors.magenta],
      ),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    ),
  );
}
