/// Profilde "Son maçlar" ve "Rekorlarım" bekçisi.
///
/// ## Kusur
///
/// Profilde oyuncunun çevrimiçi geçmişi hiç yoktu: yalnız "Henüz soru
/// çözmedin" cümlesi duruyordu. Kimle oynadığını, kazanıp kazanmadığını,
/// en uzun serisini göremeyen oyuncunun geri dönmek için bir nedeni de
/// yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// Bölümler sunucuya dayanır; sunucu yokken (çevrimdışı, yerel misafir)
/// "henüz maç yok" yerine hata yazmak, ya da bilinmeyen sayıyı "0" diye
/// göstermek (örn. hiç düello oynamamışken "Kazanma oranı %0") hiçbir
/// derleme/analiz testini bozmaz; yalnız oyuncuya yanlış bilgi verir.
///
/// ## Kural
///
/// * Son maçlar: rakip adı, mod, sonuç (Kazandın/Kaybettin/Berabere/hükmen),
///   skor ve tarih; en çok 10 satır, yeniden eskiye.
/// * Boş durum oynamaya çağırır; sunucu hatasında "yüklenemedi" + tekrar dene
///   ("henüz maç yok" DEMEZ); çevrimdışı/yerel misafirde sunucuya sorulmaz.
/// * Rekorlar: hiçbiri bilinmiyorsa "İlk rekorunu kır" + oyna düğmesi (beş
///   satırlık "—" tablosu YOK); bazısı biliniyorsa yalnız bilinenler + ipucu;
///   sıfır uydurulmaz; kazanma oranı yalnız düello oynanmışsa.
/// * 320 px ve %200 yazıda (TR + KU) taşma yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/match_history.dart';
import 'package:zankurd_mobile/src/screens/profile/profile_matches_section.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';

import 'support/widget_test_helpers.dart';

/// Sunucu RPC'sini bozan depo.
class _FailingRepository extends MockZanKurdRepository {
  int matchCalls = 0;
  int recordCalls = 0;

  @override
  Future<List<RecentMatch>> loadMyRecentMatches({int limit = 10}) async {
    matchCalls++;
    throw StateError('offline');
  }

  @override
  Future<ServerRecords> loadMyServerRecords() async {
    recordCalls++;
    throw StateError('offline');
  }
}

RecentMatch _match(
  String id, {
  RecentMatchKind kind = RecentMatchKind.async,
  RecentMatchResult result = RecentMatchResult.win,
  String? opponent = 'Rojda',
  int? mine = 5,
  int? theirs = 4,
  bool forfeit = false,
  DateTime? at,
}) => RecentMatch(
  kind: kind,
  id: id,
  result: result,
  opponentName: opponent,
  myScore: mine,
  opponentScore: theirs,
  forfeit: forfeit,
  playedAt: at ?? DateTime(2026, 10, 24, 12),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
    StreakStore.resetInstance();
  });
  tearDown(() async {
    StreakStore.resetInstance();
    SyncManager.resetForTesting();
  });

  group('modeller', () {
    test('RecentMatch.tryParse: alanlar, tür ve hükmen', () {
      final m = RecentMatch.tryParse({
        'kind': 'room_1v1',
        'id': 'r1',
        'opponent_id': 'u2',
        'opponent_name': 'Evîn',
        'result': 'loss',
        'forfeit': true,
        'my_score': 3,
        'opponent_score': 8,
        'at': '2026-10-24T10:00:00Z',
      })!;
      expect(m.kind, RecentMatchKind.room1v1);
      expect(m.result, RecentMatchResult.loss);
      expect(m.forfeit, isTrue);
      expect(m.myScore, 3);
      expect(m.playedAt, DateTime.utc(2026, 10, 24, 10));
    });

    test(
      'bilinmeyen tür oda sayılır; sonucu ya da tarihi bozuk satır düşer',
      () {
        expect(
          RecentMatch.tryParse({
            'kind': 'yeni_tur',
            'id': 'x',
            'result': 'draw',
            'at': '2026-10-24T10:00:00Z',
          })!.kind,
          RecentMatchKind.room,
        );
        expect(
          RecentMatch.tryParse({
            'kind': 'async',
            'id': 'x',
            'result': 'belirsiz',
            'at': '2026-10-24T10:00:00Z',
          }),
          isNull,
        );
        expect(
          RecentMatch.tryParse({
            'kind': 'async',
            'id': 'x',
            'result': 'win',
            'at': 'bozuk',
          }),
          isNull,
        );
      },
    );

    test('ServerRecords: oran yalnız düello varsa, yoksa null', () {
      expect(const ServerRecords().winRatePercent, isNull);
      final r = ServerRecords.fromJson({
        'duel_wins': 2,
        'duel_losses': 1,
        'duel_draws': 0,
        'best_quiz_streak': null,
        'best_contest_correct': 9,
      });
      expect(r.duelTotal, 3);
      expect(r.winRatePercent, 67);
      expect(r.bestQuizStreak, isNull);
      expect(r.bestContestCorrect, 9);
    });

    test('sahte depo en çok limit satırı yeniden eskiye verir', () async {
      final repo = freshMockRepository()
        ..recentMatchesForTesting = [
          for (var i = 0; i < 12; i++)
            _match('m$i', at: DateTime(2026, 10, 1 + i)),
        ];
      final list = await repo.loadMyRecentMatches(limit: 10);
      expect(list, hasLength(10));
      expect(list.first.id, 'm11');
      expect(list.last.id, 'm2');
    });
  });

  group('Son maçlar', () {
    testWidgets('satırlar: rakip, sonuç, skor, tarih', (tester) async {
      final repo = freshMockRepository()
        ..recentMatchesForTesting = [
          _match('a', opponent: 'Rojda'),
          _match(
            'b',
            kind: RecentMatchKind.room1v1,
            result: RecentMatchResult.loss,
            opponent: 'Evîn',
            mine: 2,
            theirs: 7,
            at: DateTime(2026, 10, 23),
          ),
          _match(
            'c',
            kind: RecentMatchKind.room,
            result: RecentMatchResult.draw,
            opponent: 'Şivan',
            mine: 6,
            theirs: 6,
            at: DateTime(2026, 10, 22),
          ),
          _match(
            'd',
            result: RecentMatchResult.win,
            opponent: 'Heval',
            forfeit: true,
            theirs: null,
            at: DateTime(2026, 10, 21),
          ),
        ];
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileMatchHistorySection(repository: repo),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Son maçlar'), findsOneWidget);
      expect(find.text('Rojda'), findsOneWidget);
      expect(find.text('Kazandın · 5–4'), findsOneWidget);
      expect(find.text('24.10'), findsOneWidget);
      expect(find.text('Evîn'), findsOneWidget);
      expect(find.text('Kaybettin · 2–7'), findsOneWidget);
      expect(find.text('Berabere · 6–6'), findsOneWidget);
      // Hükmen: skor yazılmaz, mevcut hükmen metni kullanılır.
      expect(find.text('Kazandın · hükmen'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-match-a')), findsOneWidget);
    });

    // 2026-10-28 kurul K9 (eski "boş Son maçlar oynamaya çağırır" kararı
    // DEĞİŞTİ): boş Rekorlar ve boş Son maçlar iki ayrı boş kart değil, TEK
    // kompakt boş durumdur ve onu Rekorlar kartı (oyna eylemiyle) taşır.
    testWidgets('boş: ayrı boş kart çizilmez (tek boş durum Rekorlar)', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: ProfileMatchHistorySection(
              repository: freshMockRepository(),
              onStartPlay: () {},
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.textContaining('Henüz maç yok'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-recent-matches-empty')),
        findsNothing,
      );
      expect(find.text('Son maçlar'), findsNothing);
    });

    testWidgets('sunucu hatası: "yüklenemedi" + tekrar dene, "maç yok" DEĞİL', (
      tester,
    ) async {
      final repo = _FailingRepository();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(body: ProfileMatchHistorySection(repository: repo)),
        ),
      );
      await _settle(tester);
      expect(find.text('Düellolar yüklenemedi.'), findsOneWidget);
      expect(find.textContaining('Henüz maç yok'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('profile-recent-matches-retry')),
      );
      await _settle(tester);
      expect(repo.matchCalls, 2);
    });

    testWidgets('çevrimdışı/yerel misafir: sunucuya sorulmaz, boş durum', (
      tester,
    ) async {
      final repo = _FailingRepository();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: ProfileMatchHistorySection(repository: repo, remote: false),
          ),
        ),
      );
      await _settle(tester);
      expect(repo.matchCalls, 0);
      expect(find.textContaining('Henüz maç yok'), findsNothing);
    });

    testWidgets('Kurmancî başlık ve sonuç metinleri', (tester) async {
      final repo = freshMockRepository()
        ..recentMatchesForTesting = [_match('a')];
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: Scaffold(body: ProfileMatchHistorySection(repository: repo)),
        ),
      );
      await _settle(tester);
      expect(find.text('Pêşbirkên dawî'), findsOneWidget);
      expect(find.text('Bi ser ketî · 5–4'), findsOneWidget);
    });
  });

  group('Rekorlarım', () {
    testWidgets('hiçbiri bilinmiyorsa "—" tablosu yok, davetkâr boş durum', (
      tester,
    ) async {
      var starts = 0;
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(
                repository: freshMockRepository(),
                onStartPlay: () => starts++,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      // K9: boş durumda bölüm başlığı yok, tek kompakt kart var.
      expect(find.text('Rekorlarım'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-record-day-streak')),
        findsNothing,
      );
      expect(find.text('İlk rekorunu kır'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-records-start')));
      expect(starts, 1);
    });

    testWidgets('boş durumda oyna düğmesi çağıran vermediyse çizilmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: freshMockRepository()),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('profile-records-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-records-start')), findsNothing);
    });

    testWidgets('bazısı biliniyorsa yalnız bilinenler + ipucu', (tester) async {
      final repo = freshMockRepository()
        ..serverRecordsForTesting = const ServerRecords(bestQuizStreak: 4);
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: repo),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('profile-record-quiz-streak')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-record-contest')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-record-win-rate')),
        findsNothing,
      );
      expect(find.text('—'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-records-hint')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-records-empty')), findsNothing);
    });

    testWidgets('hepsi biliniyorsa ipucu yok', (tester) async {
      final repo = freshMockRepository()
        ..serverRecordsForTesting = const ServerRecords(
          duelWins: 1,
          bestQuizStreak: 2,
          bestContestCorrect: 3,
        );
      final streak = await StreakStore.load();
      await streak.recordPlay();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: repo),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('profile-records-hint')), findsNothing);
    });

    testWidgets('320 px + %200 yazıda boş durum taşmaz', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ProfileRecordsSection(
                    repository: freshMockRepository(),
                    onStartPlay: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gerçek değerler: seri (yerel) + sunucu sayıları', (
      tester,
    ) async {
      // Depo önce kurulur: `freshMockRepository` yerel kayıtları sıfırlar.
      final repo = freshMockRepository()
        ..serverRecordsForTesting = const ServerRecords(
          duelWins: 3,
          duelLosses: 1,
          duelDraws: 0,
          bestQuizStreak: 8,
          bestContestCorrect: 9,
        );
      final streak = await StreakStore.load();
      await streak.recordPlay();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: repo),
            ),
          ),
        ),
      );
      await _settle(tester);
      String valueOf(String key) {
        final row = find.byKey(ValueKey('profile-record-$key'));
        expect(row, findsOneWidget);
        final texts = tester
            .widgetList<Text>(
              find.descendant(of: row, matching: find.byType(Text)),
            )
            .map((t) => t.data)
            .toList();
        return texts.last!;
      }

      expect(valueOf('day-streak'), '1');
      expect(valueOf('quiz-streak'), '8');
      expect(valueOf('contest'), '9');
      expect(valueOf('duel-wins'), '3');
      expect(valueOf('win-rate'), '%75');
    });

    testWidgets('0 galibiyet ama düello oynanmış: "0" gerçek, oran %0', (
      tester,
    ) async {
      final repo = freshMockRepository()
        ..serverRecordsForTesting = const ServerRecords(duelLosses: 2);
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: repo),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-record-duel-wins')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-record-win-rate')),
          matching: find.text('%0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sunucu hatasında yerel seri yine görünür, ötekiler "—"', (
      tester,
    ) async {
      final streak = await StreakStore.load();
      await streak.recordPlay();
      final repo = _FailingRepository();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: repo),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(repo.recordCalls, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-record-day-streak')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.text('—'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-record-quiz-streak')),
        findsNothing,
      );
    });

    testWidgets('çevrimdışı: sunucuya sorulmaz', (tester) async {
      final repo = _FailingRepository();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileRecordsSection(repository: repo, remote: false),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(repo.recordCalls, 0);
    });
  });

  group('ProfileScreen içinde', () {
    testWidgets('bölümler profilde durur', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 4000);
      addTearDown(tester.view.reset);
      // U4 (2026-10-28 tur 4): hiç oynamamış profil tek "Başlangıç" kartıdır;
      // bölümler oynamış oyuncuda görünür (bir başarı açılmış).
      final repo = freshMockRepository()
        ..recentMatchesForTesting = [_match('a')];
      SharedPreferences.setMockInitialValues({
        'zankurd.achievements.unlocked': ['first_game'],
      });
      AchievementStore.resetInstance();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(body: ProfileScreen(repository: repo)),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('profile-records')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-recent-matches')),
        findsOneWidget,
      );
      expect(find.text('Rojda'), findsOneWidget);
    });
  });

  group('taşma yok', () {
    for (final (name, size, scale) in [
      ('390x844 %200', const Size(390, 844), 2.0),
      ('320x568 %100', const Size(320, 568), 1.0),
      ('320x568 %200', const Size(320, 568), 2.0),
    ]) {
      for (final ku in [false, true]) {
        for (final empty in [false, true]) {
          testWidgets('$name ${ku ? 'KU' : 'TR'} ${empty ? 'boş' : 'dolu'}', (
            tester,
          ) async {
            tester.view.devicePixelRatio = 3.0;
            tester.view.physicalSize = size * 3;
            addTearDown(tester.view.reset);
            final repo = freshMockRepository();
            if (!empty) {
              repo
                ..recentMatchesForTesting = [
                  _match('a', opponent: 'Şivanê Çiyayî Yê Mezin Û Dirêj'),
                  _match(
                    'b',
                    kind: RecentMatchKind.room1v1,
                    result: RecentMatchResult.loss,
                    opponent: 'Rojda Xanimê Dirêj',
                  ),
                  _match(
                    'c',
                    kind: RecentMatchKind.room,
                    result: RecentMatchResult.draw,
                    opponent: null,
                  ),
                  _match('d', forfeit: true, theirs: null),
                ]
                ..serverRecordsForTesting = const ServerRecords(
                  duelWins: 12,
                  duelLosses: 7,
                  duelDraws: 1,
                  bestQuizStreak: 14,
                  bestContestCorrect: 10,
                );
            }
            await tester.pumpWidget(
              testShell(
                languageProvider: ku ? kurmanciLang() : null,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ProfileRecordsSection(repository: repo),
                          ProfileMatchHistorySection(
                            repository: repo,
                            onStartPlay: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await _settle(tester);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
