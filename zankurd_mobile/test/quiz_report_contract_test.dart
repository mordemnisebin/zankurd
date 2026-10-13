import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Soru bildirme başarısı/hatası kullanıcıya görünmeli; mock çağrıyı kaydetmeli.
///
/// ## Kusur
///
/// `_reportQuestion` snackbar ve `repository.reportQuestion` insert
/// sözleşmesi vardı ama mock gövdesi boştu ve hiçbir widget testi bildir
/// yolunu sürmüyordu. Başarı/hata metni kırılsa ya da depo no-op kalsa
/// testler yeşil kalırdı.
class _RecordingReportRepository extends MockZanKurdRepository {
  final reports = <({String id, String reason})>[];

  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    reports.add((id: question.id, reason: reason));
  }
}

class _FailingReportRepository extends MockZanKurdRepository {
  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    throw StateError('injected: report failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  Future<void> pumpQuiz(WidgetTester tester, MockZanKurdRepository repo) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);
    final question = repo.playableQuestions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: repo.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('bildirince depo çağrılır ve başarı snackbar görünür', (
    tester,
  ) async {
    final repo = _RecordingReportRepository();
    await pumpQuiz(tester, repo);

    await tester.tap(find.byTooltip('Bildir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Gönder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.reports, isNotEmpty);
    expect(find.text('Soru raporu gönderildi.'), findsOneWidget);
  });

  testWidgets('bildirme hatasında hata snackbar görünür', (tester) async {
    final repo = _FailingReportRepository();
    await pumpQuiz(tester, repo);

    await tester.tap(find.byTooltip('Bildir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Gönder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('gönderilemedi'), findsOneWidget);
  });

  test('mock reportQuestion çağrıyı kaydeder', () async {
    final repo = MockZanKurdRepository();
    final question = repo.playableQuestions.first;
    await repo.reportQuestion(question, 'şık yanlış');
    expect(repo.reportedQuestions, isNotEmpty);
    expect(repo.reportedQuestions.single.reason, 'şık yanlış');
  });
}
