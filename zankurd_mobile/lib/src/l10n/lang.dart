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
  };

  /// Optional Kurmanci display labels (ID stays the map key).
  static const Map<String, String> _kuDisplay = {'Cografya': 'Erdnîgarî'};

  static String tr(String kuName) => _kuToTr[kuName] ?? kuName;

  static String localized(String kuName, bool isKu) =>
      isKu ? (_kuDisplay[kuName] ?? kuName) : tr(kuName);
}
