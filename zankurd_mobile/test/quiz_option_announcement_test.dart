/// Şıkların ekran okuyucuya nasıl okunduğu: harf + metin + durum.
///
/// T6: doğru seçilen şıkkın kutlama katmanında etiketi kaybolmamalı.
/// Şıkların doğru/yanlış durumu görünürde
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

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'kutlama boyunca şık düğümü ve rozetler okunur: reduced=$reducedMotion',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final revealed = ValueNotifier(false);
        try {
          await tester.pumpWidget(
            testShell(
              reducedMotion: reducedMotion,
              child: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: revealed,
                  builder: (context, answered, child) => QuizOptionTile(
                    index: 0,
                    answer: 'yaşam',
                    selected: answered,
                    correct: answered,
                    disabled: answered,
                    audiencePercent: 0.75,
                    opponentNamesWhoSelected: const ['Rojda'],
                    onTap: () => revealed.value = true,
                  ),
                ),
              ),
            ),
          );
          final tile = find.byType(QuizOptionTile);
          final nodeId = tester.getSemantics(tile).id;
          expect(tester.getSemantics(tile).label, 'A: yaşam');
          await tester.tap(tile);
          await tester.pump();
          // Başlangıç, sekmenin ortası ve bitişi; geçiş de erişilebilir kalır.
          for (final elapsed in [
            Duration.zero,
            const Duration(milliseconds: 180),
            const Duration(milliseconds: 300),
          ]) {
            await tester.pump(elapsed);
            final node = tester.getSemantics(tile);
            expect(node.id, nodeId);
            expect(node.label, 'A: yaşam, Doğru');
            expect(node.flagsCollection.isSelected, Tristate.isTrue);
            final labels = tester.semantics
                .simulatedAccessibilityTraversal()
                .map((node) => node.label)
                .toList();
            expect(
              labels.where((label) => label == 'A: yaşam, Doğru'),
              hasLength(1),
            );
            expect(labels, contains('Rojda'));
            expect(labels.any((label) => label.contains('75')), isTrue);
          }
        } finally {
          semantics.dispose();
          revealed.dispose();
        }
      },
    );
  }

  // curated_movement_0001: doğru cevap sırayla A, B, C ve D'de.
  // Sabit turlar gerçek forRound yolunu kullanır; konum ayrıca doğrulanır.
  const rounds = [
    't6-options-3',
    't6-options-4',
    't6-options-10',
    't6-options-0',
  ];
  for (final ku in [false, true]) {
    for (var correctIndex = 0; correctIndex < rounds.length; correctIndex++) {
      for (final chooseCorrect in [true, false]) {
        testWidgets(
          'şık duyurusu ${ku ? 'KU' : 'TR'}: doğru ${String.fromCharCode(65 + correctIndex)}, '
          '${chooseCorrect ? 'doğru' : 'yanlış'} seçim',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              final repository = freshMockRepository();
              await tester.pumpWidget(
                testShell(
                  languageProvider: ku ? kurmanciLang() : turkishLang(),
                  child: QuizScreen(
                    repository: repository,
                    room: repository.createRoom().copyWith(questionCount: 1),
                    questions: repository.questions.take(1).toList(),
                    roundId: rounds[correctIndex],
                    enableTimer: false,
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 600));

              final tiles = find.byType(QuizOptionTile);
              expect(tiles, findsNWidgets(4));
              final answers = tester
                  .widgetList<QuizOptionTile>(tiles)
                  .map((tile) => tile.answer)
                  .toList();
              expect(answers[correctIndex], 'yaşam');
              final correctWord = Tr.forKu(K.correct, ku);
              final wrongWord = Tr.forKu(K.wrong, ku);
              String labelOf(int i) => tester.getSemantics(tiles.at(i)).label;
              for (var i = 0; i < 4; i++) {
                expect(
                  labelOf(i),
                  '${String.fromCharCode(65 + i)}: ${answers[i]}',
                );
                expect(
                  tester.getSemantics(tiles.at(i)).flagsCollection.isSelected,
                  isNot(Tristate.isTrue),
                );
              }

              final selectedIndex = chooseCorrect
                  ? correctIndex
                  : (correctIndex + 1) % 4;
              await tester.tap(tiles.at(selectedIndex));
              await tester.pump();
              for (var i = 0; i < 12; i++) {
                await tester.pump(const Duration(milliseconds: 300));
              }

              final labels = [for (var i = 0; i < 4; i++) labelOf(i)];
              expect(
                labels.where((label) => label.endsWith(', $correctWord')),
                hasLength(1),
                reason: 'doğru şık tam bir kez duyurulmalı: $labels',
              );
              final spokenLabels = tester.semantics
                  .simulatedAccessibilityTraversal()
                  .map((node) => node.label)
                  .toList();
              for (var i = 0; i < 4; i++) {
                final state = i == correctIndex
                    ? ', $correctWord'
                    : i == selectedIndex
                    ? ', $wrongWord'
                    : '';
                final expected =
                    '${String.fromCharCode(65 + i)}: ${answers[i]}$state';
                expect(labels[i], expected);
                expect(
                  spokenLabels.where((label) => label == expected),
                  hasLength(1),
                );
                expect(
                  tester.getSemantics(tiles.at(i)).flagsCollection.isSelected,
                  i == selectedIndex ? Tristate.isTrue : Tristate.isFalse,
                );
              }
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
