import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/mission_toast.dart';

void main() {
  testWidgets('mission toast keeps ZanKurd typography in snackbar overlay', (
    tester,
  ) async {
    final mission = DailyMission(
      type: MissionType.completeQuiz,
      target: 1,
      coinReward: 25,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => MissionToast.show(context, mission),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    final heading = Tr.forKu(K.gorevTamamlandi, false);
    final detail = '${mission.labelTr} — +${mission.xpReward} XP';

    final headingText = tester.widget<Text>(find.text(heading));
    final detailText = tester.widget<Text>(find.text(detail));

    expect(headingText.style?.fontFamily, AppTypography.fontFamily);
    expect(detailText.style?.fontFamily, AppTypography.fontFamily);
  });

  for (final language in ['tr', 'ku']) {
    testWidgets('mission toast fits 320x568 at 200% text — $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mission = DailyMission(
        type: MissionType.completeQuiz,
        target: 1,
        coinReward: 25,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(initialLang: language),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => MissionToast.show(context, mission),
                      child: const Text('show'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();

      final isKu = language == 'ku';
      final heading = Tr.forKu(K.gorevTamamlandi, isKu);
      final label = isKu ? mission.labelKu : mission.labelTr;
      final detail = '$label — +${mission.xpReward} XP';

      expect(find.text(heading), findsOneWidget);
      expect(find.text(detail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
