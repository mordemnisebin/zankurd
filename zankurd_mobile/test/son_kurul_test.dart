/// 2026-10-29 son kurul — son tasarım jürisinin (GPT-6 Astra, GPT-6.1 Sol,
/// GPT-6.1 Terra) en az iki modelin uyuştuğu bulguları.
///
/// ## Kusurlar ve niçin sessiz kalırlardı
///
/// 1. **Sonuç "Üst üste" > "Doğru":** ekran turu fikstürü `bestStreak`i sabit
///    2 veriyordu; 1 doğrulu turda "1 Doğru · 2 Üst üste" basıldı. Oyunun
///    kendisi zinciri doğru sayar (`quiz_screen`: doğruda +1, yanlışta 0),
///    ama sonuç ekranı gelen değere körü körüne güveniyordu. Artık ekran
///    zinciri doğru sayısıyla sınırlar; fikstür zinciri kayıtlardan hesaplar.
///    Hiçbir test iki sayının TUTARLILIĞINA bakmıyordu.
/// 2. **İki inceleme eylemi:** alt perdede "Cevapları gör (n)", gövdede
///    "Yanlışları incele" aynı işi sunuyordu; rozetteki "2" neyin sayısı
///    olduğunu söylemiyordu. Testler her düğmenin VARLIĞINI ölçüyordu.
/// 3. **Turnuva "Dolunca":** neyin dolacağı (4 oyuncu) yazmıyordu; bekleme
///    ekranında 24 saatin bittiği an yoktu. Lobide sunucu doluluk vermez
///    (`get_tournament_bracket` yalnız kayıtlı oyuncuya döner) — uydurulmaz.
/// 4. **Oda "3+ kişi":** oda 2 kişiyle başlar (`canStart`, `start_room_game`),
///    kapasite 2–50. Metin bir eski kararın kalıntısıydı.
/// 5. **Bot açıklaması:** bot olasılığı yalnız arama BAŞLAYINCA küçük notta
///    söyleniyordu; VS sahnesinde bot rakip insan gibi görünüyordu.
/// 6. **Kelimelerim sayıları:** "Tekrar · bugün 5", "3 kelime · 2 soru" ve
///    "4 kelime" kapsamı söylemiyordu.
/// 7. **Mağaza:** Joker paketi ve Ekstra çevirmenin işlev satırı yoktu.
/// 8. **Çark:** dinlenirken işaretçi iki dilimin SINIRINI gösteriyordu
///    (dönme açısı 0; −90° bir dilim sınırı). Ödül eşlemesi bir yardımcıya
///    çıkarıldı ve burada her dilim için sınanır.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

class _NoOpponentRepository extends MockZanKurdRepository {
  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async =>
      const {'status': 'waiting'};

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() =>
      const Stream.empty();

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async => const {
    'status': 'cancelled',
  };
}

class _WaitingCupRepository extends MockZanKurdRepository {
  _WaitingCupRepository(this.bracket);
  final TournamentBracket bracket;

  @override
  String? get currentUserId => 'me';

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => bracket;
}

class _ShopRepo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 300;
}

Widget _matchShell(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
    ),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

List<AnswerRecord> _records({required int wrong, int total = 3}) => [
  for (var i = 0; i < total; i++)
    AnswerRecord(
      id: 'r$i',
      category: 'Ziman',
      prompt: 'Pirs $i',
      answers: const ['A', 'B'],
      correctAnswer: 'A',
      selectedAnswer: i >= total - wrong ? 'B' : 'A',
      explanation: 'Şirove',
      explanationTr: 'Açıklama $i',
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> pumpResult(
    WidgetTester tester, {
    required int wrong,
    required int bestStreak,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final repository = freshMockRepository();
    final records = _records(wrong: wrong);
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 240,
          correctCount: records.length - wrong,
          wrongCount: wrong,
          totalQuestions: records.length,
          bestStreak: bestStreak,
          coinsAwarded: 0,
          answerRecords: records,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('1–2 sonuç ekranı', () {
    testWidgets('"Üst üste" doğru sayısını aşamaz', (tester) async {
      await pumpResult(tester, wrong: 2, bestStreak: 2);
      final tiles = tester.widget<ResultStatTiles>(
        find.byType(ResultStatTiles),
      );
      expect(tiles.correct, 1);
      expect(tiles.streak, lessThanOrEqualTo(tiles.correct));
    });

    testWidgets('tek inceleme eylemi; rozet birimli; liste alt perdenin '
        'üstünde biter', (tester) async {
      await pumpResult(tester, wrong: 2, bestStreak: 1);
      expect(
        find.byKey(
          const ValueKey('result-review-mistakes-button'),
          skipOffstage: false,
        ),
        findsNothing,
        reason: 'alt perdedeki "Cevapları gör" varken ikinci inceleme yolu',
      );
      final see = find.byKey(const ValueKey('result-see-answers-button'));
      expect(see, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-see-answers-badge')),
          matching: find.text('2 yanlış'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Cevapları gör (2 yanlış)'), findsOneWidget);

      // Kaydırılan gövde sabit alt perdenin ÜSTÜNDE biter: son bölüm
      // perdenin altında kalamaz.
      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(list).bottom,
        lessThanOrEqualTo(tester.getRect(see).top + 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('3 turnuva', () {
    testWidgets('lobide kapasite görünür', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: freshMockRepository())),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tournament-capacity')),
          matching: find.text('${TournamentConfig.totalPlayers} oyuncu'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('beklerken doluluk ve 24 saatin sonu yazılır', (tester) async {
      SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
      final openedAt = DateTime(2026, 10, 29, 9, 5);
      final repository = _WaitingCupRepository(
        TournamentBracket(
          tournamentId: 't1',
          userId: 'me',
          currentRound: 0,
          status: 'active',
          rounds: const [TournamentRound(roundNumber: 1, matches: [])],
          createdAt: openedAt,
          entryCount: 2,
          size: 4,
        ),
      );
      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: repository)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('2/4 oyuncu katıldı'), findsOneWidget);
      final due = formatMatchDeadline(
        openedAt.add(const Duration(hours: cupFillHours)),
      );
      expect(find.textContaining('24 saatin sonu: $due'), findsOneWidget);
    });
  });

  test('4 oda alt satırı gerçek en az/en çok oyuncu sayısını söyler', () {
    final tr = Tr.of(K.roomTileSub, AppLanguage.tr);
    final ku = Tr.of(K.roomTileSub, AppLanguage.ku);
    for (final s in [tr, ku]) {
      expect(s, isNot(contains('3+')));
      expect(s, contains('{min}'));
      expect(s, contains('{max}'));
    }
    expect(GameRoom.allowedMaxPlayers.first, 2);
  });

  group('5 eşleşme', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      XPStore.resetInstance();
    });

    testWidgets('bot olasılığı aramadan önce, düğmenin üstünde', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _matchShell(MatchmakingScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      final note = find.byKey(const ValueKey('matchmaking-bot-disclosure'));
      expect(note, findsOneWidget);
      expect(
        tester.getRect(note).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const ValueKey('matchmaking-random-cta')))
              .top,
        ),
      );
    });

    testWidgets('bot rakip VS sahnesinde "Bot" diye yazılır', (tester) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _matchShell(
          MatchmakingScreen(
            repository: _NoOpponentRepository(),
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('matchmaking-random-cta')));
      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.byKey(const ValueKey('mm-offer-bot')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining(RegExp(r'^Bot · Seviye \d+$')),
        findsOneWidget,
      );
      // Yönlendirme zamanlayıcısı bitsin.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('7 mağaza: güçlendiricilerin işlev satırı var', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: ShopScreen(repository: _ShopRepo())),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shop-stock-note-joker_pack_3')),
      findsOneWidget,
    );
    expect(find.text('Günün çarkında bir tur daha'), findsOneWidget);
  });

  group('8 çark', () {
    final n = SpinWheelScreen.rewards.length;
    final segment = 2 * math.pi / n;

    test('dinlenirken işaretçi bir dilimin ortasını gösterir', () {
      final local =
          (SpinWheelScreen.pointerAngle - SpinWheelScreen.restAngle) %
          (2 * math.pi);
      final offsetInSegment = local % segment;
      expect((offsetInSegment - segment / 2).abs(), lessThan(1e-9));
    });

    test('her kazanan dilim işaretçinin altında ve ortasında durur; ek '
        'çevirme son yerinden en az beş tur döner', () {
      for (var i = 0; i < n; i++) {
        for (final from in [
          0.0,
          SpinWheelScreen.restAngle % (2 * math.pi),
          4.2,
        ]) {
          final target = SpinWheelScreen.spinTarget(i, from: from);
          expect(SpinWheelScreen.segmentUnderPointer(target), i);
          expect(target - from, greaterThanOrEqualTo(5 * 2 * math.pi - 1e-9));
          final local = (SpinWheelScreen.pointerAngle - target) % (2 * math.pi);
          expect(((local % segment) - segment / 2).abs(), lessThan(1e-6));
        }
      }
    });
  });
}
