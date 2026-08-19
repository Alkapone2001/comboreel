import '../domain/wallet_snapshot.dart';
import '../domain/rewarded_ad_claim.dart';

abstract interface class MonetizationRepository {
  Future<WalletSnapshot> wallet(String userId);
  Future<bool> hasEpisodeAccess(String episodeId);
  Future<UnlockResult> unlockEpisodeWithCoins({
    required String episodeId,
    required String idempotencyKey,
  });
  Future<RewardedAdClaim> createRewardedEpisodeClaim(String episodeId);
  Future<RewardedAdClaimStatus> rewardedEpisodeClaimStatus(String claimId);
}

class InsufficientCoinsException implements Exception {
  const InsufficientCoinsException();
}
