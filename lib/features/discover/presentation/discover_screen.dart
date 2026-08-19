import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_artwork.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/domain/catalogue_series.dart';
import '../../home/domain/series.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.catalogueRepository,
    required this.onOpenSeries,
  });

  final CatalogueRepository catalogueRepository;
  final ValueChanged<DramaSeries> onOpenSeries;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<CatalogueSeries>> _results;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _results = widget.catalogueRepository.latestSeries(limit: 30);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _results = _query.isEmpty
            ? widget.catalogueRepository.latestSeries(limit: 30)
            : widget.catalogueRepository.searchSeries(_query);
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _results = widget.catalogueRepository.latestSeries(limit: 30);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find your next obsession.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                SearchBar(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  hintText: 'Search series',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear search',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _GenreChips(),
                const SizedBox(height: 28),
                Text(
                  _query.isEmpty ? 'Browse all' : 'Results for “$_query”',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<List<CatalogueSeries>>(
          future: _results,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _DiscoverMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Search is unavailable',
                  message: 'Check your connection and try again.',
                  action: TextButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload'),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final results = snapshot.data!;
            if (results.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _DiscoverMessage(
                  icon: Icons.search_off_rounded,
                  title: 'No stories found',
                  message: 'Try another title or browse a different genre.',
                  action: TextButton(
                    onPressed: _clearSearch,
                    child: const Text('Clear search'),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent:
                      265 +
                      ((MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                            0,
                            1.5,
                          ) *
                          45),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return _DiscoverCard(
                    series: item,
                    rank: index,
                    onTap: () =>
                        widget.onOpenSeries(_presentationSeries(item, index)),
                  );
                },
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _GenreChips extends StatelessWidget {
  const _GenreChips();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      Chip(label: Text('Romance')),
      Chip(label: Text('Thriller')),
      Chip(label: Text('Crime')),
      Chip(label: Text('Family Drama')),
    ],
  );
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({
    required this.series,
    required this.rank,
    required this.onTap,
  });
  final CatalogueSeries series;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationSeries(series, rank);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Open ${series.title}, ${series.episodeCount} episodes',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: presentation.colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
                child: AppArtwork(
                  source: series.posterUrl,
                  fallback: const SizedBox.expand(),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      size: 46,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              series.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              series.releaseYear?.toString() ?? 'New series',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverMessage extends StatelessWidget {
  const _DiscoverMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          action,
        ],
      ),
    ),
  );
}

DramaSeries _presentationSeries(CatalogueSeries series, int rank) {
  const palettes = [
    [Color(0xFF8E2D56), Color(0xFF241019)],
    [Color(0xFF0F4C5C), Color(0xFF081B20)],
    [Color(0xFF7B4B2A), Color(0xFF21140C)],
    [Color(0xFF42275A), Color(0xFF15121A)],
  ];
  return DramaSeries(
    id: series.id,
    title: series.title,
    genre: series.genres.isEmpty
        ? series.originalLanguage.toUpperCase()
        : series.genres.join(' · '),
    episodeLabel: series.episodeCount > 0
        ? '${series.episodeCount} episodes'
        : 'New series',
    colors: palettes[rank % palettes.length],
    badge: rank < 3 ? '#${rank + 1}' : null,
    synopsis: series.synopsis,
    releaseYear: series.releaseYear,
    ageRating: series.ageRating,
    originalLanguage: series.originalLanguage,
    episodeCount: series.episodeCount,
    posterUrl: series.posterUrl,
    heroUrl: series.heroUrl,
  );
}
