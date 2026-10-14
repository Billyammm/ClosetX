import 'package:supabase_flutter/supabase_flutter.dart';

const _projectUrl = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Public storage bucket that holds designers' front/back artwork.
const designImagesBucket = 'design-images';

bool get isSupabaseConfigured =>
    _projectUrl.trim().isNotEmpty && _anonKey.trim().isNotEmpty;

Future<void> initializeSupabase() async {
  if (!isSupabaseConfigured) return;

  await Supabase.initialize(url: _projectUrl, publishableKey: _anonKey);
}

SupabaseClient? get supabaseClient =>
    isSupabaseConfigured ? Supabase.instance.client : null;
