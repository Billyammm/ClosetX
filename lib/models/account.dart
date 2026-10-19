import 'garment.dart';

enum AccountRole {
  shopper,
  designer;

  static AccountRole parse(Object? value) =>
      value == 'designer' ? AccountRole.designer : AccountRole.shopper;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.designerStatus,
    this.designerRejectionReason,
  });

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
    id: row['id'] as String,
    email: (row['email'] as String?) ?? '',
    fullName: (row['full_name'] as String?) ?? '',
    role: AccountRole.parse(row['role']),
    designerStatus: (row['designer_status'] as String?) ?? 'approved',
    designerRejectionReason: row['designer_rejection_reason'] as String?,
  );

  final String id;
  final String email;
  final String fullName;
  final AccountRole role;
  final String designerStatus;
  final String? designerRejectionReason;

  bool get isDesigner => role == AccountRole.designer;
  bool get isApprovedDesigner => isDesigner && designerStatus == 'approved';
  String get displayName => fullName.trim().isEmpty ? email : fullName;
}

class DesignerNotification {
  const DesignerNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.status,
    this.rejectionReason,
    this.designTitle,
  });

  factory DesignerNotification.fromRow(Map<String, dynamic> row) =>
      DesignerNotification(
        id: row['id'] as String,
        type: row['notification_type'] as String,
        status: row['status'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        isRead: row['is_read'] as bool? ?? false,
        rejectionReason: row['rejection_reason'] as String?,
        designTitle: row['design_title'] as String?,
      );

  final String id;
  final String type;
  final String? status;
  final DateTime createdAt;
  final bool isRead;
  final String? rejectionReason;
  final String? designTitle;

  bool get isDesignSaved => type == 'design_saved';
  bool get isAccepted => status == 'approved';
}

class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.bio,
    required this.location,
    this.logoUrl,
    this.logoPath,
  });

  factory Brand.fromRow(Map<String, dynamic> row) => Brand(
    id: row['id'] as String,
    name: (row['name'] as String?) ?? '',
    bio: (row['bio'] as String?) ?? '',
    location: (row['location'] as String?) ?? '',
    logoUrl: row['logo_url'] as String?,
    logoPath: row['logo_path'] as String?,
  );

  final String id;
  final String name;
  final String bio;
  final String location;
  final String? logoUrl;
  final String? logoPath;

  bool get hasLogo => logoUrl?.isNotEmpty ?? false;
}

/// A design owned by the signed-in designer, with the storage paths needed
/// to clean up its artwork.
class DesignerDesign {
  const DesignerDesign({
    required this.id,
    required this.garment,
    required this.isPublished,
    required this.reviewStatus,
    this.rejectionReason,
    required this.saveCount,
    required this.imagePaths,
  });

  final String id;
  final Garment garment;
  final bool isPublished;
  final String reviewStatus;
  final String? rejectionReason;
  final int saveCount;
  final List<String> imagePaths;
}
