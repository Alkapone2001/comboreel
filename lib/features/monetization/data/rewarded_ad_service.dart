import '../domain/rewarded_ad_claim.dart';

abstract interface class RewardedAdService {
  bool get isAvailable;

  Future<void> show({required String userId, required String claimId});
}

class UnavailableRewardedAdService implements RewardedAdService {
  const UnavailableRewardedAdService();

  @override
  bool get isAvailable => false;

  @override
  Future<void> show({required String userId, required String claimId}) =>
      throw const RewardedAdUnavailableException();
}

class DemoRewardedAdService implements RewardedAdService {
  const DemoRewardedAdService();

  @override
  bool get isAvailable => true;

  @override
  Future<void> show({required String userId, required String claimId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
