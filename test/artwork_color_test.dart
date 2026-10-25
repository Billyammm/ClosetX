import 'dart:typed_data';

import 'package:closetx/utils/artwork_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dominant visible artwork color ignores transparent pixels', () {
    final rgba = Uint8List.fromList([
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      for (var i = 0; i < 4; i++) ...[180, 30, 20, 0],
    ]);

    expect(dominantColorFromRgba(rgba), const Color(0xFF000000));
  });

  test('dominant color combines front and back artwork samples', () {
    final front = Uint8List.fromList([100, 0, 0, 255]);
    final back = Uint8List.fromList([
      for (var i = 0; i < 4; i++) ...[0, 80, 240, 255],
    ]);

    expect(dominantColorFromRgba(front), const Color(0xFF640000));
    expect(dominantColorFromRgba(back), const Color(0xFF0050F0));
    expect(dominantColorFromRgbaImages([front, back]), const Color(0xFF0050F0));
  });

  test('transparent images have no dominant color', () {
    final rgba = Uint8List.fromList([20, 40, 60, 0]);

    expect(dominantColorFromRgba(rgba), isNull);
  });
}
