import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/widgets/lesson_recall_card.dart';

import 'support/widget_test_helpers.dart';

/// Ders bitişi adlandırılmış bir akıştır (Opus–Astra kapışması U14,
/// 2026-10-29).
///
/// Kusur: son slaytta "Tamamla" ile "Kısa test" yan yana duruyordu; hangisinin
/// dersi bitirdiği ve testin tamamlamaya etkisi yazmıyordu (kare 96). Hızlı
/// hatırlama kartında yanıt açılınca yönerge hâlâ "düşün, sonra yanıtı göster"
/// diyordu. İşlev çalıştığı için hiçbir test sormadı: "kullanıcı ne
/// yapacağını biliyor mu?".
void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('son slaytın akış notu tamamla/testi adlandırır (x$scale)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(child: LessonFinishHint()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Tamamla dersi bitirir ve sonraki dersi açar. Kısa test isteğe '
          'bağlıdır, tamamlamayı etkilemez.',
        ),
        findsOneWidget,
      );
    });
  }

  test('not son slaytın kaydırılan içeriğinde (alt perdede değil)', () {
    final src = File('lib/src/screens/learning_screen.dart').readAsStringSync();
    expect(src, contains('if (isLast) ...['));
    expect(src, contains('const LessonFinishHint()'));
    final nav = src.substring(src.indexOf('class LessonSlideNavigation'));
    expect(
      nav.substring(0, nav.indexOf('\n}\n')),
      isNot(contains('lessonFinishHint')),
    );
  });

  testWidgets('hatırlama kartı: yanıt açılınca yönerge sıradaki adımı söyler', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: const Scaffold(
          body: SingleChildScrollView(
            child: LessonRecallCard(
              entries: [
                LearnerLexiconEntry(
                  id: 'a',
                  termKu: 'Elîfbê',
                  meaningTr: 'Alfabe',
                  sourceId: 't',
                ),
                LearnerLexiconEntry(
                  id: 'b',
                  termKu: 'Dûr',
                  meaningTr: 'Uzak',
                  sourceId: 't',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Bu kelime veya ifadenin anlamını düşün, sonra yanıtı göster.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('lesson-recall-reveal')));
    await tester.pumpAndSettle();
    expect(find.text('Bildin mi? Sonrakine geç.'), findsOneWidget);
    expect(find.text('Alfabe'), findsOneWidget);
  });
}
