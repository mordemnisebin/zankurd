// Tasarım kurulu tur 6 (5 denetçi + ChatGPT): "Özel oda oluştur"daki
// SEÇİLMEMİŞ seçenek çipleri (oyuncu sayısı, soru sayısı, süre, ücret) devre
// dışı gibi görünüyordu: çerçeve en açık ton (tx3) idi ve dokunma yüksekliği
// küçük algılanıyordu.
//
// Niçin sessiz kaldı: seçili hâlin stili ölçülüyordu (kurul_secili_stil_test),
// seçilmemişin çerçeve/yazı tonu ve yüksekliği hiçbir testte yoktu; kusur
// yalnız ekran görüntüsünde "soluk" olarak göründü. Bekçi: çerçeve ikincil
// metin tonu (tx2), yazı tam opak ana metin (tx) ve yükseklik >= 44, iki temada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'seçilmemiş çip devre dışı görünmez (${dark ? "gece" : "gündüz"})',
      (tester) async {
        final t = dark ? SahneTokens.night : SahneTokens.day;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  child: SahnePickChip(
                    label: '16',
                    selected: false,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(find.text('16'));
        expect(text.style?.color, t.tx);
        expect(text.style?.color?.a, 1.0, reason: 'Yazı tam opak olmalı.');
        expect(
          tester.getSize(find.byType(SahnePickChip)).height,
          greaterThanOrEqualTo(44),
        );
        final material = tester.widgetList<Material>(
          find.descendant(
            of: find.byType(SahnePickChip),
            matching: find.byType(Material),
          ),
        );
        final borders = material
            .map((m) => m.shape)
            .whereType<ShapeBorder>()
            .map((s) => s is OutlinedBorder ? s.side.color : null)
            .whereType<Color>();
        expect(borders, contains(t.tx2), reason: 'Çerçeve tx3 değil tx2.');
      },
    );
  }
}
