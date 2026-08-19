import 'dart:io';

void main() {
  final failures = <String>[];
  String read(String path) => File(path).readAsStringSync();
  void require(bool condition, String message) {
    if (!condition) failures.add(message);
  }

  final manifest = read('android/app/src/main/AndroidManifest.xml');
  require(
    manifest.contains('android.permission.INTERNET'),
    'Android release manifest must request INTERNET.',
  );
  require(
    manifest.contains('android:usesCleartextTraffic="false"'),
    'Android release must reject cleartext traffic.',
  );
  require(
    manifest.contains('android:scheme="comboreel"'),
    'Android must register the ComboReel deep-link scheme.',
  );

  final gradle = read('android/app/build.gradle.kts');
  require(
    !gradle.contains('signingConfigs.getByName("debug")'),
    'Android release must never use debug signing.',
  );
  require(
    read('.gitignore').contains('*.jks'),
    'Android keystores must be ignored by Git.',
  );
  require(
    read('ios/Runner/Info.plist').contains('<string>comboreel</string>'),
    'iOS must register the ComboReel deep-link scheme.',
  );

  final dartSources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  const serverSecrets = [
    'SUPABASE_SERVICE_ROLE_KEY',
    'STRIPE_SECRET_KEY',
    'CLOUDFLARE_STREAM_API_TOKEN',
    'APPLE_PRIVATE_KEY',
    'GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY',
  ];
  for (final file in dartSources) {
    final contents = file.readAsStringSync();
    for (final secret in serverSecrets) {
      require(
        !contents.contains(secret),
        'Server secret name $secret leaked into ${file.path}.',
      );
    }
    require(
      !contents.contains("'http://") && !contents.contains('"http://'),
      'Cleartext URL found in ${file.path}.',
    );
  }

  final accountData = read('supabase/functions/account-data/index.ts');
  require(
    !accountData.contains('"access-control-allow-origin": "*"'),
    'Account-data CORS must use an exact origin allowlist.',
  );
  require(
    accountData.contains('recent_sign_in_required'),
    'Account deletion must enforce recent authentication.',
  );
  require(
    accountData.contains('auth.admin.deleteUser'),
    'Account deletion must remove the Auth user.',
  );

  final redirects = read('web/_redirects');
  for (final route in ['/privacy', '/terms', '/delete-account']) {
    require(redirects.contains(route), 'Web release rewrite missing $route.');
  }
  final headers = read('web/_headers');
  for (final header in [
    'X-Content-Type-Options',
    'Referrer-Policy',
    'Permissions-Policy',
    'X-Frame-Options',
  ]) {
    require(headers.contains(header), 'Web security header missing $header.');
  }

  final webBundle = File('build/web/main.dart.js');
  if (webBundle.existsSync()) {
    const maximumBytes = 4 * 1024 * 1024;
    require(
      webBundle.lengthSync() <= maximumBytes,
      'Web JavaScript bundle exceeds the 4 MiB regression budget.',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Release audit failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Release audit passed (${webBundle.existsSync() ? 'including web bundle budget' : 'source checks only'}).',
  );
}
