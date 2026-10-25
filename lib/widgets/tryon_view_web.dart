import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../models/garment.dart';

const isTryOnSupported = true;

/// Embeds the try-on page in an iframe that may use the camera.
class TryOnView extends StatefulWidget {
  const TryOnView({
    required this.src,
    this.shirtColorHex = '#F2F2F2',
    this.frontAdjustment = const PrintFitAdjustment(),
    this.backAdjustment = const PrintFitAdjustment(),
    this.frontArtworkBytes,
    this.frontArtworkMimeType,
    this.backArtworkBytes,
    this.backArtworkMimeType,
    super.key,
  });

  final String src;
  final String shirtColorHex;
  final PrintFitAdjustment frontAdjustment;
  final PrintFitAdjustment backAdjustment;
  final Uint8List? frontArtworkBytes;
  final String? frontArtworkMimeType;
  final Uint8List? backArtworkBytes;
  final String? backArtworkMimeType;

  @override
  State<TryOnView> createState() => _TryOnViewState();
}

class _TryOnViewState extends State<TryOnView> {
  web.HTMLIFrameElement? _iframe;
  String? _loadedSrc;

  @override
  void didUpdateWidget(covariant TryOnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _loadedSrc = null;
      if (_iframe != null) _iframe!.src = widget.src;
    } else if (oldWidget.shirtColorHex != widget.shirtColorHex ||
        oldWidget.frontAdjustment != widget.frontAdjustment ||
        oldWidget.backAdjustment != widget.backAdjustment) {
      _sendDesignUpdate();
    }
  }

  void _sendDesignUpdate() {
    final iframe = _iframe;
    if (iframe == null || _loadedSrc != widget.src) return;
    final message = jsonEncode({
      'type': 'closetx:design',
      'front': Uri.parse(widget.src).queryParameters['front'],
      'back': Uri.parse(widget.src).queryParameters['back'],
      'color': widget.shirtColorHex,
      'frontAdjustment': {
        'scale': widget.frontAdjustment.scale,
        'offsetX': widget.frontAdjustment.offsetX,
        'offsetY': widget.frontAdjustment.offsetY,
      },
      'backAdjustment': {
        'scale': widget.backAdjustment.scale,
        'offsetX': widget.backAdjustment.offsetX,
        'offsetY': widget.backAdjustment.offsetY,
      },
    });
    iframe.contentWindow?.postMessage(
      message.toJS,
      web.window.location.origin.toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey(widget.src),
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe = element as web.HTMLIFrameElement;
        _iframe = iframe;
        iframe.onLoad.listen((_) {
          if (!mounted || !identical(_iframe, iframe)) return;
          _loadedSrc = widget.src;
          _sendDesignUpdate();
        });
        iframe
          ..src = widget.src
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
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

void revokePreviewUrl(String url) => web.URL.revokeObjectURL(url);
