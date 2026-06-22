import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Anonim kullanım istatistikleri servisi.
/// Firebase Analytics entegrasyonu kullanılarak gerçek olay kaydı burada yapılır.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  /// Uygulama başlatıldığında çağrılır.
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        _analytics = FirebaseAnalytics.instance;
        debugPrint('[Analytics] Firebase Analytics başlatıldı');
      } catch (e) {
        debugPrint('[Analytics] Firebase Analytics başlatılamadı: $e');
      }
    } else {
      debugPrint('[Analytics] Bu platformda Firebase Analytics desteklenmiyor');
    }
  }

  /// Özel olay kaydeder.
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    debugPrint('[Analytics] $name ${parameters ?? ''}');
    try {
      if (_analytics != null) {
        await _analytics!.logEvent(
          name: name,
          parameters: parameters,
        );
      }
    } catch (e) {
      debugPrint('[Analytics] Olay gönderilemedi: $e');
    }
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
