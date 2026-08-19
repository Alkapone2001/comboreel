class AnalyticsDashboard {
  const AnalyticsDashboard({
    required this.days,
    required this.activeViewers,
    required this.sessions,
    required this.seriesOpens,
    required this.playbackStarts,
    required this.completions,
    required this.unlocks,
    required this.purchases,
    required this.completionRate,
    required this.topSeries,
  });

  final int days;
  final int activeViewers;
  final int sessions;
  final int seriesOpens;
  final int playbackStarts;
  final int completions;
  final int unlocks;
  final int purchases;
  final double completionRate;
  final List<TopSeriesMetric> topSeries;

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> json) =>
      AnalyticsDashboard(
        days: json['days'] as int? ?? 30,
        activeViewers: json['active_viewers'] as int? ?? 0,
        sessions: json['sessions'] as int? ?? 0,
        seriesOpens: json['series_opens'] as int? ?? 0,
        playbackStarts: json['playback_starts'] as int? ?? 0,
        completions: json['completions'] as int? ?? 0,
        unlocks: json['unlocks'] as int? ?? 0,
        purchases: json['purchases'] as int? ?? 0,
        completionRate: (json['completion_rate'] as num? ?? 0).toDouble(),
        topSeries: (json['top_series'] as List? ?? const [])
            .map(
              (item) => TopSeriesMetric.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

class TopSeriesMetric {
  const TopSeriesMetric({
    required this.seriesId,
    required this.title,
    required this.opens,
  });
  final String seriesId;
  final String title;
  final int opens;

  factory TopSeriesMetric.fromJson(Map<String, dynamic> json) =>
      TopSeriesMetric(
        seriesId: json['series_id'] as String,
        title: json['title'] as String,
        opens: json['opens'] as int? ?? 0,
      );
}
