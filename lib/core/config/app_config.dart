class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.admobAndroidRewardedAdUnitId = '',
    this.admobIosRewardedAdUnitId = '',
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
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String admobAndroidRewardedAdUnitId;
  final String admobIosRewardedAdUnitId;

  bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
