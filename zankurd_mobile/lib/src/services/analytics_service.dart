import 'package:flutter/foundation.dart';

/// Anonim kullanım istatistikleri servisi.
/// Firebase Analytics entegrasyonu yapıldığında gerçek olay kaydı burada yapılır.
/// Şu anda yalnızca debug logları üretir.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Uygulama başlatıldığında çağrılır.
  Future<void> initialize() async {
    // TODO: FirebaseAnalytics.instance başlatma
    debugPrint('[Analytics] Servis başlatıldı');
  }

  /// Özel olay kaydeder.
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    // TODO: FirebaseAnalytics.instance.logEvent
    debugPrint('[Analytics] $name ${parameters ?? ''}');
  }

  /// Quiz başlatma olayı.
  Future<void> logQuizStart({
    required String category,
    required String mode,
  }) =>
      logEvent('quiz_start', {'category': category, 'mode': mode});

  /// Quiz tamamlama olayı.
  Future<void> logQuizComplete({
    required String category,
    required int correctCount,
    required int totalQuestions,
    required int xpEarned,
  }) =>
      logEvent('quiz_complete', {
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
}
