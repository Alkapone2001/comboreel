import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/push_campaign.dart';
import 'push_campaign_repository.dart';

class SupabasePushCampaignRepository implements PushCampaignRepository {
  const SupabasePushCampaignRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PushCampaign>> campaigns() async {
    final rows = await _client
        .from('push_campaigns')
        .select()
        .order('created_at', ascending: false)
        .limit(30);
    return rows.map<PushCampaign>((row) => PushCampaign.fromJson(row)).toList();
  }

  @override
  Future<PushCampaign> create({
    required String title,
    required String body,
    String? deepLink,
  }) async {
    final data = await _client.rpc(
      'create_push_campaign',
      params: {'p_title': title, 'p_body': body, 'p_deep_link': deepLink},
    );
    return PushCampaign.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> send(String campaignId) async {
    await _client.functions.invoke(
      'send-push-campaign',
      body: {'campaign_id': campaignId},
    );
  }
}
