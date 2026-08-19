import 'package:comboreel/features/admin/data/admin_repository.dart';
import 'package:comboreel/features/admin/domain/admin_models.dart';
import 'package:comboreel/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:comboreel/features/analytics/data/analytics_repository.dart';
import 'package:comboreel/features/analytics/domain/analytics_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('viewer cannot enter Creator Studio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(repository: _FakeAdminRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Creator Studio access required'), findsOneWidget);
    expect(find.text('Create series'), findsNothing);
  });

  testWidgets('editor sees drafts and episode operations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          repository: _FakeAdminRepository(role: AdminRole.editor),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Midnight Contract'), findsWidgets);
    expect(find.text('DRAFT'), findsWidgets);
    expect(find.text('Add episode'), findsOneWidget);
    expect(find.byTooltip('Upload video'), findsOneWidget);
    expect(find.byTooltip('Publish'), findsOneWidget);
  });

  testWidgets('editor opens consented operations analytics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          repository: _FakeAdminRepository(role: AdminRole.editor),
          analyticsRepository: _FakeAnalyticsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Operations analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Active viewers'), findsOneWidget);
    expect(find.text('Midnight Contract'), findsWidgets);
  });
}

class _FakeAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<bool> consentEnabled() async => true;
  @override
  Future<void> setConsent(bool enabled) async {}
  @override
  Future<void> track(
    String event, {
    String? seriesId,
    String? episodeId,
    Map<String, Object?> properties = const {},
  }) async {}
  @override
  Future<AnalyticsDashboard> dashboard({int days = 30}) async =>
      const AnalyticsDashboard(
        days: 30,
        activeViewers: 42,
        sessions: 64,
        seriesOpens: 120,
        playbackStarts: 90,
        completions: 70,
        unlocks: 18,
        purchases: 6,
        completionRate: 77.8,
        topSeries: [
          TopSeriesMetric(
            seriesId: 'series-1',
            title: 'Midnight Contract',
            opens: 80,
          ),
        ],
      );
}

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.role = AdminRole.viewer});
  final AdminRole role;

  @override
  Future<AdminRole> currentRole() async => role;

  @override
  Future<List<AdminSeries>> series() async => const [
    AdminSeries(
      id: 'series-1',
      slug: 'midnight-contract',
      title: 'Midnight Contract',
      synopsis: 'A dangerous bargain changes everything.',
      status: 'draft',
    ),
  ];

  @override
  Future<List<AdminEpisode>> episodes(String seriesId) async => const [
    AdminEpisode(
      id: 'episode-1',
      seriesId: 'series-1',
      number: 1,
      title: 'The Offer',
      status: 'draft',
      durationSeconds: 75,
      isFree: true,
      coinPrice: 0,
      streamUid: 'stream-1',
    ),
  ];

  Never _unused() => throw UnimplementedError();

  @override
  Future<StreamUploadTicket> createUpload(
    String episodeId,
    String fileName,
  ) async => _unused();
  @override
  Future<StreamProcessingStatus> processingStatus(String episodeId) async =>
      _unused();
  @override
  Future<AdminEpisode> saveEpisode(
    Map<String, dynamic> values, {
    String? id,
  }) async => _unused();
  @override
  Future<AdminSeries> saveSeries(
    Map<String, dynamic> values, {
    String? id,
  }) async => _unused();
  @override
  Future<void> setEpisodePublished(String id, bool published) async =>
      _unused();
  @override
  Future<void> setSeriesPublished(String id, bool published) async => _unused();
}
