import 'package:flutter/material.dart';

import '../core/services/app_services.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/catalogue/domain/catalogue_episode.dart';
import '../features/home/domain/series.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/my_list_screen.dart';
import '../features/player/presentation/episode_player_screen.dart';
import '../features/series/presentation/series_detail_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});

  final AppServices services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  String? get _viewerId =>
      widget.services.authRepository.currentUser?.id ??
      (widget.services.backendConfigured ? null : 'demo-viewer');

  void _openSeries(DramaSeries series) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesDetailScreen(
          series: series,
          catalogueRepository: widget.services.catalogueRepository,
          viewerLibraryRepository: widget.services.viewerLibraryRepository,
          viewerId: _viewerId,
          onWatch: _openPlayer,
        ),
      ),
    );
  }

  void _openPlayer(CatalogueEpisode episode, {int positionSeconds = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EpisodePlayerScreen(
          episode: episode,
          initialPositionSeconds: positionSeconds,
          viewerLibraryRepository: widget.services.viewerLibraryRepository,
          viewerId: _viewerId,
        ),
      ),
    );
  }

  Future<void> _openSeriesPlayer(DramaSeries series) async {
    final episodes = await widget.services.catalogueRepository
        .episodesForSeries(series.id);
    if (!mounted || episodes.isEmpty) return;
    final episode = series.episodeId == null
        ? episodes.first
        : episodes.firstWhere(
            (item) => item.id == series.episodeId,
            orElse: () => episodes.first,
          );
    _openPlayer(episode, positionSeconds: series.positionSeconds);
  }

  void _openMyList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyListScreen(
          catalogueRepository: widget.services.catalogueRepository,
          viewerLibraryRepository: widget.services.viewerLibraryRepository,
          viewerId: _viewerId,
          onOpenSeries: _openSeries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        catalogueRepository: widget.services.catalogueRepository,
        viewerLibraryRepository: widget.services.viewerLibraryRepository,
        viewerId: _viewerId,
        onOpenSeries: _openSeries,
        onPlay: _openSeriesPlayer,
      ),
      DiscoverScreen(
        catalogueRepository: widget.services.catalogueRepository,
        onOpenSeries: _openSeries,
      ),
      const _PlaceholderPage(
        icon: Icons.monetization_on_rounded,
        title: 'Coins & rewards',
        message: 'Your coin balance, daily rewards, rewarded ads, and purchase packs will live here.',
        accent: AppColors.gold,
      ),
      ProfileScreen(
        authRepository: widget.services.authRepository,
        backendConfigured: widget.services.backendConfigured,
        onOpenMyList: _openMyList,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on),
            label: 'Coins',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.message,
    this.accent = AppColors.coral,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 38),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
