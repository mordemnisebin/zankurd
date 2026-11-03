import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// "13 yaşından büyük müsün?" beyanı (mağaza / COPPA).
///
/// ## Niçin
///
/// Uygulama oda sohbeti, arkadaş listesi ve kullanım analizi barındırıyor;
/// mağazalar ve COPPA/KVKK 13 yaş altı için bunların KAPALI olmasını
/// bekler. Beyan, yaş doğrulaması değildir (kimlik istemeyiz); amaç çocuğa
/// sosyal yüzeyi ve kişiselleştirilmiş ölçümü açmamaktır.
///
/// ## Davranış
///
/// * 13 yaşından küçük ([AgeDeclaration.minor]): sohbet, arkadaş/sosyal
///   özellikler ve kullanım analizi KAPALI; öğrenme ve tek kişilik oyun
///   AÇIK kalır (bkz. `FeatureGate.chat/social`,
///   `AnalyticsConsentProvider.load/setEnabled`).
/// * Cevap yoksa ([declaration] null) kısıtlama YOKTUR: mevcut kullanıcı
///   bir şeyden yoksun bırakılmaz; ona yalnız BİR KEZ sorulur
///   ([shouldAsk]/[markAsked]), yeni kullanıcıya ilk açılış akışında.
/// * Beyan yalnız cihazdadır: profilde sütun yoktur (göç eklenmedi) ve
///   hesap açan biri başka cihazda yeniden sorulur. Bilinçli: DB'ye yaş
///   bilgisi yazmak da ayrı bir veri sorumluluğudur.
enum AgeDeclaration { adult, minor }

class AgeGate {
  const AgeGate._();

  static const declarationKey = 'zankurd.ageGate.v1';
  static const askedKey = 'zankurd.ageGate.v1.asked';

  /// Bağlamı olmayan katmanların okuduğu tek boğaz noktası (bkz.
  /// `AnalyticsConsentProvider.isEnabled` ile aynı desen).
  static AgeDeclaration? declaration;

  static bool get isMinor => declaration == AgeDeclaration.minor;

  @visibleForTesting
  static void debugSet(AgeDeclaration? value) => declaration = value;

  /// Diskten okur ve [declaration]ı günceller. Hata = kısıtsız (null).
  static Future<AgeDeclaration?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      declaration = switch (prefs.getString(declarationKey)) {
        'adult' => AgeDeclaration.adult,
        'minor' => AgeDeclaration.minor,
        _ => null,
      };
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'age_gate_load');
    }
    return declaration;
  }

  /// Beyanı yazar. Yazım başarısız olsa da bellekteki değer uygulanır:
  /// çocuk beyanı bir hata yüzünden kısıtsız kalmasın.
  static Future<void> declare(AgeDeclaration value) async {
    declaration = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(declarationKey, value.name);
      await prefs.setBool(askedKey, true);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'age_gate_save');
    }
  }

  /// Hiç cevap yok ve daha önce sorulmadı mı?
  static Future<bool> shouldAsk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(declarationKey) != null) return false;
      return prefs.getBool(askedKey) != true;
    } catch (_) {
      return false;
    }
  }

  /// Sorunun gösterildiğini işaretler: kullanıcıya en fazla bir kez sorulur.
  static Future<void> markAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(askedKey, true);
    } catch (_) {}
  }
}
