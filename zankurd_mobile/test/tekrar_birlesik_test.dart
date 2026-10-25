import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/tekrar_plani.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/tekrar_screen.dart';
import 'package:zankurd_mobile/src/widgets/todays_review_card.dart';

import 'support/widget_test_helpers.dart';

/// Tek "Tekrar" girişi (2026-10-24, sahip kararı "Hepsi şimdi").
///
/// ## Kusur
///
/// Üç örtüşen tekrar mekanizması vardı: "Kelimelerim" içindeki kelime
/// tekrarı kartı (Leitner), öğrenme ekranındaki "Bugünkü tekrar / Tekrar
/// edilecek N soru" kartı (yanlış defteri) ve kart modları. Kullanıcı
/// hangisini kullanacağını ayıramıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Her mekanizmanın kendi testi yeşildi; "kullanıcıya kaç giriş
/// gösteriyoruz" sorusunu soran bir test yoktu.
///
/// ## Bekçi
///
/// * bugünkü sayı iki kaynağın TOPLAMIDIR ve oturum ikisini de içerir;
/// * kelime aşaması Leitner kuralıyla kendi deposuna yazar, soru aşaması
///   (QuizScreen) açılırken yanlış defterine dokunulmaz;
/// * kelime tekrarını yalnız [TekrarScreen] açar (eski ikinci giriş yok);
/// * vadesi gelen yokken "Bugün tekrar yok" + öneri;
/// * 320 dp + %200 yazıda iki dilde taşma yok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MistakeStore.resetInstance();
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  tearDown(() {
    MistakeStore.resetInstance();
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  Future<WordListStore> words(List<String> ids, {DateTime? at}) async {
    final store = await WordListStore.load(storage: InMemoryDataStorage());
    final base = at ?? DateTime.now().subtract(const Duration(days: 1));
    for (var i = 0; i < ids.length; i++) {
      await store.add(ids[i], now: base.add(Duration(minutes: i)));
    }
    return store;
  }

  Future<MistakeStore> mistakes(List<String> ids) async {
    SharedPreferences.setMockInitialValues({'zankurd.mistakeQuestionIds': ids});
    MistakeStore.resetInstance();
    return MistakeStore.load();
  }

  Future<void> pumpShell(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double scale = 1,
    bool ku = false,
  }) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = Size(width, 900) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      testShell(
        languageProvider: ku ? kurmanciLang() : turkishLang(),
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('plan', () {
    test('bugünkü sayı iki kaynağın toplamıdır', () async {
      final repo = MockZanKurdRepository();
      final plan = TekrarPlan.build(
        wordStore: await words(['rojbas', 'evarbas', 'q-deri']),
        mistakeStore: await mistakes(['offline_0005', 'offline_0010']),
        playable: repo.playableQuestions,
      );
      expect(plan.dueWords, 3);
      expect(plan.dueQuestions, 2);
      expect(plan.dueTotal, 5);
      expect(plan.words, hasLength(3));
      expect(plan.questions, hasLength(2));
    });

    test(
      'pay: en çok 12, her kaynak en az yarısını korur, kelime en çok 10',
      () {
        expect(TekrarPlan.allocate(3, 20), (3, 9));
        expect(TekrarPlan.allocate(20, 20), (6, 6));
        expect(TekrarPlan.allocate(20, 2), (10, 2));
        expect(TekrarPlan.allocate(20, 0), (10, 0));
        expect(TekrarPlan.allocate(0, 20), (0, 12));
        expect(TekrarPlan.allocate(0, 0), (0, 0));
        for (var w = 0; w < 30; w++) {
          for (var q = 0; q <= 12; q++) {
            final (a, b) = TekrarPlan.allocate(w, q);
            expect(
              a + b,
              lessThanOrEqualTo(kTekrarSessionCap),
              reason: '$w/$q',
            );
          }
        }
      },
    );

    test('vadesi gelmemiş kelime sayılmaz', () async {
      final repo = MockZanKurdRepository();
      final store = await words(['rojbas'], at: DateTime.now());
      await store.recordReview('rojbas', correct: true);
      final plan = TekrarPlan.build(
        wordStore: store,
        mistakeStore: await mistakes([]),
        playable: repo.playableQuestions,
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.dueTotal, 0);
    });
  });

  group('giriş kartı', () {
    testWidgets('"Tekrar · bugün N" ve döküm (kelime + soru)', (tester) async {
      final w = await words(['rojbas', 'evarbas']);
      final m = await mistakes([
        'offline_0005',
        'offline_0010',
        'offline_0015',
      ]);
      await pumpShell(
        tester,
        Scaffold(
          body: TodaysReviewCard(
            repository: MockZanKurdRepository(),
            isKu: false,
            wordStore: w,
            mistakeStore: m,
          ),
        ),
      );
      expect(find.text('Tekrar · bugün 5'), findsOneWidget);
      expect(find.text('2 kelime · 3 soru'), findsOneWidget);
    });

    testWidgets('yalnız kelime varsa kart yine görünür ve oturum açar', (
      tester,
    ) async {
      final w = await words(['rojbas']);
      final m = await mistakes([]);
      await pumpShell(
        tester,
        Scaffold(
          body: TodaysReviewCard(
            repository: MockZanKurdRepository(),
            isKu: false,
            wordStore: w,
            mistakeStore: m,
            hideWhenEmpty: true,
          ),
        ),
      );
      expect(find.text('Tekrar · bugün 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('todays-review-card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('word-review-term')), findsOneWidget);
    });
  });

  group('oturum', () {
    testWidgets('önce kelimeler, sonra sorular; her biri kendi kuralıyla', (
      tester,
    ) async {
      final w = await words(['rojbas', 'evarbas']);
      final m = await mistakes(['offline_0005', 'offline_0010']);
      final before = m.ids.toSet();
      await pumpShell(
        tester,
        TekrarScreen(
          repository: MockZanKurdRepository(),
          isKu: false,
          wordStore: w,
          mistakeStore: m,
        ),
      );

      // Aşama 1: kelimeler (ilk kelime Rojbaş: en çok geciken).
      expect(find.byKey(const ValueKey('word-review-term')), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      for (final id in ['rojbas', 'evarbas']) {
        await tester.tap(find.text(LearnerLexicon.byId(id)!.meaningTr).first);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('word-review-next')));
        await tester.pump();
      }
      // Leitner: doğru -> 2. kutu, aralık 2 gün.
      expect(w.wordFor('rojbas')!.box, 2);
      expect(w.wordFor('evarbas')!.box, 2);
      expect(w.dueCount(), 0);
      // Soru aşaması henüz açılmadı: yanlış defteri değişmedi.
      expect(m.ids, before);

      expect(find.byKey(const ValueKey('word-review-done')), findsOneWidget);
      expect(find.text('Sorulara geç · 2'), findsOneWidget);
      expect(find.text('Kelimeler tamam'), findsOneWidget);
      expect(find.text('Tekrarlar tamam'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('word-review-finish')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Aşama 2: aynı iki soru, öğrenme kipinde quiz.
      final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
      expect(quiz.questions.map((q) => q.id).toSet(), {
        'offline_0005',
        'offline_0010',
      });
      expect(quiz.practice, isTrue);
      expect(quiz.enableTimer, isFalse);
      expect(find.byKey(const ValueKey('word-review-term')), findsNothing);
    });

    testWidgets('yalnız kelime varsa bitiş düğmesi "Tamamla" ve kapatır', (
      tester,
    ) async {
      final w = await words(['rojbas']);
      final m = await mistakes([]);
      await pumpShell(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TekrarScreen(
                    repository: MockZanKurdRepository(),
                    isKu: false,
                    wordStore: w,
                    mistakeStore: m,
                  ),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(LearnerLexicon.byId('rojbas')!.meaningTr).first,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('word-review-next')));
      await tester.pump();
      expect(find.text('Sorulara geç · 1'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('word-review-finish')));
      await tester.pumpAndSettle();
      expect(find.byType(TekrarScreen), findsNothing);
    });

    testWidgets('kelime yoksa doğrudan sorular açılır', (tester) async {
      final w = await words([]);
      final m = await mistakes(['offline_0005']);
      await pumpShell(
        tester,
        TekrarScreen(
          repository: MockZanKurdRepository(),
          isKu: false,
          wordStore: w,
          mistakeStore: m,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('word-review-term')), findsNothing);
    });

    testWidgets('hiçbir şey yoksa "Bugün tekrar yok" + öneri', (tester) async {
      final w = await words([]);
      final m = await mistakes([]);
      await pumpShell(
        tester,
        TekrarScreen(
          repository: MockZanKurdRepository(),
          isKu: false,
          wordStore: w,
          mistakeStore: m,
        ),
      );
      expect(find.byKey(const ValueKey('tekrar-empty')), findsOneWidget);
      expect(find.text('Bugün tekrar yok'), findsWidgets);
      expect(find.text('Yeni kelimeler öğren ya da oyna.'), findsOneWidget);
      expect(find.text('Sözlüğe göz at'), findsOneWidget);
    });
  });

  group('taşma: 320 dp + %200 yazı, iki dil', () {
    for (final ku in [false, true]) {
      testWidgets('kart, kelime aşaması, geçiş, boş durum (ku=$ku)', (
        tester,
      ) async {
        final w = await words(['rojbas', 'evarbas']);
        final m = await mistakes(['offline_0005', 'offline_0010']);
        await pumpShell(
          tester,
          Scaffold(
            body: TodaysReviewCard(
              repository: MockZanKurdRepository(),
              isKu: ku,
              wordStore: w,
              mistakeStore: m,
            ),
          ),
          width: 320,
          scale: 2,
          ku: ku,
        );
        expect(tester.takeException(), isNull, reason: 'kart');

        await pumpShell(
          tester,
          TekrarScreen(
            repository: MockZanKurdRepository(),
            isKu: ku,
            wordStore: w,
            mistakeStore: m,
          ),
          width: 320,
          scale: 2,
          ku: ku,
        );
        expect(tester.takeException(), isNull, reason: 'kelime');
        for (final id in ['rojbas', 'evarbas']) {
          final right = LearnerLexicon.byId(id)!.meaningTr;
          final option = find.text(right).first;
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pump();
          final next = find.byKey(const ValueKey('word-review-next'));
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pump();
        }
        expect(find.byKey(const ValueKey('word-review-done')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'geçiş');

        final e = await words([]);
        final em = await mistakes([]);
        await pumpShell(
          tester,
          TekrarScreen(
            repository: MockZanKurdRepository(),
            isKu: ku,
            wordStore: e,
            mistakeStore: em,
          ),
          width: 320,
          scale: 2,
          ku: ku,
        );
        expect(find.byKey(const ValueKey('tekrar-empty')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'boş');
      });
    }
  });

  test('tek giriş: kelime tekrarını yalnız TekrarScreen açar', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (file.path.endsWith('word_drill_screen.dart') ||
          file.path.endsWith('tekrar_screen.dart')) {
        continue;
      }
      // Pro serbest pratik (2026-10-25) tekrar DEĞİLDİR: kutu/vade yazmaz,
      // yalnız aboneye ayrı başlıkla görünür. Bu yüzden başka ekranlardan
      // yalnız `practice: true` ile açılabilir; vadesi gelen kelimelerin
      // tekrarı yine tek kapıdan (TekrarScreen) geçer.
      var at = text.indexOf('WordDrillScreen(');
      var bad = false;
      while (at >= 0) {
        final end = text.indexOf(';', at);
        final call = text.substring(at, end < 0 ? text.length : end);
        if (!call.contains('practice: true')) bad = true;
        at = text.indexOf('WordDrillScreen(', at + 1);
      }
      if (bad) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: 'ikinci tekrar girişi: $offenders');
    final myWords = File(
      'lib/src/screens/my_words_screen.dart',
    ).readAsStringSync();
    expect(myWords, isNot(contains('my-words-review-start')));
  });
}
