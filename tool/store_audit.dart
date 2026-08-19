import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  final strict = arguments.contains('--strict');
  final failures = <String>[];
  final pending = <String>[];

  Map<String, dynamic> jsonFile(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  void limit(Map<String, dynamic> data, String key, int maximum) {
    final value = data[key]?.toString() ?? '';
    if (value.isEmpty || value.length > maximum) {
      failures.add(
        '$key must contain 1–$maximum characters (found ${value.length}).',
      );
    }
  }

  void dimensions(String path, int width, int height, {bool opaque = false}) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) {
      failures.add('$path is not a readable image.');
      return;
    }
    if (decoded.width != width || decoded.height != height) {
      failures.add(
        '$path must be ${width}x$height (found ${decoded.width}x${decoded.height}).',
      );
    }
    if (opaque && decoded.hasAlpha) {
      final transparent = decoded.any((pixel) => pixel.a.toInt() < 255);
      if (transparent) {
        failures.add('$path contains transparency.');
      }
    }
  }

  final apple = jsonFile('store/app_store/en-US.json');
  limit(apple, 'name', 30);
  limit(apple, 'subtitle', 30);
  limit(apple, 'promotional_text', 170);
  limit(apple, 'description', 4000);
  limit(apple, 'keywords', 100);
  final play = jsonFile('store/play_store/en-US.json');
  limit(play, 'app_name', 30);
  limit(play, 'short_description', 80);
  limit(play, 'full_description', 4000);

  dimensions(
    'assets/brand/comboreel-icon-master.png',
    1254,
    1254,
    opaque: true,
  );
  dimensions('store/assets/app-icon-512.png', 512, 512, opaque: true);
  dimensions(
    'store/assets/play-feature-graphic-1024x500.png',
    1024,
    500,
    opaque: true,
  );

  for (final placeholder in [
    'REQUIRED_PUBLIC_ORIGIN',
    'REQUIRED_PUBLIC_SUPPORT',
  ]) {
    if (jsonEncode([apple, play]).contains(placeholder)) {
      pending.add('Replace $placeholder metadata values.');
    }
  }
  final captureDirectory = Directory('store/assets/screenshots');
  if (!captureDirectory.existsSync() ||
      captureDirectory.listSync().whereType<File>().isEmpty) {
    pending.add('Capture real release-candidate phone/tablet screenshots.');
  }
  if (strict) {
    failures.addAll(pending);
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Store audit failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Store asset and metadata checks passed.');
  if (pending.isNotEmpty) {
    stdout.writeln('Pending release inputs:');
    for (final item in pending) {
      stdout.writeln('- $item');
    }
  }
}
