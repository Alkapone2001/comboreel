import 'dart:io';

void main() {
  final failures = <String>[];
  String read(String path) => File(path).readAsStringSync();
  void require(bool condition, String message) {
    if (!condition) failures.add(message);
  }

  final quality = read('.github/workflows/quality.yml');
  for (final gate in [
    'flutter pub get --enforce-lockfile',
    'dart format --output=none --set-exit-if-changed',
    'flutter analyze',
    'flutter test',
    'flutter build web --release',
    'tool/release_audit.dart',
    'tool/store_audit.dart',
    'supabase/tests/bootstrap.sql',
    '*_contract.sql',
  ]) {
    require(quality.contains(gate), 'Quality workflow is missing: $gate');
  }
  require(
    quality.contains('permissions:\n  contents: read'),
    'Quality workflow permissions must be read-only.',
  );

  final deploy = read('.github/workflows/deploy-web-staging.yml');
  require(
    deploy.contains('workflow_dispatch:'),
    'Staging deployment must require an explicit dispatch.',
  );
  require(
    deploy.contains('environment: staging'),
    'Staging deployment must use the protected staging environment.',
  );
  require(
    deploy.contains('cloudflare/wrangler-action@'),
    'Staging deployment must publish through Cloudflare Pages.',
  );
  require(
    !deploy.contains('SUPABASE_SERVICE_ROLE_KEY'),
    'A server service-role key must never enter a client deployment workflow.',
  );
  require(
    !deploy.contains('STRIPE_SECRET_KEY'),
    'Stripe secrets must never enter a client deployment workflow.',
  );
  require(
    deploy.contains('PUBLIC_APP_URL'),
    'Staging deployment must configure canonical HTTPS share links.',
  );

  final databaseContracts = Directory('supabase/tests')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('_contract.sql'))
      .length;
  require(
    databaseContracts >= 3,
    'Expected monetization, analytics/push, and privacy SQL contracts.',
  );
  require(
    File('web/_headers').existsSync() && File('web/_redirects').existsSync(),
    'Web deployment metadata is incomplete.',
  );

  final authConfig = read('supabase/config.toml');
  final authTemplates = <String, String>{
    'confirmation': 'supabase/templates/confirmation.html',
    'recovery': 'supabase/templates/recovery.html',
    'email_change': 'supabase/templates/email_change.html',
    'invite': 'supabase/templates/invite.html',
    'magic_link': 'supabase/templates/magic_link.html',
  };
  for (final entry in authTemplates.entries) {
    require(
      authConfig.contains('[auth.email.template.${entry.key}]'),
      'Auth email configuration is missing ${entry.key}.',
    );
    final file = File(entry.value);
    require(
      file.existsSync(),
      'Auth email template is missing: ${entry.value}',
    );
    if (file.existsSync()) {
      final html = file.readAsStringSync();
      require(html.contains('ComboReel'), '${entry.key} is not branded.');
      require(
        html.contains('{{ .ConfirmationURL }}'),
        '${entry.key} must use the Supabase confirmation URL.',
      );
      require(
        !html.toLowerCase().contains('<script'),
        '${entry.key} must not contain executable scripts.',
      );
      require(
        !html.contains('http://'),
        '${entry.key} must not contain insecure remote links.',
      );
    }
  }
  for (final type in ['password_changed', 'email_changed']) {
    require(
      authConfig.contains('[auth.email.notification.$type]') &&
          authConfig.contains('$type]\nenabled = true'),
      'Security notification $type must be enabled.',
    );
    final path = 'supabase/templates/${type}_notification.html';
    require(
      File(path).existsSync(),
      'Security email template is missing: $path',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Deployment audit failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Deployment automation audit passed ($databaseContracts SQL contracts).',
  );
}
