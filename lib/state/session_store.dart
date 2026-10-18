import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/closetx_repository.dart';
import '../models/account.dart';
import '../supabase/supabase_config.dart';

/// Result of a sign-up: either signed straight in, or waiting on the
/// confirmation email (when the Supabase project requires it).
enum SignUpOutcome { signedIn, confirmEmail }

class SessionStore extends ChangeNotifier {
  SessionStore({ClosetXRepository? repository})
    : _repository = repository ?? ClosetXRepository() {
    final client = supabaseClient;
    if (client == null) return;
    _authSubscription = client.auth.onAuthStateChange.listen(
      (state) => _syncUser(state.session?.user),
    );
    _syncUser(client.auth.currentUser);
  }

  final ClosetXRepository _repository;
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;
  UserProfile? _profile;
  Brand? _brand;
  bool _isLoading = false;
  Object? _loadError;

  bool get isSignedIn => _userId != null;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  String? get userId => _userId;
  UserProfile? get profile => _profile;
  Brand? get brand => _brand;
  bool get isDesigner => _profile?.isApprovedDesigner ?? false;
  bool get isShopper => _profile?.role == AccountRole.shopper;

  Future<void> ensureProfileLoaded() async {
    if (_userId != null && _profile == null) await refresh();
  }

  Future<void> _syncUser(User? user) async {
    if (user?.id == _userId) return;
    _userId = user?.id;
    _profile = null;
    _brand = null;
    notifyListeners();
    if (user != null) await refresh();
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final profile = await _repository.loadProfile(userId);
      final brand = profile?.isApprovedDesigner == true
          ? await _repository.loadBrandFor(userId)
          : null;
      if (userId != _userId) return;
      _profile = profile;
      _brand = brand;
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  SupabaseClient get _client {
    final client = supabaseClient;
    if (client == null) {
      throw const AuthException(
        'Sign-in needs a Supabase project. Add your project URL and key to supabase.env.json.',
      );
    }
    return client;
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await _syncUser(response.user);
    await ensureProfileLoaded();
  }

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required AccountRole role,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role.name},
      // Send the confirmation link back to this web app.
      emailRedirectTo: kIsWeb ? Uri.base.origin : null,
    );
    if (response.session == null) return SignUpOutcome.confirmEmail;
    await _syncUser(response.user);
    await ensureProfileLoaded();
    return SignUpOutcome.signedIn;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _syncUser(null);
  }

  Future<void> saveBrand({
    required String name,
    required String bio,
    required String location,
    DesignImage? logo,
  }) async {
    final userId = _userId;
    if (userId == null) throw const AuthException('Sign in first.');
    _brand = await _repository.saveBrand(
      userId: userId,
      existing: _brand,
      name: name,
      bio: bio,
      location: location,
      logo: logo,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<SessionStore> {
  const SessionScope({
    required SessionStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static SessionStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope is missing above this context.');
    return scope!.notifier!;
  }
}
