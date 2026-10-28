// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
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
/// "Günün dersi", `experience` verilmediği için varsayılan `competition`
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

  test('pratik oturumu öğrenme akışı olarak başlatılır', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _startPractice()');
    expect(start, greaterThan(-1), reason: '_startPractice bulunamadı');
    final nextMethod = source.indexOf('\n  Future<void> ', start + 1);
    final body = source.substring(
      start,
      nextMethod == -1 ? source.length : nextMethod,
    );

    expect(
      body,
      contains('experience: QuizExperience.learning'),
      reason: 'Pratik yarışma modunda açılıyor',
    );
    expect(body, contains('enableTimer: false'));
  });

  test('yanlış tekrarı öğrenme pratiği olarak başlatılır', () {
    // 2026-10-28, kurul K9: profildeki "Yanlışlarım" satırı (ve
    // `_startMistakePractice`) kalktı; yanlış tekrarı Öğren'deki Tekrar
    // aşamasına (`tekrarQuestionRoute`) toplandı. Kural aynı: yanlış tekrarı
    // yarışma deneyimine ve süre baskısına düşmemeli.
    final source = File(
      'lib/src/screens/tekrar_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('Route<void> tekrarQuestionRoute(');
    expect(start, greaterThan(-1), reason: 'tekrarQuestionRoute bulunamadı');
    final nextMethod = source.indexOf('\nclass ', start + 1);
    final body = source.substring(
      start,
      nextMethod == -1 ? source.length : nextMethod,
    );

    expect(body, contains('practice: true'));
    expect(
      body,
      contains('experience: QuizExperience.learning'),
      reason: 'Yanlış tekrarı yarışma deneyimine düşmemeli',
    );
    expect(
      body,
      contains('enableTimer: false'),
      reason: 'Yanlış tekrarı süre baskısı olmadan çalışmalı',
    );
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

    expect(find.text('Nîv bi nîv'), findsNothing);
    expect(find.text('50/50'), findsNothing);
  });

  Future<void> pumpAndOpenExit(
    WidgetTester tester,
    MockZanKurdRepository repository,
    QuizExperience experience, {
    bool answerFirst = true,
  }) async {
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
    if (answerFirst) {
      await tester.tap(find.text(repository.questions.first.answers.first));
      await tester.pumpAndSettle();
    }

    // Quiz ekranı bir rota olarak açıldığı için AppBar geri düğmesi var;
    // PopScope onu yakalayıp onay diyalogunu gösterir.
    //
    // 2026-09-29 Şahnê: soru ekranı oyun sahnesidir (C iskeleti); geri oku
    // yerine sahnenin kapat (✗) düğmesi ayrılır. Kural aynı: çıkış onay
    // diyaloğundan geçer.
    await tester.tap(find.byKey(const ValueKey('quiz-close')));
    await tester.pumpAndSettle();
  }

  // 2026-10-02 uçtan uca QA: ilk soruda (cevap yok) X'e dokunmak turu sormadan
  // bitiriyordu; onay yalnız "ilerleme" varken (`PopScope.canPop`) çıkıyordu.
  // Niçin sessiz kalıyordu: bütün çıkış testleri önce bir şık işaretleyip
  // sonra çıkıyordu, yani "ilerleme var" yolunu sınıyor, ilk soru yolunu
  // hiç sınamıyordu.
  for (final experience in QuizExperience.values) {
    testWidgets('ilk soruda da X onay sorar ($experience), vazgeçince tur '
        'sürer', (tester) async {
      await pumpAndOpenExit(tester, repository, experience, answerFirst: false);
      expect(
        find.text(
          experience == QuizExperience.learning
              ? 'Turdan çıkılsın mı?'
              : 'Yarıştan çıkılsın mı?',
        ),
        findsOneWidget,
        reason: 'ilk soruda X sormadan çıkarmamalı',
      );
      // Güvenli eylem: turda kal.
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('öğrenme akışında çıkış diyalogu "ders" der', (tester) async {
    await pumpAndOpenExit(tester, repository, QuizExperience.learning);
    expect(find.text('Turdan çıkılsın mı?'), findsOneWidget);
    expect(find.text('Yarıştan çıkılsın mı?'), findsNothing);
  });

  testWidgets('yarışma akışında çıkış diyalogu "yarış" der', (tester) async {
    await pumpAndOpenExit(tester, repository, QuizExperience.competition);
    expect(find.text('Yarıştan çıkılsın mı?'), findsOneWidget);
    expect(find.text('Turdan çıkılsın mı?'), findsNothing);
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

  // 2026-10-24 (ürün sahibi onayı): kural yanlış cevap için DAR bir istisna
  // aldı — rakipsiz turda yanlışın hemen altında doğru cevap + açıklama
  // açılır (`wrong_answer_insight_test.dart`). Doğru cevapta ve yarış
  // modlarında (günün turu, düello, oda, bot) açıklama hâlâ turda açılmaz.
  //
  // 2026-07-26: kural tersine döndü. Açıklama artık **hiçbir modda** cevabın
  // hemen altında gösterilmez; tur sırasında yalnız doğru cevap görünür,
  // açıklamaların tamamı sonuç ekranında bir arada gelir. Uygulama sahibi
  // bunu birkaç kez sorun olarak bildirdi: şık işaretlenir işaretlenmez
  // altında paragraf açılıyor ve turun ritmi kesiliyordu.
  testWidgets('öğrenme akışında YANLIŞ cevabın altında açıklama açılır', (
    tester,
  ) async {
    await answerFirst(tester, QuizExperience.learning);
    expect(find.text('Bu acikllamanin gorunmesi gerekir.'), findsOneWidget);
    // 2026-08-19: "Doğru cevap" kutusu çoktan seçmeli sorulardan
    // kaldırıldı — doğru şık zaten yeşile dönüp tik alıyordu, kutu aynı
    // bilgiyi ikinci kez söyleyip kıt olan dikey alanı kaplıyordu
    // (uygulama sahibinin bildirimi). Kutu yalnız kelime sıralamada
    // kalır; orada doğru dizilimi açan başka hiçbir şey yok
    // (bkz. `needsAnswerRevealFallback`, `lesson_explanation_test`).
    // Korunan asıl kural DEĞİŞMEDİ: açıklama METNİ tur içinde açılmaz.
    expect(find.text('Doğru cevap'), findsNothing);
  });

  testWidgets('rakipsiz yarış akışında da yanlışta açıklama açılır', (
    tester,
  ) async {
    await answerFirst(tester, QuizExperience.competition);
    expect(find.text('Bu acikllamanin gorunmesi gerekir.'), findsOneWidget);
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
      find.descendant(of: overlay, matching: find.text('Süre ve cevap')),
      findsNothing,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('Cevabını ver')),
      findsOneWidget,
    );
  });
}
