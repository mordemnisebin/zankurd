// 2026-10-20 TASARIM KURULU (tur 6b): sonuç ekranı dikey ritim.
//
// ## Kusur
//
// Sonuçta yıldız → başlık → puan → alt satır → sayım kartı → ödül kartı
// arası boşluklar tutarsızdı (8, 12, 16 ve 28 karışık): başlık yıldıza
// yapışık, kartlar birbirinden farklı mesafede duruyordu. İki denetçi
// "boşluklar rastgele" dedi.
//
// ## Niçin sessiz kalırdı
//
// Aralıklar tek tek `SizedBox` sabitleridir; hiçbiri derleme ya da taşma
// hatası vermez, mevcut testler yalnız SIRAyı ölçer. Bu dosya mesafeyi
// ölçer: amblem→başlık 12, alt satır→sayım kartı 20, sayım→ödül 20.
//
// Alt çubuğun son satırı örtmemesi ayrı bekçidedir:
// `sahne_result_template_test.dart` (`alt boşluk`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('amblem→başlık 12, alt satır→sayım 20, sayım→ödül 20', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: SahneResultScaffold(
          hero: const SahneResultHero(
            emblem: SizedBox(key: ValueKey('amb'), height: 44),
            title: 'Bitti',
            value: 7,
            caption: 'puan',
          ),
          stats: const SahneResultStats(
            stats: [
              SahneResultStat(
                leading: SizedBox(),
                value: 2,
                label: 'Doğru',
                showWhenZero: true,
              ),
            ],
          ),
          rewards: const SahneResultRewards(coins: 30, xp: 100),
          sections: const [Text('bölüm')],
          primary: SahneResultAction(label: 'Tamam', onPressed: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final emblem = tester.getRect(find.byKey(const ValueKey('amb')));
    final title = tester.getRect(find.text('Bitti'));
    final caption = tester.getRect(find.text('puan'));
    final stats = tester.getRect(find.byType(SahneResultStats));
    final rewards = tester.getRect(find.byType(SahneResultRewards));

    expect(title.top - emblem.bottom, closeTo(12, 6)); // metin iç boşluğu
    // Kahraman bloğunun alt dolgusu (16) dahil, ölçü metnin alt kenarından.
    expect(stats.top - caption.bottom, closeTo(20, 5));
    expect(rewards.top - stats.bottom, closeTo(20, 0.5));
  });
}
