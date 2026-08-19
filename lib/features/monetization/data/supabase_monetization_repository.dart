import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/wallet_snapshot.dart';
import '../domain/rewarded_ad_claim.dart';
import '../domain/store_purchase.dart';
import 'monetization_repository.dart';

class SupabaseMonetizationRepository implements MonetizationRepository {
  SupabaseMonetizationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<bool> hasEpisodeAccess(String episodeId) async {
    final result = await _client.rpc(
      'has_episode_access',
      params: {'p_episode_id': episodeId},
    );
    return result as bool? ?? false;
  }

  @override
  Future<UnlockResult> unlockEpisodeWithCoins({
    required String episodeId,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'unlock_episode_with_coins',
        params: {
          'p_episode_id': episodeId,
          'p_idempotency_key': idempotencyKey,
        },
      ) as List<dynamic>;
      final row = rows.single as Map<String, dynamic>;
      return UnlockResult(
        accessGranted: row['access_granted'] as bool? ?? false,
        balance: row['balance'] as int? ?? 0,
        alreadyOwned: row['already_owned'] as bool? ?? false,
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('insufficient_coins')) {
        throw const InsufficientCoinsException();
      }
      rethrow;
    }
  }

  @override
  Future<WalletSnapshot> wallet(String userId) async {
    final wallet = await _client
        .from('wallets')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    final rows = await _client
        .from('coin_transactions')
        .select('amount, reason, balance_after, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return WalletSnapshot(
      balance: wallet?['balance'] as int? ?? 0,
      transactions: rows
          .map(
            (row) => CoinActivity(
              amount: row['amount'] as int,
              reason: (row['reason'] as String).replaceAll('_', ' '),
              balanceAfter: row['balance_after'] as int,
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<RewardedAdClaim> createRewardedEpisodeClaim(String episodeId) async {
    final rows = await _client.rpc(
      'create_rewarded_episode_claim',
      params: {'p_episode_id': episodeId},
    ) as List<dynamic>;
    final row = rows.single as Map<String, dynamic>;
    return RewardedAdClaim(
      id: row['claim_id'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  @override
  Future<RewardedAdClaimStatus> rewardedEpisodeClaimStatus(
    String claimId,
  ) async {
    final rows = await _client.rpc(
      'rewarded_episode_claim_status',
      params: {'p_claim_id': claimId},
    ) as List<dynamic>;
    if (rows.isEmpty) return RewardedAdClaimStatus.expired;
    final value = (rows.single as Map<String, dynamic>)['status'] as String;
    return RewardedAdClaimStatus.values.byName(value);
  }

  @override
  Future<PurchaseVerificationResult> verifyMobilePurchase(
    StorePurchaseUpdate purchase,
  ) async {
    final result = await _client.functions.invoke(
      'verify-mobile-purchase',
      body: {
        'source': purchase.source,
        'product_id': purchase.productId,
        'verification_data': purchase.verificationData,
        'purchase_id': purchase.purchaseId,
      },
    );
    final data = result.data as Map<String, dynamic>;
    if (result.status != 200 || data['ok'] != true) {
      throw StateError(
        data['error'] as String? ?? 'Purchase verification failed',
      );
    }
    return PurchaseVerificationResult(
      accepted: data['accepted'] as bool? ?? false,
      balance: data['balance'] as int?,
      premiumUntil: data['premium_until'] == null
          ? null
          : DateTime.parse(data['premium_until'] as String),
    );
  }
}
