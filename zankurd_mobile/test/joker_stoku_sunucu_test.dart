/// Joker paketi hakları hesapta (2026-10-28) bekçisi.
///
/// ## Kusur
///
/// "Joker paketi (3)" jetonla sunucuda ödeniyordu ama kalan hak yalnız
/// cihazdaydı; uygulama silinince ya da telefon değişince parası ödenmiş
/// haklar kayboluyordu (gece kod denetimi: GPT-6 Sol).
///
/// ## Kural
///
/// * Sunucu değeri varsa yerel önbellek ona eşitlenir.
/// * Sunucuya ulaşılamazsa (null) yerel sayı korunur.
/// * Kullanım yerelden hemen düşer ve sunucuya bildirilir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/joker_stock_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

class _Repo extends MockZanKurdRepository {
  int? server;
  int serverUses = 0;

  @override
  Future<int?> loadJokerStock() async => server;

  @override
  Future<void> consumeJokerStock() async => serverUses++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('yeni cihazda hesaptaki haklar geri gelir', () async {
    final repo = _Repo()..server = 3;
    expect(await JokerStockStore.count(), 0);
    expect(await JokerStockStore.syncFromServer(repo), 3);
    expect(await JokerStockStore.count(), 3);
  });

  test('sunucuya ulaşılamazsa yerel sayı korunur', () async {
    await JokerStockStore.add(2);
    expect(await JokerStockStore.syncFromServer(_Repo()), 2);
  });

  test('kullanım yerelden düşer ve sunucuya bildirilir', () async {
    final repo = _Repo();
    await JokerStockStore.add(1);
    expect(await JokerStockStore.consumeWith(repo), isTrue);
    expect(await JokerStockStore.count(), 0);
    expect(repo.serverUses, 1);
    expect(await JokerStockStore.consumeWith(repo), isFalse);
    expect(repo.serverUses, 1, reason: 'hak yoksa sunucuya gidilmez');
  });
}
