import 'package:flutter/material.dart';

import '../models/garment.dart';
import '../supabase/supabase_config.dart';

class SupabaseDesignRepository {
  Future<List<Garment>> loadApprovedDesigns() async {
    final client = supabaseClient;
    if (client == null) {
      throw StateError('Supabase has not been configured.');
    }

    final rows = await client
        .from('designs')
        .select(
          'id, designer_id, title, description, front_image_url, back_image_url, price, category, status, lens_id, lens_group_id',
        )
        .eq('status', 'approved')
        .order('created_at', ascending: false);

    return rows
        .map((row) {
          final rawPrice = row['price'];
          final parsedPrice = rawPrice is num
              ? rawPrice.round()
              : int.tryParse('$rawPrice');
          if (parsedPrice == null || parsedPrice < 0) {
            throw FormatException(
              'Approved design ${row['id']} has an invalid price.',
            );
          }

          final lensId = _optionalString(row['lens_id']);
          final lensGroupId = _optionalString(row['lens_group_id']);
          return Garment(
            id: 'supabase:${row['id']}',
            name: _requiredString(row, 'title'),
            designer: 'ClosetX Designer',
            price: parsedPrice,
            category: _optionalString(row['category']) ?? 'Designs',
            imageUrl: _requiredString(row, 'front_image_url'),
            color: const Color(0xFFE8E2D8),
            impact: lensId == null && lensGroupId == null
                ? 'Approved design'
                : 'Lens Studio ready',
            description:
                _optionalString(row['description']) ??
                'An approved design from the ClosetX community.',
            backImageUrl: _optionalString(row['back_image_url']),
            lensId: lensId,
            lensGroupId: lensGroupId,
          );
        })
        .toList(growable: false);
  }

  String _requiredString(Map<String, dynamic> row, String key) {
    final value = _optionalString(row[key]);
    if (value == null) {
      throw FormatException('Approved design ${row['id']} is missing "$key".');
    }
    return value;
  }

  String? _optionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
