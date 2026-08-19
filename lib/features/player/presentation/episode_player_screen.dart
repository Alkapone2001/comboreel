import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalogue/domain/catalogue_episode.dart';
import '../../library/data/viewer_library_repository.dart';
import '../data/playback_repository.dart';
import '../domain/playback_session.dart';

class EpisodePlayerScreen extends StatefulWidget {
  const EpisodePlayerScreen({
    super.key,
    required this.episode,
    required this.viewerLibraryRepository,
    required this.playbackRepository,
    required this.viewerId,
    this.initialPositionSeconds = 0,
  });

  final CatalogueEpisode episode;
  final ViewerLibraryRepository viewerLibraryRepository;
  final PlaybackRepository playbackRepository;
  final String? viewerId;
  final int initialPositionSeconds;

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen> {
  VideoPlayerController? _videoController;
  PlaybackSession? _session;
  SubtitleTrack? _selectedSubtitle;
  bool _demoPlaying = true;
  bool _isLiked = false;
  bool _loading = true;
  String? _error;
  late int _positionSeconds;
  int _lastPersistedSecond = -1;

  bool get _isPlaying => _videoController?.value.isPlaying ?? _demoPlaying;

  @override
  void initState() {
    super.initState();
    _positionSeconds = widget.initialPositionSeconds.clamp(
      0,
      widget.episode.durationSeconds,
    );
    unawaited(_loadSession());
  }

  Future<void> _loadSession() async {
    try {
      final session = await widget.playbackRepository.createSession(
        widget.episode.id,
      );
      _session = session;
      _selectedSubtitle = session.subtitles
          .where((track) => track.isDefault)
          .firstOrNull;
      if (session.hlsUrl != null) {
        await _initializeVideo(session.hlsUrl!, _selectedSubtitle);
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } on PlaybackAccessException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.code;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'playback_unavailable';
        });
      }
    }
  }

  Future<void> _initializeVideo(Uri hlsUrl, SubtitleTrack? subtitle) async {
    final previous = _videoController;
    final shouldPlay = previous?.value.isPlaying ?? true;
    final resumeAt =
        previous?.value.position ?? Duration(seconds: _positionSeconds);
    if (previous != null) {
      previous.removeListener(_onVideoChanged);
      await previous.dispose();
    }

    final controller = VideoPlayerController.networkUrl(
      hlsUrl,
      formatHint: VideoFormat.hls,
      closedCaptionFile: subtitle == null
          ? null
          : _loadCaptions(subtitle.vttUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _videoController = controller;
    await controller.initialize();
    await controller.setLooping(false);
    if (resumeAt > Duration.zero && resumeAt < controller.value.duration) {
      await controller.seekTo(resumeAt);
    }
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
    final second = controller.value.position.inSeconds;
    if (second != _positionSeconds && mounted) {
      setState(() => _positionSeconds = second);
    }
    if (second > 0 && second % 10 == 0 && second != _lastPersistedSecond) {
      _lastPersistedSecond = second;
      unawaited(_saveProgress());
    }
  }

  @override
  void dispose() {
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(controller.dispose());
    }
    unawaited(_saveProgress());
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final viewerId = widget.viewerId;
    if (viewerId == null) return;
    final duration =
        _videoController?.value.duration.inSeconds ??
        widget.episode.durationSeconds;
    await widget.viewerLibraryRepository.saveProgress(
      userId: viewerId,
      episodeId: widget.episode.id,
      positionSeconds: _positionSeconds,
      completed: duration > 0 && _positionSeconds >= duration - 3,
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
        controller?.value.duration.inSeconds ?? widget.episode.durationSeconds;
    final fraction = duration <= 0
        ? 0.0
        : (_positionSeconds / duration).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _VideoSurface(controller: controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            _PlaybackError(code: _error!, onRetry: _loadSession),
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
                      _EpisodeChip(number: widget.episode.episodeNumber),
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
                            const Text(
                              'Bound by a Secret',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Episode ${widget.episode.episodeNumber} • ${widget.episode.title}',
                              style: const TextStyle(color: Color(0xFFD0D0D6)),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Every clue changes the story. Keep watching to reveal the next secret.',
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
                            label: '12.4K',
                            color: _isLiked ? AppColors.coral : Colors.white,
                            onTap: () => setState(() => _isLiked = !_isLiked),
                          ),
                          _PlayerAction(
                            icon: Icons.bookmark_border_rounded,
                            label: 'Save',
                            onTap: () {},
                          ),
                          _PlayerAction(
                            icon: Icons.ios_share_rounded,
                            label: 'Share',
                            onTap: () {},
                          ),
                          _PlayerAction(
                            icon: Icons.list_rounded,
                            label: 'Episodes',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: fraction,
                    minHeight: 3,
                    color: AppColors.coral,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_positionSeconds),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Next episode'),
                      ),
                    ],
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
  const _PlaybackError({required this.code, required this.onRetry});
  final String code;
  final VoidCallback onRetry;

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
          Text(
            code == 'episode_locked'
                ? 'This episode is locked'
                : 'Video could not load',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'EP $number / 42',
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
