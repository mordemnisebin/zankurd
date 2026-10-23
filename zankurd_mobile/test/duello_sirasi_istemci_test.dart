/// Sırayla düello 24 saat / hükmen / kalan süre (istemci) bekçisi.
///
/// ## Kusur
///
/// Düello satırları yalnız durumu söylüyordu ("Rakip bekleniyor", "Yarım
/// kaldı"): oyuncu sırasının ne kadar süre açık kaldığını göremiyordu, bu
/// yüzden hamlesini erteleyip süreyi kaçırıyordu. Süre dolunca turunu bitiren
/// oyuncu da "Rakip çıkmadı" ile eli boş kalıyordu; hükmen kazanç ve hükmen
/// kayıp ekranda hiç yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// `expires_at` zaten `AsyncDuelStart`ta ayrıştırılıp KULLANILMADAN duruyordu;
/// liste özetine hiç girmediği için hiçbir test eksikliği görmüyordu. Hükmen
/// sonuç `myCorrect == null` ile "Yarım kaldı" okunabilir ya da skorsuz
/// sonuç ekranı boş skor kartıyla çökebilir — ikisi de derlemeyi geçer.
///
/// ## Kural
///
/// * Özet `expires_at` ve `forfeit` alanlarını ayrıştırır; yokluğu eski
///   sunucuyla uyumludur (null / false).
/// * "Sıra sende" satırları en yakın bitişten başlayarak en üsttedir ve ince
///   kalan-süre çubuğu taşır; "Rakip bekleniyor" satırı yalnız kalan süre
///   metni taşır (çubuk yok).
/// * Kalan süre "18 sa kaldı" / "35 dk kaldı" (KU: "saet mane" / "deqe
///   mane"); hükmen sonuç "Kazandın · hükmen" / "Kaybettin · hükmen" ve tek
///   satır neden.
/// * Hükmen kazanan normal galibiyetin XP'sini (doğru × 20 + 30) alır;
///   kaybeden XP talep etmez.
/// * %200 yazı ve 320 px genişlikte taşma yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_time.dart';
import 'package:zankurd_mobile/src/screens/home/home_duel_card.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

/// `claimAsyncDuelXp` çağrılarını sayan depo.
class _ClaimCountingRepository extends MockZanKurdRepository {
  int claims = 0;

  @override
  Future<int> claimAsyncDuelXp(String duelId) {
    claims++;
    return super.claimAsyncDuelXp(duelId);
  }
}

AsyncDuelSummary _summary({
  AsyncDuelStatus status = AsyncDuelStatus.open,
  int? myCorrect,
  AsyncDuelOutcome? outcome,
  bool incoming = false,
  DateTime? expiresAt,
  bool forfeit = false,
  String id = 'd',
}) => AsyncDuelSummary(
  duelId: id,
  status: status,
  role: AsyncDuelRole.opponent,
  opponentName: 'Rojda',
  myCorrect: myCorrect,
  outcome: outcome,
  createdAt: DateTime.utc(2026, 10, 24),
  seen: true,
  incomingChallenge: incoming,
  expiresAt: expiresAt,
  isForfeit: forfeit,
);

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) => {
  'duel_id': 'x',
  'status': 'matched',
  'role': 'opponent',
  'created_at': '2026-10-24T08:00:00Z',
  'seen': true,
  ...extra,
};

Future<void> _surface(WidgetTester tester, {Size? size}) async {
  await tester.binding.setSurfaceSize(size ?? const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _listScreen(MockZanKurdRepository repo, {bool ku = false}) => testShell(
  languageProvider: ku ? kurmanciLang() : null,
  child: AsyncDuelListScreen(repository: repo),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
  });

  group('AsyncDuelSummary: expires_at ve forfeit', () {
    test('ayrıştırır', () {
      final s = AsyncDuelSummary.fromJson(
        _json(
          extra: {
            'expires_at': '2026-10-25T08:00:00Z',
            'forfeit': true,
            'outcome': 'win',
            'my_correct': 5,
          },
        ),
      );
      expect(s.expiresAt, DateTime.utc(2026, 10, 25, 8));
      expect(s.isForfeit, isTrue);
      expect(s.outcome, AsyncDuelOutcome.win);
    });

    test('alanlar yoksa eski sunucuyla uyumlu: null / false', () {
      final s = AsyncDuelSummary.fromJson(_json());
      expect(s.expiresAt, isNull);
      expect(s.isForfeit, isFalse);
      expect(s.timeLeft(DateTime.utc(2026, 10, 24)), isNull);
    });

    test('withProfiles yeni alanları korur', () {
      final s = AsyncDuelSummary.fromJson(
        _json(extra: {'expires_at': '2026-10-25T08:00:00Z', 'forfeit': true}),
      ).withProfiles();
      expect(s.expiresAt, DateTime.utc(2026, 10, 25, 8));
      expect(s.isForfeit, isTrue);
    });

    test('kalan süre, sıra bende ve rakip bekleniyor kuralları', () {
      final now = DateTime.now();
      final mine = _summary(expiresAt: now.add(const Duration(hours: 5)));
      expect(mine.isMyTurn, isTrue);
      expect(mine.isWaitingOpponent, isFalse);
      expect(mine.timeLeft(now)!.inHours, anyOf(4, 5));

      final waiting = _summary(
        myCorrect: 4,
        expiresAt: now.add(const Duration(hours: 5)),
      );
      expect(waiting.isMyTurn, isFalse);
      expect(waiting.isWaitingOpponent, isTrue);

      final incoming = _summary(incoming: true);
      expect(incoming.isMyTurn, isTrue);

      final done = _summary(
        status: AsyncDuelStatus.completed,
        myCorrect: 4,
        outcome: AsyncDuelOutcome.win,
      );
      expect(done.isMyTurn, isFalse);
      expect(done.isWaitingOpponent, isFalse);
    });

    test('saati geçmiş ama henüz süpürülmemiş düello devam ettirilmez', () {
      final late = _summary(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      expect(late.canResume, isFalse);
      expect(late.timeLeft(DateTime.now()), isNull);
    });
  });

  group('sıralama: "Sıra sende" önce, en yakın bitiş başta', () {
    test('sıra bende satırları bitişe göre, kalanlar sunucu sırasıyla', () {
      final now = DateTime.now();
      final late = _summary(
        id: 'late',
        expiresAt: now.add(const Duration(hours: 20)),
      );
      final soon = _summary(
        id: 'soon',
        expiresAt: now.add(const Duration(hours: 2)),
      );
      final mid = _summary(
        id: 'mid',
        incoming: true,
        expiresAt: now.add(const Duration(hours: 9)),
      );
      final waiting = _summary(
        id: 'waiting',
        myCorrect: 3,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final done = _summary(
        id: 'done',
        status: AsyncDuelStatus.completed,
        myCorrect: 3,
        outcome: AsyncDuelOutcome.loss,
      );
      final unknown = _summary(id: 'unknown');

      final ordered = asyncDuelInboxOrder([
        waiting,
        late,
        done,
        unknown,
        mid,
        soon,
      ]).map((s) => s.duelId).toList();

      expect(ordered, ['soon', 'mid', 'late', 'unknown', 'waiting', 'done']);
    });
  });

  group('kalan süre metni', () {
    Future<String?> label(
      WidgetTester tester,
      Duration? left, {
      bool ku = false,
    }) async {
      String? result;
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : null,
          child: Builder(
            builder: (context) {
              result = asyncDuelTimeLeftLabel(context, left);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('TR: saat ve dakika', (tester) async {
      expect(
        await label(tester, const Duration(hours: 18, minutes: 5)),
        '18 sa kaldı',
      );
      expect(await label(tester, const Duration(minutes: 35)), '35 dk kaldı');
      expect(
        await label(tester, const Duration(hours: 23, minutes: 59)),
        '24 sa kaldı',
      );
      expect(await label(tester, const Duration(seconds: 20)), '1 dk kaldı');
      expect(await label(tester, Duration.zero), isNull);
      expect(await label(tester, null), isNull);
    });

    testWidgets('KU: saet / deqe + mane', (tester) async {
      expect(
        await label(tester, const Duration(hours: 18), ku: true),
        '18 saet mane',
      );
      expect(
        await label(tester, const Duration(minutes: 35), ku: true),
        '35 deqe mane',
      );
    });

    test('çubuk oranı 24 saate göre, üstü kırpılır', () {
      expect(asyncDuelTimeFraction(const Duration(hours: 12)), 0.5);
      expect(asyncDuelTimeFraction(const Duration(hours: 40)), 1.0);
    });
  });

  group('Düellolarım satırları', () {
    testWidgets(
      '"Sıra sende" rozeti + kalan süre + çubuk; sıralı; bekleyen yalnız metin',
      (tester) async {
        await _surface(tester);
        final repo = freshMockRepository();
        repo.addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 18, minutes: 20),
          opponentName: 'Berfin',
        );
        repo.addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 3, minutes: 10),
          opponentName: 'Rojda',
        );
        repo.addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 10, minutes: 10),
          myTurn: false,
          opponentName: 'Welat',
        );

        await tester.pumpWidget(_listScreen(repo));
        await tester.pumpAndSettle();

        // İki "Sıra sende" rozeti, ikisi de ince çubuklu.
        expect(find.text('Sıra sende'), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('async-duel-time-bar')),
          findsNWidgets(2),
        );
        expect(find.text('18 sa kaldı'), findsOneWidget);
        expect(find.text('3 sa kaldı'), findsOneWidget);
        // Beklenen satır: durum metni + kalan süre, çubuk yok.
        expect(find.text('Rakip bekleniyor'), findsOneWidget);
        expect(find.text('10 sa kaldı'), findsOneWidget);

        // Sıra: en yakın bitiş (3 sa) → 18 sa → bekleyen.
        final soon = tester.getTopLeft(find.text('3 sa kaldı')).dy;
        final later = tester.getTopLeft(find.text('18 sa kaldı')).dy;
        final waiting = tester.getTopLeft(find.text('10 sa kaldı')).dy;
        expect(soon, lessThan(later));
        expect(later, lessThan(waiting));
      },
    );

    testWidgets('süre ≤ 4 saatte kalan süre metni acele (hata) renginde', (
      tester,
    ) async {
      await _surface(tester);
      final repo = freshMockRepository();
      repo.addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 3, minutes: 10),
      );
      repo.addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 18, minutes: 10),
      );
      await tester.pumpWidget(_listScreen(repo));
      await tester.pumpAndSettle();

      Color colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;
      expect(colorOf('3 sa kaldı'), isNot(colorOf('18 sa kaldı')));
    });

    testWidgets('hükmen: "Kazandın · hükmen" / "Kaybettin · hükmen" + neden', (
      tester,
    ) async {
      await _surface(tester);
      final repo = freshMockRepository()
        ..addForfeitedAsyncDuelForTesting(iWon: true, opponentName: 'Rojda')
        ..addForfeitedAsyncDuelForTesting(iWon: false, opponentName: 'Berfin');
      await tester.pumpWidget(_listScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Kazandın · hükmen'), findsOneWidget);
      expect(find.text('Kaybettin · hükmen'), findsOneWidget);
      expect(find.text('Rojda 24 saatte oynamadı'), findsOneWidget);
      expect(find.text('24 saatte oynamadın'), findsOneWidget);
      // Bitmiş düelloda kalan süre ya da çubuk yok.
      expect(find.byKey(const ValueKey('async-duel-time-bar')), findsNothing);
    });

    testWidgets('hükmen KU metinleri', (tester) async {
      await _surface(tester);
      final repo = freshMockRepository()
        ..addForfeitedAsyncDuelForTesting(iWon: true, opponentName: 'Rojda')
        ..addForfeitedAsyncDuelForTesting(iWon: false, opponentName: 'Berfin');
      await tester.pumpWidget(_listScreen(repo, ku: true));
      await tester.pumpAndSettle();

      expect(find.text('Tu bi ser ketî · xweber'), findsOneWidget);
      expect(find.text('Te winda kir · xweber'), findsOneWidget);
      expect(find.text('Rojda di 24 saetan de nelîst'), findsOneWidget);
      expect(find.text('Te di 24 saetan de nelîst'), findsOneWidget);
    });

    testWidgets('Yarış sekmesi: sırası bende satırları en üstte, süreli', (
      tester,
    ) async {
      await _surface(tester, size: const Size(390, 1600));
      final repo = freshMockRepository();
      repo.addOpenAsyncDuelForTesting(expiresIn: const Duration(hours: 7));
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repo, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      final turn = find.byKey(const ValueKey('play-hub-async-duel-turn'));
      expect(turn, findsOneWidget);
      expect(
        find.descendant(of: turn, matching: find.text('Sıra sende')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: turn, matching: find.text('7 sa kaldı')),
        findsOneWidget,
      );
      // Aynı satır alttaki "Düellolarım" kutusunda ikinci kez çıkmaz.
      expect(find.text('7 sa kaldı'), findsOneWidget);
    });
  });

  group('hükmen sonuç ekranı', () {
    Future<void> openResult(
      WidgetTester tester,
      MockZanKurdRepository repo, {
      bool ku = false,
    }) async {
      final summary = (await repo.loadMyAsyncDuels()).single;
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : null,
          child: AsyncDuelResultScreen(
            repository: repo,
            view: AsyncDuelResultView.fromSummary(summary),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('kazanan: başlık, neden, skor kartı yok, XP 5×20+30', (
      tester,
    ) async {
      await _surface(tester);
      final repo = _ClaimCountingRepository()
        ..addForfeitedAsyncDuelForTesting(iWon: true, opponentName: 'Rojda');
      await tester.runAsync(() async {});
      await openResult(tester, repo);

      expect(find.text('Kazandın · hükmen'), findsOneWidget);
      expect(find.text('Rojda 24 saatte oynamadı'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('async-duel-result-scoreboard')),
        findsNothing,
      );
      expect(find.text('+130 XP'), findsOneWidget);
      expect(repo.claims, 1);
    });

    testWidgets('kaybeden: başlık, neden, XP yok ve XP talep edilmez', (
      tester,
    ) async {
      await _surface(tester);
      final repo = _ClaimCountingRepository()
        ..addForfeitedAsyncDuelForTesting(iWon: false, opponentName: 'Rojda');
      await openResult(tester, repo);

      expect(find.text('Kaybettin · hükmen'), findsOneWidget);
      expect(find.text('24 saatte oynamadın'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(repo.claims, 0, reason: 'kaybedenin sunucuda sonuç satırı yok');
    });

    testWidgets('KU başlık ve neden', (tester) async {
      await _surface(tester);
      final repo = freshMockRepository()
        ..addForfeitedAsyncDuelForTesting(iWon: true, opponentName: 'Rojda');
      await openResult(tester, repo, ku: true);

      expect(find.text('Tu bi ser ketî · xweber'), findsOneWidget);
      expect(find.text('Rojda di 24 saetan de nelîst'), findsOneWidget);
    });

    test('görünüm: hükmen "Yarım kaldı" değil, tamamlanmış sonuçtur', () {
      final loser = AsyncDuelResultView.fromSummary(
        _summary(
          status: AsyncDuelStatus.expired,
          outcome: AsyncDuelOutcome.loss,
          forfeit: true,
        ),
      );
      expect(loser.kind, AsyncDuelResultKind.completed);
      expect(loser.isForfeit, isTrue);
      expect(loser.isForfeitLoss, isTrue);
      expect(loser.myCorrect, isNull);
    });
  });

  group('mock depo hükmen XP', () {
    test('kazanan 5×20+30 = 130 alır; kaybeden talep edemez', () async {
      final repo = freshMockRepository()
        ..addForfeitedAsyncDuelForTesting(iWon: true, myCorrect: 5)
        ..addForfeitedAsyncDuelForTesting(iWon: false);
      final list = await repo.loadMyAsyncDuels();
      final won = list.firstWhere((s) => s.outcome == AsyncDuelOutcome.win);
      final lost = list.firstWhere((s) => s.outcome == AsyncDuelOutcome.loss);
      expect(won.isForfeit && lost.isForfeit, isTrue);
      expect(won.status, AsyncDuelStatus.expired);

      final before = repo.awardedXpTotal;
      await repo.claimAsyncDuelXp(won.duelId);
      expect(repo.awardedXpTotal - before, 130);
      await expectLater(
        repo.claimAsyncDuelXp(lost.duelId),
        throwsA(isA<StateError>()),
      );
    });

    test('pencere 24 saat: yeni düello bitişi 24 saat sonra', () async {
      final repo = freshMockRepository();
      final start = await repo.startAsyncDuel();
      final left = start.expiresAt.difference(DateTime.now());
      expect(left, lessThanOrEqualTo(const Duration(hours: 24)));
      expect(left, greaterThan(const Duration(hours: 23, minutes: 59)));
      final summary = (await repo.loadMyAsyncDuels()).single;
      expect(summary.expiresAt, start.expiresAt);
    });
  });

  group('ana ekran kartı', () {
    Widget card(MockZanKurdRepository repo) => testShell(
      child: Scaffold(
        body: SingleChildScrollView(
          child: HomeDuelCard(repository: repo, asyncDuelEnabled: true),
        ),
      ),
    );

    testWidgets('yarım turum: "Sıra sende", kalan süre + çubuk, "Devam et"', (
      tester,
    ) async {
      await _surface(tester);
      final repo = freshMockRepository()
        ..addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 18, minutes: 10),
          opponentName: 'Rojda',
        );
      await tester.pumpWidget(card(repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-duel-card-your-turn')),
        findsOneWidget,
      );
      expect(find.text('Sıra sende'), findsOneWidget);
      expect(find.text('Rojda'), findsOneWidget);
      expect(find.text('18 sa kaldı'), findsOneWidget);
      expect(find.byKey(const ValueKey('async-duel-time-bar')), findsOneWidget);
      expect(find.text('Devam et'), findsOneWidget);
    });

    testWidgets('birden çok sıra: en yakın bitiş gösterilir', (tester) async {
      await _surface(tester);
      final repo = freshMockRepository()
        ..addOpenAsyncDuelForTesting(expiresIn: const Duration(hours: 20))
        ..addOpenAsyncDuelForTesting(expiresIn: const Duration(minutes: 35));
      await tester.pumpWidget(card(repo));
      await tester.pumpAndSettle();

      expect(find.text('Sıra sende · 2'), findsOneWidget);
      expect(find.text('35 dk kaldı'), findsOneWidget);
    });

    testWidgets('yalnız rakip beklenen düello: durum + kalan süre, çubuksuz', (
      tester,
    ) async {
      await _surface(tester);
      final repo = freshMockRepository()
        ..addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 9, minutes: 10),
          myTurn: false,
        );
      await tester.pumpWidget(card(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-duel-card')), findsOneWidget);
      expect(find.text('Rakip bekleniyor'), findsOneWidget);
      expect(find.text('9 sa kaldı'), findsOneWidget);
      expect(find.byKey(const ValueKey('async-duel-time-bar')), findsNothing);
    });
  });

  group('büyük yazı ve dar ekran: taşma yok', () {
    Future<void> noOverflow(
      WidgetTester tester,
      Widget child, {
      required Size size,
      required double textScale,
    }) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = size * 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: child,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    }

    MockZanKurdRepository richRepo() => freshMockRepository()
      ..addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 3, minutes: 10),
        opponentName: 'Rojda Xanimê Dirêj',
      )
      ..addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 12),
        myTurn: false,
        opponentName: 'Şivanê Çiyayî Yê Mezin',
      )
      ..addForfeitedAsyncDuelForTesting(
        iWon: true,
        opponentName: 'Rojda Xanimê Dirêj',
      )
      ..addForfeitedAsyncDuelForTesting(
        iWon: false,
        opponentName: 'Şivanê Çiyayî Yê Mezin',
      );

    for (final (name, size, scale) in [
      ('390x844 %200', const Size(390, 844), 2.0),
      ('320x568 %100', const Size(320, 568), 1.0),
      ('320x568 %200', const Size(320, 568), 2.0),
    ]) {
      testWidgets('düello listesi $name', (tester) async {
        await noOverflow(
          tester,
          AsyncDuelListScreen(repository: richRepo()),
          size: size,
          textScale: scale,
        );
      });

      testWidgets('ana ekran kartı $name', (tester) async {
        await noOverflow(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: HomeDuelCard(
                repository: richRepo(),
                asyncDuelEnabled: true,
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
      });

      for (final won in [true, false]) {
        testWidgets('hükmen sonuç (${won ? 'kazanan' : 'kaybeden'}) $name', (
          tester,
        ) async {
          final repo = freshMockRepository()
            ..addForfeitedAsyncDuelForTesting(
              iWon: won,
              opponentName: 'Rojda Xanimê Dirêj',
            );
          final summary = (await repo.loadMyAsyncDuels()).single;
          await noOverflow(
            tester,
            AsyncDuelResultScreen(
              repository: repo,
              view: AsyncDuelResultView.fromSummary(summary),
            ),
            size: size,
            textScale: scale,
          );
        });
      }
    }
  });
}
