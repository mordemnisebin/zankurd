import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-25 canlı denetimi: ana ekranın tek birincil eylemi olan
/// "Günün Dersi", `experience` verilmediği için varsayılan `competition`
/// modunda açılıyordu. Sonuçları: yanlış cevaptan sonra açıklama paneli hiç
/// render edilmiyor, çıkış diyalogu dersi "yarış" diye adlandırıyor ve
/// analytics tüm ders oturumlarını solo quiz olarak raporluyordu.
void main() {
  late MockZanKurdRepository repository;
  setUp(() {
    repository = freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  test('günün dersi öğrenme akışı olarak başlatılır', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _startDailyQuiz()');
    expect(start, greaterThan(-1), reason: '_startDailyQuiz bulunamadı');
    final body = source.substring(start, start + 1400);

    expect(
      body,
      contains('experience: QuizExperience.learning'),
      reason: 'Günün Dersi yarışma modunda açılıyor',
    );
    expect(body, contains('enableTimer: false'));
  });

  testWidgets('öğrenme akışında joker çubuğu gösterilmez', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [repository.questions.first],
          experience: QuizExperience.learning,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nîv bi Nîv'), findsNothing);
    expect(find.text('50/50'), findsNothing);
  });

  Future<void> pumpAndOpenExit(
    WidgetTester tester,
    MockZanKurdRepository repository,
    QuizExperience experience,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QuizScreen(
                  repository: repository,
                  room: repository.createRoom(),
                  questions: [repository.questions.first],
                  experience: experience,
                ),
              ),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    // Onay diyalogu yalnız ilerleme varsa çıkar (`PopScope.canPop`):
    // önce bir şık işaretlenir.
    await tester.tap(find.text(repository.questions.first.answers.first));
    await tester.pumpAndSettle();

    // Quiz ekranı bir rota olarak açıldığı için AppBar geri düğmesi var;
    // PopScope onu yakalayıp onay diyalogunu gösterir.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  testWidgets('öğrenme akışında çıkış diyalogu "ders" der', (tester) async {
    await pumpAndOpenExit(tester, repository, QuizExperience.learning);
    expect(find.text('Dersten çıkılsın mı?'), findsOneWidget);
    expect(find.text('Yarıştan çıkılsın mı?'), findsNothing);
  });

  testWidgets('yarışma akışında çıkış diyalogu "yarış" der', (tester) async {
    await pumpAndOpenExit(tester, repository, QuizExperience.competition);
    expect(find.text('Yarıştan çıkılsın mı?'), findsOneWidget);
    expect(find.text('Dersten çıkılsın mı?'), findsNothing);
  });

  // Bu, 1. düzeltmenin asıl kanıtı: öğrenme akışında cevaptan sonra
  // açıklama görünür, yarışma akışında görünmez.
  const explained = QuizQuestion(
    id: 'expl-1',
    category: 'Ziman',
    prompt: 'Test sorusu',
    answers: ['Alfa', 'Beta', 'Gama', 'Delta'],
    correctAnswer: 'Alfa',
    explanation: 'Bu acikllamanin gorunmesi gerekir.',
    explanationTr: 'Bu acikllamanin gorunmesi gerekir.',
    explanationKu: 'Ev ravekirin divê xuya bibe.',
  );

  Future<void> answerFirst(
    WidgetTester tester,
    QuizExperience experience,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [explained],
          experience: experience,
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'));
    // Açıklama paneli 800 ms gecikmeli açılır.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
  }

  // 2026-07-26: kural tersine döndü. Açıklama artık **hiçbir modda** cevabın
  // hemen altında gösterilmez; tur sırasında yalnız doğru cevap görünür,
  // açıklamaların tamamı sonuç ekranında bir arada gelir. Uygulama sahibi
  // bunu birkaç kez sorun olarak bildirdi: şık işaretlenir işaretlenmez
  // altında paragraf açılıyor ve turun ritmi kesiliyordu.
  testWidgets('öğrenme akışında açıklama cevabın altında açılmaz', (
    tester,
  ) async {
    await answerFirst(tester, QuizExperience.learning);
    expect(find.text('Bu acikllamanin gorunmesi gerekir.'), findsNothing);
    // 2026-08-19: "Doğru cevap" kutusu çoktan seçmeli sorulardan
    // kaldırıldı — doğru şık zaten yeşile dönüp tik alıyordu, kutu aynı
    // bilgiyi ikinci kez söyleyip kıt olan dikey alanı kaplıyordu
    // (uygulama sahibinin bildirimi). Kutu yalnız kelime sıralamada
    // kalır; orada doğru dizilimi açan başka hiçbir şey yok
    // (bkz. `needsAnswerRevealFallback`, `lesson_explanation_test`).
    // Korunan asıl kural DEĞİŞMEDİ: açıklama METNİ tur içinde açılmaz.
    expect(find.text('Doğru cevap'), findsNothing);
  });

  testWidgets('yarışma akışında da açıklama gösterilmez', (tester) async {
    await answerFirst(tester, QuizExperience.competition);
    expect(find.text('Bu acikllamanin gorunmesi gerekir.'), findsNothing);
  });

  testWidgets('öğrenme akışında rehberin ilk adımı süreden söz etmez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [repository.questions.first],
          experience: QuizExperience.learning,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = find.byType(CoachMarkOverlay);
    expect(overlay, findsOneWidget);
    // Sayaç çizilmediği için ilk adım sayacı hedefleyemez.
    expect(
      find.descendant(of: overlay, matching: find.text('Süre + Cevap')),
      findsNothing,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('Cevabı seç')),
      findsOneWidget,
    );
  });
}
