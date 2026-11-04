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
/// * Cevap yoksa ([declaration] null) sosyal yüzey (sohbet, arkadaş isteği,
///   oda sohbeti) AÇILMAZ (2026-11-04, ikinci tur kurul): eskiden "cevap
///   yok = serbest"ti ve kapıyı atlamak için tek yapılacak soruyu
///   kapatmaktı; çocuk sohbete sessizce giriyordu. Şimdi kullanıcı ilk kez
///   sosyal bir özelliğe dokununca yaş sorusu çıkar
///   (`StartupPrompts.ensureAgeCleared`); cevaplayana dek kapalı kalır.
///   Öğrenme ve tek kişilik oyun HİÇBİR durumda kapanmaz; ilk açılış
///   sorusu ([shouldAsk]/[markAsked]) yine bir kez çıkar. Daha önce cevap
///   vermiş kullanıcı cevabını korur.
/// * Beyan yalnız cihazdadır: profilde sütun yoktur (göç eklenmedi) ve
///   hesap açan biri başka cihazda yeniden sorulur. Bilinçli: DB'ye yaş
///   bilgisi yazmak da ayrı bir veri sorumluluğudur.
enum AgeDeclaration { adult, minor }

class AgeGate {
  const AgeGate._();

  static const declarationKey = 'zankurd.ageGate.v1';
  static const askedKey = 'zankurd.ageGate.v1.asked';

  /// Yetişkin beyanını veren hesabın kimliği. Beyan cihaz geneli değildir:
  /// A "13+" dedikten sonra aynı cihazda B'ye geçilirse B'ye yeniden
  /// sorulur (2026-11-04 denetimi; eskiden `ensureAgeCleared` soru göstermeden
  /// sosyal erişime izin veriyordu). Sahipsiz beyan (girişten önce, ilk
  /// açılışta verilen) ilk görünen hesabı sahip yapar: misafirin kayıtlı
  /// hesaba yükseltilmesi aynı kimliği korur, beyan kaybolmaz.
  static const ownerKey = 'zankurd.ageGate.v1.owner';

  static String? _boundUserId;

  /// Bağlamı olmayan katmanların okuduğu tek boğaz noktası (bkz.
  /// `AnalyticsConsentProvider.isEnabled` ile aynı desen).
  static AgeDeclaration? declaration;

  static bool get isMinor => declaration == AgeDeclaration.minor;

  /// 13 yaşından büyük olduğunu AÇIKÇA beyan etti mi (sosyal yüzeyin şartı).
  static bool get isAdult => declaration == AgeDeclaration.adult;

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

  /// Oturum kullanıcısı değiştiğinde çağrılır: başka bir hesabın YETİŞKİN
  /// beyanı bu hesaba geçmez (bellek ve disk). Çocuk beyanı cihazda kalır
  /// (kısıtlayıcı yön). Hata = yetişkin beyanı güvenilmez sayılır.
  static Future<void> bindUser(String? userId) async {
    _boundUserId = userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(declarationKey) != 'adult') return;
      final owner = prefs.getString(ownerKey);
      if (owner == null || owner.isEmpty) {
        await prefs.setString(ownerKey, userId);
        return;
      }
      if (owner == userId) return;
      await prefs.remove(declarationKey);
      await prefs.remove(askedKey);
      await prefs.remove(ownerKey);
      if (declaration == AgeDeclaration.adult) declaration = null;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'age_gate_bind');
      if (declaration == AgeDeclaration.adult) declaration = null;
    }
  }

  /// Beyanı yazar. Yazım başarısız olsa da bellekteki değer uygulanır:
  /// çocuk beyanı bir hata yüzünden kısıtsız kalmasın.
  static Future<void> declare(AgeDeclaration value) async {
    declaration = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(declarationKey, value.name);
      await prefs.setBool(askedKey, true);
      final owner = _boundUserId;
      if (owner == null) {
        await prefs.remove(ownerKey);
      } else {
        await prefs.setString(ownerKey, owner);
      }
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

  /// "Soruldu" işaretini geri alır: cevapsız kapatılan soru bir sonraki
  /// açılışta yeniden sorulsun (yaş bilinmeden ölçüm/sosyal açılmaz).
  static Future<void> clearAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(declarationKey) != null) return;
      await prefs.remove(askedKey);
    } catch (_) {}
  }

  /// Sorunun gösterildiğini işaretler: kullanıcıya en fazla bir kez sorulur.
  static Future<void> markAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(askedKey, true);
    } catch (_) {}
  }
}
