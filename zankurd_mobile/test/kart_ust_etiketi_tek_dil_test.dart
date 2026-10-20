// 2026-10-20 TASARIM KURULU (tur 9b): kart üst etiketleri (eyebrow) tek dil.
//
// ## Kusur
//
// Ana sayfada "İlk ders" yeşil, "Hızlı düello" kırmızı/mor, öğrenmede
// "Sıradaki ders" nane yeşili hap olarak çıkıyordu: aynı işi gören kart üst
// etiketi üç ayrı renk konuşuyor, yeşil (doğru) ve kırmızı (hata) anlamını
// yitiriyordu (Opus iki tur + Gemini).
//
// ## Niçin sessiz kalırdı
//
// Her ekran etiketine kendi rol rengini ([SahneTokens.learnTx],
// [SahneTokens.raceTx]) elle verirdi; hepsi "geçerli bir belirteç"ti, hiçbiri
// derleme ya da kontrast hatası vermedi, ekran görüntüsü testleri renk
// ölçmez. Bu dosya (1) belirteç düzeyinde tek rengi, (2) hapın okunur
// kaldığını, (3) kart bileşenlerinin ve bilinen ekran dosyalarının o
// belirteci kullandığını ölçer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {
    'gündüz': SahneTokens.day,
    'gece': SahneTokens.night,
  }.entries) {
    test('${entry.key}: üst etiket bağlantı rengidir, yeşil/kırmızı değil', () {
      final t = entry.value;
      expect(t.eyebrowTx, t.linkTx);
      for (final other in [t.okTx, t.errTx, t.raceTx, t.learnTx]) {
        expect(t.eyebrowTx, isNot(other));
      }
    });

    test('${entry.key}: hap dolgusu üstünde etiket ≥ 4.5:1', () {
      final t = entry.value;
      for (final surface in [t.bg, t.s1, t.s2]) {
        final fill = Color.alphaBlend(t.eyebrowFill, surface);
        expect(_contrast(t.eyebrowTx, fill), greaterThanOrEqualTo(4.5));
      }
    });
  }

  testWidgets('sahne kartı üst etiketi yarış ve ders rolünde aynı renk', (
    tester,
  ) async {
    Future<Color?> eyebrow(Widget card, String label) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
      return tester.widget<Text>(find.text(label)).style?.color;
    }

    final duel = await eyebrow(
      SahneStageCard.duel(
        title: 'Başlık',
        actionLabel: 'Git',
        onAction: () {},
        eyebrow: 'Hızlı düello',
      ),
      'Hızlı düello',
    );
    final lesson = await eyebrow(
      SahneStageCard.lesson(
        title: 'Başlık',
        actionLabel: 'Git',
        onAction: () {},
        done: 0,
        total: 5,
        eyebrow: 'İlk ders',
      ),
      'İlk ders',
    );
    expect(duel, SahneTokens.night.eyebrowTx);
    expect(lesson, duel);
  });

  testWidgets('learn rozeti (Sıradaki ders) açık vurgu dolgusu + vurgu yazı', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SahneBadge(label: 'Sıradaki ders')),
      ),
    );
    final t = SahneTokens.of(tester.element(find.byType(SahneBadge)));
    final text = tester.widget<Text>(find.text('Sıradaki ders'));
    expect(text.style?.color, t.eyebrowTx);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SahneBadge),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as ShapeDecoration).color, t.eyebrowFill);
  });

  test('ana sayfa ve yarış kartlarının üst etiketi rol rengi kullanmaz', () {
    for (final path in [
      'lib/src/screens/home/today_task_card.dart',
      'lib/src/screens/home/room_invite_card.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('eyebrowTx'), reason: path);
    }
    final hub = File('lib/src/screens/play_hub_screen.dart').readAsStringSync();
    expect(
      hub,
      contains(
        'context.t(K.quickDuel),\n'
        '                  style: SahneType.captionStrong.copyWith(color: t.eyebrowTx)',
      ),
    );
  });
}
