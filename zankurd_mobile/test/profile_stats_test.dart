import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-22 canlı UX denetimi (P0-4): quiz bitirdikten sonra profildeki
/// "Oyun" karosu 0 gösteriyordu. Karo `roomsPlayed` okuyordu; o yalnız
/// çevrimiçi oda sayısıdır ve solo quiz onu artırmaz. Karo artık tüm
/// modlarda cevaplanan soru sayısını gösterir.
void main() {
  testWidgets('cevaplanan soru karosu solo oyunda da artar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await MistakeStore.load();
    // Bir yanlış + bir doğru: toplam 2 cevaplanan soru.
    await store.markMistake('stat-q1', category: 'Ziman');
    await store.markResolved('stat-q1');

    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pump();
    for (
      var i = 0;
      i < 40 && find.text('Cevaplanan Soru').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Cevaplanan Soru'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Oyun'), findsNothing);
  });

  testWidgets('hiç oynamamış oyuncuya lig rozeti şişirilmez', (tester) async {
    // 2026-07-26 denetimi: profilde rozet "Altın Lig" derken hemen altındaki
    // karo "Sıralama —" diyordu. İki gösterge aynı ekranda birbirini
    // yalanlıyordu; sebep farklı kapılardı — rozet sunucudan gelen
    // `roomsPlayed`e, karo yerel cevaplanan soru sayısına bakıyordu.
    //
    // Mock depo "benim istatistiğim" olarak tablonun birincisini döndürür
    // (rank 1, roomsPlayed 50); hiç soru cevaplamamış bir oyuncu bu yüzden
    // altın rozet görüyordu.
    // Önceki test aynı süreçte MistakeStore tekilini doldurmuştu; tekil
    // sıfırlanmazsa bu test "2 soru cevaplamış" bir oyuncuyla koşar.
    MistakeStore.resetInstance();
    SharedPreferences.setMockInitialValues({});
    await MistakeStore.load();

    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40 && find.text('Sıralama').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Bronz Lig'), findsOneWidget);
    expect(find.text('Altın Lig'), findsNothing);
    // Rozet ile karo aynı kapıdan geçer: ikisi de boş kalmalı.
    expect(find.text('#1'), findsNothing);
  });
}
