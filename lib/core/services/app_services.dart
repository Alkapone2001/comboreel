import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/offline_auth_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/catalogue/data/catalogue_repository.dart';
import '../../features/catalogue/data/offline_catalogue_repository.dart';
import '../../features/catalogue/data/supabase_catalogue_repository.dart';
import '../config/app_config.dart';

class AppServices {
  const AppServices({
    required this.config,
    required this.authRepository,
    required this.catalogueRepository,
  });

  const AppServices.offline()
    : config = const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
      authRepository = const OfflineAuthRepository(),
      catalogueRepository = const OfflineCatalogueRepository();

  final AppConfig config;
  final AuthRepository authRepository;
  final CatalogueRepository catalogueRepository;

  bool get backendConfigured => config.hasSupabase;

  static Future<AppServices> bootstrap() async {
    final config = AppConfig.fromEnvironment();
    if (!config.hasSupabase) {
      return AppServices(
        config: config,
        authRepository: const OfflineAuthRepository(),
        catalogueRepository: const OfflineCatalogueRepository(),
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
    );
  }
}
