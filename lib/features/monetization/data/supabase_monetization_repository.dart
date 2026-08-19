import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/wallet_snapshot.dart';
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
}
