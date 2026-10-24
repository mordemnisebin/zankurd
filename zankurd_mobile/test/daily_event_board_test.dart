import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/daily_event_board.dart';

import 'support/widget_test_helpers.dart';

/// Günün yarışması sonucunun bekçisi (2026-10-24).
///
/// ## Kusur
///
/// Günün turu bitince oyuncu yalnız kendi skorunu görüyordu: kaçıncı
/// olduğunu, kimin önde olduğunu, dünün birincisini ve yeni turun ne zaman
/// açıldığını bilmiyordu. Sunucuda da sonuç kaydı yoktu (tur `contestId:
/// null` ile açılır).
///
/// ## Niçin sessiz kalırdı
///
/// Geri sayım bir saat dilimi hatasıyla (cihaz saati yerine İstanbul gece
/// yarısı) saatlerce yanlış olabilir ve hiçbir şey kırılmaz; pano boş
/// gelirse de ekran "çalışıyor" görünür. Sunucu günü `app_today()`
/// İstanbul günüdür; istemci aynı sınırı kullanmak zorundadır.
///
/// ## Kural
///
/// * Sınır her gün 21:00 UTC (İstanbul 00:00, UTC+3, yaz saati yok).
/// * Pano yalnız tur bitmişse görünür; tur sonu ekranı sonucu YAZAR, sonra
///   okur.
/// * İlk üç + (ilk üçte değilse) kendi satırın vurgulu + dünün birincisi.
/// * Okunamazsa dürüst satır; geri sayım yine görünür.
void main() {
  group('geri sayım (İstanbul gece yarısı = 21:00 UTC)', () {
    test('sınır 21:00 UTC', () {
      expect(
        nextContestResetAt(DateTime.utc(2026, 10, 24, 12)),
        DateTime.utc(2026, 10, 24, 21),
      );
      expect(
        nextContestResetAt(DateTime.utc(2026, 10, 24, 20, 59, 59)),
        DateTime.utc(2026, 10, 24, 21),
      );
      // Tam sınırda yeni gün başlamıştır: sonraki sıfırlama 24 saat sonra.
      expect(
        nextContestResetAt(DateTime.utc(2026, 10, 24, 21)),
        DateTime.utc(2026, 10, 25, 21),
      );
      // Ay ve yıl sonu taşar.
      expect(
        nextContestResetAt(DateTime.utc(2026, 12, 31, 22)),
        DateTime.utc(2027, 1, 1, 21),
      );
    });

    test('cihaz saat dilimi sonucu değiştirmez', () {
      final utc = DateTime.utc(2026, 10, 24, 12);
      // Aynı an, "yerel" olarak verilse de aynı sınır.
      expect(nextContestResetAt(utc.toLocal()), nextContestResetAt(utc));
    });

    test('kalan süre saat ve dakikaya, dakikaya yukarı yuvarlanarak', () {
      expect(contestResetCountdown(DateTime.utc(2026, 10, 24, 18)), (
        hours: 3,
        minutes: 0,
      ));
      expect(contestResetCountdown(DateTime.utc(2026, 10, 24, 12, 30)), (
        hours: 8,
        minutes: 30,
      ));
      // 59 sn kala "0 sa 0 dk" denmez.
      expect(contestResetCountdown(DateTime.utc(2026, 10, 24, 20, 59, 1)), (
        hours: 0,
        minutes: 1,
      ));
      // Yeni günün ilk anı: 24 saat.
      expect(contestResetCountdown(DateTime.utc(2026, 10, 24, 21)), (
        hours: 24,
        minutes: 0,
      ));
    });
  });

  group('model', () {
    test('sunucu yanıtı ayrıştırılır; bozuk satır atlanır', () {
      final board = DailyEventBoard.tryParse({
        'participants': 7,
        'top': [
          {
            'rank': 1,
            'name': 'Rojda',
            'correct': 10,
            'total': 10,
            'seconds': 62,
            'is_me': false,
          },
          {'rank': 'x'},
        ],
        'me': {
          'rank': 5,
          'name': 'Sen',
          'correct': 6,
          'total': 10,
          'seconds': 90,
          'is_me': true,
        },
        'yesterday': null,
      })!;
      expect(board.top.length, 1);
      expect(board.top.single.timeLabel, '1:02');
      expect(board.me!.isMe, isTrue);
      expect(board.me!.rank, 5);
      expect(board.yesterdayWinner, isNull);
      expect(board.participants, 7);
      expect(DailyEventBoard.tryParse('yok'), isNull);
    });
  });

  group('pano kartı', () {
    const bugun = DailyEventBoard(
      participants: 9,
      top: [
        DailyEventEntry(
          rank: 1,
          name: 'Rojda',
          correct: 10,
          total: 10,
          seconds: 62,
        ),
        DailyEventEntry(
          rank: 2,
          name: 'Baran',
          correct: 9,
          total: 10,
          seconds: 70,
        ),
        DailyEventEntry(
          rank: 3,
          name: 'Dilan',
          correct: 9,
          total: 10,
          seconds: 85,
        ),
      ],
      me: DailyEventEntry(
        rank: 6,
        name: 'Ben',
        correct: 6,
        total: 10,
        seconds: 131,
        isMe: true,
      ),
      yesterdayWinner: DailyEventEntry(
        rank: 1,
        name: 'Hevi',
        correct: 10,
        total: 10,
        seconds: 55,
      ),
    );

    final saat = DateTime.utc(2026, 10, 24, 18, 30); // 2 sa 30 dk kala

    Future<void> pump(
      WidgetTester tester,
      MockZanKurdRepository repo, {
      LanguageProvider? lang,
      double scale = 1.0,
      Size? size,
    }) async {
      if (size != null) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
      }
      await tester.pumpWidget(
        testShell(
          languageProvider: lang,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DailyEventBoardCard(
                    repository: repo,
                    clock: () => saat,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'ilk üç, kendi satırım (vurgulu), dünün birincisi, geri sayım',
      (tester) async {
        final repo = MockZanKurdRepository()..sampleDailyEventBoard = bugun;
        await pump(tester, repo);

        expect(find.text('Bugünün sıralaması'), findsOneWidget);
        for (final ad in ['Rojda', 'Baran', 'Dilan', 'Ben']) {
          expect(find.text(ad), findsOneWidget);
        }
        expect(find.text('10/10'), findsOneWidget);
        expect(find.text('9/10'), findsNWidgets(2));
        expect(find.text('1:02'), findsOneWidget);
        // Kendi satırım ilk üçte değil: ayrıca ve "Sen" rozetiyle.
        expect(find.byKey(const ValueKey('daily-event-row-6')), findsOneWidget);
        expect(find.text('Sen'), findsOneWidget);
        expect(find.text('Dünün birincisi: Hevi · 10/10'), findsOneWidget);
        expect(find.text('Yeni tur 2 sa 30 dk sonra'), findsOneWidget);
      },
    );

    testWidgets('ilk üçteysem kendi satırım ikinci kez çıkmaz', (tester) async {
      final repo = MockZanKurdRepository()
        ..sampleDailyEventBoard = DailyEventBoard(
          top: [
            bugun.top[0],
            const DailyEventEntry(
              rank: 2,
              name: 'Ben',
              correct: 9,
              total: 10,
              seconds: 70,
              isMe: true,
            ),
          ],
          me: const DailyEventEntry(
            rank: 2,
            name: 'Ben',
            correct: 9,
            total: 10,
            seconds: 70,
            isMe: true,
          ),
        );
      await pump(tester, repo);

      expect(find.text('Ben'), findsOneWidget);
      expect(find.text('Sen'), findsOneWidget);
      // Dün kimse bitirmediyse satır yok.
      expect(find.byKey(const ValueKey('daily-event-yesterday')), findsNothing);
    });

    testWidgets('çevrimdışı: dürüst satır, geri sayım yine görünür', (
      tester,
    ) async {
      final repo = MockZanKurdRepository(); // pano null = okunamadı
      await pump(tester, repo);

      expect(find.text('Sıralama şu an yüklenemedi.'), findsOneWidget);
      expect(find.text('Yeni tur 2 sa 30 dk sonra'), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-event-row-1')), findsNothing);
    });

    testWidgets('Kurmancî metinler', (tester) async {
      final repo = MockZanKurdRepository()..sampleDailyEventBoard = bugun;
      await pump(tester, repo, lang: kurmanciLang());

      expect(find.text('Rêzbendiya îroyê'), findsOneWidget);
      expect(find.text('Yekemînê duh: Hevi · 10/10'), findsOneWidget);
      expect(find.text('Gera nû piştî 2 saet 30 deqe'), findsOneWidget);
      expect(find.text('Tu'), findsOneWidget);
    });

    for (final ku in [false, true]) {
      testWidgets('320 genişlik, %200 yazı taşmaz (${ku ? 'ku' : 'tr'})', (
        tester,
      ) async {
        final repo = MockZanKurdRepository()..sampleDailyEventBoard = bugun;
        await pump(
          tester,
          repo,
          lang: ku ? kurmanciLang() : null,
          scale: 2.0,
          size: const Size(320, 800),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('daily-event-countdown')), findsOne);
      });
    }
  });

  group('ekranlar', () {
    Future<void> markDoneToday() async {
      final store = await AchievementStore.load();
      await store.recordQuizResult(
        category: 'Tevlihev',
        totalQuestions: 10,
        correctCount: 7,
        bestStreak: 3,
        dailyStreak: 0,
        userScore: 0,
        dailyQuiz: true,
      );
    }

    testWidgets('günün turu ekranı: bitmediyse sıralama YOK', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repo = MockZanKurdRepository();

      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily-event-board')), findsNothing);
      expect(find.text('Bugünün sıralaması'), findsNothing);
    });

    testWidgets('günün turu ekranı: bugün bitirdiyse sıralama açılır', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      await markDoneToday();
      final repo = MockZanKurdRepository()
        ..sampleDailyEventBoard = const DailyEventBoard(
          top: [
            DailyEventEntry(
              rank: 1,
              name: 'Rojda',
              correct: 10,
              total: 10,
              seconds: 62,
            ),
          ],
        );

      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily-event-board')), findsOneWidget);
      expect(find.text('Rojda'), findsOneWidget);
    });

    Future<void> pumpResult(
      WidgetTester tester,
      MockZanKurdRepository repo, {
      required bool dailyQuiz,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repo,
            room: repo.createRoom(),
            score: 70,
            correctCount: 7,
            wrongCount: 3,
            totalQuestions: 10,
            bestStreak: 3,
            coinsAwarded: 0,
            dailyQuiz: dailyQuiz,
            answerRecords: const [
              AnswerRecord(
                id: 'a',
                category: 'Ziman',
                prompt: 'p',
                answers: ['x', 'y'],
                correctAnswer: 'x',
                selectedAnswer: 'x',
                explanation: '',
                responseMs: 12000,
              ),
              AnswerRecord(
                id: 'b',
                category: 'Ziman',
                prompt: 'q',
                answers: ['x', 'y'],
                correctAnswer: 'x',
                selectedAnswer: 'y',
                explanation: '',
                responseMs: 8400,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('tur sonu: günün turu sonucu yazılır, pano görünür', (
      tester,
    ) async {
      freshMockRepository();
      final repo = MockZanKurdRepository()
        ..sampleDailyEventBoard = const DailyEventBoard(
          top: [
            DailyEventEntry(
              rank: 1,
              name: 'Rojda',
              correct: 10,
              total: 10,
              seconds: 62,
            ),
          ],
        );
      await pumpResult(tester, repo, dailyQuiz: true);

      expect(repo.dailyEventSubmissions, [(7, 10, 20)]);
      expect(find.byKey(const ValueKey('result-daily-board')), findsOneWidget);
      expect(find.text('Rojda'), findsOneWidget);
    });

    testWidgets('tur sonu: günün turu DEĞİLSE yazılmaz, pano yok', (
      tester,
    ) async {
      freshMockRepository();
      final repo = MockZanKurdRepository();
      await pumpResult(tester, repo, dailyQuiz: false);

      expect(repo.dailyEventSubmissions, isEmpty);
      expect(find.byKey(const ValueKey('result-daily-board')), findsNothing);
    });
  });

  tearDown(() => SharedPreferences.setMockInitialValues({}));
}
