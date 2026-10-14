import '../models/garment.dart';

export 'tryon_view_stub.dart' if (dart.library.js_interop) 'tryon_view_web.dart';

enum TryOnMode { viewer3d, camera }

/// URL of the bundled three.js / MediaPipe page in `web/tryon/`.
String tryOnPageUrl({
  required TryOnMode mode,
  String? frontImageUrl,
  String? backImageUrl,
  String? shirtColorHex,
}) {
  return Uri(
    path: 'tryon/index.html',
    queryParameters: {
      'mode': mode == TryOnMode.camera ? 'camera' : '3d',
      'front': ?frontImageUrl,
      'back': ?backImageUrl,
      'color': ?shirtColorHex,
    },
  ).toString();
}

String tryOnPageUrlFor(Garment garment, TryOnMode mode) => tryOnPageUrl(
  mode: mode,
  frontImageUrl: garment.frontArtworkUrl,
  backImageUrl: garment.backImageUrl,
  shirtColorHex: garment.shirtColorHex,
);
