import 'package:shared_preferences/shared_preferences.dart';

/// Bildirim ayarlarını yöneten servis.
/// Firebase Messaging bağımlılığı projeye eklendiğinde
/// gerçek push bildirimleri burada yapılandırılır.
class NotificationService {
  NotificationService._(
    this._preferences,
    this._enabled,
    this._hour,
    this._minute,
  );

  static const _enabledKey = 'zankurd.notifications.enabled';
  static const _hourKey = 'zankurd.notifications.hour';
  static const _minuteKey = 'zankurd.notifications.minute';

  static NotificationService? _instance;

  static Future<NotificationService> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    return _instance = NotificationService._(
      preferences,
      preferences?.getBool(_enabledKey) ?? false,
      preferences?.getInt(_hourKey) ?? 19,
      preferences?.getInt(_minuteKey) ?? 0,
    );
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  bool _enabled;
  int _hour;
  int _minute;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  String get timeDisplay =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _preferences?.setBool(_enabledKey, value);
    if (value) {
      await _scheduleDaily();
    } else {
      await _cancelAll();
    }
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    await _preferences?.setInt(_hourKey, hour);
    await _preferences?.setInt(_minuteKey, minute);
    if (_enabled) {
      await _scheduleDaily();
    }
  }

  /// Günlük hatırlatıcıyı zamanlar.
  /// Firebase Messaging entegrasyonu yapıldığında bu metod
  /// gerçek FCM topic subscription ve local notification kullanır.
  Future<void> _scheduleDaily() async {
    // TODO: firebase_messaging veya flutter_local_notifications
    // entegrasyonu yapıldığında burada gerçek zamanlama yapılacak.
    // Şimdilik ayarlar sadece kalıcı olarak saklanıyor.
  }

  Future<void> _cancelAll() async {
    // TODO: Mevcut zamanlanmış bildirimleri iptal et.
  }
}
