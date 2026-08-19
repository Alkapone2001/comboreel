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
