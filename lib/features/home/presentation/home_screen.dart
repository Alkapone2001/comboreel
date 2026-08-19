import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/domain/catalogue_series.dart';
import '../../library/data/viewer_library_repository.dart';
import '../../library/domain/viewer_progress.dart';
import '../domain/series.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.catalogueRepository,
    required this.viewerLibraryRepository,
    required this.viewerId,
    required this.onOpenSeries,
    required this.onPlay,
  });

  final CatalogueRepository catalogueRepository;
  final ViewerLibraryRepository viewerLibraryRepository;
  final String? viewerId;
  final ValueChanged<DramaSeries> onOpenSeries;
  final ValueChanged<DramaSeries> onPlay;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeCatalogue> _catalogue;

  @override
  void initState() {
    super.initState();
    _loadCatalogue();
  }

  void _loadCatalogue() {
    _catalogue = _HomeCatalogue.load(
      widget.catalogueRepository,
      widget.viewerLibraryRepository,
      widget.viewerId,
    );
  }

  void _retry() => setState(_loadCatalogue);

  @override
  Widget build(BuildContext context) => FutureBuilder<_HomeCatalogue>(
    future: _catalogue,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _CatalogueError(onRetry: _retry);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      if (data.latest.isEmpty) return const _EmptyCatalogue();
      final hero = _toDramaSeries(data.featured ?? data.latest.first, 0);
      final trending = data.latest
          .take(10)
          .toList()
          .asMap()
          .entries
          .map((entry) => _toDramaSeries(entry.value, entry.key + 1))
          .toList();
      final continueItems = data.progress.map(_progressToDramaSeries).toList();
      return _HomeContent(
        hero: hero,
        trending: trending,
        continueItems: continueItems,
        onOpenSeries: widget.onOpenSeries,
        onPlay: widget.onPlay,
      );
    },
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.hero,
    required this.trending,
    required this.continueItems,
    required this.onOpenSeries,
    required this.onPlay,
  });

  final DramaSeries hero;
  final List<DramaSeries> trending;
  final List<DramaSeries> continueItems;
  final ValueChanged<DramaSeries> onOpenSeries;
  final ValueChanged<DramaSeries> onPlay;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _TopBar()),
        SliverToBoxAdapter(
          child: _HeroBanner(
            series: hero,
            onOpenSeries: () => onOpenSeries(hero),
            onPlay: () => onPlay(hero),
          ),
        ),
        if (continueItems.isNotEmpty)
          SliverToBoxAdapter(
            child: _SeriesSection(
              title: 'Continue Watching',
              width: 210,
              height: 132,
              series: continueItems,
              builder: (item) =>
                  _ContinueCard(series: item, onTap: () => onPlay(item)),
            ),
          ),
        SliverToBoxAdapter(
          child: _SeriesSection(
            title: 'Trending Now',
            width: 148,
            height: 238,
            series: trending,
            builder: (item) =>
                _PosterCard(series: item, onTap: () => onOpenSeries(item)),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    ),
  );
}

class _HomeCatalogue {
  const _HomeCatalogue({
    required this.featured,
    required this.latest,
    required this.progress,
  });
  final CatalogueSeries? featured;
  final List<CatalogueSeries> latest;
  final List<ViewerProgress> progress;

  static Future<_HomeCatalogue> load(
    CatalogueRepository repository,
    ViewerLibraryRepository library,
    String? viewerId,
  ) async {
    final results = await Future.wait([
      repository.featuredSeries(),
      repository.latestSeries(),
    ]);
    final featured = results.first;
    return _HomeCatalogue(
      featured: featured.isEmpty ? null : featured.first,
      latest: results.last,
      progress: viewerId == null
          ? const []
          : await library.recentProgress(viewerId),
    );
  }
}

DramaSeries _progressToDramaSeries(ViewerProgress progress) => DramaSeries(
  id: progress.seriesId,
  title: progress.seriesTitle,
  genre: progress.episodeTitle,
  episodeLabel: 'Episode ${progress.episodeNumber}',
  colors: const [Color(0xFF243B55), Color(0xFF141E30)],
  progress: progress.fraction,
  episodeId: progress.episodeId,
  positionSeconds: progress.positionSeconds,
);

DramaSeries _toDramaSeries(CatalogueSeries series, int rank) {
  const palettes = [
    [Color(0xFF6B233F), Color(0xFF19101C), Color(0xFF09090C)],
    [Color(0xFF8E2D56), Color(0xFF241019)],
    [Color(0xFF0F4C5C), Color(0xFF081B20)],
    [Color(0xFF7B4B2A), Color(0xFF21140C)],
  ];
  return DramaSeries(
    id: series.id,
    title: series.title,
    genre: series.originalLanguage.toUpperCase(),
    episodeLabel: series.releaseYear?.toString() ?? 'New series',
    colors: palettes[rank % palettes.length],
    badge: rank == 0 ? 'NEW SERIES' : '#$rank',
  );
}

class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.coral),
          const SizedBox(height: 16),
          Text(
            'Stories could not load',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'New stories are coming soon.',
        style: TextStyle(color: AppColors.muted),
      ),
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
  const _HeroBanner({
    required this.series,
    required this.onOpenSeries,
    required this.onPlay,
  });

  final DramaSeries series;
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
        colors: series.colors,
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
                _Badge(label: series.badge!),
                const SizedBox(height: 14),
                Text(
                  series.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  series.genre,
                  style: const TextStyle(
                    color: Color(0xFFE8BDC9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  series.episodeLabel,
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
