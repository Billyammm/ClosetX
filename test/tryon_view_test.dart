import 'package:closetx/models/garment.dart';
import 'package:closetx/widgets/tryon_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const garment = Garment(
    id: 'supabase:design-id',
    name: 'Studio shirt',
    designer: 'ClosetX Designer',
    price: 500,
    category: 'T-Shirts',
    imageUrl: 'https://example.com/thumbnail.png',
    frontImageUrl: 'https://example.com/front.png',
    backImageUrl: 'https://example.com/back.png',
    shirtColorHex: '#F2F2F2',
    color: Colors.white,
    impact: 'Ready for 3D try-on',
    description: 'A designer shirt.',
  );

  test('designer 3D preview uses the design artwork', () {
    final uri = Uri.parse(tryOnPageUrlFor(garment, TryOnMode.viewer3d));

    expect(uri.path, 'tryon/index.html');
    expect(uri.queryParameters['mode'], '3d');
    expect(uri.queryParameters['front'], 'https://example.com/front.png');
    expect(uri.queryParameters['back'], 'https://example.com/back.png');
    expect(uri.queryParameters['color'], '#F2F2F2');
  });

  test('designer camera try-on opens camera mode for the design', () {
    final uri = Uri.parse(tryOnPageUrlFor(garment, TryOnMode.camera));

    expect(uri.queryParameters['mode'], 'camera');
    expect(uri.queryParameters['front'], 'https://example.com/front.png');
    expect(uri.queryParameters['back'], 'https://example.com/back.png');
  });

  test('upload preview can hold the front view for fit adjustments', () {
    final uri = Uri.parse(
      tryOnPageUrl(mode: TryOnMode.viewer3d, autoRotate: false),
    );

    expect(uri.queryParameters['autoRotate'], 'false');
  });

  test('saved artwork fit adjustments are included in the try-on URL', () {
    const adjustedGarment = Garment(
      id: 'supabase:adjusted-design-id',
      name: 'Adjusted shirt',
      designer: 'ClosetX Designer',
      price: 500,
      category: 'T-Shirts',
      imageUrl: 'https://example.com/thumbnail.png',
      frontImageUrl: 'https://example.com/front.png',
      backImageUrl: 'https://example.com/back.png',
      shirtColorHex: '#F2F2F2',
      color: Colors.white,
      impact: 'Ready for 3D try-on',
      description: 'A designer shirt.',
      frontPrintAdjustment: PrintFitAdjustment(
        scale: 1.4,
        offsetX: 0.1,
        offsetY: -0.2,
      ),
      backPrintAdjustment: PrintFitAdjustment(
        scale: 0.8,
        offsetX: -0.1,
        offsetY: 0.15,
      ),
    );
    final uri = Uri.parse(tryOnPageUrlFor(adjustedGarment, TryOnMode.viewer3d));

    expect(uri.queryParameters['frontScale'], '1.4');
    expect(uri.queryParameters['frontOffsetX'], '0.1');
    expect(uri.queryParameters['frontOffsetY'], '-0.2');
    expect(uri.queryParameters['backScale'], '0.8');
    expect(uri.queryParameters['backOffsetX'], '-0.1');
    expect(uri.queryParameters['backOffsetY'], '0.15');
  });

  test('live preview update serializes fit and shirt colour changes', () {
    final script = tryOnDesignMessage(
      source: Uri.parse(
        tryOnPageUrl(
          mode: TryOnMode.viewer3d,
          frontImageUrl: 'https://example.com/front.png',
          backImageUrl: 'https://example.com/back.png',
        ),
      ),
      shirtColorHex: '#123ABC',
      frontAdjustment: const PrintFitAdjustment(
        scale: 1.5,
        offsetX: 0.2,
        offsetY: -0.1,
      ),
      backAdjustment: const PrintFitAdjustment(),
    );

    expect(script, contains('"type":"closetx:design"'));
    expect(script, contains('"color":"#123ABC"'));
    expect(script, contains('"front":"https://example.com/front.png"'));
    expect(script, contains('"scale":1.5'));
    expect(script, contains('"offsetY":-0.1'));
    expect(script, contains('window.location.origin'));
  });
}
