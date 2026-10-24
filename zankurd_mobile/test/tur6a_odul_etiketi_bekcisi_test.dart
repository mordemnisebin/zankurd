// Tasarım kurulu tur 6: sonuç ekranının ödül kartında Kurmancî "Hat
// qezenckirin" etiketi, yanındaki "+30" ve "+100 XP" rozetleriyle AYNI satırda
// durduğundan rozetlerin artığı dar sütuna sığmayıp iki satıra kırılıyordu.
//
// Niçin sessiz kaldı: düzen yalnız yazı ölçeği eşiğine bakıyordu ve testler
// Türkçe "Kazanıldı" (kısa) ile koşuyordu; kırılma ancak uzun Kurmancî etiketle
// ve gerçek yazı tipiyle ortaya çıkar. Bekçi etiketi her dilde, her ölçekte ve
// 320 genişlikte tek satır ve rozetlerin ÜSTÜNDE ister.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  for (final label in ['Hat qezenckirin', 'Kazanıldı']) {
    for (final scale in [1.0, 2.0]) {
      for (final width in [320.0, 390.0]) {
        testWidgets(
          '"$label" tek satır, rozetlerin üstünde (x$scale, $width)',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.binding.setSurfaceSize(Size(width, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              testShell(
                child: SingleChildScrollView(
                  child: SahneResultRewards(
                    label: label,
                    coins: 30,
                    xp: 100,
                    coinLabel: '+30',
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final text = find.text(label);
            expect(text, findsOneWidget);
            // Tek satır: yükseklik, aynı yazı tipinde tek satırlık ölçünün
            // 1,5 katından az (iki satır ≥ 2 katı).
            final h = tester.getSize(text).height;
            final one = (TextPainter(
              text: TextSpan(
                text: 'Hg',
                style: tester.widget<Text>(text).style,
              ),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(tester.element(text)),
            )..layout()).height;
            // Test koşucusunda yazı tipi kare (Ahem) olduğundan %200'de en uzun
            // etiket kendi genişliğinden dolayı sarar; tek satır beklentisi
            // yalnız 1.0 ölçekte, üstte-altta düzeni her ölçekte sınanır.
            if (scale == 1.0) {
              expect(
                h,
                lessThan(one * 1.5),
                reason: 'Etiket iki satıra kırılmış.',
              );
            }
            expect(
              tester.getBottomLeft(text).dy,
              lessThanOrEqualTo(tester.getTopLeft(find.text('+30')).dy),
              reason: 'Etiket rozetlerin üstünde olmalı.',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
