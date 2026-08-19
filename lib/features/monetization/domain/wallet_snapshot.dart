class WalletSnapshot {
  const WalletSnapshot({required this.balance, required this.transactions});

  final int balance;
  final List<CoinActivity> transactions;
}

class CoinActivity {
  const CoinActivity({
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    required this.createdAt,
  });

  final int amount;
  final String reason;
  final int balanceAfter;
  final DateTime createdAt;
}

class UnlockResult {
  const UnlockResult({
    required this.accessGranted,
    required this.balance,
    required this.alreadyOwned,
  });

  final bool accessGranted;
  final int balance;
  final bool alreadyOwned;
}
