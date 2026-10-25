import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/garment.dart';
import '../theme.dart';

bool get isTryOnSupported => Platform.isAndroid;

/// Embeds the bundled three.js / MediaPipe try-on page on Android.
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
  late final WebViewController _controller;
  late final Future<void> _ready;
  HttpServer? _server;
  String? _loadRequestedSrc;
  Object? _loadError;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _controller = WebViewController();
      _ready = _initialize();
    }
  }

  @override
  void didUpdateWidget(covariant TryOnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _pageReady = false;
    } else if (oldWidget.frontArtworkBytes != widget.frontArtworkBytes ||
        oldWidget.frontArtworkMimeType != widget.frontArtworkMimeType ||
        oldWidget.backArtworkBytes != widget.backArtworkBytes ||
        oldWidget.backArtworkMimeType != widget.backArtworkMimeType) {
      if (_pageReady) {
        _pageReady = false;
        unawaited(
          _controller.reload().catchError((Object error) {
            debugPrint('Could not reload try-on artwork: $error');
          }),
        );
      }
    } else if (_pageReady &&
        (oldWidget.shirtColorHex != widget.shirtColorHex ||
            oldWidget.frontAdjustment != widget.frontAdjustment ||
            oldWidget.backAdjustment != widget.backAdjustment)) {
      _sendDesignUpdate();
    }
  }

  void _sendDesignUpdate() {
    if (!_pageReady) return;
    final source = Uri.parse(widget.src);
    final script =
        '''
window.postMessage(${jsonEncode({
          'type': 'closetx:design',
          'front': source.queryParameters['front'],
          'back': source.queryParameters['back'],
          'color': widget.shirtColorHex,
          'frontAdjustment': {'scale': widget.frontAdjustment.scale, 'offsetX': widget.frontAdjustment.offsetX, 'offsetY': widget.frontAdjustment.offsetY},
          'backAdjustment': {'scale': widget.backAdjustment.scale, 'offsetX': widget.backAdjustment.offsetX, 'offsetY': widget.backAdjustment.offsetY},
        })}, window.location.origin);
''';
    unawaited(
      _controller.runJavaScript(script).catchError((Object error) {
        debugPrint('Could not update try-on preview: $error');
      }),
    );
  }

  Future<void> _initialize() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      _serveRequest,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Try-on asset server failed: $error\n$stackTrace');
      },
    );

    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(paper);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          _pageReady = true;
          _sendDesignUpdate();
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null &&
              uri.scheme == 'http' &&
              uri.host == 'localhost' &&
              uri.port == server.port) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ),
    );

    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      await androidController.setOnPlatformPermissionRequest((request) async {
        if (request.types.length != 1 ||
            !request.types.contains(WebViewPermissionResourceType.camera)) {
          await request.deny();
          return;
        }

        try {
          final status = await Permission.camera.request();
          if (status.isGranted) {
            await request.grant();
          } else {
            await request.deny();
          }
        } catch (error, stackTrace) {
          debugPrint(
            'Could not request camera permission: $error\n$stackTrace',
          );
          await request.deny();
        }
      });
    }
  }

  Future<void> _serveRequest(HttpRequest request) async {
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    final preview = _previewForPath(request.uri.path);
    if (preview != null) {
      final bytes = preview.$1;
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final extension = preview.$2;
      request.response.headers
        ..contentType = ContentType(
          'image',
          extension == 'jpg' ? 'jpeg' : extension,
        )
        ..set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.add(bytes);
      await request.response.close();
      return;
    }

    final assetPath = switch (request.uri.path) {
      '/tryon/index.html' => 'web/tryon/index.html',
      '/tryon/shirt.glb' => 'web/tryon/shirt.glb',
      _ => null,
    };
    if (assetPath == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final asset = await rootBundle.load(assetPath);
      request.response.headers.contentType = request.uri.path.endsWith('.html')
          ? ContentType.html
          : ContentType('model', 'gltf-binary');
      request.response.add(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      await request.response.close();
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load try-on asset "$assetPath": $error\n$stackTrace',
      );
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  (Uint8List?, String)? _previewForPath(String path) {
    for (final side in ['front', 'back']) {
      for (final extension in ['png', 'jpg', 'webp']) {
        if (path != '/tryon/preview/$side.$extension') continue;
        final bytes = side == 'front'
            ? widget.frontArtworkBytes
            : widget.backArtworkBytes;
        final mimeType = side == 'front'
            ? widget.frontArtworkMimeType
            : widget.backArtworkMimeType;
        if (mimeType == 'image/$extension' ||
            (extension == 'jpg' && mimeType == 'image/jpeg')) {
          return (bytes, extension);
        }
        return (null, extension);
      }
    }
    return null;
  }

  Future<void> _loadPage() async {
    final server = _server;
    if (server == null) return;

    final source = Uri.parse(widget.src);
    final page = Uri(
      scheme: 'http',
      host: 'localhost',
      port: server.port,
      path: source.path.startsWith('/') ? source.path : '/${source.path}',
      queryParameters: source.queryParameters,
    );
    try {
      _pageReady = false;
      await _controller.loadRequest(page);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            '3D and camera try-on are available on Android and in the ClosetX web app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _TryOnError(message: snapshot.error.toString());
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_loadError != null) {
          return _TryOnError(
            message: _loadError.toString(),
            onRetry: () {
              setState(() => _loadError = null);
              _loadRequestedSrc = null;
            },
          );
        }

        if (_loadRequestedSrc != widget.src) {
          _loadRequestedSrc = widget.src;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadPage();
          });
        }
        return WebViewWidget(controller: _controller);
      },
    );
  }
}

class _TryOnError extends StatelessWidget {
  const _TryOnError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: muted, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Could not open try-on.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

String? createPreviewUrl(Uint8List bytes, String mimeType) => null;

void revokePreviewUrl(String url) {}
