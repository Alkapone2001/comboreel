import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/offline_auth_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../config/app_config.dart';

class AppServices {
  const AppServices({required this.config, required this.authRepository});

  const AppServices.offline()
    : config = const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
      authRepository = const OfflineAuthRepository();

  final AppConfig config;
  final AuthRepository authRepository;

  bool get backendConfigured => config.hasSupabase;

  static Future<AppServices> bootstrap() async {
    final config = AppConfig.fromEnvironment();
    if (!config.hasSupabase) {
      return AppServices(
        config: config,
        authRepository: const OfflineAuthRepository(),
      );
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    return AppServices(
      config: config,
      authRepository: SupabaseAuthRepository(Supabase.instance.client),
    );
  }
}
