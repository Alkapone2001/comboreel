import '../domain/analytics_dashboard.dart';

abstract interface class AnalyticsRepository {
  Future<bool> consentEnabled();
  Future<void> setConsent(bool enabled);
  Future<void> track(
    String event, {
    String? seriesId,
    String? episodeId,
    Map<String, Object?> properties = const {},
  });
  Future<AnalyticsDashboard> dashboard({int days = 30});
}

class NoopAnalyticsRepository implements AnalyticsRepository {
  const NoopAnalyticsRepository();
  @override
  Future<bool> consentEnabled() async => false;
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
  Future<AnalyticsDashboard> dashboard({int days = 30}) =>
      throw StateError('Analytics requires Supabase.');
}
