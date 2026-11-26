import 'dart:io';

import 'package:image/image.dart';

void main() {
  final source = File('lib/assets/icon/Hands Holding a Controller Icon.png');
  final src = decodePng(source.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not read the icon image');
    exit(1);
  }

  final size = src.width > src.height ? src.width : src.height;
  final canvas = Image(width: size, height: size, numChannels: 4);
  fill(canvas, color: _background(src));

  const scale = 0.58;
  final width = (src.width * scale).round();
  final height = (src.height * scale).round();
  final resized = copyResize(
    src,
    width: width,
    height: height,
    interpolation: Interpolation.nearest,
  );
  final background = _background(src);
  for (final pixel in resized) {
    final distance = (pixel.r - background.r).abs() +
        (pixel.g - background.g).abs() +
        (pixel.b - background.b).abs();
    if (distance < 48) {
      pixel.set(background);
    }
  }
  compositeImage(
    canvas,
    resized,
    dstX: ((size - width) / 2).round(),
    dstY: ((size - height) / 2).round(),
  );

  File('lib/assets/icon/app_icon.png').writeAsBytesSync(encodePng(canvas));
}

Color _background(Image src) {
  final counts = <int, int>{};
  void add(int x, int y) {
    final pixel = src.getPixel(x, y);
    final key = (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
    counts[key] = (counts[key] ?? 0) + 1;
  }

  for (var i = 0; i < src.width; i++) {
    add(i, 0);
    add(i, src.height - 1);
  }
  for (var i = 0; i < src.height; i++) {
    add(0, i);
    add(src.width - 1, i);
  }

  var best = 0;
  var bestCount = -1;
  for (final entry in counts.entries) {
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return ColorRgb8((best >> 16) & 0xFF, (best >> 8) & 0xFF, best & 0xFF);
}
