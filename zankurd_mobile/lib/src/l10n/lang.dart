import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import 'strings.dart';

/// Supported application languages.
enum AppLanguage {
  ku('ku', 'Kurmancî'),
  tr('tr', 'Türkçe');

  const AppLanguage(this.code, this.displayName);

  final String code;
  final String displayName;

  bool get isKu => this == AppLanguage.ku;
  bool get isTr => this == AppLanguage.tr;

  static AppLanguage fromCode(String code) {
    return code.toLowerCase() == 'tr' ? AppLanguage.tr : AppLanguage.ku;
  }
}

class LanguageProvider extends ChangeNotifier {
  LanguageProvider({String initialLang = 'ku', SharedPreferences? preferences})
    : this.fromLanguage(AppLanguage.fromCode(initialLang), preferences);

  LanguageProvider.fromLanguage(
    AppLanguage initialLanguage, [
    this._preferences,
  ]) : _language = initialLanguage;

  static const _storageKey = 'zankurd.language';

  static Future<LanguageProvider> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCode = preferences.getString(_storageKey) ?? 'ku';
    return LanguageProvider.fromLanguage(
      AppLanguage.fromCode(storedCode),
      preferences,
    );
  }

  AppLanguage _language;
  final SharedPreferences? _preferences;

  AppLanguage get language => _language;
  String get lang => _language.code;
  bool get isKu => _language == AppLanguage.ku;
  bool get isTr => _language == AppLanguage.tr;

  void setLanguage(AppLanguage nextLanguage) {
    if (_language != nextLanguage) {
      _language = nextLanguage;
      _preferences?.setString(_storageKey, nextLanguage.code);
      AnalyticsService.instance.logLanguageChange(nextLanguage.code);
      notifyListeners();
    }
  }

  void setLang(String lang) => setLanguage(AppLanguage.fromCode(lang));

  void toggle() => setLanguage(isKu ? AppLanguage.tr : AppLanguage.ku);
}

/// Dile duyarlı büyük harf.
///
/// `String.toUpperCase()` yereli tanımaz: Türkçede 'i' → 'I' verir, oysa
/// doğrusu 'İ'dir. Bölüm başlıkları büyük harfle çizildiği için ayarlar
/// ekranı "GÜVENLIK", "SES & BILDIRIM", "SESLENDIRME" yazıyordu
/// (2026-07-27). Kusur sessizdi: metinler sözlükte doğruydu, yalnız
/// büyütme yanlıştı ve yalnız içinde 'i' geçen başlıklarda görünüyordu.
///
/// Kurmancîde 'i' → 'I' **doğrudur** (alfabede i ve î ayrı harflerdir),
/// bu yüzden eşleme dile bağlıdır; tek bir düzeltme iki dili birden
/// bozardı.
String upperForLanguage(String value, {required bool ku}) {
  if (ku) return value.toUpperCase();
  return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

/// Helper to get bilingual strings.
extension LangContext on BuildContext {
  /// Eylem çağrıları (toggle/setLang) için: abonelik kurmaz.
  LanguageProvider get langProvider =>
      Provider.of<LanguageProvider>(this, listen: false);

  /// build() içinde dinleyerek okur; event handler/async kodda
  /// dinleme yasak olduğundan otomatik olarak dinlemeden okumaya düşer.
  bool get isKu {
    try {
      return Provider.of<LanguageProvider>(this).isKu;
    } on Object {
      return Provider.of<LanguageProvider>(this, listen: false).isKu;
    }
  }

  AppLanguage get language =>
      Provider.of<LanguageProvider>(this, listen: false).language;

  /// Etkin dile göre büyük harf — bkz. [upperForLanguage].
  String upper(String value) => upperForLanguage(value, ku: isKu);

  /// Returns [ku] if Kurdish is active, [tr] if Turkish.
  String s(String ku, String tr) => isKu ? ku : tr;

  /// Anahtar tabanlı metin erişimi — [Tr] kayıt defterinden okur.
  ///
  /// [s] ile arasındaki fark, çağrı yerinin dil sayısından bağımsız
  /// olmasıdır: üçüncü bir dil eklendiğinde `t(...)` kullanan hiçbir satır
  /// değişmez, `s(ku, tr)` kullanan her satır değişmek zorundadır. Yeni kod
  /// [t] kullanmalı; [s] göç tamamlanana kadar duran bir köprüdür
  /// (bkz. `lib/src/l10n/strings.dart` göç yolu).
  ///
  /// Dil, [isKu] ile aynı biçimde *dinleyerek* okunur. İlk yazımında
  /// `langProvider` (listen: false) kullanılmıştı; bu yüzden dil
  /// değiştiğinde `t()` kullanan widget'lar yeniden çizilmiyor ve ekran
  /// eski dilde kalıyordu (2026-07-25, göç sırasında testlerin yakaladığı
  /// regresyon). Abone olmayan okuma yalnız event handler / async kodda
  /// doğrudur; orada [isKu] zaten kendiliğinden dinlemesiz okumaya düşer.
  String t(String key, [Map<String, String>? params]) {
    final language = isKu ? AppLanguage.ku : AppLanguage.tr;
    return Tr.of(key, language, params);
  }

  /// Translates Supabase Auth Turkish error messages to Kurdish if active.
  String translateAuthError(String turkishMessage) {
    if (!isKu) return turkishMessage;
    switch (turkishMessage) {
      case 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.':
        return 'Girêdan çênebû. Înternet an DNS kontrol bike.';
      case 'Beklenmeyen bir hata oluştu.':
        return 'Şaşiyeke nediyar çêbû.';
      case 'Google girişi şu anda etkin değil. Supabase panelinde Google sağlayıcısını aç.':
        return 'Têketina Google niha ne çalak e. Google di panela Supabase de çalak bike.';
      case 'Giriş bağlantısı doğrulanamadı. Uygulama yönlendirme ayarlarını kontrol et.':
        return 'Girêdana têketinê nehate piştrastkirin. Saziyên arastekirina sepanê kontrol bike.';
      case 'E-posta veya parola hatalı.':
        return 'E-peyam an şîfre şaş e.';
      case 'Bu e-posta zaten kullanılıyor.':
        return 'Ev e-peyam jixwe tê bikaranîn.';
      case 'Parola çok zayıf (en az 6 karakter).':
        return 'Şîfre pir qels e (herî kêm 6 karakter).';
      case 'Geçersiz e-posta adresi.':
        return 'Navnîşana e-peyamê ya nederbasdar.';
      case 'E-posta adresin henüz doğrulanmamış. Gelen kutunu kontrol et.':
        return 'Navnîşana e-peyama te hîna nehatiye piştrastkirin. Sindoqa xwe ya nameyan kontrol bike.';
      case 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.':
        return 'Pir ceribandin hatin kirin. Hinekî bisekine û dîsa biceribîne.';
      case 'Misafir girişi şu anda kapalı.':
        return 'Têketina mêvanan niha girtî ye.';
      case 'Bir hata oluştu. Lütfen tekrar deneyin.':
        return 'Çewtiyek rû da. Ji kerema xwe dîsa biceribîne.';
      default:
        return turkishMessage;
    }
  }
}

/// Category names in both languages.
class CategoryNames {
  /// Stable category IDs (also used as keys in stores / SQL).
  static const Map<String, String> _kuToTr = {
    'Ziman': 'Dil',
    'Çand': 'Kültür',
    'Dîrok': 'Tarih',
    'Edebiyat': 'Edebiyat',
    'Cografya': 'Coğrafya',
    'Muzîk': 'Müzik',
    'Siyaset': 'Siyaset',
    'Paradigma': 'Paradigma',
    'Teknolojî': 'Teknoloji',
    'Sînema': 'Sinema',
  };

  /// Optional Kurmanci display labels (ID stays the map key).
  static const Map<String, String> _kuDisplay = {
    'Edebiyat': 'Wêje',
    'Cografya': 'Erdnîgarî',
    'Paradigma': 'Paradîgma',
  };

  static String tr(String kuName) => _kuToTr[kuName] ?? kuName;

  static String localized(String kuName, bool isKu) =>
      isKu ? (_kuDisplay[kuName] ?? kuName) : tr(kuName);
}

/// Seviye adları veri katmanında Kurmancî sabit olarak tutulur (kimlik
/// görevi görür). Türkçe arayüzde bunlar çevrilmeden gösteriliyordu:
/// seviye haritasında "Destpêk / Bingeh / Navîn / Pêşketî / Mamoste"
/// yazıyor, arayüzün geri kalanı Türkçe kalıyordu (2026-07-22 canlı UX
/// denetimi). [CategoryNames] ile aynı desen.
class LevelNames {
  const LevelNames._();

  static const Map<String, String> _kuToTr = {
    'Destpêk': 'Başlangıç',
    'Bingeh': 'Temel',
    'Navîn': 'Orta',
    'Pêşketî': 'İleri',
    'Mamoste': 'Usta',
  };

  static String tr(String kuName) => _kuToTr[kuName] ?? kuName;

  static String localized(String kuName, bool isKu) =>
      isKu ? kuName : tr(kuName);
}

/// Centralized strings for the Quiz Screen to avoid hardcoded UI text in logic.
class QuizStrings {
  static String answered(bool isKu) => isKu ? 'Bersiv da' : 'Cevapladı';
  static String waiting(bool isKu) =>
      isKu ? 'Li benda bersivê ye' : 'Cevap bekliyor';
  static String you(bool isKu) => isKu ? 'Tu' : 'Sen';
  static String opponent(bool isKu) => isKu ? 'Hevrik' : 'Rakip';
  static String playAgain(bool isKu) => isKu ? 'Dîsa bilîze' : 'Tekrar oyna';
}

/// Centralized common UI strings (dialog buttons, state messages, general actions).
class CommonStrings {
  const CommonStrings._();

  static String ok(bool isKu) => isKu ? 'Temam' : 'Tamam';
  static String cancel(bool isKu) => isKu ? 'Betal bike' : 'İptal';
  static String retry(bool isKu) => isKu ? 'Dîsa biceribîne' : 'Tekrar Dene';
  static String error(bool isKu) => isKu ? 'Çewtî' : 'Hata';
  static String loading(bool isKu) => isKu ? 'Tê barkirin...' : 'Yükleniyor...';
  static String share(bool isKu) => isKu ? 'Parve bike' : 'Paylaş';
  static String close(bool isKu) => isKu ? 'Bigire' : 'Kapat';
  static String save(bool isKu) => isKu ? 'Biparêze' : 'Kaydet';
  static String back(bool isKu) => isKu ? 'Paşve' : 'Geri';
  static String continueText(bool isKu) => isKu ? 'Berdewam bike' : 'Devam Et';
}
