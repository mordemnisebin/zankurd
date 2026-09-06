/// `KilimBoard` — turun dokuma kaydı.
///
/// ## Korunan karar
///
/// Doğru cevap DOLU altın baklava, yanlış cevap İÇİ BOŞ çerçevedir.
/// Beklenen eşleme yeşil/kırmızıydı ve şerit uzun süre öyleydi; iki
/// nedenle değiştirildi (2026-08-19):
///
/// 1. Dokumada hata kırmızı iplik değil, motifte bir gediktir.
/// 2. Yeşil/kırmızı ayrımı deuteranopide ve gri tonlamada YOK OLUR.
///    Dolu/boş bir BİÇİM farkıdır; renk görmeyen kullanıcıda da, şerit
///    ekran görüntüsü olarak paylaşıldığında da ayakta kalır.
///
/// İkinci madde bu şerit paylaşılabilir bir nesneye dönüştüğü için
/// teorik değil. Bir gün "yanlışı kırmızı yapalım daha okunur" diye
/// geri alınmak istenirse bu test niçin olmadığını söyler.
///
/// ## Niçin çizim çağrıları denetleniyor
///
/// Bileşen `CustomPaint`tir; ekranda okunabilir bir metin bırakmaz.
/// Sonucu yalnız boyama çağrılarından doğrulanabilir. Piksel
/// karşılaştırması yerine `paints` kullanılır: piksel testte platform
/// kenar yumuşatmasına bağlıdır, çağrı listesi bağlı değildir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_board.dart';

Widget host(Widget child, {double width = 300}) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('doğru cevap DOLU altın baklava dokur', (tester) async {
    await tester.pumpWidget(
      host(const KilimBoard(total: 4, currentIndex: 1, results: [true])),
    );

    expect(
      find.byType(KilimBoard),
      paints..path(color: AppTheme.gold, style: PaintingStyle.fill),
    );
  });

  testWidgets('yanlış cevap İÇİ BOŞ bırakır — kırmızı dolgu değil', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const KilimBoard(total: 4, currentIndex: 1, results: [false])),
    );

    // Gedik: altının soluk tonunda bir ÇERÇEVE çizilir.
    expect(find.byType(KilimBoard), paints..path(style: PaintingStyle.stroke));

    // Ve hiçbir yerde uyarı kırmızısı DOLGUSU olmaz. Bu satır testin
    // asıl gövdesi: yeşil/kırmızıya geri dönüş buradan yakalanır.
    expect(
      find.byType(KilimBoard),
      isNot(paints..path(color: AppTheme.wrong, style: PaintingStyle.fill)),
    );
  });

  testWidgets('uzun sette motif yerine oran şeridine düşer', (tester) async {
    // 40 soru × 300 px → hücre 7.5 px, eşik 9 px'in altında.
    await tester.pumpWidget(
      host(
        KilimBoard(
          total: 40,
          currentIndex: 3,
          results: List<bool>.filled(3, true),
        ),
      ),
    );

    // Sıkışık kip yuvarlatılmış dikdörtgen çizer, baklava yolu çizmez.
    expect(find.byType(KilimBoard), paints..rrect());
  });

  testWidgets('ekran okuyucuya doğru sayısını söyler', (tester) async {
    await tester.pumpWidget(
      host(
        const KilimBoard(
          total: 5,
          currentIndex: 3,
          results: [true, false, true],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Ji 5 pirsan 3 hatin bersivandin, 2 rast'),
      findsOne,
    );
  });
}
