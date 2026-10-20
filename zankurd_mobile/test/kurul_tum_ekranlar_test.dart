// Tasarım kurulu tüm ekranlar 2026-10-20 (8 model, 35 ekran): ortak bulgular.
//
// 1. 1v1 sonucu rakibi göstermiyordu; kahraman artık iki avatarı yüz yüze
//    koyar (`result-duel-faceoff`) ve skoru "Sen 320 – 180 Rojda" yazar.
//    ("Yeni oda" tur karesinden kayan kaydırma yüzünden öne çıkıyordu; kare
//    artık sayfa tepesinde.)
// 2. Konu satırı (eşleşme, sonuç) ana sayfa çizimini kullanır: `mark` verilen
//    bilgi satırı SahneTopicMarkBadge çizer, çizgi ikon değil. "Kültür" üç
//    ayrı biçimde görünüyordu.
// 3. Şıkların alta oturması her soru modunda aynı kuraldır
//    (`_portraitAnchorHeight`, `placement-answers-anchored`,
//    `async-duel-answers-anchored`); görsel kare turda doğrulanır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  testWidgets('konu işareti verilen bilgi satırı çizimi gösterir', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SahneListRow.thumb(
            image: null,
            title: 'Dil',
            tone: CategoryVisuals.tone('Ziman'),
            mark: CategoryVisuals.mark('Ziman'),
          ),
        ),
      ),
    );
    // 2026-10-20 (B): küçük konunun DOLU rengi + beyaz ikon (44x44).
    final tile = find.descendant(
      of: find.byType(SahneListRow),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).color ==
                CategoryVisuals.tone('Ziman').fill(night: false),
      ),
    );
    expect(tile, findsOneWidget);
    expect(t.getSize(tile), const Size(44, 44));
  });
}
