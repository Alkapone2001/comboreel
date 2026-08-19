import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/app_services.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/catalogue/domain/catalogue_episode.dart';
import '../features/catalogue/domain/catalogue_series.dart';
import '../features/home/domain/series.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/my_list_screen.dart';
import '../features/library/presentation/watch_history_screen.dart';
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
  final List<StreamSubscription<Uri>> _deepLinkSubscriptions = [];

  @override
  void initState() {
    super.initState();
    unawaited(widget.services.analyticsRepository.track('app_opened'));
    _deepLinkSubscriptions
      ..add(
        widget.services.pushNotificationService.deepLinks.listen(_openDeepLink),
      )
      ..add(widget.services.deepLinkService.links.listen(_openDeepLink));
    final initialDeepLink = Uri.tryParse(
      Uri.base.queryParameters['deep_link'] ?? '',
    );
    if (initialDeepLink != null && initialDeepLink.scheme == 'comboreel') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openDeepLink(initialDeepLink),
      );
    }
  }

  Future<void> _openDeepLink(Uri uri) async {
    if (!mounted) return;
    const destinations = {'home': 0, 'discover': 1, 'coins': 2, 'profile': 3};
    final segments = uri.scheme == 'comboreel'
        ? [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    final destination = segments.firstOrNull;
    final index = destinations[destination];
    if (index != null) {
      setState(() => _selectedIndex = index);
      return;
    }
    if (destination != 'series' || segments.length < 2) return;
    try {
      final items = await widget.services.catalogueRepository.latestSeries(
        limit: 100,
      );
      final catalogue = items
          .where((item) => item.id == segments[1])
          .firstOrNull;
      if (catalogue == null || !mounted) throw StateError('story_not_found');
      if (segments.length >= 4 && segments[2] == 'episode') {
        final episodes = await widget.services.catalogueRepository
            .episodesForSeries(catalogue.id);
        final episode = episodes
            .where((item) => item.id == segments[3])
            .firstOrNull;
        if (episode == null || !mounted) throw StateError('episode_not_found');
        _openPlayer(episode);
      } else {
        _openSeries(_presentation(catalogue));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That shared story is not available.')),
        );
      }
    }
  }

  DramaSeries _presentation(CatalogueSeries series) => DramaSeries(
    id: series.id,
    title: series.title,
    genre: series.genres.join(' · '),
    episodeLabel: '${series.episodeCount} episodes',
    colors: const [Color(0xFF6B233F), Color(0xFF19101C), Color(0xFF09090C)],
    synopsis: series.synopsis,
    releaseYear: series.releaseYear,
    ageRating: series.ageRating,
    originalLanguage: series.originalLanguage,
    episodeCount: series.episodeCount,
    posterUrl: series.posterUrl,
    heroUrl: series.heroUrl,
  );

  @override
  void dispose() {
    for (final subscription in _deepLinkSubscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  String? get _viewerId =>
      widget.services.authRepository.currentUser?.id ??
      (widget.services.backendConfigured ? null : 'demo-viewer');

  void _openSeries(DramaSeries series) {
    unawaited(
      widget.services.analyticsRepository.track(
        'series_opened',
        seriesId: series.id,
        properties: const {'source': 'catalogue'},
      ),
    );
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
          analyticsRepository: widget.services.analyticsRepository,
          contentShareService: widget.services.contentShareService,
        ),
      ),
    );
  }

  void _openPlayer(CatalogueEpisode episode, {int positionSeconds = 0}) {
    unawaited(
      widget.services.analyticsRepository.track(
        'playback_started',
        seriesId: episode.seriesId,
        episodeId: episode.id,
        properties: {'position_seconds': positionSeconds},
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EpisodePlayerScreen(
          episode: episode,
          initialPositionSeconds: positionSeconds,
          viewerLibraryRepository: widget.services.viewerLibraryRepository,
          playbackRepository: widget.services.playbackRepository,
          viewerId: _viewerId,
          contentShareService: widget.services.contentShareService,
          preferencesRepository: widget.services.viewerPreferencesRepository,
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

  void _openWatchHistory() {
    final viewerId = _viewerId;
    if (viewerId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchHistoryScreen(
          catalogueRepository: widget.services.catalogueRepository,
          viewerLibraryRepository: widget.services.viewerLibraryRepository,
          viewerId: viewerId,
          onResume: (episode, positionSeconds) =>
              _openPlayer(episode, positionSeconds: positionSeconds),
        ),
      ),
    );
  }

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminDashboardScreen(
          repository: widget.services.adminRepository,
          analyticsRepository: widget.services.analyticsRepository,
          pushCampaignRepository: widget.services.pushCampaignRepository,
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
        onSearch: () => setState(() => _selectedIndex = 1),
        onNotifications: () => setState(() => _selectedIndex = 3),
      ),
      DiscoverScreen(
        catalogueRepository: widget.services.catalogueRepository,
        onOpenSeries: _openSeries,
      ),
      CoinsScreen(
        repository: widget.services.monetizationRepository,
        store: widget.services.storePurchaseService,
        viewerId: _viewerId,
        analyticsRepository: widget.services.analyticsRepository,
      ),
      ProfileScreen(
        authRepository: widget.services.authRepository,
        backendConfigured: widget.services.backendConfigured,
        onOpenMyList: _openMyList,
        adminRepository: widget.services.adminRepository,
        onOpenAdmin: _openAdmin,
        onOpenWatchHistory: _openWatchHistory,
        onOpenPremium: () => setState(() => _selectedIndex = 2),
        analyticsRepository: widget.services.analyticsRepository,
        pushNotificationService: widget.services.pushNotificationService,
        privacyRepository: widget.services.privacyRepository,
        preferencesRepository: widget.services.viewerPreferencesRepository,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          const destinations = ['home', 'discover', 'coins', 'profile'];
          unawaited(
            widget.services.analyticsRepository.track(
              'navigation_selected',
              properties: {'destination': destinations[value]},
            ),
          );
          setState(() => _selectedIndex = value);
        },
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
