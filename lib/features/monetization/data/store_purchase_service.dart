import '../domain/store_purchase.dart';

abstract interface class StorePurchaseService {
  bool get isSupported;
  String get recoveryActionLabel;
  Stream<StorePurchaseUpdate> get updates;

  Future<List<StoreProduct>> loadProducts();
  Future<void> purchase(StoreProduct product, {required String userId});
  Future<void> restore({required String userId});
  Future<void> complete(StorePurchaseUpdate purchase);
}

class UnavailableStorePurchaseService implements StorePurchaseService {
  const UnavailableStorePurchaseService();

  @override
  bool get isSupported => false;
  @override
  String get recoveryActionLabel => 'Restore Purchases';
  @override
  Stream<StorePurchaseUpdate> get updates => const Stream.empty();
  @override
  Future<List<StoreProduct>> loadProducts() async => const [];
  @override
  Future<void> purchase(StoreProduct product, {required String userId}) =>
      throw StateError('Store purchases are not available on this platform.');
  @override
  Future<void> restore({required String userId}) =>
      throw StateError('Store purchases are not available on this platform.');
  @override
  Future<void> complete(StorePurchaseUpdate purchase) async {}
}
