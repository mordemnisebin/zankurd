import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_reporter.dart';

/// Supabase tabanlı kimlik sağlayıcı.
///
/// Giriş yapan kullanıcı ile skor/profil verisinin yazıldığı Supabase
/// kimliği aynıdır; böylece liderlik/coin ilerlemesi hesaba bağlanır.
/// Misafir modu Supabase anonim oturumu kullanır ve daha sonra e-posta
/// ile kalıcı hesaba yükseltilebilir.
class AuthProvider extends ChangeNotifier {
  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSub;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;
  bool _mockAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailConfirmation => _needsEmailConfirmation;

  /// Misafir (anonim) oturum da kimlikli sayılır.
  /// Supabase yapılandırması yoksa test/mock kapısı yine kullanıcı seçimini bekler.
  bool get isAuthenticated =>
      _client == null ? _mockAuthenticated : _currentUser != null;

  bool get isGuest => _currentUser?.isAnonymous ?? false;

  AuthProvider(SupabaseClient client) : _client = client {
    _currentUser = client.auth.currentUser;
    _authSub = client.auth.onAuthStateChange.listen((state) {
      _currentUser = state.session?.user;
      notifyListeners();
    });
  }

  /// Test/mock constructor — Supabase başlatılmadan kullanım için.
  AuthProvider.test({bool authenticated = false})
    : _client = null,
      _mockAuthenticated = authenticated;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function(SupabaseClient auth) body) async {
    final client = _client;
    if (client == null) return true;

    _isLoading = true;
    _errorMessage = null;
    _needsEmailConfirmation = false;
    notifyListeners();

    try {
      await body(client);
      _currentUser = client.auth.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _translateError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Beklenmeyen bir hata oluştu.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _run((client) async {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      // E-posta doğrulaması açıksa oturum hemen başlamaz.
      _needsEmailConfirmation =
          response.session == null && response.user != null;
    });
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _run(
      (client) =>
          client.auth.signInWithPassword(email: email, password: password),
    );
  }

  /// Misafir olarak devam et — anonim Supabase oturumu.
  Future<bool> signInAsGuest() {
    if (_client == null) {
      _mockAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return Future.value(true);
    }
    return _run((client) async {
      if (client.auth.currentSession != null) return;
      await client.auth.signInAnonymously();
    });
  }

  /// Google ile giriş, Supabase OAuth üzerinden tarayıcı açar.
  /// Çalışması için Supabase Dashboard'da Google sağlayıcısının
  /// yapılandırılmış olması gerekir.
  Future<bool> signInWithGoogle() {
    return _run((client) async {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Google girişi başlatılamadı.');
      }
    });
  }

  Future<bool> resetPassword(String email) {
    return _run((client) => client.auth.resetPasswordForEmail(email));
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) {
      _mockAuthenticated = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    try {
      await client.auth.signOut();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'signOut failed');
    }
    _currentUser = client.auth.currentUser;
    _errorMessage = null;
    notifyListeners();
  }

  String _translateError(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'E-posta veya parola hatalı.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'Bu e-posta zaten kullanılıyor.';
    }
    if (message.contains('password should be')) {
      return 'Parola çok zayıf (en az 6 karakter).';
    }
    if (message.contains('invalid email') ||
        message.contains('unable to validate email')) {
      return 'Geçersiz e-posta adresi.';
    }
    if (message.contains('email not confirmed')) {
      return 'E-posta adresin henüz doğrulanmamış. Gelen kutunu kontrol et.';
    }
    if (message.contains('rate limit')) {
      return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.';
    }
    if (message.contains('anonymous')) {
      return 'Misafir girişi şu anda kapalı.';
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
