import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// "Süresiz mod" tercihini yönetir: tek başına oynanan turlarda soru sayacı
/// çalışmaz.
///
/// ## Niçin
///
/// WCAG 2.2.1 (Level A) zaman sınırı olan içerikte kullanıcıya sınırı
/// kapatma, uzatma ya da ayarlama yollarından en az birini vermeyi şart
/// koşar. ZanKurd'da öğrenme ve tekrar akışları zaten sayaçsız
/// (`enableTimer: false`), ama kategori turu ve alıştırma turu sayaçlıydı ve
/// kapatmanın hiçbir yolu yoktu. Sayaç okuma hızına, motor becerisine ve
/// dikkate doğrudan bağlıdır; ikinci dilde okuyan biri için de fazladan yük
/// üretir — bu uygulamanın kullanıcılarının çoğu tam olarak bu durumda.
///
/// ## Niçin YALNIZ solo ve alıştırma
///
/// Süresiz mod rekabetçi hiçbir akışta geçerli değildir: oda, 1v1, turnuva,
/// yarışma, günlük tur ve bot yarışı sayaçlı kalır. Sebep basit — orada
/// süre puanın bir parçasıdır ve kapatmak turu adaletsiz yapar.
///
/// Bu ayrım güvenle çizilebiliyor çünkü ödül yerleşimi zaten aynı sınırı
/// kullanıyor: `quiz_reward_settlement_service` solo ve alıştırma turlarında
/// erken dönüp sıfır coin veriyor (`widget.practice || room.id == null`).
/// Yani süresiz modun açık olduğu turlar hiçbir sunucu ödülünü ya da lig
/// puanını beslemiyor; kapatılan şey yalnız oyuncunun kendi baskısı.
class UntimedModeProvider extends ChangeNotifier {
  UntimedModeProvider({bool initialEnabled = false})
    : _enabled = initialEnabled;

  static const _storageKey = 'zankurd.untimedSolo';

  bool _enabled;

  bool get enabled => _enabled;

  static Future<UntimedModeProvider> load() async {
    var value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_storageKey) ?? false;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'untimed_mode_load');
    }
    return UntimedModeProvider(initialEnabled: value);
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'untimed_mode_persist');
    }
  }

  /// Ağaçta sağlayıcı yoksa `false` döner.
  ///
  /// [ReducedMotionProvider.isReducedIn] ile aynı gerekçe: bu bir
  /// İYİLEŞTİRME'dir, widget'lar onu okuyabilmek için sağlayıcı zorunlu
  /// kılmamalı. Sağlayıcısız bir testte ya da ekran turu aracında
  /// `ProviderNotFoundException` ile çökmek yerine güvenli varsayılana —
  /// "sayaç açık", yani mevcut davranış — düşer.
  static bool isEnabledIn(BuildContext context) {
    try {
      return Provider.of<UntimedModeProvider>(context, listen: false).enabled;
    } on ProviderNotFoundException {
      return false;
    }
  }
}
