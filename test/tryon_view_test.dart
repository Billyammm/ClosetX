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
}
