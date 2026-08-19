import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/analytics_dashboard.dart';
import '../../notifications/data/push_campaign_repository.dart';
import '../../notifications/domain/push_campaign.dart';
import '../data/admin_repository.dart';
import '../data/resumable_upload_service.dart';
import '../domain/admin_models.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.repository,
    this.uploadService = const ResumableUploadService(),
    this.analyticsRepository = const NoopAnalyticsRepository(),
    this.pushCampaignRepository = const UnavailablePushCampaignRepository(),
  });

  final AdminRepository repository;
  final ResumableUploadService uploadService;
  final AnalyticsRepository analyticsRepository;
  final PushCampaignRepository pushCampaignRepository;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  AdminRole _role = AdminRole.viewer;
  List<AdminSeries> _series = const [];
  AdminSeries? _selected;
  List<AdminEpisode> _episodes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final role = await widget.repository.currentRole();
      final series = role == AdminRole.viewer
          ? <AdminSeries>[]
          : await widget.repository.series();
      if (!mounted) return;
      setState(() {
        _role = role;
        _series = series;
        _selected = series.firstOrNull;
        _loading = false;
      });
      if (_selected != null) {
        await _loadEpisodes(_selected!.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadEpisodes(String seriesId) async {
    final episodes = await widget.repository.episodes(seriesId);
    if (mounted) setState(() => _episodes = episodes);
  }

  Future<void> _select(AdminSeries item) async {
    setState(() {
      _selected = item;
      _episodes = const [];
    });
    await _loadEpisodes(item.id);
  }

  Future<void> _editSeries([AdminSeries? item]) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SeriesEditor(item: item),
    );
    if (values == null) return;
    await _work(() async {
      await widget.repository.saveSeries(values, id: item?.id);
      await _load();
    });
  }

  Future<void> _editEpisode([AdminEpisode? item]) async {
    final selected = _selected;
    if (selected == null) return;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EpisodeEditor(seriesId: selected.id, item: item),
    );
    if (values == null) return;
    await _work(() async {
      await widget.repository.saveEpisode(values, id: item?.id);
      await _loadEpisodes(selected.id);
    });
  }

  Future<void> _toggleSeries(AdminSeries item) => _work(() async {
    await widget.repository.setSeriesPublished(
      item.id,
      item.status != 'published',
    );
    await _load();
  });

  Future<void> _toggleEpisode(AdminEpisode item) => _work(() async {
    await widget.repository.setEpisodePublished(
      item.id,
      item.status != 'published',
    );
    await _loadEpisodes(item.seriesId);
  });

  Future<void> _upload(AdminEpisode episode) async {
    const videoGroup = XTypeGroup(
      label: 'Video',
      extensions: ['mp4', 'mov', 'm4v', 'webm'],
    );
    final file = await openFile(acceptedTypeGroups: const [videoGroup]);
    if (file == null) return;
    final progress = ValueNotifier<double>(0);
    if (!mounted) return;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, _) => AlertDialog(
          title: const Text('Uploading master video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 14),
              Text('${(value * 100).toStringAsFixed(0)}% uploaded'),
              const SizedBox(height: 8),
              const Text(
                'You can safely retry if the connection is interrupted.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final ticket = await widget.repository.createUpload(
        episode.id,
        file.name,
      );
      await widget.uploadService.upload(
        file: file,
        uploadUrl: ticket.uploadUrl,
        onProgress: (value) {
          progress.value = value;
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) Navigator.of(context).pop();
      _showError(error);
      return;
    } finally {
      await dialogFuture;
      progress.dispose();
    }
    await _work(() => _waitForProcessing(episode.id));
  }

  Future<void> _waitForProcessing(String episodeId) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final status = await widget.repository.processingStatus(episodeId);
      if (status.state == 'ready') {
        if (_selected != null) {
          await _loadEpisodes(_selected!.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video processed and ready to publish.'),
            ),
          );
        }
        return;
      }
      if (status.state == 'error') {
        throw StateError(status.errorReason ?? 'Video processing failed.');
      }
      await Future<void>.delayed(const Duration(seconds: 6));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload complete. Processing continues in Cloudflare.'),
        ),
      );
    }
  }

  Future<void> _work(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_message(error)),
        backgroundColor: AppColors.coral,
      ),
    );
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('PostgrestException(message: ', '')
      .split(', code:')
      .first
      .replaceFirst('Bad state: ', '');

  Future<void> _showAnalytics() async {
    try {
      final dashboard = await widget.analyticsRepository.dashboard();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _AnalyticsDialog(dashboard: dashboard),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showCampaigns() => showDialog<void>(
    context: context,
    builder: (_) => _CampaignDialog(repository: widget.pushCampaignRepository),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Creator Studio'),
      actions: [
        IconButton(
          onPressed: _role == AdminRole.viewer ? null : _showAnalytics,
          icon: const Icon(Icons.insights_outlined),
          tooltip: 'Operations analytics',
        ),
        IconButton(
          onPressed: _role == AdminRole.viewer ? null : _showCampaigns,
          icon: const Icon(Icons.campaign_outlined),
          tooltip: 'Push campaigns',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _role == AdminRole.viewer
        ? const _AccessDenied()
        : _error != null
        ? Center(child: Text(_error!))
        : LayoutBuilder(
            builder: (context, constraints) {
              final catalogue = _SeriesPanel(
                series: _series,
                selected: _selected,
                onSelect: _select,
                onCreate: () => _editSeries(),
              );
              final detail = _ContentPanel(
                series: _selected,
                episodes: _episodes,
                onEditSeries: () => _editSeries(_selected),
                onToggleSeries: _selected == null
                    ? null
                    : () => _toggleSeries(_selected!),
                onAddEpisode: () => _editEpisode(),
                onEditEpisode: _editEpisode,
                onToggleEpisode: _toggleEpisode,
                onUpload: _upload,
              );
              return constraints.maxWidth >= 900
                  ? Row(
                      children: [
                        SizedBox(width: 320, child: catalogue),
                        const VerticalDivider(width: 1),
                        Expanded(child: detail),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 230, child: catalogue),
                        const Divider(height: 1),
                        Expanded(child: detail),
                      ],
                    );
            },
          ),
  );
}

class _CampaignDialog extends StatefulWidget {
  const _CampaignDialog({required this.repository});
  final PushCampaignRepository repository;
  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  late Future<List<PushCampaign>> _campaigns;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _campaigns = widget.repository.campaigns();

  Future<void> _compose() async {
    final draft = await showDialog<({String title, String body, String link})>(
      context: context,
      builder: (_) => const _CampaignComposer(),
    );
    if (draft == null) return;
    setState(() => _working = true);
    try {
      await widget.repository.create(
        title: draft.title,
        body: draft.body,
        deepLink: draft.link,
      );
      if (mounted) setState(_reload);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _send(PushCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send this campaign now?'),
        content: Text(
          '“${campaign.title}” will be delivered to every opted-in device. '
          'A sent campaign cannot be recalled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await widget.repository.send(campaign.id);
      if (mounted) setState(_reload);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Push campaigns'),
    content: SizedBox(
      width: 700,
      height: 440,
      child: FutureBuilder<List<PushCampaign>>(
        future: _campaigns,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No campaigns yet. Create a draft to begin.'),
            );
          }
          return ListView.separated(
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, index) {
              final campaign = snapshot.data![index];
              return ListTile(
                title: Text(campaign.title),
                subtitle: Text(
                  '${campaign.status.toUpperCase()} · '
                  '${campaign.successCount}/${campaign.targetCount} delivered',
                ),
                trailing: campaign.status == 'draft'
                    ? FilledButton.tonal(
                        onPressed: _working ? null : () => _send(campaign),
                        child: const Text('Review & send'),
                      )
                    : null,
              );
            },
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: _working ? null : _compose,
        icon: const Icon(Icons.add),
        label: const Text('New draft'),
      ),
    ],
  );
}

class _CampaignComposer extends StatefulWidget {
  const _CampaignComposer();
  @override
  State<_CampaignComposer> createState() => _CampaignComposerState();
}

class _CampaignComposerState extends State<_CampaignComposer> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController(text: 'comboreel://home');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New push campaign'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Notification title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a title.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a message.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Deep link',
                border: OutlineInputBorder(),
              ),
              validator: (value) => !(value ?? '').startsWith('comboreel://')
                  ? 'Use a comboreel:// link.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(context, (
            title: _title.text.trim(),
            body: _body.text.trim(),
            link: _link.text.trim(),
          ));
        },
        child: const Text('Save draft'),
      ),
    ],
  );
}

class _AnalyticsDialog extends StatelessWidget {
  const _AnalyticsDialog({required this.dashboard});
  final AnalyticsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Active viewers', dashboard.activeViewers.toString()),
      ('Sessions', dashboard.sessions.toString()),
      ('Series opens', dashboard.seriesOpens.toString()),
      ('Playback starts', dashboard.playbackStarts.toString()),
      ('Completed', dashboard.completions.toString()),
      ('Completion rate', '${dashboard.completionRate.toStringAsFixed(1)}%'),
      ('Unlocks', dashboard.unlocks.toString()),
      ('Purchases', dashboard.purchases.toString()),
    ];
    return AlertDialog(
      title: Text('Last ${dashboard.days} days'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: 155,
                        child: Card(
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.$2,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  metric.$1,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text('Top series', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (dashboard.topSeries.isEmpty)
                const Text(
                  'No consented series activity yet.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                ...dashboard.topSeries.map(
                  (series) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(series.title),
                    trailing: Text('${series.opens} opens'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 54, color: AppColors.muted),
          SizedBox(height: 16),
          Text(
            'Creator Studio access required',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Ask a platform administrator to grant you the Editor role.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _SeriesPanel extends StatelessWidget {
  const _SeriesPanel({
    required this.series,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });
  final List<AdminSeries> series;
  final AdminSeries? selected;
  final ValueChanged<AdminSeries> onSelect;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text('Series', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            IconButton(
              onPressed: onCreate,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create series',
            ),
          ],
        ),
      ),
      Expanded(
        child: series.isEmpty
            ? const Center(child: Text('Create your first series.'))
            : ListView.builder(
                itemCount: series.length,
                itemBuilder: (_, index) {
                  final item = series[index];
                  return ListTile(
                    selected: selected?.id == item.id,
                    title: Text(item.title),
                    subtitle: Text(item.status.toUpperCase()),
                    trailing: Icon(
                      item.status == 'published'
                          ? Icons.public
                          : Icons.edit_note,
                    ),
                    onTap: () => onSelect(item),
                  );
                },
              ),
      ),
    ],
  );
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({
    required this.series,
    required this.episodes,
    required this.onEditSeries,
    required this.onToggleSeries,
    required this.onAddEpisode,
    required this.onEditEpisode,
    required this.onToggleEpisode,
    required this.onUpload,
  });
  final AdminSeries? series;
  final List<AdminEpisode> episodes;
  final VoidCallback onEditSeries;
  final VoidCallback? onToggleSeries;
  final VoidCallback onAddEpisode;
  final ValueChanged<AdminEpisode> onEditEpisode;
  final ValueChanged<AdminEpisode> onToggleEpisode;
  final ValueChanged<AdminEpisode> onUpload;
  @override
  Widget build(BuildContext context) {
    final item = series;
    if (item == null) {
      return const Center(child: Text('Select or create a series.'));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(item.slug, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditSeries,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit metadata'),
                ),
                FilledButton.icon(
                  onPressed: onToggleSeries,
                  icon: Icon(
                    item.status == 'published'
                        ? Icons.visibility_off
                        : Icons.publish,
                  ),
                  label: Text(
                    item.status == 'published' ? 'Unpublish' : 'Publish',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          item.synopsis,
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Text('Episodes', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: onAddEpisode,
              icon: const Icon(Icons.add),
              label: const Text('Add episode'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...episodes.map(
          (episode) => Card(
            color: AppColors.surface,
            child: ListTile(
              leading: CircleAvatar(child: Text('${episode.number}')),
              title: Text(episode.title),
              subtitle: Text(
                '${episode.status.toUpperCase()} · ${episode.durationSeconds}s · ${episode.isFree ? 'Free' : '${episode.coinPrice} coins'}',
              ),
              onTap: () => onEditEpisode(episode),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => onUpload(episode),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    tooltip: 'Upload video',
                  ),
                  IconButton(
                    onPressed:
                        episode.streamUid == null &&
                            episode.status != 'published'
                        ? null
                        : () => onToggleEpisode(episode),
                    icon: Icon(
                      episode.status == 'published'
                          ? Icons.visibility_off
                          : Icons.publish,
                    ),
                    tooltip: episode.status == 'published'
                        ? 'Unpublish'
                        : 'Publish',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesEditor extends StatefulWidget {
  const _SeriesEditor({this.item});
  final AdminSeries? item;
  @override
  State<_SeriesEditor> createState() => _SeriesEditorState();
}

class _SeriesEditorState extends State<_SeriesEditor> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  bool featured = false;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    featured = item?.isFeatured ?? false;
    fields = {
      'title': TextEditingController(text: item?.title),
      'slug': TextEditingController(text: item?.slug),
      'synopsis': TextEditingController(text: item?.synopsis),
      'poster_url': TextEditingController(text: item?.posterUrl),
      'hero_url': TextEditingController(text: item?.heroUrl),
      'release_year': TextEditingController(
        text: item?.releaseYear?.toString(),
      ),
      'age_rating': TextEditingController(text: item?.ageRating),
    };
  }

  @override
  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Create series' : 'Edit series'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _field('title', 'Title', required: true),
              _field('slug', 'URL slug', required: true),
              _field('synopsis', 'Synopsis', lines: 4),
              _field('poster_url', 'Poster image URL'),
              _field('hero_url', 'Hero image URL'),
              Row(
                children: [
                  Expanded(child: _field('release_year', 'Release year')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('age_rating', 'Age rating')),
                ],
              ),
              SwitchListTile(
                value: featured,
                onChanged: (value) => setState(() => featured = value),
                title: const Text('Feature on home screen'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(context, {
            for (final entry in fields.entries)
              entry.key: entry.key == 'release_year'
                  ? int.tryParse(entry.value.text)
                  : entry.value.text.trim(),
            'original_language': 'en',
            'is_featured': featured,
          });
        },
        child: const Text('Save'),
      ),
    ],
  );
  Widget _field(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: fields[key],
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) =>
                (value?.trim().isEmpty ?? true) ? '$label is required.' : null
          : null,
    ),
  );
}

class _EpisodeEditor extends StatefulWidget {
  const _EpisodeEditor({required this.seriesId, this.item});
  final String seriesId;
  final AdminEpisode? item;
  @override
  State<_EpisodeEditor> createState() => _EpisodeEditorState();
}

class _EpisodeEditorState extends State<_EpisodeEditor> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController number;
  late final TextEditingController coins;
  bool free = false;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    title = TextEditingController(text: item?.title);
    number = TextEditingController(text: item?.number.toString());
    coins = TextEditingController(text: (item?.coinPrice ?? 5).toString());
    free = item?.isFree ?? false;
  }

  @override
  void dispose() {
    title.dispose();
    number.dispose();
    coins.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Add episode' : 'Edit episode'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Episode title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Title is required.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: number,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Episode number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                        ? 'Use 1 or higher.'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: coins,
                    keyboardType: TextInputType.number,
                    enabled: !free,
                    decoration: const InputDecoration(
                      labelText: 'Coin price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              value: free,
              onChanged: (value) => setState(() => free = value),
              title: const Text('Free episode'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(context, {
            'series_id': widget.seriesId,
            'episode_number': int.parse(number.text),
            'title': title.text.trim(),
            'is_free': free,
            'coin_price': free ? 0 : int.tryParse(coins.text) ?? 5,
          });
        },
        child: const Text('Save'),
      ),
    ],
  );
}
