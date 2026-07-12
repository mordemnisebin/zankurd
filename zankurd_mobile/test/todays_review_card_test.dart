import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/todays_review_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MistakeStore.resetInstance();
  });

  Future<void> pump(
    WidgetTester tester, {
    void Function(List<QuizQuestion>)? onStart,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TodaysReviewCard(
            repository: MockZanKurdRepository(),
            isKu: false,
            onStartReview: onStart,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hazır tekrar sayısını gösterir', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.mistakeQuestionIds': [
        'offline_0005',
        'offline_0010',
        'offline_0014',
      ],
    });
    await pump(tester);
    expect(find.byKey(const ValueKey('todays-review-card')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hazır tekrar yoksa sakin tamamlandı durumu gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.byKey(const ValueKey('todays-review-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('todays-review-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gelecekteki tekrarlar hazır sayılmaz', (tester) async {
    final future = DateTime.now()
        .add(const Duration(days: 5))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'zankurd.mistakeQuestionIds': ['offline_0005'],
      'zankurd.mistakeMetadata':
          '{"offline_0005":{"nextReview":$future,"intervalDays":5,'
          '"repetitions":2,"easeFactor":2.5}}',
    });
    await pump(tester);
    expect(find.byKey(const ValueKey('todays-review-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('karta dokununca hazır sorularla tekrar başlar', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.mistakeQuestionIds': ['offline_0005', 'offline_0010'],
    });
    List<QuizQuestion>? captured;
    await pump(tester, onStart: (qs) => captured = qs);
    await tester.tap(find.byKey(const ValueKey('todays-review-card')));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(captured!.map((q) => q.id).toSet(), {
      'offline_0005',
      'offline_0010',
    });
  });

  testWidgets('tablet boyutunda overflow oluşmaz', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.mistakeQuestionIds': ['offline_0005', 'offline_0010'],
    });
    await pump(tester, size: const Size(800, 1200));
    expect(tester.takeException(), isNull);
  });
}
