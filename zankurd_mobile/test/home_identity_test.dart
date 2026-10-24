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
///
/// 2026-10-19 SADELEŞME (bu dosya güncellendi): günün görevi artık gece sahne
/// kartı değil SAKİN YÜZEY KARTIDIR (`SahneSurfaceCard`: gündüz beyaz + 1 px
/// kenar, gece Perde) ve ilerleme 80 px'lik ders elması yerine ince 4 px
/// çubuk ve küçük "4/15" metnidir. İki test bu yüzden değişti: ilerleme
/// testi çubuğu (`SahneProgressBar`) ve metni bekler, elmas YOKTUR; kart
/// testi yüzey kartını ve TEMANIN (gündüz) birincil metnini bekler. Tek
/// birincil düğme (Agir + koyu metin) kuralı aynı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  testWidgets('günün görevi ilerlemeyi ince çubuk ve küçük metinle okutur', (
    tester,
  ) async {
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

    expect(find.byType(SahneLessonDiamond), findsNothing);
    final bar = tester.widget<SahneProgressBar>(
      find.byKey(const ValueKey('home-daily-task-progress')),
    );
    // 2026-10-20 renk ve canlılık: kalın (8 px) Zimrût çubuk.
    expect(bar.height, 8);
    expect(bar.value, closeTo(4 / 15, 1e-9));
    expect(bar.trailing, '4/15');
    expect(find.text('4/15'), findsOneWidget);
  });

  testWidgets(
    'günün görevi sakin yüzey kartıdır; tek birincil düğme Agir + koyu metin',
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
        find.descendant(of: card, matching: find.byType(SahneSurfaceCard)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(SahneStageCard)),
        findsNothing,
      );

      // `firstSession` burada varsayılan (false) ve done(4) < total(15):
      // 2026-09-27'den beri bu durumda başlık "Günün dersi" değil "Günlük
      // hedef" der (bkz. TodayTaskCard.build). 2026-10-19: kart temanın
      // yüzeyidir (gündüz beyaz): başlık gündüzün birincil metni.
      final title = tester.widget<Text>(find.text('Günlük hedef'));
      expect(title.style?.color, SahneTokens.day.tx);

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
