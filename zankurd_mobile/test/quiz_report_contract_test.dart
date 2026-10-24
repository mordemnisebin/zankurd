import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Soru bildirme başarısı/hatası kullanıcıya görünmeli; mock çağrıyı kaydetmeli.
///
/// 2026-10-19 SADELEŞME (bu dosya güncellendi): "Bildir" artık gövdedeki ayrı
/// bir ikon düğmesi değil üst satırdaki ⋯ menüsünün satırıdır (Kaydet +
/// Bildir). Testler önce menüyü açar (`_openReport`); bildirme akışının
/// kendisi (diyalog, depo çağrısı, snackbar) değişmedi.
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

/// ⋯ menüsünü açıp "Bildir" satırına dokunur.
Future<void> _openReport(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('quiz-more-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quiz-menu-report')));
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

    await _openReport(tester);
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

    await _openReport(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Gönder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('gönderilemedi'), findsOneWidget);
  });

  /// Bildirme diyaloğunun yazı denetleyicisi diyalogun kendi State'ine aittir.
  ///
  /// ## Kusur
  ///
  /// `_reportQuestion` denetleyiciyi yaratıp `await showDialog` döner dönmez
  /// atıyordu. Diyalogun kapanış animasyonu onlarca kare sürer ve bu sürede
  /// `SahneField` atılmış denetleyiciyi dinlemeye devam ederdi ("A
  /// TextEditingController was used after being disposed").
  ///
  /// ## Niçin sessizdi
  ///
  /// Üstteki testler "Gönder"e basıp yalnız 400 ms ilerletiyordu; animasyon
  /// bitmeden bakılıyor, atılmış denetleyiciye ilk dokunuşta oluşan istisna
  /// ise hiçbir yerde sorgulanmıyordu. Burada kapanış `pumpAndSettle` ile
  /// sonuna kadar oynatılır ve çerçeve istisnası açıkça sorgulanır.
  for (final action in ['Vazgeç', 'Gönder']) {
    testWidgets('bildirme diyaloğu "$action" ile kapanırken çökmez', (
      tester,
    ) async {
      await pumpQuiz(tester, _RecordingReportRepository());

      await _openReport(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Odaklanmış alan: çökme yalnız odağı/imleci olan alanda görülür.
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.tap(find.text(action));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  /// `QuizScreen` kendi yarattığı `FloatingReactionController`ı atmalı.
  ///
  /// ## Kusur
  ///
  /// `_reactionController` (bir `ChangeNotifier`) `dispose()`ta hiç
  /// atılmıyordu; her quiz oturumu bir sızıntı bırakıyordu. Kaplama
  /// (`FloatingReactionOverlay`) dışarıdan verilen denetleyiciyi sahiplenmez,
  /// yani atma işi yalnız bu ekrandadır (`RoomScreen` atıyordu, bu ekran
  /// atmıyordu).
  ///
  /// ## Niçin sessizdi
  ///
  /// Sızıntı hiçbir davranış değiştirmez: ekran, testler ve kullanıcı için
  /// her şey çalışır. Denetleyici özeldir, dışarıdan gözlemlenemez; tek
  /// bekçi kaynak düzeyindedir.
  test('QuizScreen dispose() tepki denetleyicisini atar', () {
    final source = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    final disposeBody = RegExp(
      r'void dispose\(\) \{(.*?)\n  \}',
      dotAll: true,
    ).firstMatch(source)!.group(1)!;
    expect(disposeBody, contains('_reactionController.dispose();'));
  });

  test('mock reportQuestion çağrıyı kaydeder', () async {
    final repo = MockZanKurdRepository();
    final question = repo.playableQuestions.first;
    await repo.reportQuestion(question, 'şık yanlış');
    expect(repo.reportedQuestions, isNotEmpty);
    expect(repo.reportedQuestions.single.reason, 'şık yanlış');
  });
}
