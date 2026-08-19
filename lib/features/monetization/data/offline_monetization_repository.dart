import '../domain/wallet_snapshot.dart';
import '../domain/rewarded_ad_claim.dart';
import 'monetization_repository.dart';

class OfflineMonetizationRepository implements MonetizationRepository {
  int _balance = 25;
  final Set<String> _unlockedEpisodes = {};
  final Map<String, UnlockResult> _requests = {};
  final Map<String, String> _rewardClaims = {};
  final List<CoinActivity> _activity = [
    CoinActivity(
      amount: 25,
      reason: 'Welcome reward',
      balanceAfter: 25,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1787090000000),
    ),
  ];

  @override
  Future<bool> hasEpisodeAccess(String episodeId) async =>
      episodeId.endsWith('episode-1') ||
      episodeId.endsWith('episode-2') ||
      episodeId.endsWith('episode-3') ||
      episodeId.endsWith('episode-4') ||
      episodeId.endsWith('episode-5') ||
      _unlockedEpisodes.contains(episodeId);

  @override
  Future<UnlockResult> unlockEpisodeWithCoins({
    required String episodeId,
    required String idempotencyKey,
  }) async {
    final previous = _requests[idempotencyKey];
    if (previous != null) return previous;
    if (_unlockedEpisodes.contains(episodeId)) {
      final result = UnlockResult(
        accessGranted: true,
        balance: _balance,
        alreadyOwned: true,
      );
      _requests[idempotencyKey] = result;
      return result;
    }
    const price = 5;
    if (_balance < price) throw const InsufficientCoinsException();
    _balance -= price;
    _unlockedEpisodes.add(episodeId);
    _activity.insert(
      0,
      CoinActivity(
        amount: -price,
        reason: 'Episode unlock',
        balanceAfter: _balance,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    final result = UnlockResult(
      accessGranted: true,
      balance: _balance,
      alreadyOwned: false,
    );
    _requests[idempotencyKey] = result;
    return result;
  }

  @override
  Future<WalletSnapshot> wallet(String userId) async => WalletSnapshot(
    balance: _balance,
    transactions: List.unmodifiable(_activity),
  );

  @override
  Future<RewardedAdClaim> createRewardedEpisodeClaim(String episodeId) async {
    final id = 'demo-reward-${_rewardClaims.length + 1}';
    _rewardClaims[id] = episodeId;
    return RewardedAdClaim(
      id: id,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<RewardedAdClaimStatus> rewardedEpisodeClaimStatus(
    String claimId,
  ) async {
    final episodeId = _rewardClaims[claimId];
    if (episodeId == null) return RewardedAdClaimStatus.expired;
    _unlockedEpisodes.add(episodeId);
    return RewardedAdClaimStatus.verified;
  }
}
