import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';
import 'local_progress_scope.dart';
import 'zankurd_repository.dart';

/// Mağazadan alınan joker hakları ("Joker paketi (3)", 2026-10-27).
///
/// Paket jetonla SUNUCUDA ödenir (`spend_coins`, `purchase_joker_pack_3`);
/// burada yalnız kalan hak sayısı tutulur. Soru sırasında joker önce günün
/// bedava hakkından, sonra bu stoktan, en son jetondan ödenir; stoktan
/// kullanımda `spend_coins` çağrılmaz (paket parası zaten alındı).
///
/// Anahtar `zankurd.missions.` önekinde: `LocalProgressScope` kullanıcıya
/// bağlar, çıkış/hesap silmede temizler (bkz. [FreeWildcardStore]).
///
/// 2026-10-28: haklar HESAPTA da tutulur (`get_joker_stock`,
/// `consume_joker_stock`): eskiden yalnız cihazdaydı, uygulama silinince ya
/// da telefon değişince parası ödenmiş haklar kayboluyordu. Yerel sayı
/// çevrimdışı önbellektir; [syncFromServer] sunucu değerini yazar.
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

  /// Sunucudaki kalan hakkı yerel önbelleğe yazar ve döner. Sunucuya
  /// ulaşılamazsa (çevrimdışı, misafir oturumu yok, göç yok) yerel sayı
  /// değişmez ve döner.
  static Future<int> syncFromServer(ZanKurdRepository repository) async {
    int? server;
    try {
      server = await repository.loadJokerStock();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'joker_stock_sync');
    }
    if (server == null) return count();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_key, server);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'joker_stock_sync_write');
    }
    return server;
  }

  /// Bir hak harcar: yerelde hemen, sunucuda arka planda. Sunucu düşüşü
  /// başarısızsa (çevrimdışı) bir sonraki eşitleme hakkı geri verir —
  /// oyuncunun aleyhine değil lehine yanılır.
  static Future<bool> consumeWith(ZanKurdRepository repository) async {
    final ok = await consume();
    if (ok) {
      try {
        await repository.consumeJokerStock();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'joker_stock_server_use');
      }
    }
    return ok;
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
