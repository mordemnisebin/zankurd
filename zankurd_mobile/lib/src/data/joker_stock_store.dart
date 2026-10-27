import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';
import 'local_progress_scope.dart';

/// Mağazadan alınan joker hakları ("Joker paketi (3)", 2026-10-27).
///
/// Paket jetonla SUNUCUDA ödenir (`spend_coins`, `purchase_joker_pack_3`);
/// burada yalnız kalan hak sayısı tutulur. Soru sırasında joker önce günün
/// bedava hakkından, sonra bu stoktan, en son jetondan ödenir; stoktan
/// kullanımda `spend_coins` çağrılmaz (paket parası zaten alındı).
///
/// Anahtar `zankurd.missions.` önekinde: `LocalProgressScope` kullanıcıya
/// bağlar, çıkış/hesap silmede temizler (bkz. [FreeWildcardStore]).
class JokerStockStore {
  const JokerStockStore._();

  /// Bir paketteki hak sayısı.
  static const packSize = 3;

  static String get _key =>
      LocalProgressScope.physical('zankurd.missions.jokerStock');

  static Future<int> count() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getInt(_key) ?? 0;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'joker_stock_read');
      return 0;
    }
  }

  /// [amount] hak ekler; yeni toplamı döner.
  static Future<int> add(int amount) async {
    final preferences = await SharedPreferences.getInstance();
    final next = (preferences.getInt(_key) ?? 0) + amount;
    await preferences.setInt(_key, next);
    return next;
  }

  /// Bir hak harcar. Stok varsa ve yazıldıysa `true`.
  static Future<bool> consume() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final current = preferences.getInt(_key) ?? 0;
      if (current <= 0) return false;
      return await preferences.setInt(_key, current - 1);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'joker_stock_write');
      return false;
    }
  }
}
