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
}
