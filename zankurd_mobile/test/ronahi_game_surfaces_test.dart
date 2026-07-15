import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets('quiz kompakt durum şeridi ve açık soru yüzeyi taşır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockZanKurdRepository();

    await tester.pumpWidget(
      _shell(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: repository.questions.take(3).toList(),
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('quiz-status-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-question-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çark tek birincil eylem yüzeyi taşır', (tester) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _shell(SpinWheelScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('spin-primary-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
