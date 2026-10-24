import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Bağlamsal bildirim kartının gösterilip gösterilmeyeceğine karar verir.
///
/// Kurallar:
/// - İlk 2 turu tamamlamadan gösterme (bağlam oluşsun).
/// - "Şimdi değil"den sonra 7 gün bekle.
/// - Toplamda en fazla 2 kez sor.
/// - İzin zaten verilmişse gösterme.
class NotificationPromptPolicy {
  NotificationPromptPolicy._(this._prefs);

  static const _roundsKey = 'zankurd.notifPrompt.rounds';
  static const _askedCountKey = 'zankurd.notifPrompt.asked';
  static const _laterAtKey = 'zankurd.notifPrompt.laterAt';
  static const _grantedKey = 'zankurd.notifPrompt.granted';

  static const _minRounds = 2;
  static const _maxAsks = 2;
  static const _cooldownDays = 7;

  final SharedPreferences _prefs;

  static Future<NotificationPromptPolicy> load() async =>
      NotificationPromptPolicy._(await SharedPreferences.getInstance());

  int get _rounds => _prefs.getInt(_roundsKey) ?? 0;
  int get _asked => _prefs.getInt(_askedCountKey) ?? 0;
  int? get _laterAtMs => _prefs.getInt(_laterAtKey);
  bool get _granted => _prefs.getBool(_grantedKey) ?? false;

  Future<void> recordRoundCompleted() async {
    await _prefs.setInt(_roundsKey, _rounds + 1);
  }

  /// Kart gösterilmeli mi?
  Future<bool> shouldShow() async {
    if (_granted) return false;
    if (_rounds < _minRounds) return false;
    if (_asked >= _maxAsks) return false;

    final laterMs = _laterAtMs;
    if (laterMs != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - laterMs;
      if (elapsed < const Duration(days: _cooldownDays).inMilliseconds) {
        return false;
      }
    }

    final ns = NotificationService.instance;
    if (ns != null && await ns.hasSystemPermission()) return false;

    return true;
  }

  Future<void> recordLater() async {
    await _prefs.setInt(_askedCountKey, _asked + 1);
    await _prefs.setInt(_laterAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> recordGranted() async {
    await _prefs.setBool(_grantedKey, true);
  }

  Future<void> clear() async {
    await _prefs.remove(_roundsKey);
    await _prefs.remove(_askedCountKey);
    await _prefs.remove(_laterAtKey);
    await _prefs.remove(_grantedKey);
  }
}
