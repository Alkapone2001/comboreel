import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/offline_auth_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/catalogue/data/catalogue_repository.dart';
import '../../features/catalogue/data/offline_catalogue_repository.dart';
import '../../features/catalogue/data/supabase_catalogue_repository.dart';
import '../../features/library/data/offline_viewer_library_repository.dart';
import '../../features/library/data/supabase_viewer_library_repository.dart';
import '../../features/library/data/viewer_library_repository.dart';
import '../../features/monetization/data/monetization_repository.dart';
import '../../features/monetization/data/offline_monetization_repository.dart';
import '../../features/monetization/data/supabase_monetization_repository.dart';
import '../../features/player/data/offline_playback_repository.dart';
import '../../features/player/data/playback_repository.dart';
import '../../features/player/data/supabase_playback_repository.dart';
import '../config/app_config.dart';

class AppServices {
  const AppServices({
    required this.config,
    required this.authRepository,
    required this.catalogueRepository,
    required this.viewerLibraryRepository,
    required this.monetizationRepository,
    this.playbackRepository = const OfflinePlaybackRepository(),
  });

  factory AppServices.offline() => AppServices(
    config: const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
    authRepository: const OfflineAuthRepository(),
    catalogueRepository: const OfflineCatalogueRepository(),
    viewerLibraryRepository: OfflineViewerLibraryRepository(),
    monetizationRepository: OfflineMonetizationRepository(),
  );

  final AppConfig config;
  final AuthRepository authRepository;
  final CatalogueRepository catalogueRepository;
  final ViewerLibraryRepository viewerLibraryRepository;
  final MonetizationRepository monetizationRepository;
  final PlaybackRepository playbackRepository;

  bool get backendConfigured => config.hasSupabase;

  static Future<AppServices> bootstrap() async {
    final config = AppConfig.fromEnvironment();
    if (!config.hasSupabase) {
      return AppServices(
        config: config,
        authRepository: const OfflineAuthRepository(),
        catalogueRepository: const OfflineCatalogueRepository(),
        viewerLibraryRepository: OfflineViewerLibraryRepository(),
        monetizationRepository: OfflineMonetizationRepository(),
      );
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    return AppServices(
      config: config,
      authRepository: SupabaseAuthRepository(Supabase.instance.client),
      catalogueRepository: SupabaseCatalogueRepository(
        Supabase.instance.client,
      ),
      viewerLibraryRepository: SupabaseViewerLibraryRepository(
        Supabase.instance.client,
      ),
      monetizationRepository: SupabaseMonetizationRepository(
        Supabase.instance.client,
      ),
      playbackRepository: SupabasePlaybackRepository(Supabase.instance.client),
    );
  }
}
