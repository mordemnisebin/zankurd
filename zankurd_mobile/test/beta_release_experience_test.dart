import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/analytics_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

class _TrackingRepository extends MockZanKurdRepository {
  int? dailyQuestionLimit;

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async {
    dailyQuestionLimit = limit;
    return super.loadDailyQuestions(limit: limit);
  }
}

void main() {
  test('beta feedback mailto uses the published support address', () {
    final uri = AppConfig.feedbackUri(subject: 'ZanKurd beta');

    expect(uri.scheme, 'mailto');
    expect(uri.path, AppConfig.supportEmail);
    expect(uri.queryParameters['subject'], 'ZanKurd beta');
  });

  test(
    'activation analytics methods are safe without Firebase consent',
    () async {
      await AnalyticsService.instance.logActivationStep('first_quiz_started');
      await AnalyticsService.instance.logOnboardingCompleted();
      await AnalyticsService.instance.logFirstQuizCompleted();
    },
  );

  testWidgets('first session task presents a short, explicit starting point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayTaskCard(
            isKu: false,
            loading: false,
            firstSession: true,
            total: 5,
            onStart: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('home-first-session-badge')),
      findsOneWidget,
    );
    expect(find.textContaining('5 soru'), findsOneWidget);
  });

  testWidgets('settings exposes a direct beta feedback action', (tester) async {
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: freshMockRepository())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-beta-feedback')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const ValueKey('settings-beta-feedback')),
      findsOneWidget,
    );
    expect(find.text('Beta geri bildirimi gönder'), findsOneWidget);
  });

  testWidgets('home starts the first session with five questions', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _TrackingRepository();

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-daily-task-start')));
    await tester.pumpAndSettle();

    expect(repository.dailyQuestionLimit, 5);
    expect(find.byType(QuizScreen), findsOneWidget);
  });
}
