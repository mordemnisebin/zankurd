import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/todays_review_card.dart';

/// Tekrar oturumu: kaynak ve boyut (2026-10-15).
///
/// ## Kusur
///
/// Kart soruları `repository.questions`tan çözüyordu, ana ekran ise
/// `playableQuestions`tan sayıyordu: incelemede/karantinada bir soru kartın
/// oturumuna girebiliyordu. Üstelik hazır olan her tekrar tek oturumda
/// açılıyordu; birikmiş tekrarlar "bugünkü" bir oturum olmaktan çıkıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Testler yalnız tek tük kimlikle ("offline_0005") kurulup sayının ve
/// açılan listenin aynı olduğuna bakıyordu; ne bir karantina sorusu ne de
/// 12'den fazla hazır kimlik vardı.
///
/// ## Bekçi
///
/// Oturum yalnız oynanabilir soruları, en çok gecikenden başlayarak ve en
/// çok [kReviewSessionCap] kadar açar; kart da aynı sayıyı vaat eder.
QuizQuestion _q(String id, ReviewStatus status) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'Pirsa $id çi ye?',
  answers: const ['a', 'b', 'c', 'd'],
  correctAnswer: 'a',
  explanation: 'Şîrove.',
  metadata: QuestionMetadata(reviewStatus: status),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('oturum yalnız oynanabilir soruları, en gecikenden, en çok 12', (
    tester,
  ) async {
    final ids = [for (var i = 0; i < 20; i++) 'ok$i'];
    QuestionBankLoader.instance.setQuestionsForTest([
      for (final id in ids) _q(id, ReviewStatus.approved),
      _q('karantina', ReviewStatus.needsReview),
    ]);
    final now = DateTime.now().millisecondsSinceEpoch;
    // ok19 en çok gecikmiş, ok0 en az; karantina sorusu en gecikmiş görünür.
    final meta = {
      for (var i = 0; i < 20; i++)
        'ok$i': {'nextReview': now - (i + 1) * 3600000, 'repetitions': 1},
      'karantina': {'nextReview': now - 99 * 3600000, 'repetitions': 1},
    };
    SharedPreferences.setMockInitialValues({
      'zankurd.mistakeQuestionIds': [...ids, 'karantina'],
      'zankurd.mistakeMetadata': jsonEncode(meta),
    });
    MistakeStore.resetInstance();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    List<QuizQuestion>? captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TodaysReviewCard(
            repository: MockZanKurdRepository(),
            isKu: false,
            onStartReview: (qs) => captured = qs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('$kReviewSessionCap soru tekrara hazır'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('todays-review-card')));
    await tester.pumpAndSettle();

    expect(captured, hasLength(kReviewSessionCap));
    expect(captured!.map((q) => q.id), isNot(contains('karantina')));
    expect(captured!.first.id, 'ok19');
    expect(captured!.map((q) => q.id), [
      for (var i = 19; i > 19 - kReviewSessionCap; i--) 'ok$i',
    ]);
  });
}
