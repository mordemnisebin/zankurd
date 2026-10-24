import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// "İki dilli etiketler" tercihi: gezinme sekmeleri, ekran ve bölüm
/// başlıkları ve konu kartlarında seçili dilin altında/üstünde öbür dilin
/// aynı anahtarlı karşılığı küçük yazılır.
///
/// ## Niçin
///
/// 2026-10-20 kullanıcı geri bildirimi: sade arayüzde bile oyuncular bir
/// şeyi bulmakta zorlanıyor. Kitle iki dilli; Kurmancîyi öğrenen Türkçe
/// arayüzde, Kurmancî arayüzü seçen de bazen Türkçe sözle yön buluyor.
/// Varsayılan AÇIK; Ayarlar'dan kapatılınca her yer tek dile döner.
///
/// Düğme, soru, şık, açıklama ve gövde metni HER ZAMAN tek dildedir; ikinci
/// dil yalnız yön bulduran etiketlerdedir.
class BilingualLabelsProvider extends ChangeNotifier {
  BilingualLabelsProvider({bool initialEnabled = true})
    : _enabled = initialEnabled;

  static const storageKey = 'zankurd.bilingualLabels';

  bool _enabled;

  bool get enabled => _enabled;

  static Future<BilingualLabelsProvider> load() async {
    var value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(storageKey) ?? true;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'bilingual_labels_load');
    }
    return BilingualLabelsProvider(initialEnabled: value);
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'bilingual_labels_persist');
    }
  }

  /// Ağaçta sağlayıcı yoksa varsayılan (AÇIK) döner ve dinler; sağlayıcısız
  /// bir testte ya da ekran turunda çökmez.
  static bool isEnabledIn(BuildContext context) {
    try {
      return Provider.of<BilingualLabelsProvider>(context).enabled;
    } on ProviderNotFoundException {
      return true;
    } on Object {
      try {
        return Provider.of<BilingualLabelsProvider>(
          context,
          listen: false,
        ).enabled;
      } on ProviderNotFoundException {
        return true;
      }
    }
  }
}
