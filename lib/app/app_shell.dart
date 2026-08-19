import 'package:flutter/material.dart';

import '../core/services/app_services.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/catalogue/domain/catalogue_episode.dart';
import '../features/home/domain/series.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/my_list_screen.dart';
import '../features/monetization/presentation/coins_screen.dart';
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
          monetizationRepository: widget.services.monetizationRepository,
          rewardedAdService: widget.services.rewardedAdService,
          viewerId: _viewerId,
          onWatch: _openPlayer,
          onOpenPremium: () {
            Navigator.of(context).pop();
            setState(() => _selectedIndex = 2);
          },
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
          playbackRepository: widget.services.playbackRepository,
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

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AdminDashboardScreen(repository: widget.services.adminRepository),
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
      CoinsScreen(
        repository: widget.services.monetizationRepository,
        store: widget.services.storePurchaseService,
        viewerId: _viewerId,
      ),
      ProfileScreen(
        authRepository: widget.services.authRepository,
        backendConfigured: widget.services.backendConfigured,
        onOpenMyList: _openMyList,
        adminRepository: widget.services.adminRepository,
        onOpenAdmin: _openAdmin,
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
