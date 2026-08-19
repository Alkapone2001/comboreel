import '../domain/wallet_snapshot.dart';

abstract interface class MonetizationRepository {
  Future<WalletSnapshot> wallet(String userId);
  Future<bool> hasEpisodeAccess(String episodeId);
  Future<UnlockResult> unlockEpisodeWithCoins({
    required String episodeId,
    required String idempotencyKey,
  });
}

class InsufficientCoinsException implements Exception {
  const InsufficientCoinsException();
}
