import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/account_security_repository.dart';
import '../../features/auth/data/account_profile_repository.dart';
import '../../features/auth/data/offline_auth_repository.dart';
import '../../features/auth/data/supabase_account_security_repository.dart';
import '../../features/auth/data/supabase_account_profile_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/admin/data/supabase_admin_repository.dart';
import '../../features/analytics/data/analytics_repository.dart';
import '../../features/analytics/data/supabase_analytics_repository.dart';
import '../../features/catalogue/data/catalogue_repository.dart';
import '../../features/catalogue/data/offline_catalogue_repository.dart';
import '../../features/catalogue/data/supabase_catalogue_repository.dart';
import '../../features/library/data/offline_viewer_library_repository.dart';
import '../../features/library/data/supabase_viewer_library_repository.dart';
import '../../features/library/data/viewer_library_repository.dart';
import '../../features/monetization/data/monetization_repository.dart';
import '../../features/monetization/data/admob_rewarded_ad_service.dart';
import '../../features/monetization/data/demo_store_purchase_service.dart';
import '../../features/monetization/data/native_store_purchase_service.dart';
import '../../features/monetization/data/offline_monetization_repository.dart';
import '../../features/monetization/data/rewarded_ad_service.dart';
import '../../features/monetization/data/supabase_monetization_repository.dart';
import '../../features/monetization/data/store_purchase_service.dart';
import '../../features/notifications/data/firebase_push_notification_service.dart';
import '../../features/notifications/data/push_notification_service.dart';
import '../../features/notifications/data/push_campaign_repository.dart';
import '../../features/notifications/data/supabase_push_campaign_repository.dart';
import '../../features/monetization/data/stripe_checkout_purchase_service.dart';
import '../../features/player/data/offline_playback_repository.dart';
import '../../features/player/data/playback_repository.dart';
import '../../features/player/data/supabase_playback_repository.dart';
import '../../features/preferences/data/supabase_viewer_preferences_repository.dart';
import '../../features/preferences/data/viewer_preferences_repository.dart';
import '../../features/privacy/data/privacy_repository.dart';
import '../../features/privacy/data/supabase_privacy_repository.dart';
import '../../features/privacy/data/subscription_management_service.dart';
import '../config/app_config.dart';
import 'content_share_service.dart';
import 'deep_link_service.dart';

class AppServices {
  const AppServices({
    required this.config,
    required this.authRepository,
    required this.catalogueRepository,
    required this.viewerLibraryRepository,
    required this.monetizationRepository,
    this.adminRepository = const UnavailableAdminRepository(),
    this.analyticsRepository = const NoopAnalyticsRepository(),
    this.pushNotificationService = const UnavailablePushNotificationService(),
    this.pushCampaignRepository = const UnavailablePushCampaignRepository(),
    this.rewardedAdService = const UnavailableRewardedAdService(),
    this.storePurchaseService = const UnavailableStorePurchaseService(),
    this.playbackRepository = const OfflinePlaybackRepository(),
    this.privacyRepository = const UnavailablePrivacyRepository(),
    this.subscriptionManagementService =
        const UnavailableSubscriptionManagementService(),
    this.deepLinkService = const NoopDeepLinkService(),
    this.contentShareService = const NoopContentShareService(),
    this.viewerPreferencesRepository =
        const UnavailableViewerPreferencesRepository(),
    this.accountSecurityRepository =
        const UnavailableAccountSecurityRepository(),
    this.accountProfileRepository = const UnavailableAccountProfileRepository(),
  });

  factory AppServices.offline() => AppServices(
    config: const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
    authRepository: const OfflineAuthRepository(),
    catalogueRepository: const OfflineCatalogueRepository(),
    viewerLibraryRepository: OfflineViewerLibraryRepository(),
    monetizationRepository: OfflineMonetizationRepository(),
    adminRepository: const UnavailableAdminRepository(),
    analyticsRepository: const NoopAnalyticsRepository(),
    pushNotificationService: const UnavailablePushNotificationService(),
    pushCampaignRepository: const UnavailablePushCampaignRepository(),
    rewardedAdService: const DemoRewardedAdService(),
    storePurchaseService: DemoStorePurchaseService(),
    viewerPreferencesRepository: OfflineViewerPreferencesRepository(),
  );

  final AppConfig config;
  final AuthRepository authRepository;
  final CatalogueRepository catalogueRepository;
  final ViewerLibraryRepository viewerLibraryRepository;
  final MonetizationRepository monetizationRepository;
  final AdminRepository adminRepository;
  final AnalyticsRepository analyticsRepository;
  final PushNotificationService pushNotificationService;
  final PushCampaignRepository pushCampaignRepository;
  final RewardedAdService rewardedAdService;
  final StorePurchaseService storePurchaseService;
  final PlaybackRepository playbackRepository;
  final PrivacyRepository privacyRepository;
  final SubscriptionManagementService subscriptionManagementService;
  final DeepLinkService deepLinkService;
  final ContentShareService contentShareService;
  final ViewerPreferencesRepository viewerPreferencesRepository;
  final AccountSecurityRepository accountSecurityRepository;
  final AccountProfileRepository accountProfileRepository;

  bool get backendConfigured => config.hasSupabase;

  static Future<AppServices> bootstrap() async {
    final config = AppConfig.fromEnvironment();
    final deepLinks = AppLinksDeepLinkService();
    if (!config.hasSupabase) {
      return AppServices(
        config: config,
        authRepository: const OfflineAuthRepository(),
        catalogueRepository: const OfflineCatalogueRepository(),
        viewerLibraryRepository: OfflineViewerLibraryRepository(),
        monetizationRepository: OfflineMonetizationRepository(),
        adminRepository: const UnavailableAdminRepository(),
        analyticsRepository: const NoopAnalyticsRepository(),
        pushNotificationService: const UnavailablePushNotificationService(),
        pushCampaignRepository: const UnavailablePushCampaignRepository(),
        rewardedAdService: const DemoRewardedAdService(),
        storePurchaseService: DemoStorePurchaseService(),
        deepLinkService: deepLinks,
        contentShareService: SystemContentShareService(config.publicAppUrl),
        viewerPreferencesRepository: OfflineViewerPreferencesRepository(),
      );
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    PushNotificationService pushNotifications =
        const UnavailablePushNotificationService();
    if (config.hasFirebase) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config.firebaseApiKey,
          appId: config.firebaseAppId,
          messagingSenderId: config.firebaseMessagingSenderId,
          projectId: config.firebaseProjectId,
        ),
      );
      final firebasePush = FirebasePushNotificationService(
        Supabase.instance.client,
        config.firebaseWebVapidKey,
      );
      await firebasePush.initialize();
      pushNotifications = firebasePush;
    }
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
      adminRepository: SupabaseAdminRepository(Supabase.instance.client),
      analyticsRepository: SupabaseAnalyticsRepository(
        Supabase.instance.client,
      ),
      pushNotificationService: pushNotifications,
      pushCampaignRepository: SupabasePushCampaignRepository(
        Supabase.instance.client,
      ),
      rewardedAdService: AdMobRewardedAdService(
        androidAdUnitId: config.admobAndroidRewardedAdUnitId,
        iosAdUnitId: config.admobIosRewardedAdUnitId,
      ),
      storePurchaseService: kIsWeb
          ? StripeCheckoutPurchaseService(Supabase.instance.client)
          : (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
          ? NativeStorePurchaseService()
          : const UnavailableStorePurchaseService(),
      playbackRepository: SupabasePlaybackRepository(Supabase.instance.client),
      privacyRepository: SupabasePrivacyRepository(Supabase.instance.client),
      subscriptionManagementService: SupabaseSubscriptionManagementService(
        Supabase.instance.client,
        appleUrl: config.appleSubscriptionManagementUrl,
        googlePlayUrl: config.googlePlaySubscriptionManagementUrl,
      ),
      deepLinkService: deepLinks,
      contentShareService: SystemContentShareService(config.publicAppUrl),
      viewerPreferencesRepository: SupabaseViewerPreferencesRepository(
        Supabase.instance.client,
      ),
      accountSecurityRepository: SupabaseAccountSecurityRepository(
        Supabase.instance.client,
      ),
      accountProfileRepository: SupabaseAccountProfileRepository(
        Supabase.instance.client,
      ),
    );
  }
}
