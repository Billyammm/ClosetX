import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

import '../models/garment.dart';

class CameraKitService {
  static const _channel = MethodChannel('com.closetx/camera_kit');

  Future<void> launchLens(Garment garment) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw PlatformException(
        code: 'CAMERA_KIT_UNSUPPORTED_PLATFORM',
        message: 'ClosetX AR try-on is currently available on Android.',
      );
    }

    final lensId = garment.lensId;
    final lensGroupId = garment.lensGroupId;
    if (lensId == null || lensGroupId == null) {
      throw PlatformException(
        code: 'MISSING_LENS_METADATA',
        message: 'This design does not have a Lens ID and Lens Group ID yet.',
      );
    }

    await _channel.invokeMethod<void>('launchLens', {
      'lensId': lensId,
      'lensGroupId': lensGroupId,
    });
  }
}
