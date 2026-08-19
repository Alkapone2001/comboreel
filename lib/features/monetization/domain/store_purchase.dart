enum StoreProductKind { coinPack, premiumSubscription }

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.kind,
    this.coinAmount,
  });

  final String id;
  final String title;
  final String description;
  final String price;
  final StoreProductKind kind;
  final int? coinAmount;
}

enum StorePurchaseStatus { pending, purchased, restored, cancelled, failed }

class StorePurchaseUpdate {
  const StorePurchaseUpdate({
    required this.id,
    required this.productId,
    required this.status,
    required this.source,
    required this.verificationData,
    this.purchaseId,
    this.error,
  });

  final String id;
  final String productId;
  final StorePurchaseStatus status;
  final String source;
  final String verificationData;
  final String? purchaseId;
  final String? error;
}

class PurchaseVerificationResult {
  const PurchaseVerificationResult({
    required this.accepted,
    this.balance,
    this.premiumUntil,
  });

  final bool accepted;
  final int? balance;
  final DateTime? premiumUntil;
}
