import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/content_share_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../catalogue/domain/catalogue_episode.dart';
import '../../library/data/viewer_library_repository.dart';
import '../../monetization/data/monetization_repository.dart';
import '../../monetization/data/rewarded_ad_service.dart';
import '../../monetization/domain/rewarded_ad_claim.dart';
import '../../preferences/data/viewer_preferences_repository.dart';
import '../data/playback_repository.dart';
import '../domain/playback_session.dart';

class EpisodePlayerScreen extends StatefulWidget {
  const EpisodePlayerScreen({
    super.key,
    required this.episode,
    required this.viewerLibraryRepository,
    required this.playbackRepository,
    required this.viewerId,
    this.episodes = const [],
    this.initialPositionSeconds = 0,
    this.contentShareService = const NoopContentShareService(),
    this.preferencesRepository = const UnavailableViewerPreferencesRepository(),
    this.monetizationRepository,
    this.rewardedAdService = const UnavailableRewardedAdService(),
    this.analyticsRepository = const NoopAnalyticsRepository(),
    this.sessionRefreshLeadTime = const Duration(seconds: 30),
    this.onEpisodeChanged,
  });

  final CatalogueEpisode episode;
  final ViewerLibraryRepository viewerLibraryRepository;
  final PlaybackRepository playbackRepository;
  final String? viewerId;
  final List<CatalogueEpisode> episodes;
  final int initialPositionSeconds;
  final ContentShareService contentShareService;
  final ViewerPreferencesRepository preferencesRepository;
  final MonetizationRepository? monetizationRepository;
  final RewardedAdService rewardedAdService;
  final AnalyticsRepository analyticsRepository;
  final Duration sessionRefreshLeadTime;
  final ValueChanged<CatalogueEpisode>? onEpisodeChanged;

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  PlaybackSession? _session;
  SubtitleTrack? _selectedSubtitle;
  bool _demoPlaying = true;
  bool _isLiked = false;
  bool _loading = true;
  bool _transitioning = false;
  bool _completionHandled = false;
  bool _resumeAfterBackground = false;
  bool _scrubbing = false;
  bool _unlocking = false;
  bool _refreshingSession = false;
  String? _error;
  Timer? _sessionRefreshTimer;
  late final List<CatalogueEpisode> _episodes;
  late CatalogueEpisode _episode;
  late int _positionSeconds;
  int _lastPersistedSecond = -1;
  int _loadGeneration = 0;
  final Set<String> _trackedCompletions = {};

  bool get _isPlaying => _videoController?.value.isPlaying ?? _demoPlaying;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episode = widget.episode;
    _episodes =
        [
          ...widget.episodes.where(
            (item) => item.seriesId == widget.episode.seriesId,
          ),
        ]..sort((left, right) {
          final season = (left.seasonNumber ?? 0).compareTo(
            right.seasonNumber ?? 0,
          );
          return season != 0
              ? season
              : left.episodeNumber.compareTo(right.episodeNumber);
        });
    if (!_episodes.any((item) => item.id == _episode.id)) {
      _episodes.add(_episode);
      _episodes.sort(
        (left, right) => left.episodeNumber.compareTo(right.episodeNumber),
      );
    }
    _positionSeconds = widget.initialPositionSeconds.clamp(
      0,
      _episode.durationSeconds,
    );
    unawaited(_loadSession());
    unawaited(_loadFavourite());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pauseForBackground();
      case AppLifecycleState.resumed:
        _resumeFromBackground();
    }
  }

  void _pauseForBackground() {
    if (_resumeAfterBackground) return;
    final controller = _videoController;
    _resumeAfterBackground = controller?.value.isPlaying ?? _demoPlaying;
    if (controller != null) {
      unawaited(controller.pause());
    } else {
      _demoPlaying = false;
    }
    unawaited(_saveProgress());
    if (mounted) setState(() {});
  }

  void _resumeFromBackground() {
    if (!_resumeAfterBackground) return;
    _resumeAfterBackground = false;
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.play());
    } else if (_error == null) {
      _demoPlaying = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadFavourite() async {
    final viewerId = widget.viewerId;
    if (viewerId == null) return;
    final favourites = await widget.viewerLibraryRepository.favouriteSeriesIds(
      viewerId,
    );
    if (mounted) {
      setState(() => _isLiked = favourites.contains(_episode.seriesId));
    }
  }

  Future<void> _toggleFavourite() async {
    final viewerId = widget.viewerId;
    if (viewerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save this series.')),
      );
      return;
    }
    final next = !_isLiked;
    setState(() => _isLiked = next);
    try {
      if (next) {
        await widget.viewerLibraryRepository.addFavourite(
          userId: viewerId,
          seriesId: _episode.seriesId,
        );
      } else {
        await widget.viewerLibraryRepository.removeFavourite(
          userId: viewerId,
          seriesId: _episode.seriesId,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLiked = !next);
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    await widget.contentShareService.share(
      title: _episode.seriesTitle == null
          ? 'Watch Episode ${_episode.episodeNumber} on ComboReel'
          : 'Watch ${_episode.seriesTitle} on ComboReel',
      deepLink: Uri(
        scheme: 'comboreel',
        host: 'series',
        pathSegments: [_episode.seriesId, 'episode', _episode.id],
      ),
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _loadSession({bool refreshing = false}) async {
    _sessionRefreshTimer?.cancel();
    final generation = ++_loadGeneration;
    final episode = _episode;
    try {
      final session = await widget.playbackRepository.createSession(episode.id);
      if (!mounted || generation != _loadGeneration) return;
      SubtitleTrack? selectedSubtitle;
      if (refreshing) {
        final activeLanguage = _selectedSubtitle?.languageCode;
        selectedSubtitle = activeLanguage == null
            ? null
            : session.subtitles
                  .where((track) => track.languageCode == activeLanguage)
                  .firstOrNull;
        selectedSubtitle ??= activeLanguage == null
            ? null
            : session.subtitles.where((track) => track.isDefault).firstOrNull;
      } else {
        final preferredLanguage = await widget.preferencesRepository
            .preferredSubtitleLanguage();
        selectedSubtitle = session.subtitles
            .where((track) => track.languageCode == preferredLanguage)
            .firstOrNull;
        selectedSubtitle ??= session.subtitles
            .where((track) => track.isDefault)
            .firstOrNull;
      }
      if (session.hlsUrl != null) {
        await _initializeVideo(
          session.hlsUrl!,
          selectedSubtitle,
          generation: generation,
        );
      } else if (mounted && !refreshing) {
        setState(() => _loading = false);
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _session = session;
        _selectedSubtitle = selectedSubtitle;
      });
      _scheduleSessionRefresh(session);
    } on PlaybackAccessException catch (error) {
      if (refreshing) {
        _scheduleRefreshRetry(generation);
      } else if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error = error.code;
        });
      }
    } catch (_) {
      if (refreshing) {
        _scheduleRefreshRetry(generation);
      } else if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error = 'playback_unavailable';
        });
      }
    }
  }

  void _scheduleSessionRefresh(PlaybackSession session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null || !mounted) return;
    final refreshAt = expiresAt.subtract(widget.sessionRefreshLeadTime);
    final delay = refreshAt.difference(DateTime.now().toUtc());
    _sessionRefreshTimer = Timer(
      delay > Duration.zero ? delay : const Duration(seconds: 1),
      () => unawaited(_refreshSession()),
    );
  }

  void _scheduleRefreshRetry(int generation) {
    if (!mounted || generation != _loadGeneration) return;
    _sessionRefreshTimer = Timer(
      const Duration(seconds: 5),
      () => unawaited(_refreshSession()),
    );
  }

  Future<void> _refreshSession() async {
    if (_refreshingSession || _transitioning || _error != null || !mounted) {
      return;
    }
    _refreshingSession = true;
    try {
      await _loadSession(refreshing: true);
    } finally {
      _refreshingSession = false;
    }
  }

  Future<void> _retrySession() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _saveProgress();
    if (!mounted) return;
    await _loadSession();
  }

  Future<void> _unlockWithCoins() async {
    final monetization = widget.monetizationRepository;
    if (monetization == null || _unlocking) return;
    if (widget.viewerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to unlock episodes with coins.')),
      );
      return;
    }
    setState(() => _unlocking = true);
    try {
      final result = await monetization.unlockEpisodeWithCoins(
        episodeId: _episode.id,
        idempotencyKey:
            '${_episode.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (result.accessGranted) {
        unawaited(
          widget.analyticsRepository.track(
            'coin_unlock_completed',
            seriesId: _episode.seriesId,
            episodeId: _episode.id,
            properties: const {'method': 'coins'},
          ),
        );
        await _retrySession();
      }
    } on InsufficientCoinsException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have enough coins.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The episode could not be unlocked.')),
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _unlockWithRewardedAd() async {
    final monetization = widget.monetizationRepository;
    final userId = widget.viewerId;
    if (monetization == null || _unlocking) return;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to unlock episodes with an ad.')),
      );
      return;
    }
    setState(() => _unlocking = true);
    try {
      final claim = await monetization.createRewardedEpisodeClaim(_episode.id);
      await widget.rewardedAdService.show(userId: userId, claimId: claim.id);
      var status = RewardedAdClaimStatus.pending;
      final verificationDeadline = DateTime.now().toUtc().add(
        const Duration(seconds: 20),
      );
      while (DateTime.now().toUtc().isBefore(verificationDeadline) &&
          DateTime.now().toUtc().isBefore(claim.expiresAt) &&
          status == RewardedAdClaimStatus.pending) {
        status = await monetization.rewardedEpisodeClaimStatus(claim.id);
        if (status == RewardedAdClaimStatus.pending) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (status != RewardedAdClaimStatus.verified) {
        throw const RewardVerificationTimeoutException();
      }
      unawaited(
        widget.analyticsRepository.track(
          'rewarded_unlock_completed',
          seriesId: _episode.seriesId,
          episodeId: _episode.id,
          properties: const {'method': 'rewarded_ad'},
        ),
      );
      if (mounted) await _retrySession();
    } on RewardedAdUnavailableException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on RewardVerificationTimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your reward is still being verified. Try again shortly.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The rewarded unlock could not be completed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _initializeVideo(
    Uri hlsUrl,
    SubtitleTrack? subtitle, {
    int? generation,
  }) async {
    final previous = _videoController;
    final shouldPlay = previous?.value.isPlaying ?? true;
    final resumeAt =
        previous?.value.position ?? Duration(seconds: _positionSeconds);

    final controller = VideoPlayerController.networkUrl(
      hlsUrl,
      formatHint: VideoFormat.hls,
      closedCaptionFile: subtitle == null
          ? null
          : _loadCaptions(subtitle.vttUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    await controller.initialize();
    if (!mounted || (generation != null && generation != _loadGeneration)) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(false);
    if (resumeAt > Duration.zero && resumeAt < controller.value.duration) {
      await controller.seekTo(resumeAt);
    }
    if (previous != null) {
      previous.removeListener(_onVideoChanged);
      await previous.dispose();
    }
    _videoController = controller;
    controller.addListener(_onVideoChanged);
    if (shouldPlay) await controller.play();
    if (mounted) {
      setState(() {
        _loading = false;
        _error = null;
      });
    }
  }

  Future<ClosedCaptionFile> _loadCaptions(Uri url) async {
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw StateError('subtitle_download_failed');
    }
    return WebVTTCaptionFile(response.body);
  }

  void _onVideoChanged() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.hasError && _error == null) {
      _demoPlaying = false;
      unawaited(controller.pause());
      unawaited(_saveProgress());
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'playback_interrupted';
        });
      }
      return;
    }
    final second = controller.value.position.inSeconds;
    if (!_scrubbing && second != _positionSeconds && mounted) {
      setState(() => _positionSeconds = second);
    }
    if (second > 0 && second % 10 == 0 && second != _lastPersistedSecond) {
      _lastPersistedSecond = second;
      unawaited(_saveProgress());
    }
    if (controller.value.isCompleted && !_completionHandled) {
      _completionHandled = true;
      unawaited(_goToRelative(1, markCurrentCompleted: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionRefreshTimer?.cancel();
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(controller.dispose());
    }
    unawaited(_saveProgress());
    super.dispose();
  }

  Future<void> _saveProgress({bool? completed}) async {
    final viewerId = widget.viewerId;
    if (viewerId == null) return;
    final episode = _episode;
    final positionSeconds = _positionSeconds;
    final duration =
        _videoController?.value.duration.inSeconds ?? episode.durationSeconds;
    final isCompleted =
        completed ?? (duration > 0 && positionSeconds >= duration - 3);
    try {
      await widget.viewerLibraryRepository.saveProgress(
        userId: viewerId,
        episodeId: episode.id,
        positionSeconds: positionSeconds,
        completed: isCompleted,
      );
      if (isCompleted && _trackedCompletions.add(episode.id)) {
        unawaited(
          widget.analyticsRepository.track(
            'episode_completed',
            seriesId: episode.seriesId,
            episodeId: episode.id,
            properties: {'position_seconds': positionSeconds},
          ),
        );
      }
    } catch (_) {
      // Playback remains available when a best-effort progress write is offline.
    }
  }

  Future<void> _seekTo(double rawSeconds) async {
    final duration =
        _videoController?.value.duration.inSeconds ?? _episode.durationSeconds;
    if (duration <= 0) return;
    final target = rawSeconds.round().clamp(0, duration);
    _scrubbing = false;
    _completionHandled = false;
    if (mounted) setState(() => _positionSeconds = target);
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(Duration(seconds: target));
    }
    await _saveProgress(completed: target >= duration - 3);
  }

  int get _currentIndex =>
      _episodes.indexWhere((item) => item.id == _episode.id);

  Future<void> _goToRelative(
    int offset, {
    bool markCurrentCompleted = false,
  }) async {
    final target = _currentIndex + offset;
    if (target < 0 || target >= _episodes.length) {
      if (markCurrentCompleted) await _saveProgress(completed: true);
      if (mounted && offset > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You reached the latest episode.')),
        );
      }
      return;
    }
    await _goToIndex(target, markCurrentCompleted: markCurrentCompleted);
  }

  Future<void> _goToIndex(
    int index, {
    bool markCurrentCompleted = false,
  }) async {
    if (_transitioning || index == _currentIndex) return;
    setState(() => _transitioning = true);
    _sessionRefreshTimer?.cancel();
    _loadGeneration++;
    await _saveProgress(completed: markCurrentCompleted ? true : null);
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      await controller.dispose();
    }
    if (!mounted) return;
    setState(() {
      _episode = _episodes[index];
      _session = null;
      _selectedSubtitle = null;
      _positionSeconds = 0;
      _lastPersistedSecond = -1;
      _completionHandled = false;
      _demoPlaying = true;
      _loading = true;
      _error = null;
    });
    widget.onEpisodeChanged?.call(_episode);
    await _loadSession();
    if (mounted) setState(() => _transitioning = false);
  }

  void _handleVerticalDrag(DragEndDetails details) {
    if (_loading || _transitioning) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -350) {
      unawaited(_goToRelative(1));
    } else if (velocity > 350) {
      unawaited(_goToRelative(-1));
    }
  }

  void _showEpisodeQueue() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: _episodes.length,
          itemBuilder: (context, index) {
            final episode = _episodes[index];
            final selected = episode.id == _episode.id;
            return ListTile(
              key: ValueKey('episode-option-${episode.id}'),
              selected: selected,
              leading: Icon(
                selected
                    ? Icons.play_circle_fill_rounded
                    : Icons.play_circle_outline_rounded,
              ),
              title: Text(
                'Episode ${episode.episodeNumber} • ${episode.title}',
              ),
              subtitle: episode.seasonNumber == null
                  ? null
                  : Text('Season ${episode.seasonNumber}'),
              trailing: episode.isFree ? const Text('FREE') : null,
              onTap: selected
                  ? () => Navigator.pop(context)
                  : () {
                      Navigator.pop(context);
                      unawaited(_goToIndex(index));
                    },
            );
          },
        ),
      ),
    );
  }

  Future<void> _close() async {
    await _saveProgress();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null) {
      setState(() => _demoPlaying = !_demoPlaying);
    } else if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (!_isPlaying) await _saveProgress();
    if (mounted) setState(() {});
  }

  Future<void> _selectSubtitle(SubtitleTrack? track) async {
    Navigator.of(context).pop();
    final hlsUrl = _session?.hlsUrl;
    if (hlsUrl == null || track == _selectedSubtitle) return;
    setState(() {
      _selectedSubtitle = track;
      _loading = true;
    });
    try {
      await _initializeVideo(hlsUrl, track);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'subtitle_unavailable';
        });
      }
    }
  }

  void _showSubtitles() {
    final tracks = _session?.subtitles ?? const <SubtitleTrack>[];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<SubtitleTrack?>(
          groupValue: _selectedSubtitle,
          onChanged: _selectSubtitle,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const ListTile(
                title: Text(
                  'Subtitles',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              RadioListTile<SubtitleTrack?>(
                value: null,
                title: const Text('Off'),
              ),
              ...tracks.map(
                (track) => RadioListTile<SubtitleTrack?>(
                  value: track,
                  title: Text(track.label),
                  subtitle: Text(track.languageCode.toUpperCase()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final duration =
        controller?.value.duration.inSeconds ?? _episode.durationSeconds;
    final seekValue = _positionSeconds.clamp(0, duration <= 0 ? 1 : duration);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: _handleVerticalDrag,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _VideoSurface(controller: controller),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              _PlaybackError(
                code: _error!,
                onRetry: () => unawaited(_retrySession()),
                coinPrice: _episode.coinPrice,
                unlocking: _unlocking,
                onReward:
                    _error == 'episode_locked' &&
                        widget.monetizationRepository != null &&
                        widget.rewardedAdService.isAvailable
                    ? () => unawaited(_unlockWithRewardedAd())
                    : null,
                onUnlock:
                    _error == 'episode_locked' &&
                        widget.monetizationRepository != null
                    ? () => unawaited(_unlockWithCoins())
                    : null,
              ),
            if (!_loading && _error == null)
              Center(
                child: IconButton.filledTonal(
                  onPressed: _togglePlayback,
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
                          onPressed: _close,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          tooltip: 'Close player',
                        ),
                        const Spacer(),
                        _EpisodeChip(
                          number: _episode.episodeNumber,
                          total: _episodes.length >= _episode.episodeNumber
                              ? _episodes.length
                              : null,
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: _showSubtitles,
                          icon: const Icon(Icons.closed_caption_rounded),
                          tooltip: 'Subtitles',
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _episode.seriesTitle ?? 'ComboReel Original',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Episode ${_episode.episodeNumber} • ${_episode.title}',
                                style: const TextStyle(
                                  color: Color(0xFFD0D0D6),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _episode.synopsis.isEmpty
                                    ? 'Keep watching to discover what happens next.'
                                    : _episode.synopsis,
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
                              label: _isLiked ? 'Saved' : 'Save',
                              color: _isLiked ? AppColors.coral : Colors.white,
                              onTap: _toggleFavourite,
                            ),
                            _PlayerAction(
                              icon: Icons.ios_share_rounded,
                              label: 'Share',
                              onTap: _share,
                            ),
                            _PlayerAction(
                              icon: Icons.list_rounded,
                              label: 'Episodes',
                              onTap: _showEpisodeQueue,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.coral,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppColors.coral,
                        overlayColor: AppColors.coral.withValues(alpha: 0.18),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        key: const ValueKey('playback-seek'),
                        value: seekValue.toDouble(),
                        min: 0,
                        max: duration <= 0 ? 1 : duration.toDouble(),
                        semanticFormatterCallback: (seconds) =>
                            '${_formatDuration(seconds.round())} of ${_formatDuration(duration)}',
                        onChangeStart: duration <= 0
                            ? null
                            : (_) => _scrubbing = true,
                        onChanged: duration <= 0
                            ? null
                            : (seconds) => setState(
                                () => _positionSeconds = seconds.round(),
                              ),
                        onChangeEnd: duration <= 0
                            ? null
                            : (seconds) => unawaited(_seekTo(seconds)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_episodes.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _currentIndex < _episodes.length - 1
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          Text(
                            _currentIndex < _episodes.length - 1
                                ? 'Swipe up for next episode'
                                : 'Swipe down for previous episode',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    if (_episodes.length > 1) const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label:
                            'Playback position ${_formatDuration(_positionSeconds)}',
                        child: Text(
                          '${_formatDuration(_positionSeconds)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    if (controller?.value.caption.text case final caption?
                        when caption.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        color: Colors.black87,
                        child: Text(caption, textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller});
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A1933), Color(0xFF160D15), Colors.black],
          ),
        ),
      );
    }
    final size = controller!.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller!),
      ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({
    required this.code,
    required this.onRetry,
    required this.coinPrice,
    required this.unlocking,
    this.onReward,
    this.onUnlock,
  });
  final String code;
  final VoidCallback onRetry;
  final int coinPrice;
  final bool unlocking;
  final VoidCallback? onReward;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.coral,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(switch (code) {
            'episode_locked' => 'This episode is locked',
            'playback_interrupted' => 'Connection interrupted',
            _ => 'Video could not load',
          }, style: Theme.of(context).textTheme.titleLarge),
          if (code == 'playback_interrupted') ...[
            const SizedBox(height: 8),
            const Text(
              'Your position is saved. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          if (onReward != null) ...[
            FilledButton.icon(
              onPressed: unlocking ? null : onReward,
              icon: const Icon(Icons.smart_display_rounded),
              label: Text(unlocking ? 'Completing unlock…' : 'Watch an ad'),
            ),
            const SizedBox(height: 8),
          ],
          if (onUnlock != null) ...[
            FilledButton.icon(
              onPressed: unlocking ? null : onUnlock,
              icon: unlocking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.monetization_on_rounded),
              label: Text(
                unlocking ? 'Unlocking…' : 'Unlock with $coinPrice coins',
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: unlocking ? null : onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({required this.number, this.total});
  final int number;
  final int? total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      total == null ? 'EP $number' : 'EP $number / $total',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
