import 'package:supabase_flutter/supabase_flutter.dart';

const _projectUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://pdeywqyobsefgwycevwf.supabase.co',
);
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseConfigured => _anonKey.trim().isNotEmpty;

Future<void> initializeSupabase() async {
  if (!isSupabaseConfigured) return;

  await Supabase.initialize(url: _projectUrl, publishableKey: _anonKey);
}

SupabaseClient? get supabaseClient =>
    isSupabaseConfigured ? Supabase.instance.client : null;
