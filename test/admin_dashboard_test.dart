import 'package:comboreel/features/admin/data/admin_repository.dart';
import 'package:comboreel/features/admin/domain/admin_models.dart';
import 'package:comboreel/features/admin/presentation/admin_dashboard_screen.dart';
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
