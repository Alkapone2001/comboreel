import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/store_purchase.dart';
import 'store_purchase_service.dart';

class StripeCheckoutPurchaseService implements StorePurchaseService {
  const StripeCheckoutPurchaseService(this._client);

  final SupabaseClient _client;

  @override
  bool get isSupported => kIsWeb;
  @override
  String get recoveryActionLabel => 'Manage billing';
  @override
  Stream<StorePurchaseUpdate> get updates => const Stream.empty();

  @override
  Future<List<StoreProduct>> loadProducts() async {
    final response = await _client.functions.invoke(
      'stripe-checkout',
      body: {'action': 'catalog'},
    );
    final data = response.data as Map<String, dynamic>;
    if (response.status != 200) {
      throw StateError(
        data['error'] as String? ?? 'Stripe catalogue unavailable',
      );
    }
    final rows = data['products'] as List<dynamic>? ?? const [];
    return rows.map((value) {
      final row = value as Map<String, dynamic>;
      final id = row['id'] as String;
      final kind = id.contains('.premium.')
          ? StoreProductKind.premiumSubscription
          : StoreProductKind.coinPack;
      return StoreProduct(
        id: id,
        title: row['title'] as String? ?? id,
        description: row['description'] as String? ?? '',
        price: _formatPrice(
          row['unit_amount'] as int? ?? 0,
          row['currency'] as String? ?? 'usd',
          row['recurring_interval'] as String?,
        ),
        kind: kind,
        coinAmount: kind == StoreProductKind.coinPack
            ? int.tryParse(id.split('.').last)
            : null,
      );
    }).toList();
  }

  String _formatPrice(int amount, String currency, String? interval) {
    const zeroDecimal = {
      'bif',
      'clp',
      'djf',
      'gnf',
      'jpy',
      'kmf',
      'krw',
      'mga',
      'pyg',
      'rwf',
      'ugx',
      'vnd',
      'vuv',
      'xaf',
      'xof',
      'xpf',
    };
    final value = zeroDecimal.contains(currency.toLowerCase())
        ? amount.toString()
        : (amount / 100).toStringAsFixed(2);
    final symbol = switch (currency.toLowerCase()) {
      'usd' => r'$',
      'eur' => '€',
      'gbp' => '£',
      _ => '${currency.toUpperCase()} ',
    };
    return '$symbol$value${interval == null ? '' : '/$interval'}';
  }

  Future<void> _redirect(Map<String, String> body) async {
    final response = await _client.functions.invoke(
      'stripe-checkout',
      body: body,
    );
    final data = response.data as Map<String, dynamic>;
    final url = Uri.tryParse(data['url'] as String? ?? '');
    if (response.status != 200 || url == null || url.scheme != 'https') {
      throw StateError(
        data['error'] as String? ?? 'Stripe redirect unavailable',
      );
    }
    if (!await launchUrl(url, webOnlyWindowName: '_self')) {
      throw StateError('The secure checkout could not be opened.');
    }
  }

  @override
  Future<void> purchase(StoreProduct product, {required String userId}) =>
      _redirect({'action': 'checkout', 'product_id': product.id});

  @override
  Future<void> restore({required String userId}) =>
      _redirect({'action': 'portal'});

  @override
  Future<void> complete(StorePurchaseUpdate purchase) async {}
}
