import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';

import 'support/widget_test_helpers.dart';

/// Öğren birincil CTA’sı boş havuzda sessizce return ediyordu.
class _EmptyDailyRepository extends MockZanKurdRepository {
  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async =>
      const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });
  });

  testWidgets('günün dersi boşsa SnackBar gösterir', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: HomeScreen(repository: _EmptyDailyRepository())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(
      find.byKey(const ValueKey('home-daily-task-start')),
    );
    await tester.tap(find.byKey(const ValueKey('home-daily-task-start')));
    await tester.pumpAndSettle();

    expect(find.text('Soru bulunamadı.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(K.noQuestionsFound, 'contest.noQuestions');
  });
}
