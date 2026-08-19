import 'dart:async';

import '../domain/store_purchase.dart';
import 'store_purchase_service.dart';

class DemoStorePurchaseService implements StorePurchaseService {
  DemoStorePurchaseService();

  final _updates = StreamController<StorePurchaseUpdate>.broadcast();
  int _sequence = 0;

  static const _products = <StoreProduct>[
    StoreProduct(
      id: 'comboreel.coins.50',
      title: '50 coins',
      description: 'Starter pack',
      price: r'$1.99',
      kind: StoreProductKind.coinPack,
      coinAmount: 50,
    ),
    StoreProduct(
      id: 'comboreel.coins.120',
      title: '120 coins',
      description: 'Most popular',
      price: r'$3.99',
      kind: StoreProductKind.coinPack,
      coinAmount: 120,
    ),
    StoreProduct(
      id: 'comboreel.coins.300',
      title: '300 coins',
      description: 'Best value',
      price: r'$7.99',
      kind: StoreProductKind.coinPack,
      coinAmount: 300,
    ),
    StoreProduct(
      id: 'comboreel.premium.monthly',
      title: 'Premium monthly',
      description: 'Unlimited episodes and no ads',
      price: r'$8.99',
      kind: StoreProductKind.premiumSubscription,
    ),
    StoreProduct(
      id: 'comboreel.premium.annual',
      title: 'Premium annual',
      description: 'Twelve months of unlimited viewing',
      price: r'$69.99',
      kind: StoreProductKind.premiumSubscription,
    ),
  ];

  @override
  bool get isSupported => true;
  @override
  Stream<StorePurchaseUpdate> get updates => _updates.stream;
  @override
  Future<List<StoreProduct>> loadProducts() async => _products;

  @override
  Future<void> purchase(StoreProduct product, {required String userId}) async {
    final sequence = ++_sequence;
    _updates.add(
      StorePurchaseUpdate(
        id: 'demo:$sequence',
        productId: product.id,
        status: StorePurchaseStatus.purchased,
        source: 'demo_store',
        verificationData: 'demo-token-$sequence',
        purchaseId: 'demo-purchase-$sequence',
      ),
    );
  }

  @override
  Future<void> restore({required String userId}) async {}
  @override
  Future<void> complete(StorePurchaseUpdate purchase) async {}
}
