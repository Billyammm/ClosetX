import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/closetx_repository.dart';
import '../models/account.dart';
import '../supabase/supabase_config.dart';

/// Result of a sign-up: either signed straight in, or waiting on the
/// confirmation email (when the Supabase project requires it).
enum SignUpOutcome { signedIn, confirmEmail }

class LoginFailure implements Exception {
  const LoginFailure({required this.status, required this.body});

  final int status;
  final Map<String, dynamic> body;

  bool get adminLocked => body['adminLocked'] == true;

  int get remainingSeconds {
    final value = body['remainingSeconds'];
    return value is int
        ? value
        : value is num
        ? value.toInt()
        : 0;
  }

  int get attemptsLeft {
    final value = body['attemptsLeft'];
    return value is int
        ? value
        : value is num
        ? value.toInt()
        : 0;
  }

  int get nextLockSeconds {
    final value = body['nextLockSeconds'];
    return value is int
        ? value
        : value is num
        ? value.toInt()
        : 30;
  }

  int get lockoutStage {
    final value = body['stage'];
    return value is int
        ? value
        : value is num
        ? value.toInt()
        : 0;
  }
}

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
  bool _needsGoogleRoleSelection = false;

  bool get isSignedIn => _userId != null;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  String? get userId => _userId;
  UserProfile? get profile => _profile;
  Brand? get brand => _brand;
  bool get isDesigner => _profile?.isApprovedDesigner ?? false;
  bool get isShopper => _profile?.role == AccountRole.shopper;
  bool get needsGoogleRoleSelection => _needsGoogleRoleSelection;

  Future<void> ensureProfileLoaded() async {
    if (_userId != null && _profile == null) await refresh();
  }

  Future<void> _syncUser(User? user) async {
    if (user?.id == _userId) return;
    _userId = user?.id;
    _needsGoogleRoleSelection =
        user != null &&
        (user.appMetadata['provider'] == 'google' ||
            user.identities?.any((identity) => identity.provider == 'google') ==
                true) &&
        user.userMetadata?['closetx_role_initialized'] != true;
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
        'Supabase configuration is missing. Build with '
        '--dart-define-from-file=supabase.env.json before installing.',
      );
    }
    return client;
  }

  Future<void> signIn({required String email, required String password}) async {
    dynamic response;
    try {
      response = await _client.functions.invoke(
        'login-with-lockout',
        body: {'email': email, 'password': password},
      );
    } catch (error) {
      final dynamic exception = error;
      final dynamic statusValue = exception.status ?? exception.statusCode;
      final int status = statusValue is int
          ? statusValue
          : statusValue is num
          ? statusValue.toInt()
          : 0;
      final details = exception.details;
      final context = exception.context;
      Map<String, dynamic> body = const {};
      if (details is Map) {
        body = Map<String, dynamic>.from(details);
      } else if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) body = Map<String, dynamic>.from(decoded);
          if (decoded is String) body = {'error': decoded};
        } catch (_) {
          if (details.trim().isNotEmpty) {
            body = {'error': details.trim()};
          }
        }
        if (body.isEmpty && details.trim().isNotEmpty) {
          body = {'error': details.trim()};
        }
      }
      if (body.isEmpty && context is Map) {
        body = Map<String, dynamic>.from(context);
      }
      if (body.isEmpty && exception.reasonPhrase is String) {
        final reasonPhrase = exception.reasonPhrase as String;
        if (reasonPhrase.trim().isNotEmpty) {
          body = {'error': reasonPhrase.trim()};
        }
      }
      throw LoginFailure(status: status, body: body);
    }

    if (response.status < 200 || response.status >= 300) {
      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      throw LoginFailure(status: response.status as int, body: body);
    }
    final body = response.data is Map ? response.data as Map : const {};
    final accessToken = body['accessToken'];
    final refreshToken = body['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const AuthException('Invalid email or password');
    }
    await _client.auth.setSession(refreshToken);
    await _syncUser(_client.auth.currentUser);
    await ensureProfileLoaded();
  }

  Future<String> requestPasswordReset({required String email}) async {
    final response = await _client.functions.invoke(
      'password-security',
      body: {'action': 'forgot', 'email': email},
    );
    final body = response.data is Map ? response.data as Map : const {};
    if (response.status < 200 || response.status >= 300) {
      throw AuthException(
        body['error'] is String
            ? body['error'] as String
            : 'Could not process the password reset request.',
      );
    }
    return body['message'] is String
        ? body['message'] as String
        : 'If this account exists, a reset link has been sent';
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await _client.functions.invoke(
      'password-security',
      body: {
        'action': 'reset',
        'token': token,
        'password': password,
        'confirmPassword': password,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final body = response.data is Map ? response.data as Map : const {};
      throw AuthException(
        body['error'] is String
            ? body['error'] as String
            : 'Could not update the password.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'closetx://login-callback/',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> chooseGoogleRole(AccountRole role) async {
    if (!_needsGoogleRoleSelection || _userId == null) {
      throw const AuthException('This Google account has already been set up.');
    }
    if (role == AccountRole.designer) {
      await _client.rpc(
        'set_initial_google_role',
        params: {'new_role': role.name},
      );
    }
    await _client.auth.updateUser(
      UserAttributes(data: {'closetx_role_initialized': true}),
    );
    _needsGoogleRoleSelection = false;
    await refresh();
    notifyListeners();
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

  Future<void> signUpShopper({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.functions.invoke(
      'create-shopper-account',
      body: {'email': email, 'password': password, 'fullName': fullName},
    );
    if (response.status < 200 || response.status >= 300) {
      final error = response.data is Map ? response.data['error'] : null;
      throw AuthException(
        error is String && error.isNotEmpty
            ? error
            : 'Could not create the shopper account.',
      );
    }
    await signIn(email: email, password: password);
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
