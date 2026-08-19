import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/analytics_dashboard.dart';
import 'analytics_repository.dart';

class SupabaseAnalyticsRepository implements AnalyticsRepository {
  SupabaseAnalyticsRepository(this._client) : _sessionId = _newUuid();

  final SupabaseClient _client;
  final String _sessionId;

  @override
  Future<bool> consentEnabled() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final data = await _client
        .from('profiles')
        .select('analytics_opt_in')
        .eq('id', user.id)
        .maybeSingle();
    return data?['analytics_opt_in'] as bool? ?? false;
  }

  @override
  Future<void> setConsent(bool enabled) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to change analytics consent.');
    await _client
        .from('profiles')
        .update({'analytics_opt_in': enabled})
        .eq('id', user.id);
  }

  @override
  Future<void> track(
    String event, {
    String? seriesId,
    String? episodeId,
    Map<String, Object?> properties = const {},
  }) async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'record_analytics_event',
        params: {
          'p_session_id': _sessionId,
          'p_event_name': event,
          'p_platform': _platform,
          'p_series_id': seriesId,
          'p_episode_id': episodeId,
          'p_properties': properties,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics event was not recorded: $error\n$stackTrace');
    }
  }

  @override
  Future<AnalyticsDashboard> dashboard({int days = 30}) async {
    final data = await _client.rpc(
      'analytics_dashboard',
      params: {'p_days': days},
    );
    return AnalyticsDashboard.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'desktop',
    };
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
