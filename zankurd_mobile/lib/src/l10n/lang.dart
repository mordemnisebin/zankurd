import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/bilingual_labels_provider.dart';
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

  /// İki dilli etiketin küçük satırı: [key]in öbür dildeki karşılığı.
  ///
  /// Ayar kapalıysa ([BilingualLabelsProvider]) ya da öbür dilde ayrı bir
  /// karşılık yoksa `null`. Tek kaynak budur: sekme, başlık ve konu kartı
  /// hepsi buradan okur (bkz. [Tr.counterpart]).
  String? secondLabel(String key, [Map<String, String>? params]) {
    final bool ku;
    try {
      ku = isKu;
    } on ProviderNotFoundException {
      return null;
    }
    return secondLabelFor(this, key, isKu: ku, params: params);
  }

  /// Kimlik sağlayıcısının hata dizgisini geçerli dile çevirir.
  ///
  /// `AuthProvider.errorMessage` artık bir metin ANAHTARIDIR (`K.authErr*`).
  /// Eskiden sağlayıcı sabit Türkçe metin döndürüyor, bu sözlük de o metni
  /// Kurmancîye eşliyordu: yeni bir hata eklemek iki yerde birbirine bağlı
  /// bir dizgi gerektiriyordu ve eşleşmeyen her şey sessizce genel cümleye
  /// düşüyordu. Anahtar olmayan dizgi (eski/üçüncü taraf ham metin) Türkçede
  /// olduğu gibi gösterilir, Kurmancîde genel hata cümlesine iner.
  String translateAuthError(String message) {
    if (Tr.hasKey(message)) return t(message);
    return isKu ? t(K.authErrGeneric) : message;
  }
}

/// [BuildContext.secondLabel]in dili parametre olarak taşıyan bileşenler
/// (`isKu` alan kartlar) için eşi: aynı ayar, aynı kaynak.
String? secondLabelFor(
  BuildContext context,
  String key, {
  required bool isKu,
  Map<String, String>? params,
}) {
  if (!BilingualLabelsProvider.isEnabledIn(context)) return null;
  return Tr.counterpart(key, isKu: isKu, params: params);
}

/// Category names in both languages. Görünen ad [Tr] tablosundadır.
class CategoryNames {
  /// Stable category IDs (also used as keys in stores / SQL).
  static const Map<String, String> _keys = {
    'Ziman': K.catZiman,
    'Çand': K.catCand,
    'Dîrok': K.catDirok,
    'Edebiyat': K.catEdebiyat,
    'Cografya': K.catCografya,
    'Muzîk': K.catMuzik,
    'Siyaset': K.catSiyaset,
    'Paradigma': K.catParadigma,
    'Teknolojî': K.catTeknoloji,
    'Sînema': K.catSinema,
    'Cîhan': K.catCihan,
    'Tevlihev': K.catTevlihev,
  };

  static String tr(String kuName) {
    final key = _keys[kuName];
    if (key == null) return kuName;
    return Tr.of(key, AppLanguage.tr);
  }

  /// Depo/sunucu kimlikleri: oyuncuya ham gösterilmez (2026-10-21 "crowd •
  /// 10 soru"). Karışık/rastgele kategori "Tevlihev/Karışık"tır, kalabalık
  /// odası "Pêşbirka komê/Grup yarışı".
  static const Map<String, String> _slugKeys = {
    'mixed': K.catTevlihev,
    'random': K.catTevlihev,
    'crowd': K.crowdRoomTitle,
  };

  static String localized(String kuName, bool isKu) {
    final key = _keys[kuName] ?? _slugKeys[kuName.trim().toLowerCase()];
    if (key == null) {
      // Çoklu kategorili oda etiketi: adlar `, ` ile birleşik gelir; her
      // biri ayrı yerelleştirilir.
      if (kuName.contains(', ')) {
        return kuName
            .split(', ')
            .map((part) => localized(part, isKu))
            .join(', ');
      }
      return kuName;
    }
    return Tr.forKu(key, isKu);
  }

  /// Ana ekran konu karosunun dar yazı sütununa sığan KISA adlar. Karo adı
  /// tek satırdır ve sarmaz; "Bilim ve Düşünce / Zanist û Raman" dört satıra
  /// sarıp ızgaranın satır boylarını bozuyordu (2026-09-30 simülatör).
  /// Burada olmayan konunun tam adı zaten kısadır.
  static const Map<String, String> _tileKeys = {
    'Paradigma': K.catParadigmaTile,
  };

  /// Karoda yazılan ad: kısa adı varsa o, yoksa [localized]. Tam ad başka
  /// her yerde ([localized]) olduğu gibi kalır.
  /// Karoda yazılan adın metin anahtarı ([tile] ile aynı seçim); bilinmeyen
  /// konuda `null`. İki dilli etiket öbür dili bu anahtardan okur.
  static String? tileKey(String kuName) => _tileKeys[kuName] ?? _keys[kuName];

  static String tile(String kuName, bool isKu) {
    final key = _tileKeys[kuName];
    if (key == null) return localized(kuName, isKu);
    return Tr.forKu(key, isKu);
  }
}

/// Seviye adları veri katmanında Kurmancî sabit olarak tutulur (kimlik
/// görevi görür). Türkçe arayüzde bunlar çevrilmeden gösteriliyordu:
/// seviye haritasında "Destpêk / Bingeh / Navîn / Pêşketî / Mamoste"
/// yazıyor, arayüzün geri kalanı Türkçe kalıyordu (2026-07-22 canlı UX
/// denetimi). [CategoryNames] ile aynı desen.
class LevelNames {
  const LevelNames._();

  static const Map<String, String> _keys = {
    'Destpêk': K.levelDestpek,
    'Bingeh': K.levelBingeh,
    'Navîn': K.levelNavin,
    'Pêşketî': K.levelPesketi,
    'Mamoste': K.levelMamoste,
  };

  static String tr(String kuName) {
    final key = _keys[kuName];
    if (key == null) return kuName;
    return Tr.of(key, AppLanguage.tr);
  }

  static String localized(String kuName, bool isKu) {
    final key = _keys[kuName];
    if (key == null) return kuName;
    return Tr.forKu(key, isKu);
  }
}

// `QuizStrings` ve `CommonStrings` burada duruyordu: `Tr`/`K` kayıt
// defterine paralel, ikinci bir metin sözlüğü. Defterde zaten var olan
// anahtarları yeniden tanımlıyorlardı ve bazılarını FARKLI karşılıklarla:
// Ayarlar'daki Kaydet düğmesi Kurmancî "Biparêze" derken Avatar, Profil
// ve Quiz ekranlarındaki aynı düğme "Tomar bike" diyordu. Aynı işlev,
// aynı uygulama, iki ayrı kelime — projenin 2026-07-30'da bilerek
// düzelttiği kusurun ("oyuncu aynı şeyi iki adla görmemeli") tekrarı.
//
// Üstelik bu sözlük `Tr.missingFor` bütünlük testinin ve Kurmancî alfabe
// bekçisinin dışındaydı. 2026-07-31 denetiminde kaldırıldı; 13 çağrı yeri
// `Tr.forKu(K.…)`ye çevrildi. Bir kavramın tek Kurmancî karşılığı olur ve
// o karşılık defterde durur.
