import 'package:flutter/material.dart';

class PrintFitAdjustment {
  const PrintFitAdjustment({
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final double scale;
  final double offsetX;
  final double offsetY;
}

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
    this.saveCount = 0,
    this.ratingAverage = 0,
    this.backImageUrl,
    this.shirtColorHex,
    this.designerLogoUrl,
    this.designerId,
    this.frontImageUrl,
    this.frontPrintAdjustment = const PrintFitAdjustment(),
    this.backPrintAdjustment = const PrintFitAdjustment(),
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
  final int saveCount;
  final double ratingAverage;
  final String? backImageUrl;

  /// Fabric colour of the 3D shirt, as `#RRGGBB`.
  final String? shirtColorHex;

  /// The brand's logo, shown next to [designer].
  final String? designerLogoUrl;

  /// Supabase profile ID of the designer who uploaded this design.
  final String? designerId;

  /// Front artwork printed on the 3D shirt. Falls back to [imageUrl] for
  /// garments without separate artwork.
  final String? frontImageUrl;

  final PrintFitAdjustment frontPrintAdjustment;
  final PrintFitAdjustment backPrintAdjustment;

  String get frontArtworkUrl => frontImageUrl ?? imageUrl;

  String get formattedPrice => formatPeso(price);
}

class DesignReview {
  const DesignReview({
    required this.rating,
    required this.comment,
    required this.authorName,
    required this.createdAt,
    this.isMine = false,
  });

  final int rating;
  final String comment;
  final String authorName;
  final DateTime createdAt;
  final bool isMine;
}

String formatPeso(int amount) {
  return '₱${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
}
