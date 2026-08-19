import '../domain/admin_models.dart';

abstract interface class AdminRepository {
  Future<AdminRole> currentRole();
  Future<List<AdminSeries>> series();
  Future<AdminSeries> saveSeries(Map<String, dynamic> values, {String? id});
  Future<List<AdminEpisode>> episodes(String seriesId);
  Future<List<AdminSeason>> seasons(String seriesId);
  Future<AdminSeason> saveSeason(Map<String, dynamic> values, {String? id});
  Future<AdminEpisode> saveEpisode(Map<String, dynamic> values, {String? id});
  Future<void> setSeriesPublished(String id, bool published);
  Future<void> setEpisodePublished(String id, bool published);
  Future<StreamUploadTicket> createUpload(String episodeId, String fileName);
  Future<StreamProcessingStatus> processingStatus(String episodeId);
}

class UnavailableAdminRepository implements AdminRepository {
  const UnavailableAdminRepository();
  @override
  Future<AdminRole> currentRole() async => AdminRole.viewer;
  Never _unavailable() => throw StateError('Creator Studio requires Supabase.');
  @override
  Future<List<AdminSeries>> series() async => _unavailable();
  @override
  Future<AdminSeries> saveSeries(
    Map<String, dynamic> values, {
    String? id,
  }) async => _unavailable();
  @override
  Future<List<AdminEpisode>> episodes(String seriesId) async => _unavailable();
  @override
  Future<List<AdminSeason>> seasons(String seriesId) async => _unavailable();
  @override
  Future<AdminSeason> saveSeason(
    Map<String, dynamic> values, {
    String? id,
  }) async => _unavailable();
  @override
  Future<AdminEpisode> saveEpisode(
    Map<String, dynamic> values, {
    String? id,
  }) async => _unavailable();
  @override
  Future<void> setSeriesPublished(String id, bool published) async =>
      _unavailable();
  @override
  Future<void> setEpisodePublished(String id, bool published) async =>
      _unavailable();
  @override
  Future<StreamUploadTicket> createUpload(
    String episodeId,
    String fileName,
  ) async => _unavailable();
  @override
  Future<StreamProcessingStatus> processingStatus(String episodeId) async =>
      _unavailable();
}
