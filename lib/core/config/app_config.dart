class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.admobAndroidRewardedAdUnitId = '',
    this.admobIosRewardedAdUnitId = '',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseMessagingSenderId = '',
    this.firebaseProjectId = '',
    this.firebaseWebVapidKey = '',
    this.publicAppUrl = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    admobAndroidRewardedAdUnitId: String.fromEnvironment(
      'ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
    ),
    admobIosRewardedAdUnitId: String.fromEnvironment(
      'ADMOB_IOS_REWARDED_AD_UNIT_ID',
    ),
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
    firebaseMessagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    firebaseWebVapidKey: String.fromEnvironment('FIREBASE_WEB_VAPID_KEY'),
    publicAppUrl: String.fromEnvironment('PUBLIC_APP_URL'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String admobAndroidRewardedAdUnitId;
  final String admobIosRewardedAdUnitId;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseProjectId;
  final String firebaseWebVapidKey;
  final String publicAppUrl;

  bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
