// Seri yalnız quiz sonuç ekranından yazılıyordu: her gün yalnız ders bitiren
// ya da sırayla düello oynayan oyuncunun serisi sıfırlanıyor, akşamki
// "Bugün hiç oynamadın" uyarısı da susmuyordu. Hiçbir test bunu sormuyordu,
// çünkü seri testleri yalnız StreakStore'u doğrudan çağırıyordu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakStore.resetInstance();
  });

  test('recordActivity bugünü işler; aynı gün ikinci kez saymaz', () async {
    await StreakStore.recordActivity();
    await StreakStore.recordActivity();
    final store = await StreakStore.load();
    expect(store.best, 1);
  });

  test('ders bitirme ve düello turu seriyi işler', () {
    for (final path in [
      'lib/src/screens/learning_screen.dart',
      'lib/src/screens/async_duel/async_duel_play_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('StreakStore.recordActivity()'),
        reason: path,
      );
    }
  });
}
