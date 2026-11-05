import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Düello sonucunda eşit doğruda görünen "Doğru sayısı eşit; daha hızlı
/// cevaplayan kazandı" ve süre satırları koyu temada okunur kalır.
///
/// ## Kusur
///
/// 2026-11-05 simülatör turu (38_C_meydan_sonuc): iki satır koyu sahnede
/// çok soluk çiziliyordu (gece zeminde ~1.6:1): sahne her zaman gecedir ama
/// satırlar sahnenin DIŞINDAKİ `t` ile boyanıyor, uygulama gündüz temasındayken
/// gündüz ikincil rengi (#454E79) koyu gökte kalıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Renk token'dı, derleme/analiz hatası yoktu; token tablosundaki "tx2 ≥ 6.5"
/// notu ekrandaki Text'in gerçek rengini değil tabloyu sınıyordu. Bekçi
/// çizilen Text'in rengini gece zeminine karşı ölçer.
double _lum(Color c) => c.computeLuminance();
double _ratio(Color a, Color b) {
  final hi = math.max(_lum(a), _lum(b));
  final lo = math.min(_lum(a), _lum(b));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('beraberlik gerekçesi $mode uygulama temasında AA kontrastlı', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final summary = AsyncDuelSummary(
        duelId: 'd',
        status: AsyncDuelStatus.completed,
        role: AsyncDuelRole.opponent,
        opponentName: 'Rojda',
        myCorrect: 3,
        opponentCorrect: 3,
        outcome: AsyncDuelOutcome.win,
        createdAt: DateTime.utc(2026, 9, 27),
        seen: true,
      );
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: mode),
          child: AsyncDuelResultScreen(
            repository: freshMockRepository(),
            view: AsyncDuelResultView.fromSummary(summary),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in ['async-duel-result-tiebreak']) {
        final text = tester.widget<Text>(find.byKey(ValueKey(key)));
        final color = text.style!.color!;
        expect(
          _ratio(color, SahneTokens.night.bg),
          greaterThanOrEqualTo(4.5),
          reason: '$key rengi $color',
        );
      }
    });
  }
}
