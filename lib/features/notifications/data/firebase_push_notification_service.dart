import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notification_service.dart';

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService(this._client, this._webVapidKey);

  final SupabaseClient _client;
  final String _webVapidKey;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _openSubscription;
  final _deepLinks = StreamController<Uri>.broadcast();

  @override
  bool get available => true;

  @override
  Stream<Uri> get deepLinks => _deepLinks.stream;

  Future<void> initialize() async {
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => _register(token),
      onError: (Object error) =>
          debugPrint('Push token refresh failed: $error'),
    );
    _openSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _open(initialMessage);
    if (await enabled()) {
      final token = await _token();
      if (token != null) await _register(token);
    }
  }

  @override
  Future<bool> enabled() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final data = await _client
        .from('profiles')
        .select('push_opt_in')
        .eq('id', user.id)
        .maybeSingle();
    return data?['push_opt_in'] as bool? ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in to configure notifications.');
    }
    if (!enabled) {
      await _client.functions.invoke(
        'push-device',
        body: {'action': 'disable_all'},
      );
      return;
    }
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Notification permission was not granted.');
    }
    final token = await _token();
    if (token == null || token.isEmpty) {
      throw StateError('This device could not register for notifications.');
    }
    await _register(token);
  }

  Future<String?> _token() => FirebaseMessaging.instance.getToken(
    vapidKey: kIsWeb && _webVapidKey.isNotEmpty ? _webVapidKey : null,
  );

  Future<void> _register(String token) => _client.functions.invoke(
    'push-device',
    body: {
      'action': 'register',
      'token': token,
      'platform': kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
      'locale': PlatformDispatcher.instance.locale.languageCode,
    },
  );

  void _open(RemoteMessage message) {
    final value = message.data['deep_link'];
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri != null && uri.scheme == 'comboreel') _deepLinks.add(uri);
  }

  void dispose() {
    unawaited(_refreshSubscription?.cancel());
    unawaited(_openSubscription?.cancel());
    unawaited(_deepLinks.close());
  }
}
