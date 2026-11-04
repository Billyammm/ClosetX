import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/app_update_service.dart';
import 'supabase/supabase_config.dart';

export 'app.dart' show ClosetXApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  await AppUpdateService.initialize();
  unawaited(AppUpdateService.checkAndNotify());
  runApp(const ClosetXApp());
}
