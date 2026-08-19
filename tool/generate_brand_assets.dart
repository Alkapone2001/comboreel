import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  final sourcePath = arguments.isEmpty
      ? 'assets/brand/comboreel-icon-master.png'
      : arguments.first;
  final source = img.decodeImage(File(sourcePath).readAsBytesSync());
  if (source == null) throw StateError('Could not decode $sourcePath.');
  if (source.width != source.height || source.width < 1024) {
    throw StateError('Brand master must be square and at least 1024 px.');
  }

  final outputs = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
        167,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
        1024,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
    'web/favicon.png': 32,
    'store/assets/app-icon-512.png': 512,
  };
  for (final entry in outputs.entries) {
    final file = File(entry.key)..parent.createSync(recursive: true);
    final resized = img.copyResize(
      source,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    file.writeAsBytesSync(img.encodePng(resized, level: 9));
  }
  final feature = img.Image(width: 1024, height: 500);
  img.fill(feature, color: img.ColorRgb8(16, 5, 19));
  final featureMark = img.copyResize(
    source,
    width: 500,
    height: 500,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(feature, featureMark, dstX: 262);
  File('store/assets/play-feature-graphic-1024x500.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(feature, level: 9));
  stdout.writeln(
    'Generated ${outputs.length} branded app assets from $sourcePath.',
  );
}
