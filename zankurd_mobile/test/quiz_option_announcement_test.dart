/// Şıkların ekran okuyucuya nasıl okunduğu: harf + metin + durum.
///
/// Kusur değil, KAYIP RİSKİ (2026-10-02 erişilebilirlik denetimi: bugün
/// doğru çalışıyor, ama korunmuyordu). Şıkların doğru/yanlış durumu görünürde
/// renk + işaret + tarama animasyonuyla anlatılır; ekran okuyucuya ise
/// YALNIZCA etiketin sonundaki ", Doğru" / ", Yanlış" (Kurmancî ", Rast" /
/// ", Şaş") söyler. Bu ek görsel durumdan bağımsız ikinci bir daldır: biri
/// durumu değiştirip etiketi unutsa hiçbir görsel test kırılmaz ve ekran
/// okuyucu kullanan oyuncu cevabının doğruluğunu hiç duyamaz; kılavuzlar
/// da yalnız "etiket var mı" diye sorar, "doğru etiket mi" demez.
/// Bekçi iki dilde: cevaptan ÖNCE etiket "A: metin" (durumsuz, seçili
/// değil), cevaptan SONRA tam bir şık "Doğru", seçilen yanlışsa seçilen
/// "Yanlış".
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final ku in [false, true]) {
    testWidgets(
      'şık etiketi: harf + metin, cevaptan sonra durum (${ku ? 'KU' : 'TR'})',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final repository = freshMockRepository();
        await tester.pumpWidget(
          testShell(
            languageProvider: ku ? kurmanciLang() : turkishLang(),
            child: QuizScreen(
              repository: repository,
              room: repository.createRoom().copyWith(questionCount: 1),
              questions: repository.questions.take(1).toList(),
              enableTimer: false,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final tiles = find.byType(QuizOptionTile);
        final count = tiles.evaluate().length;
        expect(count, greaterThanOrEqualTo(2));

        final correctWord = Tr.forKu(K.correct, ku);
        final wrongWord = Tr.forKu(K.wrong, ku);

        String labelOf(int i) => tester.getSemantics(tiles.at(i)).label;

        for (var i = 0; i < count; i++) {
          final letter = String.fromCharCode(65 + i);
          expect(labelOf(i), startsWith('$letter: '), reason: 'şık $i');
          expect(labelOf(i), isNot(contains(correctWord)));
          expect(labelOf(i), isNot(contains(wrongWord)));
          expect(
            tester.getSemantics(tiles.at(i)).flagsCollection.isSelected,
            isNot(Tristate.isTrue),
          );
        }

        await tester.tap(tiles.at(0));
        await tester.pump();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        final labels = [for (var i = 0; i < count; i++) labelOf(i)];
        expect(
          labels.where((l) => l.endsWith(', $correctWord')),
          hasLength(1),
          reason: 'doğru şık tam bir kez duyurulmalı: $labels',
        );
        if (!labels[0].endsWith(', $correctWord')) {
          expect(labels[0], endsWith(', $wrongWord'));
        }
        semantics.dispose();
      },
    );
  }
}
