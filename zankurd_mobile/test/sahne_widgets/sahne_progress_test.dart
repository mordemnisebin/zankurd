/// Şahnê ilerleme göstergelerinin ve ödül gliflerinin bekçisi.
///
/// ## Neyi korur
///
/// * Elmas dizisinde durumlar ŞEKİLLE ayrışır, yalnız renkle değil: aynı
///   hücre gri tonlamaya çevrildiğinde bile doğru / yanlış / bekleyen /
///   sürüyor birbirinden farklı çizilir (renk körü oyuncu da okur). Eski
///   ilerleme noktaları yalnız yeşil/kırmızıydı.
/// * Sayaç son 5 saniyede Boyax'a döner ve nabız atar; "hareketi azalt"
///   açıkken yalnız renk değişir, nabız yoktur.
/// * Ders elması, sayaç ve dizi ekran okuyucuya tek bir söz verir.
/// * Glifler dekoratiftir (ekran okuyucu okumaz); gündüzde kontur koyu
///   altındır.
/// * 320 px @2.0'da taşma yok.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

const _states = [
  SahneDiamondState.correct,
  SahneDiamondState.wrong,
  SahneDiamondState.correct,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
];

/// Ressamı 96 × 96'lık bir resme çizer ve gri tonlamalı piksellerini döner.
Future<List<int>> _grey(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(96, 96));
  final image = await recorder.endRecording().toImage(96, 96);
  final data = (await image.toByteData())!;
  final bytes = data.buffer.asUint8List();
  return [
    for (var i = 0; i < bytes.length; i += 4)
      // Luma × alfa: renk atılır, yalnız şekil ve açıklık kalır.
      ((0.299 * bytes[i] + 0.587 * bytes[i + 1] + 0.114 * bytes[i + 2]) *
              bytes[i + 3] /
              255)
          .round(),
  ];
}

int _differentPixels(List<int> a, List<int> b) {
  var n = 0;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 24) n++;
  }
  return n;
}

T _painterOf<T extends CustomPainter>(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<T>()
      .first;
}

void main() {
  setUpAll(loadAppFonts);

  Widget all() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SahneProgressBar(value: 0.4, trailing: '2/5', semanticLabel: 'Ders'),
      SizedBox(height: 12),
      SahneProgressBar(
        value: 0.2,
        tone: SahneProgressTone.gold,
        trailing: '200 / 1000 XP',
      ),
      SizedBox(height: 12),
      SahneDiamondRow(
        states: _states,
        currentIndex: 3,
        semanticLabel: '4/10: 2 rast, 1 şaş',
      ),
      SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SahneLessonDiamond(done: 2, total: 5),
          SahneTimerDiamond(
            secondsLeft: 17,
            fraction: 0.85,
            semanticLabel: '17 çirke mane',
          ),
          SahnePathNode(
            state: SahnePathNodeState.done,
            semanticLabel: 'Qediya',
          ),
          SahnePathNode(
            state: SahnePathNodeState.inProgress,
            semanticLabel: 'Didome',
          ),
          SahnePathNode(
            state: SahnePathNodeState.locked,
            semanticLabel: 'Girtî',
          ),
          SahneGlyph(SahneGlyphKind.coin),
          SahneGlyph(SahneGlyphKind.flame),
          SahneGlyph(SahneGlyphKind.bolt),
          SahneGlyph(SahneGlyphKind.star),
          SahneGlyph(SahneGlyphKind.star, filled: false),
          SahneGlyph(SahneGlyphKind.crown),
        ],
      ),
    ],
  );

  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: 320 px @2.0 taşmaz; tek söz okunur', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(tester, all(), dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('4/10: 2 rast, 1 şaş'), findsOneWidget);
      expect(find.bySemanticsLabel('2/5'), findsOneWidget);
      expect(find.bySemanticsLabel('17 çirke mane'), findsOneWidget);
      expect(find.bySemanticsLabel('Didome'), findsOneWidget);
      final bar = tester.getSemantics(find.byType(SahneProgressBar).first);
      expect(bar.value, '2/5');
      expect(bar.label, 'Ders');

      // Glif ressamı gündüzde koyu altın, gecede Zêr kontur kullanır.
      final t = dark ? SahneTokens.night : SahneTokens.day;
      final glyph = _painterOf<SahneGlyphPainter>(tester);
      expect(glyph.fill, t.gold);
      expect(glyph.edge, t.goldTx);
      semantics.dispose();
    });
  }

  testWidgets('elmas durumları gri tonlamada da birbirinden ayrışır', (
    tester,
  ) async {
    for (final tokens in [SahneTokens.night, SahneTokens.day]) {
      final images = <SahneDiamondState, List<int>>{};
      await tester.runAsync(() async {
        for (final s in SahneDiamondState.values) {
          images[s] = await _grey(
            SahneDiamondPainter(state: s, tokens: tokens),
          );
        }
      });
      const states = SahneDiamondState.values;
      for (var i = 0; i < states.length; i++) {
        for (var j = i + 1; j < states.length; j++) {
          expect(
            _differentPixels(images[states[i]]!, images[states[j]]!),
            greaterThan(150),
            reason: '${states[i]} ile ${states[j]} şekilce ayrışmalı',
          );
        }
      }
      // Doğru DOLU (merkez boyalı), bekleyen BOŞ (merkez boş).
      const center = 30 * 96 + 48; // ✓ işaretinin üstünde, dolgu içinde
      expect(images[SahneDiamondState.correct]![center], greaterThan(40));
      expect(images[SahneDiamondState.pending]![center], 0);
    }
  });

  testWidgets('şimdiki hücre altın dış halka alır', (tester) async {
    late List<int> plain;
    late List<int> current;
    await tester.runAsync(() async {
      plain = await _grey(
        const SahneDiamondPainter(
          state: SahneDiamondState.pending,
          tokens: SahneTokens.night,
        ),
      );
      current = await _grey(
        const SahneDiamondPainter(
          state: SahneDiamondState.pending,
          tokens: SahneTokens.night,
          current: true,
        ),
      );
    });
    // Dış halka elmasın tepe köşesinin hemen altında.
    const top = 4 * 96 + 48;
    expect(plain[top], 0);
    expect(current[top], greaterThan(40));
  });

  for (final dark in [true, false]) {
    testWidgets('sayaç ≤ 5 sn Boyax\'a döner (${dark ? 'gece' : 'gündüz'})', (
      tester,
    ) async {
      Future<SahneDiamondTrackPainter> pumpAt(int s) async {
        await pumpSahne(
          tester,
          SahneTimerDiamond(
            secondsLeft: s,
            fraction: s / 20,
            semanticLabel: '$s',
          ),
          dark: dark,
          textScale: 1,
        );
        return _painterOf<SahneDiamondTrackPainter>(tester);
      }

      // Sayaç her zaman oyun sahnesinde (gece) durur, ama bileşen
      // bağlamın belirteçleriyle çizer.
      final t = dark ? SahneTokens.night : SahneTokens.day;
      final calm = await pumpAt(17);
      expect(calm.trail, t.gold);
      // 2026-09-29 doğallık (K9): sakin sayaçta hale yok (eskiden altın
      // hale bekleniyordu); hale yalnız son saniyelerde, Boyax.
      expect(calm.halo, isNull);
      final hot = await pumpAt(5);
      expect(hot.trail, t.raceTx);
      expect(hot.halo, SahneStageColors.haloRace);
      final number = tester.widget<Text>(find.text('5'));
      expect(number.style?.color, t.raceTx);
      expect(await pumpAt(4).then((p) => p.trail), t.raceTx);
      expect(await pumpAt(6).then((p) => p.trail), t.gold);
    });
  }

  for (final reduce in [false, true]) {
    testWidgets('sayaç nabzı (hareketi azalt: $reduce)', (tester) async {
      await pumpSahne(
        tester,
        const SahneTimerDiamond(
          secondsLeft: 3,
          fraction: 0.15,
          semanticLabel: '3',
        ),
        dark: true,
        textScale: 1,
        reduceMotion: reduce,
      );
      await tester.pump(const Duration(milliseconds: 250));
      final scale = tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(SahneTimerDiamond),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      if (reduce) {
        expect(scale, 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
      } else {
        expect(scale, greaterThan(1));
        expect(scale, lessThanOrEqualTo(1.06));
      }
    });
  }

  test('sayaç izi tepe köşeden saat yönünde tükenir', () {
    final path = sahneDiamondPath(const Rect.fromLTWH(0, 0, 60, 60));
    final metric = path.computeMetrics().first;
    // Yol tepeden başlar; ilk çeyrek tepe → sağ köşe.
    final start = metric.getTangentForOffset(0)!.position;
    final quarter = metric.getTangentForOffset(metric.length / 4)!.position;
    expect(start, const Offset(30, 0));
    expect(quarter.dx, closeTo(60, 0.01));
    expect(quarter.dy, closeTo(30, 0.01));
  });

  // Kusur (2026-10-02 erişilebilirlik denetimi): çubuğun yanındaki değer
  // metni `Flexible(flex: 0)` idi, yani hiç küçülmezdi; çubuk 0 genişliğe
  // inebilir ama metin inemez. Seviyeler ekranının "0/2 Seviye" değeri 320
  // px + %200 yazıda 256 px'lik satırı 39 px taşırıyordu. Sessiz kalma
  // sebebi: dokunma/etiket/kontrast kılavuzları taşmayı ölçmez, taşan
  // Row'daki her düğüm hâlâ "dokunulur ve etiketli" görünür; yalnız
  // 320 px @2.0 koşulu yakalar. Büyük yazıda değer çubuğun ALTINA iner.
  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: uzun değer büyük yazıda taşmaz, çubuğun altına iner', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneProgressBar(
          value: 0.3,
          trailing: '3/12 Seviye tamamlandı',
          semanticLabel: 'Seviyeler',
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      final barBottom = tester
          .getBottomLeft(
            find.descendant(
              of: find.byType(SahneProgressBar),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .dy;
      final text = find.text('3/12 Seviye tamamlandı');
      expect(tester.getTopLeft(text).dy, greaterThanOrEqualTo(barBottom));
      expect(tester.getTopRight(text).dx, lessThanOrEqualTo(320 - 16 + 0.5));
    });
  }
}
