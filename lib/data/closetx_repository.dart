import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/garment.dart';
import '../supabase/supabase_config.dart';

/// Picked artwork ready to upload.
class DesignImage {
  const DesignImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  String get extension => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}

class NewDesign {
  const NewDesign({
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.shirtColorHex,
    required this.thumbnail,
    required this.front,
    required this.back,
  });

  final String title;
  final String description;
  final int price;
  final String category;
  final String shirtColorHex;

  /// Product photo shoppers see in the featured list.
  final DesignImage thumbnail;
  final DesignImage front;
  final DesignImage back;
}

class ClosetXRepository {
  static const _designColumns =
      'id, designer_id, title, description, price, category, shirt_color, '
      'thumbnail_url, thumbnail_path, front_image_url, back_image_url, '
      'front_image_path, back_image_path, is_published, brands(name, logo_url)';
  static const _brandColumns = 'id, name, bio, location, logo_url, logo_path';

  SupabaseClient get _client {
    final client = supabaseClient;
    if (client == null) {
      throw StateError('Supabase has not been configured.');
    }
    return client;
  }

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  Future<List<Garment>> loadPublishedDesigns() async {
    final rows = await _client
        .from('designs')
        .select(_designColumns)
        .eq('is_published', true)
        .order('created_at', ascending: false);
    final saveCounts = await _client.rpc('get_published_design_save_counts');
    final saveCountsByDesign = {
      for (final row in (saveCounts as List).cast<Map<String, dynamic>>())
        row['design_id'] as String: (row['save_count'] as num).toInt(),
    };
    return rows
        .map(
          (row) => _garmentFromRow(
            row,
            saveCount: saveCountsByDesign[row['id'] as String] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<DesignerDesign>> loadMyDesigns(String userId) async {
    final saveCounts = await loadDesignSaveCounts();
    final saveCountsByDesign = {
      for (final row in saveCounts)
        row['design_id'] as String: (row['save_count'] as num).toInt(),
    };
    final rows = await _client
        .from('designs')
        .select(_designColumns)
        .eq('designer_id', userId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => DesignerDesign(
            id: row['id'] as String,
            garment: _garmentFromRow(row),
            isPublished: row['is_published'] == true,
            reviewStatus: (row['review_status'] as String?) ?? 'approved',
            rejectionReason: row['rejection_reason'] as String?,
            saveCount: saveCountsByDesign[row['id'] as String] ?? 0,
            imagePaths: [
              row['thumbnail_path'] as String?,
              row['front_image_path'] as String?,
              row['back_image_path'] as String?,
            ].nonNulls.toList(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadDesignSaveCounts() async {
    final rows = await _client.rpc('get_design_save_counts');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Set<String>> loadSavedDesignIds(String shopperId) async {
    final rows = await _client
        .from('saved_designs')
        .select('design_id')
        .eq('shopper_id', shopperId);
    return rows.map((row) => row['design_id'] as String).toSet();
  }

  Future<void> setDesignSaved({
    required String shopperId,
    required String designId,
    required bool isSaved,
  }) async {
    if (isSaved) {
      await _client.from('saved_designs').insert({
        'shopper_id': shopperId,
        'design_id': designId,
      });
    } else {
      await _client
          .from('saved_designs')
          .delete()
          .eq('shopper_id', shopperId)
          .eq('design_id', designId);
    }
  }

  Garment _garmentFromRow(Map<String, dynamic> row, {int saveCount = 0}) {
    final rawPrice = row['price'];
    final price = rawPrice is num
        ? rawPrice.round()
        : int.tryParse('$rawPrice');
    if (price == null || price < 0) {
      throw FormatException('Design ${row['id']} has an invalid price.');
    }
    final brand = row['brands'];
    final brandName = brand is Map ? _optionalString(brand['name']) : null;
    final brandLogoUrl = brand is Map
        ? _optionalString(brand['logo_url'])
        : null;
    final frontImageUrl = _requiredString(row, 'front_image_url');
    final shirtColorHex = _optionalString(row['shirt_color']) ?? '#F2F2F2';

    return Garment(
      id: 'supabase:${row['id']}',
      name: _requiredString(row, 'title'),
      designer: brandName ?? 'ClosetX Designer',
      designerLogoUrl: brandLogoUrl,
      price: price,
      category: _optionalString(row['category']) ?? 'T-Shirts',
      imageUrl: _optionalString(row['thumbnail_url']) ?? frontImageUrl,
      frontImageUrl: frontImageUrl,
      backImageUrl: _optionalString(row['back_image_url']),
      color: _colorFromHex(shirtColorHex),
      shirtColorHex: shirtColorHex,
      impact: 'Ready for 3D try-on',
      description:
          _optionalString(row['description']) ??
          'A design from the ClosetX community.',
      saveCount: saveCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Accounts
  // ---------------------------------------------------------------------------

  Future<UserProfile?> loadProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select(
          'id, email, full_name, role, designer_status, '
          'designer_rejection_reason',
        )
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromRow(row);
  }

  Future<Brand?> loadBrandFor(String userId) async {
    final row = await _client
        .from('brands')
        .select(_brandColumns)
        .eq('owner_id', userId)
        .maybeSingle();
    return row == null ? null : Brand.fromRow(row);
  }

  /// Creates or updates the designer's brand. A new [logo] replaces the
  /// previous one, which is then removed from storage.
  Future<Brand> saveBrand({
    required String userId,
    Brand? existing,
    required String name,
    required String bio,
    required String location,
    DesignImage? logo,
  }) async {
    final storage = _client.storage.from(designImagesBucket);
    final values = <String, Object?>{
      'name': name,
      'bio': bio,
      'location': location,
    };
    String? logoPath;
    if (logo != null) {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      logoPath = '$userId/brand-logo-$stamp.${logo.extension}';
      await storage.uploadBinary(
        logoPath,
        logo.bytes,
        fileOptions: FileOptions(contentType: logo.mimeType),
      );
      values['logo_url'] = storage.getPublicUrl(logoPath);
      values['logo_path'] = logoPath;
    }

    try {
      final query = existing == null
          ? _client.from('brands').insert({...values, 'owner_id': userId})
          : _client.from('brands').update(values).eq('id', existing.id);
      final row = await query.select(_brandColumns).single();
      final oldLogoPath = existing?.logoPath;
      if (logoPath != null && oldLogoPath != null && oldLogoPath != logoPath) {
        await storage.remove([oldLogoPath]).catchError((_) => <FileObject>[]);
      }
      return Brand.fromRow(row);
    } catch (_) {
      if (logoPath != null) {
        await storage.remove([logoPath]).catchError((_) => <FileObject>[]);
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Design uploads
  // ---------------------------------------------------------------------------

  Future<void> createDesign({
    required String userId,
    required Brand brand,
    required NewDesign design,
  }) async {
    final storage = _client.storage.from(designImagesBucket);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final thumbnailPath =
        '$userId/$stamp-thumbnail.${design.thumbnail.extension}';
    final frontPath = '$userId/$stamp-front.${design.front.extension}';
    final backPath = '$userId/$stamp-back.${design.back.extension}';
    final uploaded = <String>[];

    try {
      for (final (path, image) in [
        (thumbnailPath, design.thumbnail),
        (frontPath, design.front),
        (backPath, design.back),
      ]) {
        await storage.uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(contentType: image.mimeType),
        );
        uploaded.add(path);
      }

      await _client.from('designs').insert({
        'brand_id': brand.id,
        'designer_id': userId,
        'title': design.title,
        'description': design.description,
        'price': design.price,
        'category': design.category,
        'shirt_color': design.shirtColorHex,
        'thumbnail_url': storage.getPublicUrl(thumbnailPath),
        'thumbnail_path': thumbnailPath,
        'front_image_url': storage.getPublicUrl(frontPath),
        'back_image_url': storage.getPublicUrl(backPath),
        'front_image_path': frontPath,
        'back_image_path': backPath,
      });
    } catch (_) {
      if (uploaded.isNotEmpty) {
        await storage.remove(uploaded).catchError((_) => <FileObject>[]);
      }
      rethrow;
    }
  }

  Future<void> setPublished(String designId, bool isPublished) async {
    await _client
        .from('designs')
        .update({'is_published': isPublished})
        .eq('id', designId);
  }

  Future<void> submitFeedback({
    required String authorName,
    required String authorEmail,
    required String message,
    required int rating,
  }) async {
    final user = supabaseClient?.auth.currentUser;
    await _client.from('feedback').insert({
      'user_id': user?.id,
      'author_name': authorName.trim(),
      'author_email': authorEmail.trim(),
      'message': message.trim(),
      'rating': rating,
    });
  }

  Future<void> deleteDesign(DesignerDesign design) async {
    await _client.from('designs').delete().eq('id', design.id);
    await _client.storage
        .from(designImagesBucket)
        .remove(design.imagePaths)
        .catchError((_) => <FileObject>[]);
  }

  // ---------------------------------------------------------------------------

  String _requiredString(Map<String, dynamic> row, String key) {
    final value = _optionalString(row[key]);
    if (value == null) {
      throw FormatException('Design ${row['id']} is missing "$key".');
    }
    return value;
  }

  String? _optionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

Color _colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? const Color(0xFFE8E2D8) : Color(0xFF000000 | value);
}
