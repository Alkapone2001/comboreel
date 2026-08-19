import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_models.dart';
import 'admin_repository.dart';

class SupabaseAdminRepository implements AdminRepository {
  const SupabaseAdminRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AdminRole> currentRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return AdminRole.viewer;
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return switch (row?['role']) {
      'admin' => AdminRole.admin,
      'editor' => AdminRole.editor,
      _ => AdminRole.viewer,
    };
  }

  @override
  Future<List<AdminSeries>> series() async {
    final rows = await _client
        .from('series')
        .select()
        .order('updated_at', ascending: false);
    return rows.map<AdminSeries>((row) => AdminSeries.fromJson(row)).toList();
  }

  @override
  Future<AdminSeries> saveSeries(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    final payload = {
      ...values,
      if (id == null) 'created_by': _client.auth.currentUser!.id,
    };
    final row = id == null
        ? await _client.from('series').insert(payload).select().single()
        : await _client
              .from('series')
              .update(payload)
              .eq('id', id)
              .select()
              .single();
    return AdminSeries.fromJson(row);
  }

  @override
  Future<List<AdminEpisode>> episodes(String seriesId) async {
    final rows = await _client
        .from('episodes')
        .select()
        .eq('series_id', seriesId)
        .order('episode_number');
    return rows.map<AdminEpisode>((row) => AdminEpisode.fromJson(row)).toList();
  }

  @override
  Future<List<AdminSeason>> seasons(String seriesId) async {
    final rows = await _client
        .from('seasons')
        .select()
        .eq('series_id', seriesId)
        .order('season_number');
    return rows.map<AdminSeason>((row) => AdminSeason.fromJson(row)).toList();
  }

  @override
  Future<AdminSeason> saveSeason(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    final row = id == null
        ? await _client.from('seasons').insert(values).select().single()
        : await _client
              .from('seasons')
              .update(values)
              .eq('id', id)
              .select()
              .single();
    return AdminSeason.fromJson(row);
  }

  @override
  Future<AdminEpisode> saveEpisode(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    final row = id == null
        ? await _client.from('episodes').insert(values).select().single()
        : await _client
              .from('episodes')
              .update(values)
              .eq('id', id)
              .select()
              .single();
    return AdminEpisode.fromJson(row);
  }

  @override
  Future<void> setSeriesPublished(String id, bool published) async {
    await _client.rpc(
      'set_series_publication',
      params: {'target_series_id': id, 'should_publish': published},
    );
  }

  @override
  Future<void> setEpisodePublished(String id, bool published) async {
    await _client.rpc(
      'set_episode_publication',
      params: {'target_episode_id': id, 'should_publish': published},
    );
  }

  @override
  Future<StreamUploadTicket> createUpload(
    String episodeId,
    String fileName,
  ) async {
    final response = await _client.functions.invoke(
      'admin-stream',
      body: {
        'action': 'create_upload',
        'episode_id': episodeId,
        'file_name': fileName,
        'max_duration_seconds': 3600,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return StreamUploadTicket(
      uploadUrl: data['upload_url'] as String,
      streamUid: data['stream_uid'] as String,
    );
  }

  @override
  Future<StreamProcessingStatus> processingStatus(String episodeId) async {
    final response = await _client.functions.invoke(
      'admin-stream',
      body: {'action': 'status', 'episode_id': episodeId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return StreamProcessingStatus(
      state: data['state'] as String,
      percentComplete: (data['percent_complete'] as num? ?? 0).toDouble(),
      errorReason: data['error_reason'] as String?,
    );
  }
}
