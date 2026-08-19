class PushCampaign {
  const PushCampaign({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.targetCount,
    required this.successCount,
    required this.failureCount,
    this.deepLink,
  });
  final String id;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final int targetCount;
  final int successCount;
  final int failureCount;
  final String? deepLink;

  factory PushCampaign.fromJson(Map<String, dynamic> json) => PushCampaign(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    targetCount: json['target_count'] as int? ?? 0,
    successCount: json['success_count'] as int? ?? 0,
    failureCount: json['failure_count'] as int? ?? 0,
    deepLink: json['deep_link'] as String?,
  );
}
