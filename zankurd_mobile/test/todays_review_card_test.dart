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
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.byKey(const ValueKey('todays-review-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('todays-review-card')), findsNothing);
    expect(find.text('Tekrarlar tamam'), findsOneWidget);
    expect(find.text('Bugün tekrar edilecek soru yok'), findsNothing);
    expect(
      find.bySemanticsLabel('Tekrarlar tamam. Bugün tekrar edilecek soru yok'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
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

  /// Çevrimiçi maç yanlışları kartı ölü bırakıyordu (2026-08-06 denetimi).
  ///
  /// `_trackMistake` çevrimiçi yolda da çalışıyor ve soruyu KENDİ id'siyle
  /// kaydediyor. Odadan gelen sorular veritabanı UUID'si taşır
  /// (`get_room_questions` satırın `id`sini döndürür); paketli bankanın
  /// kimlikleri ise `offline_0005` biçimindedir. Rozet bütün hazır
  /// kimlikleri sayıyor, başlatma ise yalnız paketli bankayla kesişimi
  /// açıyordu — kesişim boş olunca dokunuş sessizce hiçbir şey yapmıyordu.
  ///
  /// Öğren sekmesinin başlık kartı, çevrimiçi 1v1 oynayan her kullanıcıda
  /// kalıcı olarak tepkisiz kalıyordu.
  group('sayı ile eylem aynı kaynaktan', () {
    testWidgets('çözümlenemeyen UUID rozeti şişirmiyor', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': [
          'offline_0005',
          // Çevrimiçi maçtan gelen, paketli bankada karşılığı olmayan id.
          '9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44',
          'c3a0f5b1-2d64-4e89-b7f3-6a8e2c9d1077',
        ],
      });
      await pump(tester);
      expect(
        find.text('3'),
        findsNothing,
        reason:
            'Rozet açılamayacak soruları sayarsa kullanıcıya olmayan bir iş '
            'vaat eder',
      );
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('yalnız UUID varsa kart sahte rozet göstermez', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': ['9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44'],
      });
      await pump(tester);
      expect(
        find.byKey(const ValueKey('todays-review-empty')),
        findsOneWidget,
        reason:
            'Hiçbiri açılamıyorsa kart, dokunulduğunda hiçbir şey yapmayan '
            'bir rozet yerine sakin tamamlandı durumunu göstermeli',
      );
    });

    testWidgets('rozetin vaat ettiği sayı gerçekten açılıyor', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': [
          'offline_0005',
          'offline_0010',
          '9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44',
        ],
      });
      List<QuizQuestion>? started;
      await pump(tester, onStart: (q) => started = q);

      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('todays-review-card')));
      await tester.pumpAndSettle();

      expect(started, isNotNull, reason: 'Dokunuş sessiz no-op olmamalı');
      expect(started!.length, 2, reason: 'Rozet neyi vaat ettiyse o açılmalı');
    });
  });
}
