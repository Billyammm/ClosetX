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
    this.lensId,
    this.lensGroupId,
  });

  final String id;
  final String name;
  final String designer;
  final int price;
  final String category;
  final String imageUrl;
  final Color color;
  final String impact;
  final String description;
  final String? backImageUrl;
  final String? lensId;
  final String? lensGroupId;

  String get formattedPrice => formatPeso(price);
}

String formatPeso(int amount) {
  return '₱${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
}
