/// Ana ekranın kimlik taşıması.
///
/// Uygulamanın kilim ilerleme dili ve Zana maskotu vardı ama ana ekranda
/// hiçbiri yoktu: kullanıcının günde İLK gördüğü ekran, her uygulamada
/// bulunan düz bir çubuk ve isimsiz bir selamlamayla açılıyordu
/// (2026-08-19). Bu testler o iki dokunuşun sessizce geri alınmasını
/// engeller.
///
/// 2026-09-29 Şahnê: kilim çubuk ve maskot kalktı; kimlik artık gece sahne
/// kartı (üstte kilim göz şeridi) ve ders elmasıyla taşınır. Bekçiler bu
/// yeni dile göre güncellendi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  testWidgets('günün görevi ilerlemeyi ders elmasıyla okutur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: () {},
            done: 4,
            total: 15,
          ),
        ),
      ),
    );

    final diamond = tester.widget<SahneLessonDiamond>(
      find.byType(SahneLessonDiamond),
    );
    expect(diamond.done, 4);
    expect(diamond.total, 15);
    expect(find.text('4/15'), findsOneWidget);
    expect(
      find.byType(LinearProgressIndicator),
      findsNothing,
      reason: 'düz çubuğa geri dönüş kimliği yeniden siler',
    );
  });

  testWidgets(
    'günün görevi gece sahne kartıdır; tek birincil düğme Agir + koyu metin',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TodayTaskCard(
              isKu: false,
              loading: false,
              onStart: () {},
              done: 4,
              total: 15,
            ),
          ),
        ),
      );

      final card = find.byKey(const ValueKey('home-daily-task'));
      expect(
        find.descendant(of: card, matching: find.byType(SahneStageCard)),
        findsOneWidget,
      );

      // `firstSession` burada varsayılan (false) ve done(4) < total(15):
      // 2026-09-27'den beri bu durumda başlık "Günün dersi" değil "Günlük
      // hedef" der (bkz. TodayTaskCard.build). Sahne kartı gündüz temasında
      // da gecedir: başlık gecenin birincil metni.
      final title = tester.widget<Text>(find.text('Günlük hedef'));
      expect(title.style?.color, SahneTokens.night.tx);

      final start = find.byKey(const ValueKey('home-daily-task-start'));
      expect(
        find.descendant(of: start, matching: find.byType(SahneButton)),
        findsOneWidget,
      );
      final label = tester.widget<Text>(
        find.descendant(of: start, matching: find.text('Devam et')),
      );
      final ctx = tester.element(
        find.descendant(of: start, matching: find.text('Devam et')),
      );
      // Agir üstünde metin HER ZAMAN koyu `onAct` (2026-09-29 ek karar).
      expect(
        DefaultTextStyle.of(ctx).style.merge(label.style).color,
        SahneTokens.night.onAct,
      );
    },
  );

  testWidgets('günün dersi ana eylemi 48dp ve semantik düğmedir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: () {},
            done: 0,
            total: 10,
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('home-daily-task-start'));
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(action);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.label, contains('Başla'));
    semantics.dispose();
  });

  testWidgets('günün dersi ana eylemi alt semantiği tek düğümde toplar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: () {},
            done: 0,
            total: 10,
          ),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('home-daily-task-start'));
    final semanticWidget = tester.widget<Semantics>(action);
    expect(semanticWidget.excludeSemantics, isTrue);
    semantics.dispose();
  });

  testWidgets('ilerleme tahtası DEĞİL çubuk kullanılır', (tester) async {
    // Kasıtlı ayrım. Tahta (`KilimBoard`) soru soru doğru/yanlış ister;
    // burada yalnız "kaç soru bitti" bilgisi var. Tahtayı kullanmak
    // olmayan veriyi ima eder ve görsel sessizce yalan söyler — mesela
    // 4/15'te dört ALTIN baklava çizilir ve hepsi doğruymuş gibi okunur.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: () {},
            done: 4,
            total: 15,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('kilim-board')), findsNothing);
  });
}
