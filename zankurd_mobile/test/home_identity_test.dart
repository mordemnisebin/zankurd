/// Ana ekranın kimlik taşıması.
///
/// Uygulamanın kilim ilerleme dili ve Zana maskotu vardı ama ana ekranda
/// hiçbiri yoktu: kullanıcının günde İLK gördüğü ekran, her uygulamada
/// bulunan düz bir çubuk ve isimsiz bir selamlamayla açılıyordu
/// (2026-08-19). Bu testler o iki dokunuşun sessizce geri alınmasını
/// engeller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_progress_bar.dart';

void main() {
  testWidgets('günün görevi kilim ilerleme dilini kullanır', (tester) async {
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

    expect(find.byType(KilimProgressBar), findsOne);
    expect(
      find.byType(LinearProgressIndicator),
      findsNothing,
      reason: 'düz çubuğa geri dönüş kimliği yeniden siler',
    );

    final bar = tester.widget<KilimProgressBar>(find.byType(KilimProgressBar));
    expect(bar.value, closeTo(4 / 15, 0.001));
  });

  testWidgets('günün görevi birincil gradyan yüzeydir, düz yedek kart değil', (
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

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-daily-task')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(
      decoration.gradient,
      isA<LinearGradient>(),
      reason:
          'Ana eylem düz yüzeyde kalırsa Yarış kahramanının yanında sönük durur.',
    );
    expect(decoration.color, isNull);

    final title = tester.widget<Text>(find.text('Günün dersi'));
    expect(title.style?.color, Colors.white);

    final bar = tester.widget<KilimProgressBar>(find.byType(KilimProgressBar));
    expect(bar.color, Colors.white);
    expect(bar.trackColor, isNotNull);

    final startInk = tester.widget<Ink>(
      find.descendant(
        of: find.byKey(const ValueKey('home-daily-task-start')),
        matching: find.byType(Ink),
      ),
    );
    expect((startInk.decoration! as BoxDecoration).color, Colors.white);
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
