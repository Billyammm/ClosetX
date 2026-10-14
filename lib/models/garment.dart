import 'package:flutter/material.dart';

class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.designer,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.color,
    required this.impact,
    required this.description,
    this.backImageUrl,
    this.shirtColorHex,
    this.designerLogoUrl,
    this.frontImageUrl,
  });

  final String id;
  final String name;
  final String designer;
  final int price;
  final String category;
  /// Product photo shown in lists and on the detail page.
  final String imageUrl;
  final Color color;
  final String impact;
  final String description;
  final String? backImageUrl;

  /// Fabric colour of the 3D shirt, as `#RRGGBB`.
  final String? shirtColorHex;

  /// The brand's logo, shown next to [designer].
  final String? designerLogoUrl;

  /// Front artwork printed on the 3D shirt. Falls back to [imageUrl] for
  /// garments without separate artwork.
  final String? frontImageUrl;

  String get frontArtworkUrl => frontImageUrl ?? imageUrl;

  String get formattedPrice => formatPeso(price);
}

String formatPeso(int amount) {
  return '₱${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
}
