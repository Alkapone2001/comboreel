import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiUrl = _requiredEnvironment('API_URL');
  final anonKey = _requiredEnvironment('ANON_KEY');
  final serviceRoleKey = _requiredEnvironment('SERVICE_ROLE_KEY');
  final runId = DateTime.now().microsecondsSinceEpoch;

  final first = await _signUp(
    apiUrl,
    anonKey,
    'rls-a-$runId@comboreel.local',
    'Viewer A',
  );
  final second = await _signUp(
    apiUrl,
    anonKey,
    'rls-b-$runId@comboreel.local',
    'Viewer B',
  );

  await _request(
    'POST',
    Uri.parse('$apiUrl/auth/v1/recover'),
    apiKey: anonKey,
    body: {'email': first.email},
    expectedStatus: 200,
    description: 'existing account can request password recovery',
  );
  await _request(
    'POST',
    Uri.parse('$apiUrl/auth/v1/recover'),
    apiKey: anonKey,
    body: {'email': 'missing-$runId@comboreel.local'},
    expectedStatus: 200,
    description: 'recovery does not reveal missing accounts',
  );

  await _expectRows(
    apiUrl,
    anonKey,
    first.token,
    'profiles?id=eq.${first.id}',
    count: 1,
    description: 'viewer can read own profile',
  );
  await _expectRows(
    apiUrl,
    anonKey,
    first.token,
    'profiles?id=eq.${second.id}',
    count: 0,
    description: 'viewer cannot read another profile',
  );

  await _request(
    'PATCH',
    Uri.parse('$apiUrl/rest/v1/profiles?id=eq.${first.id}'),
    apiKey: anonKey,
    bearer: first.token,
    body: {'preferred_language': 'es'},
    expectedStatus: 204,
    description: 'viewer can update preferred subtitle language',
  );
  await _request(
    'PATCH',
    Uri.parse('$apiUrl/rest/v1/profiles?id=eq.${first.id}'),
    apiKey: anonKey,
    bearer: first.token,
    body: {'display_name': 'Updated Viewer'},
    expectedStatus: 204,
    description: 'viewer can update own display name',
  );
  await _request(
    'PUT',
    Uri.parse('$apiUrl/auth/v1/user?redirect_to=http://127.0.0.1:7357'),
    apiKey: anonKey,
    bearer: first.token,
    body: {'email': 'updated-$runId@comboreel.local'},
    expectedStatus: 200,
    description: 'email change requires confirmation through Auth',
  );
  await _request(
    'PATCH',
    Uri.parse('$apiUrl/rest/v1/profiles?id=eq.${first.id}'),
    apiKey: anonKey,
    bearer: first.token,
    body: {'role': 'admin'},
    expectedStatus: 403,
    description: 'viewer cannot elevate own role',
  );

  const publishedId = '10000000-0000-4000-8000-000000000001';
  const draftId = '10000000-0000-4000-8000-000000000002';
  await _request(
    'POST',
    Uri.parse('$apiUrl/rest/v1/series?on_conflict=id'),
    apiKey: serviceRoleKey,
    bearer: serviceRoleKey,
    headers: {'Prefer': 'resolution=merge-duplicates'},
    body: [
      {
        'id': publishedId,
        'slug': 'rls-published-smoke',
        'title': 'Published Smoke Story',
        'synopsis': 'A complete integration-test fixture.',
        'poster_url': 'https://example.com/poster.jpg',
        'hero_url': 'https://example.com/hero.jpg',
        'release_year': 2026,
        'age_rating': '13+',
        'status': 'draft',
        'published_at': null,
      },
      {
        'id': draftId,
        'slug': 'rls-draft-smoke',
        'title': 'Draft Smoke Story',
        'synopsis': 'A private integration-test fixture.',
        'poster_url': 'https://example.com/draft-poster.jpg',
        'hero_url': 'https://example.com/draft-hero.jpg',
        'release_year': 2026,
        'age_rating': '13+',
        'status': 'draft',
        'published_at': null,
      },
    ],
    expectedStatus: 201,
    alternateStatus: 200,
    description: 'service role seeds visibility fixtures',
  );
  await _request(
    'POST',
    Uri.parse('$apiUrl/rest/v1/episodes?on_conflict=id'),
    apiKey: serviceRoleKey,
    bearer: serviceRoleKey,
    headers: {'Prefer': 'resolution=merge-duplicates'},
    body: {
      'id': '20000000-0000-4000-8000-000000000001',
      'series_id': publishedId,
      'episode_number': 1,
      'title': 'Smoke Episode',
      'duration_seconds': 90,
      'stream_uid': 'local-smoke-stream',
      'status': 'published',
      'published_at': DateTime.now().toUtc().toIso8601String(),
    },
    expectedStatus: 201,
    alternateStatus: 200,
    description: 'service role seeds a publishable episode',
  );
  await _request(
    'PATCH',
    Uri.parse('$apiUrl/rest/v1/series?id=eq.$publishedId'),
    apiKey: serviceRoleKey,
    bearer: serviceRoleKey,
    body: {
      'status': 'published',
      'published_at': DateTime.now().toUtc().toIso8601String(),
    },
    expectedStatus: 204,
    description: 'service role publishes a complete series',
  );
  await _expectRows(
    apiUrl,
    anonKey,
    null,
    'series?id=in.($publishedId,$draftId)&select=id',
    count: 1,
    description: 'anonymous catalogue exposes published series only',
  );

  await _request(
    'POST',
    Uri.parse('$apiUrl/rest/v1/favourites'),
    apiKey: anonKey,
    bearer: first.token,
    body: {'user_id': first.id, 'series_id': publishedId},
    expectedStatus: 201,
    description: 'viewer can create own favourite',
  );
  await _expectRows(
    apiUrl,
    anonKey,
    second.token,
    'favourites?series_id=eq.$publishedId',
    count: 0,
    description: 'viewer cannot read another viewer favourite',
  );

  await _expectRows(
    apiUrl,
    anonKey,
    first.token,
    'privacy_consents?user_id=eq.${first.id}',
    count: 2,
    description: 'signup records privacy and terms consent',
  );

  await _request(
    'PUT',
    Uri.parse('$apiUrl/auth/v1/user'),
    apiKey: anonKey,
    bearer: first.token,
    body: {'password': 'ComboReel-Updated-2026!'},
    expectedStatus: 200,
    description: 'authenticated viewer can update password securely',
  );

  stdout.writeln('Local Supabase Auth/RLS smoke test passed (18 checks).');
}

Future<_Session> _signUp(
  String apiUrl,
  String anonKey,
  String email,
  String displayName,
) async {
  final response = await _request(
    'POST',
    Uri.parse('$apiUrl/auth/v1/signup'),
    apiKey: anonKey,
    body: {
      'email': email,
      'password': 'ComboReel-Test-2026!',
      'data': {
        'display_name': displayName,
        'privacy_version': '2026-08-19',
        'terms_version': '2026-08-19',
      },
    },
    expectedStatus: 200,
    description: 'sign up $displayName',
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final user = body['user'] as Map<String, dynamic>?;
  final token = body['access_token'] as String?;
  final id = user?['id'] as String?;
  if (token == null || id == null) {
    throw StateError('Signup did not return an authenticated session.');
  }
  return _Session(id, email, token);
}

Future<void> _expectRows(
  String apiUrl,
  String apiKey,
  String? bearer,
  String path, {
  required int count,
  required String description,
}) async {
  final response = await _request(
    'GET',
    Uri.parse('$apiUrl/rest/v1/$path'),
    apiKey: apiKey,
    bearer: bearer,
    expectedStatus: 200,
    description: description,
  );
  final rows = jsonDecode(response.body) as List<dynamic>;
  if (rows.length != count) {
    throw StateError(
      '$description: expected $count rows, received ${rows.length}.',
    );
  }
}

Future<http.Response> _request(
  String method,
  Uri uri, {
  required String apiKey,
  String? bearer,
  Object? body,
  Map<String, String> headers = const {},
  required int expectedStatus,
  int? alternateStatus,
  required String description,
}) async {
  final request = http.Request(method, uri)
    ..headers.addAll({
      'apikey': apiKey,
      if (bearer != null) 'Authorization': 'Bearer $bearer',
      if (body != null) 'Content-Type': 'application/json',
      ...headers,
    });
  if (body != null) request.body = jsonEncode(body);
  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);
  if (response.statusCode != expectedStatus &&
      response.statusCode != alternateStatus) {
    throw StateError(
      '$description: expected HTTP $expectedStatus, received '
      '${response.statusCode}: ${response.body}',
    );
  }
  stdout.writeln('PASS: $description');
  return response;
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('Missing required environment variable $name.');
  }
  return value;
}

class _Session {
  const _Session(this.id, this.email, this.token);
  final String id;
  final String email;
  final String token;
}
