import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';
import 'local_progress_scope.dart';

/// Günde bir kez, jetonsuz joker hakkı.
///
/// Yeni oyuncunun jetonu (8–19) en ucuz jokerin fiyatının (20) altında
/// kalıyordu; joker özelliği ilk günlerde hiç denenemiyordu. Bu depo "bugün
/// bedava joker hakkı kullanıldı mı" bilgisini tutar; sunucu jeton mantığı
/// (`spend_coins`) değişmez, bedava kullanımda o çağrı hiç yapılmaz.
///
/// Anahtar `zankurd.missions.` önekindedir: `LocalProgressScope` bu öneki
/// kullanıcıya bağlar ve hesap silme/çıkışta yerel ilerlemeyle birlikte
/// temizler. Anahtar HER çağrıda yeniden hesaplanır (önbellekli örnek yok):
/// hesap değişince önceki kullanıcının günü yeni kullanıcıya sızmaz.
///
/// "Gün" cihazın yerel gün sınırıdır (gece yarısı yenilenir), UTC değil.
class FreeWildcardStore {
  const FreeWildcardStore._();

  static String get _key =>
      LocalProgressScope.physical('zankurd.missions.freeWildcardDay');

  /// `yyyy-MM-dd`, yerel gün.
  static String dayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  /// Bugün için bedava hak hâlâ duruyor mu?
  ///
  /// Depo okunamazsa `false`: kalıcı yazamayan bir cihazda hakkı her açılışta
  /// yeniden vermek sınırsız bedava joker olurdu.
  static Future<bool> isAvailable({DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_key) != dayKey(now ?? DateTime.now());
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'free_wildcard_read');
      return false;
    }
  }

  /// Bugünkü hakkı harcar. Hak vardıysa ve yazıldıysa `true`; zaten
  /// harcanmışsa ya da yazılamadıysa `false`.
  static Future<bool> consume({DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final today = dayKey(now ?? DateTime.now());
      if (preferences.getString(_key) == today) return false;
      return await preferences.setString(_key, today);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'free_wildcard_write');
      return false;
    }
  }
}
