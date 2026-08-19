import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final baseUrl = Platform.environment['MAILPIT_URL'];
  if (baseUrl == null || baseUrl.isEmpty) {
    stderr.writeln(
      'MAILPIT_URL is required. Run this through the local smoke script.',
    );
    exitCode = 1;
    return;
  }

  final listResponse = await http.get(Uri.parse('$baseUrl/api/v1/messages'));
  if (listResponse.statusCode != 200) {
    throw StateError(
      'Mailpit message list returned ${listResponse.statusCode}.',
    );
  }
  final list = jsonDecode(listResponse.body) as Map<String, dynamic>;
  final messages = list['messages'] as List<dynamic>? ?? const [];
  final bySubject = <String, Map<String, dynamic>>{
    for (final value in messages)
      (value as Map<String, dynamic>)['Subject'] as String: value,
  };

  const actionSubjects = [
    'Reset your ComboReel password',
    'Confirm your new ComboReel email',
  ];
  const notificationSubjects = ['Your ComboReel password was changed'];
  for (final subject in [...actionSubjects, ...notificationSubjects]) {
    final summary = bySubject[subject];
    if (summary == null) throw StateError('Mailpit is missing "$subject".');
    final id = summary['ID'] as String;
    final response = await http.get(Uri.parse('$baseUrl/api/v1/message/$id'));
    if (response.statusCode != 200) {
      throw StateError('Mailpit could not load "$subject".');
    }
    final message = jsonDecode(response.body) as Map<String, dynamic>;
    final html = message['HTML'] as String? ?? '';
    if (!html.contains('ComboReel') || html.toLowerCase().contains('<script')) {
      throw StateError('Delivered "$subject" failed branding/security checks.');
    }
    if (actionSubjects.contains(subject) &&
        (!html.contains('/auth/v1/verify?token=') || !html.contains('href='))) {
      throw StateError('Delivered "$subject" has no Auth verification link.');
    }
    stdout.writeln('PASS: delivered $subject');
  }
  stdout.writeln('Local transactional email audit passed.');
}
