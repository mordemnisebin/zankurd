/// 2026-09-30 canlı: sunucu denetiminin veri gösterimi bulguları.
///
/// ## Sıralama (madde 1)
///
/// Misafir bir hızlı düello (bota karşı) ve günün soruları turunu oynadıktan
/// sonra Gün/Hafta/Ay sekmelerinde satırı "0 puan" görünüyordu. Kök neden
/// istemcide değil kuraldadır: `get_leaderboard` (`room_players` x `rooms`,
/// yalnız `status = 'finished'`) sadece BİTEN ÇEVRİMİÇİ ODALARI toplar; bot
/// düellosu ve günün soruları cihazda oynanır, oda açmaz. Yani sunucuda
/// puan hiç yazılmaz ve bu bilerek böyledir. Sessiz kalıyordu çünkü liste
/// 0 puanlı satırı da çiziyordu (bir odada hiç puan almamış biri ya da
/// terk edilmiş oda), ve satır alt metni "1 ode" oyun sayısını yer gibi
/// anlatıyordu.
///
/// Bekçi: 0 puanlı satır listeye girmez (hiç kimse puanlı değilse boş durum
/// gösterilir), oyuncunun kendi satırı 0 puanla süzüldüyse sabit satır
/// yerine toplam XP basılmaz, ve oda sayısı "yarış / pêşbirk" birimiyle
/// yazılır.
///
/// ## Öteki maddeler
///
/// * Günün soruları turu bittiği gün sayfa "Tamamlandı / Tekrar oyna" der;
///   Öğren'deki kart 10/10 iken "Devam et" değil "Tekrar oyna" der.
/// * Premium rozeti cümle düzeninde; davet kodu her yerde "ZK-" ile; soru
///   öner yer tutucusu harfsiz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/suggest_question_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/widget_test_helpers.dart';

LeaderboardEntry _entry(
  int rank,
  String id,
  String name,
  int score, {
  int rooms = 3,
}) => LeaderboardEntry(
  rank: rank,
  playerId: id,
  displayName: name,
  totalScore: score,
  bestStreak: 2,
  roomsPlayed: rooms,
);

class _BoardRepo extends MockZanKurdRepository {
  _BoardRepo(this.rows, {this.stats, this.periodRank});

  final List<LeaderboardEntry> rows;
  final LeaderboardEntry? stats;

  /// Sabit satırın kaynağı (2026-09-30): seçili dönemin sıralaması.
  final LeaderboardEntry? periodRank;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => rows;

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => stats;

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async => periodRank;
}

Future<void> _pumpBoard(WidgetTester tester, MockZanKurdRepository repo) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: LeaderboardScreen(repository: repo)),
    ),
  );
  await tester.pumpAndSettle();
}

class _TagRepo extends MockZanKurdRepository {
  @override
  Future<String?> getPlayerTag() async => '7RHC';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
  });

  group('sıralama', () {
    testWidgets('0 puanlı satır listeye girmez, puanlılar sırasını korur', (
      tester,
    ) async {
      await _pumpBoard(
        tester,
        _BoardRepo([
          _entry(1, 'a', 'Awaz', 900),
          _entry(2, 'b', 'Berfîn', 400),
          _entry(3, 'user', 'Ben', 0, rooms: 1),
          _entry(4, 'c', 'Cegerxwîn', 0),
        ]),
      );
      expect(find.text('Awaz'), findsOneWidget);
      expect(find.text('Berfîn'), findsOneWidget);
      expect(find.text('Cegerxwîn'), findsNothing);
      // Kendi 0 puanlı satırı listede yok ve yerine toplam XP'li sabit
      // satır da basılmaz.
      expect(
        find.byKey(const ValueKey('leaderboard-my-rank-row')),
        findsNothing,
      );
    });

    testWidgets('kendi satırı 0 puanla süzüldüyse XP satırı sabitlenmez', (
      tester,
    ) async {
      await _pumpBoard(
        tester,
        _BoardRepo(
          [_entry(1, 'a', 'Awaz', 900), _entry(2, 'user', 'Ben', 0, rooms: 1)],
          // `getPlayerStats` hâlâ `leaderboard_entries`/`profiles.xp`
          // (TOPLAM XP) verir: dönem puanı değil, aynı etiketle
          // sunulamaz. Sabit satırın kaynağı artık `getMyLeaderboardRank`
          // ve burada null — oyuncunun dönem puanı yok.
          stats: _entry(40, 'user', 'Ben', 1143, rooms: 0),
          periodRank: null,
        ),
      );
      expect(find.text('Awaz'), findsOneWidget);
      expect(find.text('1143'), findsNothing);
    });

    testWidgets('kimse puanlı değilse boş durum gösterilir', (tester) async {
      await _pumpBoard(
        tester,
        _BoardRepo([_entry(1, 'user', 'Ben', 0, rooms: 1)]),
      );
      expect(find.text('Henüz puan yok'), findsOneWidget);
      expect(find.text('Yarışa başla'), findsOneWidget);
      expect(find.textContaining('0 oda'), findsNothing);
    });

    testWidgets('oyun sayısı "oda" değil "yarış" birimiyle yazılır', (
      tester,
    ) async {
      await _pumpBoard(
        tester,
        _BoardRepo([_entry(1, 'a', 'Awaz', 900, rooms: 7)]),
      );
      expect(find.text('7 yarış · 2 seri'), findsOneWidget);
      expect(find.textContaining(' oda'), findsNothing);
    });

    testWidgets('Kurmancî birim "pêşbirk"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: Scaffold(
            body: LeaderboardScreen(
              repository: _BoardRepo([_entry(1, 'a', 'Awaz', 900, rooms: 7)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7 pêşbirk · 2 zincîr'), findsOneWidget);
    });
  });

  group('günün soruları', () {
    testWidgets('bitirilmeden önce "Başla", bitirilince "Tekrar oyna"', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      AchievementStore.resetInstance();
      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Başla'), findsOneWidget);
      expect(find.text('Tekrar oyna'), findsNothing);
    });

    testWidgets('tur bugün bittiyse sayfa tamamlandı der', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      AchievementStore.resetInstance();
      final store = await AchievementStore.load();
      await store.recordQuizResult(
        category: 'Tevlihev',
        totalQuestions: 10,
        correctCount: 10,
        bestStreak: 10,
        dailyStreak: 1,
        userScore: 825,
        dailyQuiz: true,
      );
      expect(store.dailyQuizDoneOn(DateTime.now()), isTrue);
      expect(
        store.dailyQuizDoneOn(DateTime.now().add(const Duration(days: 1))),
        isFalse,
        reason: 'yarın yeni tur: bayrak günle birlikte tutulur',
      );

      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tekrar oyna'), findsOneWidget);
      expect(find.text('Tamamlandı'), findsOneWidget);
      expect(find.text('Başla'), findsNothing);
    });

    testWidgets('sayfa içeriği ekranın üst kenarına yapışık kalmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      // Kart ve çipler kalan alanda ortalanır; alt yarı bomboş değildir.
      final chip = tester.getBottomLeft(find.text('20 sn/soru'));
      expect(chip.dy, greaterThan(430));
    });
  });

  group('Öğren kartı', () {
    Future<void> pump(WidgetTester tester, {required int done}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: TodayTaskCard(
              isKu: false,
              loading: false,
              done: done,
              total: 10,
              onStart: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('hedef dolunca "Devam et" değil "Tekrar oyna"', (tester) async {
      await pump(tester, done: 10);
      expect(find.text('Tekrar oyna'), findsOneWidget);
      expect(find.text('Devam et'), findsNothing);
    });

    testWidgets('hedef dolmadan "Devam et", hiç başlamadan "Başla"', (
      tester,
    ) async {
      await pump(tester, done: 4);
      expect(find.text('Devam et'), findsOneWidget);
      await pump(tester, done: 0);
      expect(find.text('Başla'), findsOneWidget);
    });
  });

  group('küçük düzeltmeler', () {
    test('premium rozeti cümle düzeninde kayıtlı', () {
      // 2026-09-30: ekrandaki çevirici kaldırıldı, kaynak düzeldi.
      for (final key in [K.premiumBadgeOn, K.premiumBadgeOff]) {
        for (final lang in AppLanguage.values) {
          final v = Tr.of(key, lang);
          expect(v, isNot(v.toUpperCase()), reason: '$key $lang');
        }
      }
    });

    testWidgets('davet kodu düğmesi "ZK-" ile yazılır ve satıra kırılmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: FriendsScreen(repository: _TagRepo()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ZK-7RHC'), findsOneWidget);
      expect(find.text('7RHC'), findsNothing);
      // "Kodê binivîse" tek satır: tam genişlikte düğme.
      final label = tester.getSize(find.text('Kodê binivîse'));
      expect(label.height, lessThanOrEqualTo(26));
    });

    testWidgets('soru öner yer tutucusu harfsiz', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: SuggestQuestionScreen(repository: MockZanKurdRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A) Cevap'), findsNothing);
      expect(find.text('Cevap'), findsNWidgets(4));
    });
  });
}
