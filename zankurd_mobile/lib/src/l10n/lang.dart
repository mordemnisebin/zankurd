import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LanguageProvider extends ChangeNotifier {
  String _lang = 'ku';
  String get lang => _lang;
  bool get isKu => _lang == 'ku';

  void setLang(String lang) {
    if (_lang != lang) {
      _lang = lang;
      notifyListeners();
    }
  }

  void toggle() => setLang(isKu ? 'tr' : 'ku');
}

/// Helper to get bilingual string — call from build() only.
extension LangContext on BuildContext {
  LanguageProvider get langProvider => Provider.of<LanguageProvider>(this);

  bool get isKu => Provider.of<LanguageProvider>(this).isKu;

  /// Returns [ku] if Kurdish is active, [tr] if Turkish.
  String s(String ku, String tr) => isKu ? ku : tr;
}

/// Category names in both languages.
class CategoryNames {
  static const Map<String, String> _kuToTr = {
    'Ziman': 'Dil',
    'Çand': 'Kültür',
    'Dîrok': 'Tarih',
    'Edebiyat': 'Edebiyat',
    'Cografya': 'Coğrafya',
    'Muzîk': 'Müzik',
  };

  static String tr(String kuName) => _kuToTr[kuName] ?? kuName;

  static String localized(String kuName, bool isKu) =>
      isKu ? kuName : tr(kuName);
}
