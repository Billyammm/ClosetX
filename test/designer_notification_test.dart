import 'package:closetx/models/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a shopper save notification', () {
    final notification = DesignerNotification.fromRow({
      'id': 'notification-id',
      'notification_type': 'design_saved',
      'status': null,
      'rejection_reason': null,
      'design_title': 'Community shirt',
      'created_at': '2026-10-19T12:00:00Z',
      'is_read': false,
    });

    expect(notification.isDesignSaved, isTrue);
    expect(notification.isAccepted, isFalse);
    expect(notification.designTitle, 'Community shirt');
    expect(notification.isRead, isFalse);
  });

  test('parses a declined design review notification', () {
    final notification = DesignerNotification.fromRow({
      'id': 'review-notification-id',
      'notification_type': 'design_review_decision',
      'status': 'rejected',
      'rejection_reason': 'Please use original artwork.',
      'design_title': 'Community shirt',
      'created_at': '2026-10-19T12:00:00Z',
      'is_read': false,
    });

    expect(notification.isDesignReviewDecision, isTrue);
    expect(notification.isDesignSaved, isFalse);
    expect(notification.isAccepted, isFalse);
    expect(notification.rejectionReason, 'Please use original artwork.');
    expect(notification.designTitle, 'Community shirt');
  });
}
