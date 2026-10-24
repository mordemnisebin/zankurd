import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';
import 'local_progress_scope.dart';

/// Günün yarışmasının BUGÜN oynanıp oynanmadığını yerelde tutar.
///
/// Günün yarışması hatırlatması (19:00) yalnız oynanmadıysa çalmalı; sunucu
/// "bugün katıldım mı" sorgusu sunmuyor ve her açılışta ağ çağrısı yapmak
/// pahalı. Yarışma sonucu yazılırken (`quiz_result_screen`) gün buraya da
/// işlenir. Başka cihazda oynanan yarışma bu cihazı bilgilendirmez: en kötü
/// ihtimalle aynı gün bir hatırlatma fazladan gelir, oynayan kullanıcıya
/// "oynamadın" denmez çünkü metin yalnız davet eder.
class ContestPlayStore {
  const ContestPlayStore._();

  static String get _key =>
      LocalProgressScope.physical('zankurd.contest.playedDay');

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Bugünün (yerel gün) yarışması oynandı mı.
  static Future<bool> playedToday({DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_key) == _dayKey(now ?? DateTime.now());
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'contest_play_store');
      return false;
    }
  }

  /// Bugünün yarışmasını oynandı olarak işler.
  static Future<void> markPlayed({DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, _dayKey(now ?? DateTime.now()));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'contest_play_store');
    }
  }
}
