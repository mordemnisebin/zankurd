import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// "Güvenli çocuk modu" — YALNIZCA CİHAZ TARAFI teknik kilitler.
///
/// ÖNEMLİ: Bu mod hukuki bir ebeveyn onayı sistemi DEĞİLDİR ve sunucu
/// tarafında zorlanmaz. Yalnız bu cihazdaki istemci arayüzünde sosyal ve
/// paylaşım özelliklerini gizler/engeller. Sunucu koruması varmış gibi
/// davranılmamalıdır.
///
/// Mod açıldığında hiçbir kullanıcı verisi (arkadaşlar, ilerleme, hesap)
/// SİLİNMEZ; yalnız erişim gizlenir. Mod kapatılınca her şey geri gelir.
class ChildSafetyProvider extends ChangeNotifier {
  ChildSafetyProvider({bool initialEnabled = false})
    : _enabled = initialEnabled;

  static const _storageKey = 'zankurd.childSafeMode';

  bool _enabled;
  bool get enabled => _enabled;

  static Future<ChildSafetyProvider> load() async {
    bool value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_storageKey) ?? false;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'child_safety_load');
    }
    return ChildSafetyProvider(initialEnabled: value);
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'child_safety_persist');
    }
  }

  // --- Cihaz-tarafı özellik kapıları (mod açıkken kapalı) ---

  /// Arkadaş arama.
  bool get allowFriendSearch => !_enabled;

  /// Yeni arkadaş isteği gönderme.
  bool get allowFriendRequests => !_enabled;

  /// Serbest metin oda sohbeti.
  bool get allowRoomChat => !_enabled;

  /// Profili herkese açık yapan görünürlük eylemleri.
  bool get allowPublicProfile => !_enabled;

  /// Dış paylaşım (sonuç paylaşma vb.) butonları.
  bool get allowExternalShare => !_enabled;

  /// Mod açıkken kişisel ad yerine güvenli, nötr bir görünen ad kullanılır.
  String safeDisplayName(String realName) {
    if (!_enabled) return realName;
    return 'Fêrkar';
  }

  /// Serbest sohbet yerine sunulabilecek hazır güvenli mesajlar.
  static const List<String> safeQuickMessages = [
    'Silav!',
    'Aferîn!',
    'Em dest pê bikin?',
    'Spas!',
    'Xatir bi te.',
  ];
}
