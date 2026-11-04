import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static const _repository = 'Billyammm/ClosetX';
  static const _latestReleaseApi =
      'https://api.github.com/repos/$_repository/releases/latest';
  static const _notificationId = 1001;
  static const _lastNotifiedTagKey = 'last_update_notification_tag';

  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) async {
        final url = response.payload;
        if (url != null && url.isNotEmpty) {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        }
      },
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  static Future<void> checkAndNotify() async {
    if (kIsWeb) return;

    try {
      final package = await PackageInfo.fromPlatform();
      final response = await http
          .get(
            Uri.parse(_latestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'ClosetX-App',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final release = jsonDecode(response.body);
      if (release is! Map<String, dynamic>) return;
      final tag = release['tag_name'];
      final version = tag is String ? _versionFromTag(tag) : null;
      if (version == null || !_isNewer(version, package.version)) return;

      final assets = release['assets'];
      final apkUrl = assets is List
          ? assets
                .whereType<Map<String, dynamic>>()
                .map((asset) => asset['browser_download_url'])
                .whereType<String>()
                .firstWhere(
                  (url) => url.toLowerCase().endsWith('.apk'),
                  orElse: () => '',
                )
          : '';
      final downloadUrl = apkUrl.isNotEmpty
          ? apkUrl
          : release['html_url'] as String?;
      if (downloadUrl == null || downloadUrl.isEmpty) return;

      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString(_lastNotifiedTagKey) == tag) return;

      const androidDetails = AndroidNotificationDetails(
        'app_updates',
        'App updates',
        channelDescription: 'Notifications about new ClosetX releases',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      await _notifications.show(
        id: _notificationId,
        title: 'A new ClosetX update is available',
        body: 'Update now for the latest improvements and fixes.',
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: downloadUrl,
      );
      await preferences.setString(_lastNotifiedTagKey, tag);
    } on TimeoutException {
      return;
    } on http.ClientException {
      return;
    } on FormatException {
      return;
    } on StateError {
      return;
    }
  }

  static String? _versionFromTag(String tag) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(tag);
    return match == null ? null : '${match[1]}.${match[2]}.${match[3]}';
  }

  static bool _isNewer(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    for (var index = 0; index < 3; index++) {
      final latestPart = latestParts[index];
      final currentPart = index < currentParts.length
          ? currentParts[index]
          : 0;
      if (latestPart != currentPart) return latestPart > currentPart;
    }
    return false;
  }
}
