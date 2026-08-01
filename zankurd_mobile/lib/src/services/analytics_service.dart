import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:zankurd_mobile/src/utils/error_reporter.dart';

/// Anonim kullanım istatistikleri servisi.
/// Firebase Analytics entegrasyonu kullanılarak gerçek olay kaydı burada yapılır.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  /// Uygulama başlatıldığında çağrılır.
  Future<void> initialize() async {
    if (_analytics != null) return;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        _analytics = FirebaseAnalytics.instance;
        await _analytics!.setAnalyticsCollectionEnabled(true);
        debugPrint('[Analytics] Firebase Analytics başlatıldı');
      } catch (e, s) {
        ErrorReporter.record(e, s, reason: 'AnalyticsService initialize');
        debugPrint('[Analytics] Firebase Analytics başlatılamadı: $e');
      }
    } else {
      debugPrint('[Analytics] Bu platformda Firebase Analytics desteklenmiyor');
    }
  }

  /// Kullanıcı izni geri çektiğinde yeni olayları hemen durdurur.
  Future<void> disable() async {
    final analytics = _analytics;
    _analytics = null;
    try {
      await analytics?.setAnalyticsCollectionEnabled(false);
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'AnalyticsService disable');
    }
  }

  /// Özel olay kaydeder.
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    debugPrint('[Analytics] $name ${parameters ?? ''}');
    try {
      if (_analytics != null) {
        await _analytics!.logEvent(name: name, parameters: parameters);
      }
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'AnalyticsService logEvent');
      debugPrint('[Analytics] Olay gönderilemedi: $e');
    }
  }

  /// Quiz başlatma olayı.
  Future<void> logQuizStart({required String category, required String mode}) =>
      logEvent('quiz_start', {'category': category, 'mode': mode});

  /// Quiz tamamlama olayı.
  Future<void> logQuizComplete({
    required String category,
    required int correctCount,
    required int totalQuestions,
    required int xpEarned,
  }) => logEvent('quiz_complete', {
    'category': category,
    'correct': correctCount,
    'total': totalQuestions,
    'xp': xpEarned,
  });

  /// Rozet kazanma olayı.
  Future<void> logBadgeEarned(String badgeId) =>
      logEvent('badge_earned', {'badge_id': badgeId});

  /// Dil değişikliği olayı.
  Future<void> logLanguageChange(String lang) =>
      logEvent('language_change', {'lang': lang});

  /// Tema değişikliği olayı.
  Future<void> logThemeChange(String theme) =>
      logEvent('theme_change', {'theme': theme});

  /// Paywall görüntülenme olayı.
  Future<void> logPaywallView() => logEvent('paywall_view');

  /// Başarılı satın alma olayı.
  Future<void> logPurchaseSuccess(String packageId) =>
      logEvent('purchase_success', {'package_id': packageId});

  /// Oturum açma olayı.
  Future<void> logSignIn(String method) =>
      logEvent('login', {'method': method});

  /// Kaydolma olayı.
  Future<void> logSignUp(String method) =>
      logEvent('sign_up', {'method': method});

  /// İzinli, kişisel veri içermeyen beta aktivasyon adımı.
  ///
  /// Oda kodu, oyuncu adı, e-posta veya soru metni gibi tanımlayıcılar
  /// gönderilmez; yalnızca ürün akışının hangi adımına ulaşıldığı tutulur.
  Future<void> logActivationStep(String step) =>
      logEvent('activation_step', {'step': step});

  Future<void> logOnboardingCompleted() =>
      logActivationStep('onboarding_completed');

  Future<void> logFirstQuizCompleted() =>
      logActivationStep('first_quiz_completed');
}
