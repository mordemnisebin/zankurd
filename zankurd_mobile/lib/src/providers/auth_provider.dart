import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/xp_store.dart';
import '../data/streak_store.dart';
import '../data/mistake_store.dart';
import '../data/seen_question_store.dart';
import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../data/daily_mission_store.dart';
import '../data/sync_manager.dart';
import '../utils/error_reporter.dart';

/// Supabase tabanlı kimlik sağlayıcı.
///
/// Giriş yapan kullanıcı ile skor/profil verisinin yazıldığı Supabase
/// kimliği aynıdır; böylece liderlik/coin ilerlemesi hesaba bağlanır.
/// Misafir modu Supabase anonim oturumu kullanır ve daha sonra e-posta
/// ile kalıcı hesaba yükseltilebilir.
class AuthProvider extends ChangeNotifier {
  static String get authRedirectUri =>
      kIsWeb ? 'https://www.zankurd.com/' : 'com.zankurd.app://login-callback/';

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
      _errorMessage = _translateUnexpectedError(e);
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
        emailRedirectTo: authRedirectUri,
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
        redirectTo: authRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Google girişi başlatılamadı.');
      }
    });
  }

  Future<bool> resetPassword(String email) {
    return _run(
      (client) =>
          client.auth.resetPasswordForEmail(email, redirectTo: authRedirectUri),
    );
  }

  Future<void> signOut() async {
    try {
      final xpStore = await XPStore.load();
      await xpStore.clear();
      XPStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'XPStore clear on signOut failed');
    }

    try {
      final streakStore = await StreakStore.load();
      await streakStore.clear();
      StreakStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'StreakStore clear on signOut failed');
    }

    try {
      final mistakeStore = await MistakeStore.load();
      await mistakeStore.clear();
      MistakeStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'MistakeStore clear on signOut failed');
    }

    try {
      final seenStore = await SeenQuestionStore.load();
      await seenStore.clear();
      SeenQuestionStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'SeenQuestionStore clear on signOut failed');
    }

    try {
      final achievementStore = await AchievementStore.load();
      await achievementStore.clear();
      AchievementStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'AchievementStore clear on signOut failed');
    }

    try {
      final masteryStore = await MasteryStore.load();
      await masteryStore.clear();
      MasteryStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'MasteryStore clear on signOut failed');
    }

    try {
      final missionStore = await DailyMissionStore.load();
      await missionStore.clear();
      DailyMissionStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'DailyMissionStore clear on signOut failed');
    }

    try {
      await SyncManager.instance.clearQueue();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'SyncManager clear on signOut failed');
    }

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

  @visibleForTesting
  String debugTranslateAuthError(AuthException e) => _translateError(e);

  @visibleForTesting
  String debugTranslateUnexpectedAuthError(Object error) =>
      _translateUnexpectedError(error);

  String _translateUnexpectedError(Object error) {
    final message = error.toString().toLowerCase();
    if (_isNetworkErrorMessage(message)) {
      return 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.';
    }
    return 'Beklenmeyen bir hata oluştu.';
  }

  String _translateError(AuthException e) {
    final message = e.message.toLowerCase();
    if (_isNetworkErrorMessage(message)) {
      return 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.';
    }
    if (message.contains('unsupported provider') ||
        message.contains('provider is not enabled')) {
      return 'Google girişi şu anda etkin değil. Supabase panelinde Google sağlayıcısını aç.';
    }
    if (message.contains('validation_failed') ||
        message.contains('redirect') ||
        message.contains('uri')) {
      return 'Giriş bağlantısı doğrulanamadı. Uygulama yönlendirme ayarlarını kontrol et.';
    }
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

  bool _isNetworkErrorMessage(String message) {
    return message.contains('failed host lookup') ||
        message.contains('name_not_resolved') ||
        message.contains('err_name_not_resolved') ||
        message.contains('failed to fetch') ||
        message.contains('network') ||
        message.contains('socket') ||
        message.contains('clientexception') ||
        message.contains('xmlhttprequest');
  }
}
