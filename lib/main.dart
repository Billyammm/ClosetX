import 'package:flutter/material.dart';

import 'app.dart';
import 'supabase/supabase_config.dart';

export 'app.dart' show ClosetXApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  runApp(const ClosetXApp());
}
