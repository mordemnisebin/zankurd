// 2026-10-28 kurul turu 2 R1: konu karosunun TONLU yüzeyinde metin kontrastı.
//
// Kusur: karo yüzeyi konu rengine boyanınca (canlılık için) metin kontrastı
// sessizce düşebilir: yüzey karışımı yükselir, soluk ikinci satır (tx2) ya da
// ad (tx) 4,5:1'in altına iner ve kimse fark etmez (ekran turu gözle bakar,
// oran ölçmez). Bu bekçi on bir konu rengini iki temada, GERÇEK karo yüzeyi
// formülüyle ([SahneTopicTint.topicSurface]) ölçer: ad (tx) ve ikinci satır
// (tx2) ≥ 4,5:1; rozet ikonu (beyaz) konu dolgusunda ≥ 4,5:1. Mod kartlarının
// tonlu yüzeyleri (Öğren/Yarış/Oda, R2) de aynı ölçüden geçer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  final hi = x > y ? x : y;
  final lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('on bir konu tonu bütün anahtarlarla tanımlı', () {
    expect(SahneCategoryTone.byCategory.length, 11);
  });

  for (final night in [false, true]) {
    final t = night ? SahneTokens.night : SahneTokens.day;
    final theme = night ? 'gece' : 'gündüz';
    group('tonlu karo kontrastı ($theme)', () {
      for (final entry in SahneCategoryTone.byCategory.entries) {
        final fill = entry.value.fill(night: night);
        final surface = t.topicSurface(fill, night: night);
        test('${entry.key}: ad ve ikinci satır ≥ 4,5:1', () {
          expect(
            _contrast(t.tx, surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} ad (tx)',
          );
          expect(
            _contrast(t.tx2, surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} ikinci satır (tx2)',
          );
        });
        test('${entry.key}: rozet ikonu konu dolgusunda ≥ 4,5:1', () {
          expect(
            _contrast(SahneVivid.onFill, fill),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} rozet',
          );
        });
        test('${entry.key}: yüzey nötr ya da doygun dolu değil', () {
          expect(surface, isNot(t.s1));
          expect(surface, isNot(fill));
          // Hafif karışım: yüzey parlaklığı s1'e fillden daha yakın.
          expect(
            (surface.computeLuminance() - t.s1.computeLuminance()).abs(),
            lessThan((fill.computeLuminance() - t.s1.computeLuminance()).abs()),
          );
        });
      }
    });

    group('mod kartı tonları ($theme)', () {
      for (final role in [SahneRole.learn, SahneRole.race, SahneRole.social]) {
        test('$role: ad ve alt yazı ≥ 4,5:1', () {
          final tint = t.roleTint(role);
          expect(_contrast(t.tx, tint), greaterThanOrEqualTo(4.5));
          expect(_contrast(t.tx2, tint), greaterThanOrEqualTo(4.5));
        });
      }
    });
  }
}
