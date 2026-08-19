import 'dart:async';

import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/core/config/app_config.dart';
import 'package:comboreel/core/services/app_services.dart';
import 'package:comboreel/core/services/content_share_service.dart';
import 'package:comboreel/core/services/deep_link_service.dart';
import 'package:comboreel/features/auth/data/offline_auth_repository.dart';
import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/library/data/offline_viewer_library_repository.dart';
import 'package:comboreel/features/monetization/data/offline_monetization_repository.dart';
import 'package:comboreel/features/series/presentation/series_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public share link wraps a validated app destination', () {
    const service = SystemContentShareService(
      'https://staging.comboreel.example',
    );
    final link = service.publicLink(Uri.parse('comboreel://series/story-1'));
    expect(link.scheme, 'https');
    expect(link.host, 'staging.comboreel.example');
    expect(link.queryParameters['deep_link'], 'comboreel://series/story-1');
    expect(
      const SystemContentShareService('http://insecure.example')
          .publicLink(Uri.parse('comboreel://home')),
      Uri.parse('comboreel://home'),
    );
  });

  testWidgets(
    'series deep link opens details and Share uses the same destination',
    (tester) async {
      final links = _FakeDeepLinks();
      final share = _FakeShare();
      addTearDown(links.close);
      final services = AppServices(
        config: const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
        authRepository: const OfflineAuthRepository(),
        catalogueRepository: const OfflineCatalogueRepository(),
        viewerLibraryRepository: OfflineViewerLibraryRepository(),
        monetizationRepository: OfflineMonetizationRepository(),
        deepLinkService: links,
        contentShareService: share,
      );
      await tester.pumpWidget(ComboReelApp(services: services));
      await tester.pumpAndSettle();

      links.add(Uri.parse('comboreel://series/demo-bound-by-a-secret'));
      await tester.pumpAndSettle();
      expect(find.byType(SeriesDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Share'));
      await tester.pump();
      expect(
        share.lastDeepLink?.toString(),
        'comboreel://series/demo-bound-by-a-secret',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      links.add(
        Uri.parse(
          'comboreel://series/demo-bound-by-a-secret/episode/demo-bound-by-a-secret-episode-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('EP 1 / 42'), findsOneWidget);
    },
  );
}

class _FakeDeepLinks implements DeepLinkService {
  final _controller = StreamController<Uri>.broadcast();
  @override
  Stream<Uri> get links => _controller.stream;
  void add(Uri uri) => _controller.add(uri);
  Future<void> close() => _controller.close();
}

class _FakeShare implements ContentShareService {
  Uri? lastDeepLink;
  @override
  Uri publicLink(Uri deepLink) => deepLink;
  @override
  Future<void> share({
    required String title,
    required Uri deepLink,
    Rect? origin,
  }) async {
    lastDeepLink = deepLink;
  }
}
