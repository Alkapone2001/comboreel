import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/rewarded_ad_claim.dart';
import 'rewarded_ad_service.dart';

class AdMobRewardedAdService implements RewardedAdService {
  const AdMobRewardedAdService({
    required this.androidAdUnitId,
    required this.iosAdUnitId,
  });

  final String androidAdUnitId;
  final String iosAdUnitId;

  String? get _adUnitId => switch (defaultTargetPlatform) {
    TargetPlatform.android => androidAdUnitId,
    TargetPlatform.iOS => iosAdUnitId,
    _ => null,
  };

  @override
  bool get isAvailable => !kIsWeb && (_adUnitId?.isNotEmpty ?? false);

  @override
  Future<void> show({required String userId, required String claimId}) async {
    final adUnitId = _adUnitId;
    if (!isAvailable || adUnitId == null) {
      throw const RewardedAdUnavailableException();
    }
    await MobileAds.instance.initialize();
    final completion = Completer<void>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdFailedToLoad: (error) => completion.completeError(
          RewardedAdUnavailableException(error.message),
        ),
        onAdLoaded: (ad) {
          var earned = false;
          ad.setServerSideOptions(
            ServerSideVerificationOptions(userId: userId, customData: claimId),
          );
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completion.isCompleted) {
                earned
                    ? completion.complete()
                    : completion.completeError(
                        const RewardedAdUnavailableException(
                          'The ad was closed before the reward was earned.',
                        ),
                      );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completion.isCompleted) {
                completion.completeError(
                  RewardedAdUnavailableException(error.message),
                );
              }
            },
          );
          ad.show(onUserEarnedReward: (_, _) => earned = true);
        },
      ),
    );
    return completion.future;
  }
}
