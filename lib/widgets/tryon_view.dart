import 'dart:convert';

import '../models/garment.dart';

export 'tryon_view_stub.dart'
    if (dart.library.js_interop) 'tryon_view_web.dart';

enum TryOnMode { viewer3d, camera }

String tryOnDesignMessage({
  required Uri source,
  required String shirtColorHex,
  required PrintFitAdjustment frontAdjustment,
  required PrintFitAdjustment backAdjustment,
}) {
  return '''
window.postMessage(${jsonEncode({
    'type': 'closetx:design',
    'front': source.queryParameters['front'],
    'back': source.queryParameters['back'],
    'color': shirtColorHex,
    'frontAdjustment': {'scale': frontAdjustment.scale, 'offsetX': frontAdjustment.offsetX, 'offsetY': frontAdjustment.offsetY},
    'backAdjustment': {'scale': backAdjustment.scale, 'offsetX': backAdjustment.offsetX, 'offsetY': backAdjustment.offsetY},
  })}, window.location.origin);
''';
}

/// URL of the bundled three.js / MediaPipe page in `web/tryon/`.
String tryOnPageUrl({
  required TryOnMode mode,
  String? frontImageUrl,
  String? backImageUrl,
  String? shirtColorHex,
  PrintFitAdjustment frontAdjustment = const PrintFitAdjustment(),
  PrintFitAdjustment backAdjustment = const PrintFitAdjustment(),
  bool autoRotate = true,
}) {
  return Uri(
    path: 'tryon/index.html',
    queryParameters: {
      'mode': mode == TryOnMode.camera ? 'camera' : '3d',
      'autoRotate': '$autoRotate',
      'front': ?frontImageUrl,
      'back': ?backImageUrl,
      'color': ?shirtColorHex,
      'frontScale': '${frontAdjustment.scale}',
      'frontOffsetX': '${frontAdjustment.offsetX}',
      'frontOffsetY': '${frontAdjustment.offsetY}',
      'backScale': '${backAdjustment.scale}',
      'backOffsetX': '${backAdjustment.offsetX}',
      'backOffsetY': '${backAdjustment.offsetY}',
    },
  ).toString();
}

String tryOnPageUrlFor(Garment garment, TryOnMode mode) => tryOnPageUrl(
  mode: mode,
  frontImageUrl: garment.frontArtworkUrl,
  backImageUrl: garment.backImageUrl,
  shirtColorHex: garment.shirtColorHex,
  frontAdjustment: garment.frontPrintAdjustment,
  backAdjustment: garment.backPrintAdjustment,
);
