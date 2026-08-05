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
import '../data/level_progress_store.dart';
import '../data/placement_store.dart';
import '../data/story_progress_store.dart';
import '../data/sync_manager.dart';
import '../services/premium_service.dart';
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

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSub;

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

  bool get isGuest => _currentUser?.isAnonymous ?? false;

  AuthProvider(SupabaseClient client) : _client = client {
    _currentUser = client.auth.currentUser;
    _syncPremiumIdentity(_currentUser);
    _authSub = client.auth.onAuthStateChange.listen((state) {
      final next = state.session?.user;
      final changed = next?.id != _currentUser?.id;
      _currentUser = next;
      applyAuthEvent(state.event, hasSession: next != null);
      // RevenueCat müşterisi Supabase kullanıcısına bağlanır: aboneliğin
      // cihaza değil hesaba ait olmasını ve cihaz paylaşımında entitlement
      // sızmamasını sağlar.
      if (changed) _syncPremiumIdentity(next);
      // `signOut()` SyncManager'ı kapatıyor; yeni bir oturum açıldığında
      // onu geri kuran hiçbir yer yoktu. Aynı oturumda çıkıp tekrar giren
      // kullanıcıda çevrimdışı ödül kuyruğu ölü kalıyor ve `instance`
      // getter'ı `StateError` fırlatıyordu (2026-07-31 denetimi).
      if (changed && next != null) {
        unawaited(
          SyncManager.restart().catchError((Object error, StackTrace stack) {
            ErrorReporter.record(error, stack, reason: 'SyncManager restart');
          }),
        );
      }
      notifyListeners();
    });
  }

  /// Test/mock constructor — Supabase başlatılmadan kullanım için.
  AuthProvider.test({bool authenticated = false})
    : _client = null,
      _mockAuthenticated = authenticated;

  void _syncPremiumIdentity(User? user) {
    final premium = PremiumService.instance;
    if (premium == null) return;
    final future = user == null
        ? premium.logOutUser()
        : premium.logInUser(user.id);
    unawaited(
      future.catchError((Object error, StackTrace stack) {
        ErrorReporter.record(error, stack, reason: 'premium identity sync');
      }),
    );
  }

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

  /// Apple ile giriş, Supabase OAuth üzerinden.
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

  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    var accountCleanupFailed = false;
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
      ErrorReporter.record(
        e,
        s,
        reason: 'MistakeStore clear on signOut failed',
      );
    }

    try {
      final seenStore = await SeenQuestionStore.load();
      await seenStore.clear();
      SeenQuestionStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'SeenQuestionStore clear on signOut failed',
      );
    }

    try {
      final achievementStore = await AchievementStore.load();
      await achievementStore.clear();
      AchievementStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'AchievementStore clear on signOut failed',
      );
    }

    try {
      final masteryStore = await MasteryStore.load();
      await masteryStore.clear();
      MasteryStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'MasteryStore clear on signOut failed',
      );
    }

    try {
      final missionStore = await DailyMissionStore.load();
      await missionStore.clear();
      DailyMissionStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'DailyMissionStore clear on signOut failed',
      );
    }

    try {
      final placementStore = await PlacementStore.load();
      await placementStore.clear();
      PlacementStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'PlacementStore clear on signOut failed',
      );
    }

    try {
      final storyStore = await StoryProgressStore.load();
      await storyStore.clear();
      StoryProgressStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'StoryProgressStore clear on signOut failed',
      );
    }

    try {
      final levelStore = await LevelProgressStore.load();
      await levelStore.clear();
      LevelProgressStore.resetInstance();
    } catch (e, s) {
      ErrorReporter.record(
        e,
        s,
        reason: 'LevelProgressStore clear on signOut failed',
      );
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
