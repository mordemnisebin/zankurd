// 9. kurul, kare 01/20/26 (Gemini + Grok): konu kartında ikon + metin sola
// yapışık, sağda orantısız boşluk; kartlar arası sıkışıktı (8 pt).
//
// Niçin sessiz kaldı: bekçiler sütun sayısı, sarma ve boy eşitliğini ölçer;
// iç boşluğun ve aralığın "ferah" olup olmadığı bir sayı değildi. Şimdi:
// kart iç sol boşluğu 16, ızgara aralığı 12 (yatay ve dikey), işaret 28'lik
// kutu, metin işaretle dikey ortalı.
//
// 2026-10-20 renk ve canlılık: karo konunun renginde DOLUDUR ve ad ikonun
// ALTINDADIR (maket); bekçi aynı ferahlığı yeni dizilişte ölçer: iç sol
// boşluk 16, üst boşluk 12, işaret 28'lik kutu, ad işaretle aynı sol hizada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('konu kartı: sol boşluk 16, aralık 12, işaret 28 ve ortalı', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeTopicGrid(
                isKu: false,
                categories: const ['Ziman', 'Çand', 'Dîrok', 'Cîhan'],
                progress: const {},
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Rect tile(String c) =>
        tester.getRect(find.byKey(ValueKey('home-topic-$c')));
    final a = tile('Ziman');
    final b = tile('Çand');
    final c = tile('Dîrok');
    expect(b.left - a.right, closeTo(12, 1), reason: 'yatay aralık');
    expect(c.top - a.bottom, closeTo(12, 1), reason: 'dikey aralık');

    final mark = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('home-topic-Ziman')),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 28 && w.height == 28,
        ),
      ),
    );
    expect(mark.left - a.left, greaterThanOrEqualTo(16));
    expect(mark.top - a.top, greaterThanOrEqualTo(12));
    expect(mark.width, 28);
    // Ad + öbür dildeki küçük satır bir blok olarak işaretin ALTINDA, aynı
    // sol hizada durur.
    final texts = find.descendant(
      of: find.byKey(const ValueKey('home-topic-Ziman')),
      matching: find.byType(Text),
    );
    final text = texts
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .reduce((a, b) => a.expandToInclude(b));
    expect(text.top, greaterThanOrEqualTo(mark.bottom));
    expect(text.left, closeTo(mark.left, 1));
  });
}
