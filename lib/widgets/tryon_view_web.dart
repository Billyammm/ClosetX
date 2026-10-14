import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const isTryOnSupported = true;

/// Embeds the try-on page in an iframe that may use the camera.
class TryOnView extends StatelessWidget {
  const TryOnView({required this.src, super.key});

  final String src;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey(src),
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe = element as web.HTMLIFrameElement;
        iframe
          ..src = src
          ..allow = 'camera; fullscreen'
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
      },
    );
  }
}

/// Object URL for locally picked artwork, so it can be previewed in 3D
/// before upload. Release it with [revokePreviewUrl].
String? createPreviewUrl(Uint8List bytes, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

void revokePreviewUrl(String url) => web.URL.revokeObjectURL(url);
