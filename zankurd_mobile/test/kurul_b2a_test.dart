import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// 2026-10-29 kurul (Opus 5.5 + GPT-6 Astra + GPT-6.1 Terra + GPT-6.1 Sol)
/// uzlaşı listesi, B2a (oyun / soru / oda / sonuç) bekçileri.
///
/// Her madde gerçek simülatör karelerinde (tur 2, iPhone 17 Pro) en az iki
/// modelin gördüğü bir kusurdur; kusurlar widget testinde sessiz kalıyordu
/// çünkü eski testler yalnız "metin var mı" diye bakıyordu, oyuncunun onu
/// nasıl okuduğunu (yarım kesik başlık, neyin sayısı olduğu belirsiz rozet,
/// bilgisiz "#1/4") ölçmüyordu.

Future<void> _setView(WidgetTester tester, double w, double h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

Widget _result({required int correct, required int wrong, int total = 10}) {
  final repository = MockZanKurdRepository();
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: correct * 100,
    correctCount: correct,
    wrongCount: wrong,
    totalQuestions: total,
    bestStreak: 0,
    coinsAwarded: 10,
    answerRecords: [
      for (var i = 0; i < total; i++)
        AnswerRecord(
          id: 'q$i',
          category: 'Ziman',
          prompt: 'Pirs $i',
          answers: const ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          selectedAnswer: i < correct
              ? 'A'
              : i < correct + wrong
              ? 'B'
              : 'TIMEOUT',
          explanation: 'Şîrove $i',
        ),
    ],
    opponents: const [
      Player(id: 'opp', name: 'QaAlı', score: 120, state: 'Online'),
    ],
  );
}

const _ordering = QuizQuestion(
  id: 'b2a-wo',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike',
  answers: ['Ez', 'diçim', 'malê'],
  correctAnswer: 'Ez diçim malê',
  explanation: '',
  type: QuestionType.wordOrdering,
);

void main() {
  // C1 (3/3): sonuç ekranında "Rakiplerle karşılaştır / Yarış sıralaması"
  // başlığı, günlük tur girişinde son satır sabit alt perdenin kıyısında
  // keskin biçimde YARIM kesiliyordu. Devamı varken içerik perdeye sönerek
  // girer (alfa maskesi; düz renk perdesi yok), sona varınca sönme kalkar.
  testWidgets('C1: alt perdeli sayfada devamı varken içerik söner', (
    tester,
  ) async {
    await _setView(tester, 402, 874);
    Widget page(int lines) => testShell(
      child: SahnePushedPage(
        title: 'Sayfa',
        bottom: const SahneButton.primary(label: 'Başla', onPressed: null),
        children: [for (var i = 0; i < lines; i++) Text('Satır $i')],
      ),
    );
    await tester.pumpWidget(page(80));
    await tester.pump();
    expect(find.byKey(const ValueKey('sahne-stage-dock-fade')), findsOneWidget);
    expect(find.byKey(const ValueKey('sahne-stage-dock-edge')), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -9000));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sahne-stage-dock-edge')),
      findsNothing,
      reason: 'sona varınca sönme/çizgi yok (K10: son satır erimez)',
    );
  });

  // C7 + C8 (Astra + Sol): rozet yalnız yanlışları sayıyordu, boş
  // (süresi dolan) sorular incelemede olduğu hâlde görünmüyordu; boş çipi
  // de neden boş kaldığını söylemiyordu.
  testWidgets('C7: inceleme rozeti yanlış + boş', (tester) async {
    await _setView(tester, 402, 1800);
    await tester.pumpWidget(testShell(child: _result(correct: 6, wrong: 2)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('2 yanlış · 2 boş'), findsOneWidget);
  });

  // C12 (Sol + Opus turu): gerçek zamanlı akış satırları sırasız verdiği için
  // aynı lobi cihazdan cihaza farklı sırada çiziliyordu.
  test('C12: oda oyuncuları katılma zamanına göre kararlı sıralanır', () {
    final rows = [
      {'player_id': 'c', 'joined_at': '2026-10-29T21:43:30Z'},
      {'player_id': 'a', 'joined_at': '2026-10-29T21:43:10Z'},
      {'player_id': 'd', 'joined_at': null},
      {'player_id': 'b', 'joined_at': '2026-10-29T21:43:10Z'},
    ]..sort(compareRoomPlayerRows);
    expect(rows.map((r) => r['player_id']), ['a', 'b', 'c', 'd']);
    final again = [rows[3], rows[1], rows[0], rows[2]]
      ..sort(compareRoomPlayerRows);
    expect(again.map((r) => r['player_id']), ['a', 'b', 'c', 'd']);
  });

  // C15 (Astra + Sol): sözcüklerin nasıl taşınıp geri alındığı yazmıyordu;
  // eksik cümlede "Kontrol et" tam etkin görünüyordu.
  testWidgets('C15: sıralamada yönerge sabit; Kontrol et tüm sözcüklerle', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: WordOrderingWidget(
            question: _ordering,
            disabled: false,
            selectedAnswer: '',
            onAnswerSubmitted: (v) => submitted = v,
          ),
        ),
      ),
    );
    await tester.pump();
    final howto = find.byKey(const ValueKey('word-ordering-howto'));
    expect(howto, findsOneWidget);
    final before = tester.getTopLeft(howto);
    FilledButton check() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(check().onPressed, isNull);
    await tester.tap(find.text('Ez').first);
    await tester.pumpAndSettle();
    expect(check().onPressed, isNull, reason: 'cümle eksik');
    expect(tester.getTopLeft(howto), before, reason: 'yönerge kaymaz');
    await tester.tap(find.text('diçim').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('malê').last);
    await tester.pumpAndSettle();
    expect(check().onPressed, isNotNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(submitted, 'Ez diçim malê');
  });

  // C31 (3/3): yarım kalan soruya dönüş bilgisi en altta küçük SnackBar'daydı.
  testWidgets('C31: sahne bildirimi üstte, yerleşimi itmez, süresi dolunca '
      'kalkar', (tester) async {
    await _setView(tester, 402, 874);
    late BuildContext ctx;
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: Center(child: Text('Soru')));
          },
        ),
      ),
    );
    final before = tester.getTopLeft(find.text('Soru'));
    QuizStageNotice.show(ctx, 'Süre işliyor');
    await tester.pump();
    expect(find.byKey(QuizStageNotice.key), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(QuizStageNotice.key)).dy,
      lessThan(200),
    );
    expect(tester.getTopLeft(find.text('Soru')), before);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(QuizStageNotice.key), findsNothing);
  });

  // Metin sözleşmeleri (TR): kurul maddelerinin sözleri.
  test('C4/C5/C9/C10/C11/C13/C16/C20/C25 metinleri', () {
    String tr(String k, [Map<String, String> p = const {}]) =>
        Tr.of(k, AppLanguage.tr, p);
    expect(
      tr(K.revealVerdictCountdown, {'verdict': 'Doğru', 'n': '3'}),
      'Doğru · sonraki 3 sn',
    );
    expect(
      tr(K.revealVerdictResults, {'verdict': 'Doğru'}),
      'Doğru · sonuçlar geliyor',
    );
    expect(tr(K.crowdAllTied), 'Eşit');
    expect(tr(K.crowdWaitingCount, {'n': '2'}), '2 oyuncu bekleniyor…');
    expect(tr(K.crowdHostStartHint), startsWith('Herkes gelince başlat'));
    expect(tr(K.freeEntry), 'Ücretsiz');
    expect(tr(K.freeEntrySummary), 'giriş ücretsiz');
    expect(tr(K.asyncDuelChip), 'Sırayla');
    expect(tr(K.perQuestionSeconds, {'n': '20'}), 'soru başına 20 sn');
    expect(tr(K.freeWildcardToday), 'Bugün ilk jokerin bedava');
    expect(tr(K.asyncDuelStartNew), 'Düello başlat');
    expect(tr(K.levelUpInline, {'n': '3'}), 'Yeni seviye: 3');
  });

  // C18 (Astra + Sol) + Astra incelemesi: görsel tam ekran açılır; açık
  // görünüm soruya bağlıdır — soru (görsel) değişince ya da görsel ekrandan
  // kalkınca kendiliğinden kapanır, yeni soruyu örtmez.
  testWidgets('C18: görsel büyütülür; soru değişince açık görünüm kapanır', (
    tester,
  ) async {
    await _setView(tester, 402, 874);
    final url = ValueNotifier<String?>('asset://assets/zankurd.webp');
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ValueListenableBuilder<String?>(
            valueListenable: url,
            builder: (context, value, _) => value == null
                ? const SizedBox()
                : QuizQuestionImage(url: value),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quiz-question-image-zoom')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quiz-question-image-zoom-view')),
      findsOneWidget,
    );
    url.value = null; // soru değişti, görsel kalktı
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quiz-question-image-zoom-view')),
      findsNothing,
    );
  });
}
