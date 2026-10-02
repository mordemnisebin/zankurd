import 'package:shared_preferences/shared_preferences.dart';

/// Silme kabul edilmeden hesap temizliğini başarılı göstermez.
/// SharedPreferences başarısız yazımda bile önbelleği değiştirebilir; sonraki
/// denemenin diskte kalmış anahtarları görebilmesi için onu yeniden yükler.
Future<void> removePersistedPreferenceKeys(
  SharedPreferences? preferences,
  Iterable<String> keys,
) async {
  if (preferences == null) return;
  try {
    for (final key in keys.toList(growable: false)) {
      if (!await preferences.remove(key)) {
        throw StateError('Local progress removal was not persisted.');
      }
    }
  } catch (_) {
    await preferences.reload();
    rethrow;
  }
}
