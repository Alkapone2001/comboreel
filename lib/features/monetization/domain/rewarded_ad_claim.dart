class RewardedAdClaim {
  const RewardedAdClaim({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;
}

enum RewardedAdClaimStatus { pending, verified, expired }

class RewardedAdUnavailableException implements Exception {
  const RewardedAdUnavailableException([
    this.message = 'Rewarded ad unavailable',
  ]);
  final String message;
}

class RewardVerificationTimeoutException implements Exception {
  const RewardVerificationTimeoutException();
}
