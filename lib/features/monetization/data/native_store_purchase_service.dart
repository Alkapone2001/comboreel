import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import '../domain/store_purchase.dart';
import 'store_purchase_service.dart';

class NativeStorePurchaseService implements StorePurchaseService {
  NativeStorePurchaseService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance {
    _subscription = _store.purchaseStream.listen(_handlePurchases);
  }

  static const productIds = <String>{
    'comboreel.coins.50',
    'comboreel.coins.120',
    'comboreel.coins.300',
    'comboreel.premium.monthly',
    'comboreel.premium.annual',
  };

  final InAppPurchase _store;
  final _controller = StreamController<StorePurchaseUpdate>.broadcast();
  final Map<String, PurchaseDetails> _pendingDetails = {};
  final Map<String, StoreProductKind> _productKinds = {};
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<StorePurchaseUpdate> get updates => _controller.stream;

  @override
  Future<List<StoreProduct>> loadProducts() async {
    if (!isSupported || !await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(productIds);
    if (response.error != null) throw StateError(response.error!.message);
    final products = response.productDetails.map((details) {
      final kind = details.id.contains('.premium.')
          ? StoreProductKind.premiumSubscription
          : StoreProductKind.coinPack;
      _productKinds[details.id] = kind;
      return StoreProduct(
        id: details.id,
        title: details.title,
        description: details.description,
        price: details.price,
        kind: kind,
        coinAmount: kind == StoreProductKind.coinPack
            ? int.tryParse(details.id.split('.').last)
            : null,
      );
    }).toList();
    products.sort(
      (a, b) => productIds
          .toList()
          .indexOf(a.id)
          .compareTo(productIds.toList().indexOf(b.id)),
    );
    return products;
  }

  @override
  Future<void> purchase(StoreProduct product, {required String userId}) async {
    final response = await _store.queryProductDetails({product.id});
    if (response.productDetails.isEmpty) {
      throw StateError('Product unavailable');
    }
    final param = PurchaseParam(
      productDetails: response.productDetails.single,
      applicationUserName: userId,
    );
    final started = product.kind == StoreProductKind.coinPack
        ? await _store.buyConsumable(purchaseParam: param, autoConsume: false)
        : await _store.buyNonConsumable(purchaseParam: param);
    if (!started) throw StateError('The store could not start this purchase.');
  }

  @override
  Future<void> restore({required String userId}) =>
      _store.restorePurchases(applicationUserName: userId);

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final details in purchases) {
      final id =
          '${details.verificationData.source}:'
          '${details.purchaseID ?? details.productID}:${details.transactionDate ?? ''}';
      _pendingDetails[id] = details;
      _controller.add(
        StorePurchaseUpdate(
          id: id,
          productId: details.productID,
          status: switch (details.status) {
            PurchaseStatus.pending => StorePurchaseStatus.pending,
            PurchaseStatus.purchased => StorePurchaseStatus.purchased,
            PurchaseStatus.restored => StorePurchaseStatus.restored,
            PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
            PurchaseStatus.error => StorePurchaseStatus.failed,
          },
          source: details.verificationData.source,
          verificationData: details.verificationData.serverVerificationData,
          purchaseId: details.purchaseID,
          error: details.error?.message,
        ),
      );
    }
  }

  @override
  Future<void> complete(StorePurchaseUpdate purchase) async {
    final details = _pendingDetails.remove(purchase.id);
    if (details == null) return;
    final isCoinPack =
        _productKinds[purchase.productId] == StoreProductKind.coinPack ||
        purchase.productId.contains('.coins.');
    if (defaultTargetPlatform == TargetPlatform.android && isCoinPack) {
      final addition = _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final result = await addition.consumePurchase(details);
      if (result.responseCode != BillingResponse.ok) {
        _pendingDetails[purchase.id] = details;
        throw StateError('Google Play could not consume the purchase.');
      }
      return;
    }
    if (details.pendingCompletePurchase) {
      await _store.completePurchase(details);
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
