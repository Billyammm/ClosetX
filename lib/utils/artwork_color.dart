import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class _ColorBucket {
  int red = 0;
  int green = 0;
  int blue = 0;
  int count = 0;
}

Color? dominantColorFromRgba(Uint8List rgba) {
  return dominantColorFromRgbaImages([rgba]);
}

Color? dominantColorFromRgbaImages(Iterable<Uint8List> images) {
  final buckets = <int, _ColorBucket>{};
  for (final rgba in images) {
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final alpha = rgba[i + 3];
      if (alpha < 128) continue;

      final red = rgba[i], green = rgba[i + 1], blue = rgba[i + 2];
      final key = ((red >> 3) << 10) | ((green >> 3) << 5) | (blue >> 3);
      final bucket = buckets.putIfAbsent(key, _ColorBucket.new);
      bucket
        ..red += red
        ..green += green
        ..blue += blue;
      bucket.count++;
    }
  }

  _ColorBucket? dominant;
  for (final bucket in buckets.values) {
    if (dominant == null || bucket.count > dominant.count) dominant = bucket;
  }
  if (dominant == null) return null;
  return Color.fromARGB(
    255,
    (dominant.red / dominant.count).round(),
    (dominant.green / dominant.count).round(),
    (dominant.blue / dominant.count).round(),
  );
}

Future<Color?> dominantArtworkColor(Iterable<Uint8List> images) async {
  final samples = <Uint8List>[];
  for (final bytes in images) {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 64,
      targetHeight: 64,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (data != null) samples.add(data.buffer.asUint8List());
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
  return dominantColorFromRgbaImages(samples);
}
