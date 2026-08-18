import 'package:flutter/material.dart';

import '../core/services/app_services.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/home/data/demo_series.dart';
import '../features/home/presentation/home_screen.dart';
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

  void _openSeries() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SeriesDetailScreen(series: featuredSeries, onWatch: _openPlayer),
      ),
    );
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EpisodePlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenSeries: _openSeries, onPlay: _openPlayer),
      const _PlaceholderPage(
        icon: Icons.explore_rounded,
        title: 'Discover stories',
        message: 'Search, genres, trending charts, and personalized collections will live here.',
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
