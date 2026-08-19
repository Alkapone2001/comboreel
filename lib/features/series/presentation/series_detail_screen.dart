import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_artwork.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/domain/catalogue_episode.dart';
import '../../catalogue/domain/catalogue_season.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../home/domain/series.dart';
import '../../library/data/viewer_library_repository.dart';
import '../../monetization/data/monetization_repository.dart';
import '../../monetization/data/rewarded_ad_service.dart';
import '../../monetization/domain/rewarded_ad_claim.dart';

class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({
    super.key,
    required this.series,
    required this.catalogueRepository,
    required this.viewerLibraryRepository,
    required this.monetizationRepository,
    required this.rewardedAdService,
    required this.viewerId,
    required this.onWatch,
    required this.onOpenPremium,
    this.analyticsRepository = const NoopAnalyticsRepository(),
  });

  final DramaSeries series;
  final CatalogueRepository catalogueRepository;
  final ViewerLibraryRepository viewerLibraryRepository;
  final MonetizationRepository monetizationRepository;
  final RewardedAdService rewardedAdService;
  final String? viewerId;
  final ValueChanged<CatalogueEpisode> onWatch;
  final VoidCallback onOpenPremium;
  final AnalyticsRepository analyticsRepository;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar.large(
          expandedHeight: 360,
          pinned: true,
          actions: [
            _FavouriteButton(
              repository: viewerLibraryRepository,
              viewerId: viewerId,
              seriesId: series.id,
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
              child: AppArtwork(
                source: series.heroUrl ?? series.posterUrl,
                fallback: const SizedBox.expand(),
                alignment: Alignment.centerRight,
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
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverList.list(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (series.genre.isNotEmpty)
                    _MetadataPill(label: series.genre),
                  if (series.releaseYear != null)
                    _MetadataPill(label: '${series.releaseYear}'),
                  if (series.ageRating != null)
                    _MetadataPill(label: series.ageRating!),
                  _MetadataPill(
                    label: series.originalLanguage.toUpperCase(),
                    icon: Icons.language_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                series.synopsis.isEmpty
                    ? 'The full synopsis is coming soon.'
                    : series.synopsis,
                style: const TextStyle(color: Color(0xFFD0D0D7), height: 1.55),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startFirstEpisode,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start watching — Episode 1'),
                ),
              ),
              const SizedBox(height: 30),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    'Episodes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    series.episodeCount > 0
                        ? '${series.episodeCount} episodes'
                        : series.episodeLabel,
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
        SliverToBoxAdapter(
          child: _EpisodeCatalogue(
            repository: catalogueRepository,
            seriesId: series.id,
            colors: series.colors,
            onWatch: onWatch,
            onUnlock: (episode) => _showUnlockSheet(context, episode),
          ),
        ),
      ],
    ),
  );

  Future<void> _startFirstEpisode() async {
    final episodes = await catalogueRepository.episodesForSeries(series.id);
    if (episodes.isNotEmpty) onWatch(episodes.first);
  }

  void _showUnlockSheet(BuildContext context, CatalogueEpisode episode) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unlock Episode ${episode.episodeNumber}',
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
                  subtitle: rewardedAdService.isAvailable
                      ? 'Unlock this episode free'
                      : 'Available in the iOS and Android apps',
                  onTap: rewardedAdService.isAvailable
                      ? () => _unlockWithRewardedAd(context, episode)
                      : null,
                ),
                _UnlockChoice(
                  icon: Icons.monetization_on_rounded,
                  title: 'Use ${episode.coinPrice} coins',
                  subtitle: 'Secure one-time unlock',
                  color: AppColors.gold,
                  onTap: () => _unlockWithCoins(context, episode),
                ),
                _UnlockChoice(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Go Premium',
                  subtitle: 'Unlimited episodes, no ads',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenPremium();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlockWithCoins(
    BuildContext sheetContext,
    CatalogueEpisode episode,
  ) async {
    if (viewerId == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Sign in to unlock episodes with coins.')),
      );
      return;
    }
    try {
      final result = await monetizationRepository.unlockEpisodeWithCoins(
        episodeId: episode.id,
        idempotencyKey:
            '${episode.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (result.accessGranted && sheetContext.mounted) {
        unawaited(
          analyticsRepository.track(
            'coin_unlock_completed',
            seriesId: episode.seriesId,
            episodeId: episode.id,
            properties: const {'method': 'coins'},
          ),
        );
        Navigator.of(sheetContext).pop();
        onWatch(episode);
      }
    } on InsufficientCoinsException {
      if (sheetContext.mounted) {
        unawaited(
          analyticsRepository.track(
            'rewarded_unlock_completed',
            seriesId: episode.seriesId,
            episodeId: episode.id,
            properties: const {'method': 'rewarded_ad'},
          ),
        );
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(content: Text('You do not have enough coins.')),
        );
      }
    }
  }

  Future<void> _unlockWithRewardedAd(
    BuildContext sheetContext,
    CatalogueEpisode episode,
  ) async {
    final userId = viewerId;
    if (userId == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Sign in to unlock episodes with an ad.')),
      );
      return;
    }
    final navigator = Navigator.of(sheetContext);
    final messenger = ScaffoldMessenger.of(sheetContext);
    try {
      final claim = await monetizationRepository.createRewardedEpisodeClaim(
        episode.id,
      );
      await rewardedAdService.show(userId: userId, claimId: claim.id);
      RewardedAdClaimStatus status = RewardedAdClaimStatus.pending;
      final verificationDeadline = DateTime.now().toUtc().add(
        const Duration(seconds: 20),
      );
      while (DateTime.now().toUtc().isBefore(verificationDeadline) &&
          DateTime.now().toUtc().isBefore(claim.expiresAt) &&
          status == RewardedAdClaimStatus.pending) {
        status = await monetizationRepository.rewardedEpisodeClaimStatus(
          claim.id,
        );
        if (status == RewardedAdClaimStatus.pending) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (status != RewardedAdClaimStatus.verified) {
        throw const RewardVerificationTimeoutException();
      }
      if (sheetContext.mounted) {
        navigator.pop();
        onWatch(episode);
      }
    } on RewardedAdUnavailableException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on RewardVerificationTimeoutException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your reward is still being verified. Try again shortly.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The rewarded unlock could not be completed.'),
        ),
      );
    }
  }
}

class _EpisodeCatalogue extends StatefulWidget {
  const _EpisodeCatalogue({
    required this.repository,
    required this.seriesId,
    required this.colors,
    required this.onWatch,
    required this.onUnlock,
  });

  final CatalogueRepository repository;
  final String seriesId;
  final List<Color> colors;
  final ValueChanged<CatalogueEpisode> onWatch;
  final ValueChanged<CatalogueEpisode> onUnlock;

  @override
  State<_EpisodeCatalogue> createState() => _EpisodeCatalogueState();
}

class _EpisodeCatalogueState extends State<_EpisodeCatalogue> {
  late Future<_EpisodeCatalogueData> _data;
  String? _selectedSeasonId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _data = _load();

  Future<_EpisodeCatalogueData> _load() async {
    final episodes = await widget.repository.episodesForSeries(widget.seriesId);
    final seasons = widget.repository is SeasonCatalogueRepository
        ? await (widget.repository as SeasonCatalogueRepository)
              .seasonsForSeries(widget.seriesId)
        : <CatalogueSeason>[];
    return _EpisodeCatalogueData(episodes: episodes, seasons: seasons);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_EpisodeCatalogueData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Episodes could not load.',
                  style: TextStyle(color: AppColors.coral),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Semantics(
              label: 'Loading episodes',
              child: const CircularProgressIndicator(),
            ),
          ),
        );
      }
      final data = snapshot.data!;
      if (data.episodes.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Text(
              'Episodes are coming soon.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        );
      }
      final selectedId = _selectedSeasonId ?? data.seasons.firstOrNull?.id;
      final visible = selectedId == null
          ? data.episodes
          : data.episodes
                .where((episode) => episode.seasonId == selectedId)
                .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.seasons.length > 1)
            Semantics(
              container: true,
              label: 'Choose season',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.seasons
                      .map(
                        (season) => ChoiceChip(
                          label: Text(season.label),
                          selected: selectedId == season.id,
                          onSelected: (_) =>
                              setState(() => _selectedSeasonId = season.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No episodes in this season yet.')),
            )
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final episode = visible[index];
                return _EpisodeTile(
                  episode: episode,
                  colors: widget.colors,
                  onWatch: () => widget.onWatch(episode),
                  onUnlock: () => widget.onUnlock(episode),
                );
              },
            ),
        ],
      );
    },
  );
}

class _EpisodeCatalogueData {
  const _EpisodeCatalogueData({required this.episodes, required this.seasons});
  final List<CatalogueEpisode> episodes;
  final List<CatalogueSeason> seasons;
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.colors,
    required this.onWatch,
    required this.onUnlock,
  });
  final CatalogueEpisode episode;
  final List<Color> colors;
  final VoidCallback onWatch;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final minutes = episode.durationSeconds ~/ 60;
    final seconds = episode.durationSeconds % 60;
    return ListTile(
      onTap: episode.isFree ? onWatch : onUnlock,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      leading: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.take(2).toList()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${episode.episodeNumber}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      title: Text(
        'Episode ${episode.episodeNumber}: ${episode.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${episode.isFree ? 'Free' : 'Locked'} • $minutes:${seconds.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: episode.isFree ? AppColors.coral : AppColors.muted,
        ),
      ),
      trailing: Icon(
        episode.isFree ? Icons.play_circle_fill_rounded : Icons.lock_rounded,
        color: episode.isFree ? Colors.white : AppColors.gold,
      ),
    );
  }
}

class _FavouriteButton extends StatefulWidget {
  const _FavouriteButton({
    required this.repository,
    required this.viewerId,
    required this.seriesId,
  });

  final ViewerLibraryRepository repository;
  final String? viewerId;
  final String seriesId;

  @override
  State<_FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<_FavouriteButton> {
  bool _favourite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final viewerId = widget.viewerId;
    if (viewerId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ids = await widget.repository.favouriteSeriesIds(viewerId);
    if (mounted) {
      setState(() {
        _favourite = ids.contains(widget.seriesId);
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final viewerId = widget.viewerId;
    if (viewerId == null || _loading) return;
    final next = !_favourite;
    setState(() => _favourite = next);
    try {
      if (next) {
        await widget.repository.addFavourite(
          userId: viewerId,
          seriesId: widget.seriesId,
        );
      } else {
        await widget.repository.removeFavourite(
          userId: viewerId,
          seriesId: widget.seriesId,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _favourite = !next);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: widget.viewerId == null || _loading ? null : _toggle,
    icon: Icon(
      _favourite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
    ),
    tooltip: _favourite ? 'Remove from My List' : 'Add to My List',
  );
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width - 40,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(99),
    ),
    child: icon == null
        ? Text(
            label,
            softWrap: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
    this.onTap,
    this.color = AppColors.coral,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
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
