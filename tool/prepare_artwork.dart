import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  if (arguments.length != 4) {
    throw ArgumentError(
      'Usage: dart run tool/prepare_artwork.dart input output width height',
    );
  }
  final source = img.decodeImage(File(arguments[0]).readAsBytesSync());
  if (source == null) throw StateError('Could not decode ${arguments[0]}.');
  final width = int.parse(arguments[2]);
  final height = int.parse(arguments[3]);
  final prepared = img.copyResizeCropSquare(source, size: width);
  final output = width == height
      ? prepared
      : img.copyResize(
          source,
          width: width,
          height: height,
          maintainAspect: true,
          interpolation: img.Interpolation.cubic,
        );
  final canvas = output.width == width && output.height == height
      ? output
      : img.copyCrop(
          output,
          x: (output.width - width) ~/ 2,
          y: (output.height - height) ~/ 2,
          width: width,
          height: height,
        );
  final destination = File(arguments[1])..parent.createSync(recursive: true);
  destination.writeAsBytesSync(img.encodeJpg(canvas, quality: 86));
  stdout.writeln(
    '${arguments[1]}: ${canvas.width}x${canvas.height}, ${destination.lengthSync()} bytes',
  );
}
