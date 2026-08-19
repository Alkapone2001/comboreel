import '../domain/push_campaign.dart';

abstract interface class PushCampaignRepository {
  Future<List<PushCampaign>> campaigns();
  Future<PushCampaign> create({
    required String title,
    required String body,
    String? deepLink,
  });
  Future<void> send(String campaignId);
}

class UnavailablePushCampaignRepository implements PushCampaignRepository {
  const UnavailablePushCampaignRepository();
  Never _unavailable() => throw StateError('Push campaigns require Supabase.');
  @override
  Future<List<PushCampaign>> campaigns() async => _unavailable();
  @override
  Future<PushCampaign> create({
    required String title,
    required String body,
    String? deepLink,
  }) async => _unavailable();
  @override
  Future<void> send(String campaignId) async => _unavailable();
}
