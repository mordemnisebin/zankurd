import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider({String initialLang = 'ku', SharedPreferences? preferences})
    : this._(initialLang, preferences);

  LanguageProvider._(String initialLang, this._preferences)
    : _lang = _normalize(initialLang);

  static const _storageKey = 'zankurd.language';

  static Future<LanguageProvider> load() async {
    final preferences = await SharedPreferences.getInstance();
    return LanguageProvider(
      initialLang: preferences.getString(_storageKey) ?? 'ku',
      preferences: preferences,
    );
  }

  static String _normalize(String lang) => lang == 'tr' ? 'tr' : 'ku';

  String _lang;
  final SharedPreferences? _preferences;

  String get lang => _lang;
  bool get isKu => _lang == 'ku';

  void setLang(String lang) {
    final nextLang = _normalize(lang);
    if (_lang != nextLang) {
      _lang = nextLang;
      _preferences?.setString(_storageKey, nextLang);
      notifyListeners();
    }
  }

  void toggle() => setLang(isKu ? 'tr' : 'ku');
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

  /// Returns [ku] if Kurdish is active, [tr] if Turkish.
  String s(String ku, String tr) => isKu ? ku : tr;

  /// Translates Supabase Auth Turkish error messages to Kurdish if active.
  String translateAuthError(String turkishMessage) {
    if (!isKu) return turkishMessage;
    switch (turkishMessage) {
      case 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.':
        return 'Girêdan çênebû. Înternet an DNS kontrol bike.';
      case 'Beklenmeyen bir hata oluştu.':
        return 'Çewtiyeke nediyar rû da.';
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
