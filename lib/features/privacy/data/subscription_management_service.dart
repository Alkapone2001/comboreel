import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class SubscriptionManagementService {
  const SubscriptionManagementService();

  bool supports(String platform);

  String labelFor(String platform);

  Future<void> manage(String platform);
}

class UnavailableSubscriptionManagementService
    implements SubscriptionManagementService {
  const UnavailableSubscriptionManagementService();

  @override
  bool supports(String platform) => false;

  @override
  String labelFor(String platform) => 'Manage subscription';

  @override
  Future<void> manage(String platform) => Future.error(
    StateError('Subscription management is unavailable in this deployment.'),
  );
}

class SupabaseSubscriptionManagementService
    implements SubscriptionManagementService {
  const SupabaseSubscriptionManagementService(
    this._client, {
    required this.appleUrl,
    required this.googlePlayUrl,
  });

  final SupabaseClient _client;
  final String appleUrl;
  final String googlePlayUrl;

  static String normalize(String platform) =>
      switch (platform.trim().toLowerCase()) {
        'apple' || 'ios' || 'app_store' => 'apple',
        'google' || 'android' || 'google_play' => 'google',
        'stripe' || 'web' => 'stripe',
        _ => '',
      };

  Uri? _configuredUri(String platform) {
    final raw = switch (normalize(platform)) {
      'apple' => appleUrl,
      'google' => googlePlayUrl,
      _ => '',
    };
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  @override
  bool supports(String platform) =>
      normalize(platform) == 'stripe' || _configuredUri(platform) != null;

  @override
  String labelFor(String platform) => switch (normalize(platform)) {
    'apple' => 'Manage in App Store',
    'google' => 'Manage in Google Play',
    'stripe' => 'Manage web billing',
    _ => 'Manage subscription',
  };

  @override
  Future<void> manage(String platform) async {
    final normalized = normalize(platform);
    Uri? url = _configuredUri(normalized);
    if (normalized == 'stripe') {
      final response = await _client.functions.invoke(
        'stripe-checkout',
        body: const {'action': 'portal'},
      );
      final data = response.data as Map<String, dynamic>? ?? const {};
      url = Uri.tryParse(data['url'] as String? ?? '');
      if (response.status != 200) {
        throw StateError(
          data['error'] as String? ?? 'Billing portal unavailable.',
        );
      }
    }
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw StateError('No secure management link is configured.');
    }
    if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
      throw StateError('The subscription manager could not be opened.');
    }
  }
}
