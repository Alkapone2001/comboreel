enum AdminRole { viewer, editor, admin }

class AdminSeries {
  const AdminSeries({
    required this.id,
    required this.slug,
    required this.title,
    required this.synopsis,
    required this.status,
    this.posterUrl,
    this.heroUrl,
    this.releaseYear,
    this.ageRating,
    this.isFeatured = false,
  });

  final String id;
  final String slug;
  final String title;
  final String synopsis;
  final String status;
  final String? posterUrl;
  final String? heroUrl;
  final int? releaseYear;
  final String? ageRating;
  final bool isFeatured;

  factory AdminSeries.fromJson(Map<String, dynamic> json) => AdminSeries(
    id: json['id'] as String,
    slug: json['slug'] as String,
    title: json['title'] as String,
    synopsis: json['synopsis'] as String? ?? '',
    status: json['status'] as String? ?? 'draft',
    posterUrl: json['poster_url'] as String?,
    heroUrl: json['hero_url'] as String?,
    releaseYear: json['release_year'] as int?,
    ageRating: json['age_rating'] as String?,
    isFeatured: json['is_featured'] as bool? ?? false,
  );
}

class AdminEpisode {
  const AdminEpisode({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    required this.status,
    required this.durationSeconds,
    required this.isFree,
    required this.coinPrice,
    this.streamUid,
  });

  final String id;
  final String seriesId;
  final int number;
  final String title;
  final String status;
  final int durationSeconds;
  final bool isFree;
  final int coinPrice;
  final String? streamUid;

  factory AdminEpisode.fromJson(Map<String, dynamic> json) => AdminEpisode(
    id: json['id'] as String,
    seriesId: json['series_id'] as String,
    number: json['episode_number'] as int,
    title: json['title'] as String,
    status: json['status'] as String? ?? 'draft',
    durationSeconds: json['duration_seconds'] as int? ?? 0,
    isFree: json['is_free'] as bool? ?? false,
    coinPrice: json['coin_price'] as int? ?? 5,
    streamUid: json['stream_uid'] as String?,
  );
}

class StreamUploadTicket {
  const StreamUploadTicket({required this.uploadUrl, required this.streamUid});
  final String uploadUrl;
  final String streamUid;
}

class StreamProcessingStatus {
  const StreamProcessingStatus({
    required this.state,
    required this.percentComplete,
    this.errorReason,
  });
  final String state;
  final double percentComplete;
  final String? errorReason;
}
