class CatalogueSeason {
  const CatalogueSeason({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
  });

  final String id;
  final String seriesId;
  final int number;
  final String? title;

  String get label => title?.trim().isNotEmpty == true
      ? 'Season $number · $title'
      : 'Season $number';

  factory CatalogueSeason.fromJson(Map<String, dynamic> json) =>
      CatalogueSeason(
        id: json['id'] as String,
        seriesId: json['series_id'] as String,
        number: json['season_number'] as int,
        title: json['title'] as String?,
      );
}
