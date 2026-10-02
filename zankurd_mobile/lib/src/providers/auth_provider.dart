import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_progress_scope.dart';
import '../data/xp_store.dart';
import '../data/streak_store.dart';
import '../data/mistake_store.dart';
import '../data/seen_question_store.dart';
import '../data/achievement_store.dart';
import '../data/badge_service.dart';
import '../data/mastery_store.dart';
import '../data/daily_mission_store.dart';
import '../data/level_progress_store.dart';
import '../data/learning_goal_store.dart';
import '../data/placement_store.dart';
import '../data/quiz_result_progress_receipt_store.dart';
import '../data/story_progress_store.dart';
import '../data/sync_manager.dart';
import '../services/premium_service.dart';
import '../services/apple_revocation.dart';
import '../services/native_auth_service.dart';
import '../utils/error_reporter.dart';

class AccountLocalCleanupException implements Exception {
  const AccountLocalCleanupException();

  @override
  String toString() => 'AccountLocalCleanupException';
}

/// Supabase tabanlı kimlik sağlayıcı.
///
/// Giriş yapan kullanıcı ile skor/profil verisinin yazıldığı Supabase
/// kimliği aynıdır; böylece liderlik/coin ilerlemesi hesaba bağlanır.
/// Misafir modu Supabase anonim oturumu kullanır ve daha sonra e-posta
/// ile kalıcı hesaba yükseltilebilir.
class AuthProvider extends ChangeNotifier {
  static String get authRedirectUri =>
      kIsWeb ? 'https://www.zankurd.com/' : 'com.zankurd.app://login-callback/';

  /// Cihazın son sahibi olarak kaydedilen kullanıcı kimliği — bkz.
  /// [_resetLocalProgressIfForeignUser].
  static const _deviceOwnerUserIdKey = LocalProgressScope.ownerKey;

  // `final` değiller: boot'da çevrimdışı açılan sağlayıcı, sonradan
  // açılan Supabase'e [attachSupabase] ile bağlanır (bkz. servisler
  // altındaki `remote_upgrade.dart`).
  SupabaseClient? _client;
  NativeAuthService _nativeAuth;
  bool _offlineMode;
  StreamSubscription<AuthState>? _authSub;
  Future<void> _authTransition = Future<void>.value();
  int _authGeneration = 0;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;
  bool _needsPasswordRecovery = false;
  bool _mockAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailConfirmation => _needsEmailConfirmation;

  /// Kurtarma bağlantısıyla açılmış, parolası HENÜZ DEĞİŞMEMİŞ oturum.
  ///
  /// `resetPasswordForEmail` yalnız bir bağlantı yollar; bağlantıya
  /// dokunulduğunda Supabase normal bir oturum açar. Bu durum ayrı
  /// modellenmezse — ki 2026-08-06 denetimine kadar modellenmiyordu —
  /// kullanıcı doğrudan Home'a düşer ve parolası eski hâliyle kalır:
  /// "parolamı unuttum" hiçbir şeyi kurtarmaz, yalnız bir kerelik giriş
  /// yapar. `AppShell` bu bayrak açıkken parola ekranını gösterir.
  bool get needsPasswordRecovery => _needsPasswordRecovery;

  /// Misafir (anonim) oturum da kimlikli sayılır.
  /// Supabase yapılandırması yoksa test/mock kapısı yine kullanıcı seçimini bekler.
  bool get isAuthenticated =>
      _client == null ? _mockAuthenticated : _currentUser != null;

  bool get isGuest =>
      (_currentUser?.isAnonymous ?? false) ||
      (_offlineMode && _mockAuthenticated);

  /// Uzak kimlik servisi başlatılamadığı için yerel misafir modunda mı?
  bool get isOfflineMode => _offlineMode;

  /// Sunucuda kalıcı yazım gerektiren eylemler bu oturumda kullanılabilir mi?
  bool get canUseRemoteActions => !_offlineMode;

  AuthProvider(SupabaseClient client, {NativeAuthService? nativeAuth})
    : _client = client,
      _offlineMode = false,
      _nativeAuth =
          nativeAuth ?? PlatformNativeAuthService(supabaseClient: client) {
    _wireAuth(client);
  }

  /// Boot'da çevrimdışı açılmış sağlayıcıyı sonradan açılan Supabase'e
  /// bağlar.
  ///
  /// ## Niçin ayrı bir kapı
  ///
  /// Kurtarma daha önce `AuthProvider(Supabase.instance.client)` ile
  /// SIFIRDAN bir sağlayıcı kuruyordu. Bu iki sonuç doğuruyordu:
  ///
  /// 1. Çevrimdışı misafir (`_mockAuthenticated`) külüne düşüyor ve
  ///    arayüz oturumu kaybediliyordu.
  /// 2. Supabase deposu ilk kullanımda `signInAnonymously` ile YENİ bir
  ///    anonim oturum açabiliyordu — misafirin yerel ilerlemesi başka
  ///    bir kimliğe taşınıyordu.
  ///
  /// Burada yalnız cihazda ZATEN kayıtlı bir oturum varsa bağlanır.
  /// Oturum yoksa hiçbir şey değişmez ve `false` döner: kurtarma
  /// vazgeçer, çevrimdışı oturum aynen sürer, `SharedPreferences`
  /// dokunulmaz.
  ///
  /// Bağlama [AuthProvider] kurucusuyla AYNI işi yapar: mevcut kullanıcı
  /// okunur, premium kimliği eşlenir ve auth olayları dinlenmeye başlar.
  Future<bool> attachSupabase(SupabaseClient client) async {
    final existing = _client;
    if (existing != null) return identical(existing, client);
    if (client.auth.currentSession == null) return false;
    _client = client;
    _offlineMode = false;
    _nativeAuth = PlatformNativeAuthService(supabaseClient: client);
    _wireAuth(client);
    notifyListeners();
    return true;
  }

  /// Mevcut oturumu okur ve auth olaylarını dinlemeye başlar.
  void _wireAuth(SupabaseClient client) {
    _currentUser = client.auth.currentUser;
    unawaited(_syncPremiumIdentity(_currentUser));
    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((state) {
      final next = state.session?.user;
      final changed = next?.id != _currentUser?.id;
      _currentUser = next;
      applyAuthEvent(state.event, hasSession: next != null);
      unawaited(
        _queueSessionPreparation(
          next,
          restartSync: changed,
          syncPremiumIdentity: changed,
          notifyWhenReady: true,
        ),
      );
    });
  }

  bool _isCurrentAuthGeneration(int generation, String? userId) =>
      generation == _authGeneration && _currentUser?.id == userId;

  Future<void> _queueSessionPreparation(
    User? user, {
    required bool restartSync,
    required bool syncPremiumIdentity,
    bool notifyWhenReady = false,
  }) {
    final generation = ++_authGeneration;
    final userId = user?.id;
    final transition = _authTransition.then((_) async {
      if (!_isCurrentAuthGeneration(generation, userId)) return;
      if (user == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (!_isCurrentAuthGeneration(generation, null)) return;
          await LocalProgressScope.activateOffline(prefs);
          if (!_isCurrentAuthGeneration(generation, null)) return;
          _dropProgressMemory();
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'signed-out local progress scope',
          );
        }
      } else {
        await _handleSessionUser(
          user,
          restartSync: restartSync,
          generation: generation,
        );
      }
      if (syncPremiumIdentity && _isCurrentAuthGeneration(generation, userId)) {
        await _syncPremiumIdentity(user);
      }
    });
    _authTransition = transition.catchError((Object error, StackTrace stack) {
      ErrorReporter.record(error, stack, reason: 'auth session transition');
    });
    final settled = _authTransition;
    if (notifyWhenReady) {
      unawaited(
        settled.then((_) {
          if (_isCurrentAuthGeneration(generation, userId)) notifyListeners();
        }),
      );
    }
    return settled;
  }

  Future<void> _handleSessionUser(
    User user, {
    required bool restartSync,
    required int generation,
  }) async {
    if (!_isCurrentAuthGeneration(generation, user.id)) return;
    var localProgressReady = true;
    try {
      localProgressReady = await _resetLocalProgressIfForeignUser(user);
    } catch (e, s) {
      localProgressReady = false;
      ErrorReporter.record(e, s, reason: 'foreign user progress guard');
    }
    if (!_isCurrentAuthGeneration(generation, user.id)) return;
    // `signOut()` SyncManager'ı kapatıyor; yeni bir oturum açıldığında onu
    // geri kuran hiçbir yer yoktu. Aynı oturumda çıkıp tekrar giren
    // kullanıcıda çevrimdışı ödül kuyruğu ölü kalıyor ve `instance` getter'ı
    // `StateError` fırlatıyordu (2026-07-31 denetimi).
    if (restartSync && localProgressReady) {
      try {
        await SyncManager.restart();
      } catch (e, s) {
        ErrorReporter.record(e, s, reason: 'SyncManager restart');
      }
    }
  }

  /// Aynı cihazda önceki oturumdan FARKLI bir kullanıcı geldiğinde onun
  /// yerel ilerlemesini göstermez. Eski hesabın anahtarları diskte kalır;
  /// silme yalnız [signOut] ile aktif kullanıcı için yapılır.
  ///
  /// Genel anahtarlı eski kurulum, kayıtlı insan sahibe ya da sahip yoksa
  /// ilk gerçek kullanıcıya bir kez taşınır. Taşıma silmeyi başaramazsa
  /// sahip kaydı güncellenmez.
  Future<bool> _resetLocalProgressIfForeignUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    // Başarısız platform yazımı bellekte başarılı görünmüş olabilir.
    // Hesap sınırını ve yeniden denemeyi daima kalıcı durumdan başlat.
    await prefs.reload();
    final previousScope = LocalProgressScope.activeUserId;
    final migrated = await LocalProgressScope.migrateLegacy(
      prefs,
      incomingUserId: user.id,
    );
    if (!migrated) return false;
    final saved = await prefs.setString(_deviceOwnerUserIdKey, user.id);
    if (!saved) return false;
    LocalProgressScope.bind(user.id);
    if (previousScope != user.id) _dropProgressMemory();
    await SyncManager.maybeInstance?.reconcileXpCache();
    await SyncManager.maybeInstance?.queueScopedOfflineLessons();
    return true;
  }

  /// Açılışta kapsamı bağlar. Ağ yokken insan sahip varsa onun alanı açılır;
  /// yoksa genel anahtarlar ilk gerçek girişe kadar görünür kalır.
  Future<void> bindLocalProgressScope() async {
    final prefs = await SharedPreferences.getInstance();
    if (_offlineMode || _currentUser == null) {
      await LocalProgressScope.activateOffline(prefs);
      return;
    }
    await _resetLocalProgressIfForeignUser(_currentUser!);
  }

  void _dropProgressMemory() {
    XPStore.resetInstance();
    StreakStore.resetInstance();
    MistakeStore.resetInstance();
    SeenQuestionStore.resetInstance();
    AchievementStore.resetInstance();
    BadgeService.resetInstance();
    MasteryStore.resetInstance();
    DailyMissionStore.resetInstance();
    PlacementStore.resetInstance();
    StoryProgressStore.resetInstance();
    LevelProgressStore.resetInstance();
    LearningGoalStore.resetInstance();
  }

  @visibleForTesting
  Future<bool> debugResetLocalProgressIfForeignUser(User user) =>
      _resetLocalProgressIfForeignUser(user);

  @visibleForTesting
  Future<void> debugPrepareSessionUser(User? user, {bool restartSync = true}) {
    _currentUser = user;
    return _queueSessionPreparation(
      user,
      restartSync: restartSync,
      syncPremiumIdentity: false,
    );
  }

  /// Test/mock constructor — Supabase başlatılmadan kullanım için.
  AuthProvider.test({bool authenticated = false, NativeAuthService? nativeAuth})
    : _client = null,
      _offlineMode = false,
      _nativeAuth = nativeAuth ?? PlatformNativeAuthService(),
      _mockAuthenticated = authenticated;

  /// Üretimde uzak kimlik servisi başlatılamadığında kullanılan mod.
  ///
  /// Test kurucusundan farklı olarak hesap tabanlı auth çağrılarını sahte
  /// başarıya çevirmiyor. Cihaz içi misafir akışı yine çalışabilir; bağlantı
  /// geri geldiğinde gerçek Supabase oturumu yeni açılışta devreye girer.
  AuthProvider.offline({NativeAuthService? nativeAuth})
    : _client = null,
      _offlineMode = true,
      _nativeAuth = nativeAuth ?? PlatformNativeAuthService();

  Future<void> _syncPremiumIdentity(User? user) async {
    final premium = PremiumService.instance;
    if (premium == null) return;
    try {
      if (user == null) {
        await premium.logOutUser();
      } else {
        await premium.logInUser(user.id);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium identity sync');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function(SupabaseClient auth) body) async {
    final client = _client;
    if (client == null) {
      if (!_offlineMode) return true;
      _isLoading = false;
      _needsEmailConfirmation = false;
      _errorMessage = 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.';
      notifyListeners();
      return false;
    }

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
    } on NativeAuthCancelled {
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = _translateError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'AuthProvider unexpected sign-in error',
      );
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

  bool get _useNativeAppleAndGoogle =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _signInWithNativeCredential(
    SupabaseClient client,
    NativeAuthCredential credential,
  ) async {
    switch (credential.provider) {
      case NativeAuthProvider.google:
        await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: credential.idToken,
          accessToken: credential.accessToken,
        );
      case NativeAuthProvider.apple:
        await client.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: credential.idToken,
          nonce: credential.nonce,
        );
        _registerAppleAuthorization(client, credential);
    }
  }

  Future<void> _linkNativeCredential(
    SupabaseClient client,
    NativeAuthCredential credential,
  ) async {
    switch (credential.provider) {
      case NativeAuthProvider.google:
        await client.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: credential.idToken,
          accessToken: credential.accessToken,
        );
      case NativeAuthProvider.apple:
        await client.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.apple,
          idToken: credential.idToken,
          nonce: credential.nonce,
        );
        _registerAppleAuthorization(client, credential);
    }
  }

  /// Apple'ın tek kullanımlık kodunu sunucuya iletir (hesap silinirken Apple
  /// bağlantısı iptal edilebilsin diye). Giriş akışını BEKLETMEZ ve hata
  /// vermez: bkz. `apple_revocation.dart`.
  void _registerAppleAuthorization(
    SupabaseClient client,
    NativeAuthCredential credential,
  ) {
    final code = credential.authorizationCode;
    if (code == null || code.isEmpty) return;
    unawaited(registerAppleAuthorization(client, code));
  }

  /// iOS'ta Google hesabını uygulama içindeki native SDK ile alır.
  /// Web ve diğer platformlarda mevcut Supabase OAuth akışı korunur.
  Future<bool> signInWithGoogle() {
    if (_useNativeAppleAndGoogle) {
      return _run((client) async {
        final credential = await _nativeAuth.signInWithGoogle();
        if (credential == null) throw const NativeAuthCancelled();
        await _signInWithNativeCredential(client, credential);
      });
    }
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

  /// iOS'ta Apple hesabını uygulama içindeki native SDK ile alır.
  /// Web ve diğer platformlarda mevcut Supabase OAuth akışı korunur.
  ///
  /// App Store İnceleme Kılavuzu 4.8: üçüncü taraf bir sosyal giriş
  /// (burada Google) sunan uygulama, Apple platformlarında eşdeğer bir
  /// "Apple ile Giriş" seçeneği de sunmak zorundadır. Bu seçenek yokken
  /// uygulama incelemeden geçemez (2026-07-25 denetimi).
  ///
  /// Çalışması için Supabase Dashboard'da Apple sağlayıcısının ve Apple
  /// Developer tarafında bir Services ID + Sign in with Apple yetkisinin
  /// tanımlı olması gerekir; bunlar uygulama kodunun dışındadır.
  Future<bool> signInWithApple() {
    if (_useNativeAppleAndGoogle) {
      return _run((client) async {
        final credential = await _nativeAuth.signInWithApple();
        if (credential == null) throw const NativeAuthCancelled();
        await _signInWithNativeCredential(client, credential);
      });
    }
    return _run((client) async {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: authRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Apple girişi başlatılamadı.');
      }
    });
  }

  /// Misafir (anonim) hesabı Apple ile bağlar — mevcut oturumu korur.
  /// [linkGoogleAccount] ile aynı gerekçe: misafir ilerlemesi kaybolmasın.
  Future<bool> linkAppleAccount() {
    if (_useNativeAppleAndGoogle) {
      return _run((client) async {
        final credential = await _nativeAuth.signInWithApple();
        if (credential == null) throw const NativeAuthCancelled();
        await _linkNativeCredential(client, credential);
      });
    }
    return _run((client) async {
      final launched = await client.auth.linkIdentity(
        OAuthProvider.apple,
        redirectTo: authRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Apple bağlantısı başlatılamadı.');
      }
    });
  }

  // 2026-07-22 canlı UX denetimi: misafir hesap yükseltme
  /// Misafir (anonim) hesabı e-posta/şifre ile kalıcı hesaba yükseltir.
  ///
  /// Supabase `updateUser` API'sini kullanır. Hata durumunda `false` döner.
  ///
  /// Dönen `UserResponse` eskiden HİÇ İNCELENMİYORDU: çağrı istisna
  /// atmadığı sürece `true` dönülüyor, ekran da "Hesabın başarıyla
  /// kaydedildi!" diyordu. Oysa e-posta onayı AÇIKKEN GoTrue hesabı
  /// kaydetmez, yalnız onaya alır. Yerel GoTrue'da (v2.192.0) iki
  /// yapılandırma da ölçüldü (2026-08-06):
  ///
  ///   onay KAPALI → is_anonymous=false, email='upgraded1@zk.test',
  ///                 new_email=null          → gerçekten kaydedildi
  ///   onay AÇIK   → is_anonymous=TRUE,      email='',
  ///                 new_email='pending1@zk.test'
  ///
  /// İkinci durumda kullanıcı hâlâ anonimdi ve adres yalnız beklemedeydi;
  /// uygulamayı silse ya da başka cihazdan girmeye çalışsa ilerlemesi
  /// (coin, liderlik kimliği, o kullanıcıya bağlı abonelik) geri
  /// gelmezdi — ama kendisine tam tersi söylenmişti.
  ///
  /// [needsEmailConfirmation] artık bu iki alandan hesaplanıyor; böylece
  /// panelde onay açık da olsa kapalı da olsa mesaj gerçeğe uyar.
  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
  }) {
    return _run((client) async {
      final response = await client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      final user = response.user;
      final pendingEmail = user?.newEmail;
      _needsEmailConfirmation =
          (pendingEmail != null && pendingEmail.isNotEmpty) ||
          (user?.isAnonymous ?? false);
    });
  }

  // 2026-07-23 canlı UX denetimi M18: signInWithGoogle() anonim oturumu
  // yeni bir hesapla değiştiriyordu, bu da misafir ilerlemesinin (XP,
  // streak, yanlış soru geçmişi) kaybolmasına yol açabiliyordu.
  // linkIdentity, mevcut anonim kimliği signOut/yeni oturum açmadan
  // Google'a bağlar; local store'lara dokunmaz.
  /// Misafir (anonim) hesabı Google ile bağlar — mevcut oturumu korur.
  Future<bool> linkGoogleAccount() {
    if (_useNativeAppleAndGoogle) {
      return _run((client) async {
        final credential = await _nativeAuth.signInWithGoogle();
        if (credential == null) throw const NativeAuthCancelled();
        await _linkNativeCredential(client, credential);
      });
    }
    return _run((client) async {
      final launched = await client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: authRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException('Google bağlantısı başlatılamadı.');
      }
    });
  }

  Future<bool> resetPassword(String email) {
    return _run(
      (client) =>
          client.auth.resetPasswordForEmail(email, redirectTo: authRedirectUri),
    );
  }

  /// Oturum olayının kurtarma bayrağına etkisi.
  ///
  /// Dinleyici eskiden YALNIZ `state.session?.user` okuyordu; olayın TÜRÜ
  /// hiç sorulmuyordu. Kurtarma bağlantısı da normal bir oturum açtığı
  /// için kullanıcı sessizce içeri giriyor, parolası değişmemiş oluyordu
  /// (2026-08-06 denetimi).
  ///
  /// Gövde ayrı bir metotta: gerçek bir `SupabaseClient` kurmadan
  /// doğrulanabilsin.
  @visibleForTesting
  void applyAuthEvent(AuthChangeEvent event, {required bool hasSession}) {
    if (event == AuthChangeEvent.passwordRecovery) {
      _needsPasswordRecovery = true;
    } else if (!hasSession) {
      // Çıkışta bayrak asılı kalmamalı, yoksa bir sonraki oturum sebepsiz
      // parola ekranıyla açılır.
      _needsPasswordRecovery = false;
    }
  }

  /// Kurtarma oturumunda yeni parolayı yazar.
  ///
  /// `resetPassword` yalnız bağlantıyı gönderir; parolayı DEĞİŞTİREN
  /// çağrı budur ve 2026-08-06'ya kadar uygulamada hiç yoktu. Başarılı
  /// olduğunda kurtarma bayrağı düşer ve `AppShell` normal akışa döner.
  Future<bool> completePasswordRecovery(String password) async {
    final ok = await _run(
      (client) => client.auth.updateUser(UserAttributes(password: password)),
    );
    if (ok) {
      _needsPasswordRecovery = false;
      notifyListeners();
    }
    return ok;
  }

  /// Kurtarmadan vazgeçilir ve oturum kapatılır.
  ///
  /// Bayrağı tek başına düşürmek, parolası hâlâ eski olan bir oturumu
  /// sessizce Home'a bırakırdı — düzeltilmek istenen durumun aynısı.
  /// Bu yüzden vazgeçmek çıkış yapmak demektir.
  Future<void> cancelPasswordRecovery() async {
    _needsPasswordRecovery = false;
    await signOut();
  }

  /// Yerel ilerleme store'larını (XP/streak/mistake/rozet/...) temizler.
  ///
  /// [signOut] ve [_resetLocalProgressIfForeignUser] arasında paylaşılır:
  /// her ikisi de aynı "bu cihaz artık başka birine ait" durumunu ele alır,
  /// yalnız tetikleyicileri farklıdır (açık çıkış / sessiz hesap değişimi).
  Future<bool> _clearLocalProgressStores() async {
    var requiredStoresCleared = true;

    try {
      final xpStore = await XPStore.load();
      await xpStore.clear();
      XPStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'XPStore clear failed');
    }

    try {
      final streakStore = await StreakStore.load();
      await streakStore.clear();
      StreakStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'StreakStore clear failed');
    }

    try {
      final mistakeStore = await MistakeStore.load();
      if (await mistakeStore.clear()) {
        MistakeStore.resetInstance();
      } else {
        requiredStoresCleared = false;
      }
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'MistakeStore clear failed');
    }

    try {
      final seenStore = await SeenQuestionStore.load();
      if (await seenStore.clear()) {
        SeenQuestionStore.resetInstance();
      } else {
        requiredStoresCleared = false;
      }
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'SeenQuestionStore clear failed');
    }

    try {
      final achievementStore = await AchievementStore.load();
      await achievementStore.clear();
      AchievementStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'AchievementStore clear failed');
    }

    try {
      final badgeService = await BadgeService.load();
      await badgeService.clear();
      BadgeService.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'BadgeService clear failed');
    }

    try {
      final masteryStore = await MasteryStore.load();
      await masteryStore.clear();
      MasteryStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'MasteryStore clear failed');
    }

    try {
      final missionStore = await DailyMissionStore.load();
      await missionStore.clear();
      DailyMissionStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'DailyMissionStore clear failed');
    }

    try {
      final placementStore = await PlacementStore.load();
      await placementStore.clear();
      PlacementStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'PlacementStore clear failed');
    }

    try {
      final storyStore = await StoryProgressStore.load();
      await storyStore.clear();
      StoryProgressStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'StoryProgressStore clear failed');
    }

    try {
      final levelStore = await LevelProgressStore.load();
      await levelStore.clear();
      LevelProgressStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'LevelProgressStore clear failed');
    }

    try {
      final goalStore = await LearningGoalStore.load();
      await goalStore.clear();
      LearningGoalStore.resetInstance();
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(e, s, reason: 'LearningGoalStore clear failed');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await QuizResultProgressReceiptStore.clearForActiveUser(prefs);
    } catch (e, s) {
      requiredStoresCleared = false;
      ErrorReporter.record(
        e,
        s,
        reason: 'QuizResultProgressReceiptStore clear failed',
      );
    }

    return requiredStoresCleared;
  }

  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    var accountCleanupFailed = false;
    // Devam eden eski oturum hazırlığını geçersiz kıl ve tamamlanmasını bekle.
    // Böylece gecikmiş A kullanıcısı, logout temizliğinden sonra kapsamı veya
    // SyncManager'ı yeniden A adına kuramaz.
    _authGeneration += 1;
    await _authTransition;
    // Yerel store'lar temizlenmeden önce bekleyen, sunucuda doğrulanabilen
    // çevrimdışı ödüller son kez gönderilir. XP cihazda tutulur ve aşağıda
    // diğer yerel ilerleme verileriyle birlikte temizlenir. `shutdown` ayrıca
    // singleton'ı serbest bırakır; yalnız `dispose()` sonraki bağlantı
    // dinleyicisinin kurulmasını engellerdi.
    try {
      if (discardPendingRewards) {
        final ownerId = pendingRewardsOwnerId?.trim();
        if (ownerId == null || ownerId.isEmpty) {
          throw StateError('Deleted account sync queue owner is missing.');
        }
        await SyncManager.discardQueueForUser(ownerId);
      } else {
        await SyncManager.shutdown();
      }
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'SyncManager shutdown on signOut');
      accountCleanupFailed = discardPendingRewards;
    }

    // RevenueCat kimliği de bırakılır; aksi halde aynı cihazda giriş yapan
    // bir sonraki kullanıcı önceki kullanıcının entitlement'ını devralır.
    try {
      await PremiumService.instance?.logOutUser();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'PremiumService logout on signOut');
    }

    final localProgressCleared = await _clearLocalProgressStores();
    if (discardPendingRewards && !localProgressCleared) {
      accountCleanupFailed = true;
    }

    // Hesap silmede cihaz sahipliği de düşer; normal çıkışta anahtar
    // kalır ve yabancı-kullanıcı denetimi bir sonraki girişte çalışır. Temizlik
    // başarısızsa anahtarı koru ki sonraki kullanıcı girişinde yeniden denensin.
    if (discardPendingRewards && localProgressCleared) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_deviceOwnerUserIdKey);
      } catch (e, s) {
        ErrorReporter.record(e, s, reason: 'deviceOwner key removal failed');
        accountCleanupFailed = true;
      }
    }

    final client = _client;
    if (client == null) {
      _mockAuthenticated = false;
      _errorMessage = null;
      notifyListeners();
      if (accountCleanupFailed) {
        throw const AccountLocalCleanupException();
      }
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
    if (accountCleanupFailed) {
      throw const AccountLocalCleanupException();
    }
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
    // 2026-07-23 M18: Google hesap bağlama hataları — kod bazlı eşleşme
    // mesaj metninden daha güvenilir (bkz. gotrue error_code.dart).
    if (e.code == 'identity_already_exists' ||
        message.contains('identity is already linked') ||
        message.contains('already been linked')) {
      return 'Bu Google hesabı zaten başka bir hesaba bağlı.';
    }
    if (e.code == 'manual_linking_disabled' ||
        message.contains('manual linking')) {
      return 'Hesap bağlama şu anda kapalı. Supabase panelinde manuel bağlamayı aç.';
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
