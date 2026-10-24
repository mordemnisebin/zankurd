/// Düello dürtme (istemci) bekçisi.
///
/// ## Kusur
///
/// Rakibini bekleyen oyuncunun elinde yalnız "Rakip bekleniyor" yazısı vardı:
/// rakip 24 saatlik pencerede oynamayı unutursa tek çare beklemekti. Sırayla
/// düellonun çekirdek döngüsü ("sıra karşıda") bu yüzden oyuncudan oyuncuya
/// iş yapamıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Düğme yalnız sunucu RPC'sine dayanır; düğmenin yanlış satırda çıkması
/// (sonucu hazır, sırası bende, kimsenin almadığı bağlantı), bekleme süresini
/// yazmaması ya da 12 saat dolmadan ikinci dokunuşa izin vermesi hiçbir
/// derleme/analiz testini bozmaz; yalnız rakibe art arda bildirim yağdırır ya
/// da dar ekranda taşar.
///
/// ## Kural
///
/// * Düğme yalnız "Rakip bekleniyor" satırında çıkar ([AsyncDuelSummary.canNudge]).
/// * Dürttükten sonra pasiftir ve "12 sa sonra tekrar" yazar; bekleme
///   `my_nudged_at`tan hesaplanır, saat YUKARI yuvarlanır.
/// * Reddedilen dürtme (bekleme, engel…) tek cümleyle söylenir, düğme açık kalır.
/// * 320 px ve %200 yazıda (TR + KU, etkin + pasif) taşma yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_nudge_button.dart';

import 'support/widget_test_helpers.dart';

const _nudgeKey = ValueKey('async-duel-nudge-button');

/// Sunucu reddini taklit eden depo.
class _RejectingRepository extends MockZanKurdRepository {
  _RejectingRepository(this.message);

  final String message;
  int attempts = 0;

  @override
  Future<DateTime> nudgeAsyncDuel(String duelId) async {
    attempts++;
    throw Exception(message);
  }
}

AsyncDuelSummary _summary({
  AsyncDuelStatus status = AsyncDuelStatus.matched,
  int? myCorrect = 4,
  AsyncDuelOutcome? outcome,
  String? opponentName = 'Rojda',
  String? invitedName,
  DateTime? expiresAt,
  DateTime? lastNudgedAt,
  bool incoming = false,
}) => AsyncDuelSummary(
  duelId: 'd1',
  status: status,
  role: AsyncDuelRole.creator,
  opponentName: opponentName,
  invitedName: invitedName,
  myCorrect: myCorrect,
  outcome: outcome,
  createdAt: DateTime.utc(2026, 10, 24),
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 9)),
  seen: true,
  incomingChallenge: incoming,
  lastNudgedAt: lastNudgedAt,
);

Widget _list(MockZanKurdRepository repo, {bool ku = false}) => testShell(
  languageProvider: ku ? kurmanciLang() : null,
  child: AsyncDuelListScreen(repository: repo),
);

bool _enabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.byKey(_nudgeKey)).onPressed != null;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
  });

  group('AsyncDuelSummary: dürtme alanları', () {
    test('my_nudged_at ayrıştırılır; yoksa null (eski sunucu)', () {
      final json = {
        'duel_id': 'x',
        'status': 'matched',
        'role': 'creator',
        'created_at': '2026-10-24T08:00:00Z',
        'seen': true,
      };
      expect(AsyncDuelSummary.fromJson(json).lastNudgedAt, isNull);
      final with_ = AsyncDuelSummary.fromJson({
        ...json,
        'my_nudged_at': '2026-10-24T09:30:00Z',
      });
      expect(with_.lastNudgedAt, DateTime.utc(2026, 10, 24, 9, 30));
      expect(with_.withProfiles().lastNudgedAt, with_.lastNudgedAt);
    });

    test(
      'canNudge: yalnız rakip bekleniyor + süre var + dürtülecek biri var',
      () {
        final now = DateTime.now();
        expect(_summary().canNudge(now), isTrue);
        // Sırası bende (turumu bitirmedim).
        expect(_summary(myCorrect: null).canNudge(now), isFalse);
        // Sonuç hazır.
        expect(
          _summary(
            status: AsyncDuelStatus.completed,
            outcome: AsyncDuelOutcome.win,
          ).canNudge(now),
          isFalse,
        );
        // Süresi geçmiş.
        expect(
          _summary(
            expiresAt: now.subtract(const Duration(minutes: 1)),
          ).canNudge(now),
          isFalse,
        );
        // Kimsenin almadığı bağlantı meydan okuması: dürtülecek kimse yok.
        expect(
          _summary(
            status: AsyncDuelStatus.open,
            opponentName: null,
          ).canNudge(now),
          isFalse,
        );
        // Kabul etmemiş davetli arkadaş dürtülebilir.
        expect(
          _summary(
            status: AsyncDuelStatus.open,
            opponentName: null,
            invitedName: 'Evîn',
          ).canNudge(now),
          isTrue,
        );
      },
    );

    test('nudgeCooldownLeft 12 saatten hesaplanır', () {
      final now = DateTime.utc(2026, 10, 24, 12);
      expect(_summary().nudgeCooldownLeft(now), isNull);
      expect(
        _summary(
          lastNudgedAt: now.subtract(const Duration(hours: 2)),
        ).nudgeCooldownLeft(now),
        const Duration(hours: 10),
      );
      expect(
        _summary(
          lastNudgedAt: now.subtract(const Duration(hours: 12, minutes: 1)),
        ).nudgeCooldownLeft(now),
        isNull,
      );
    });

    test('sunucu ret iletileri sınıflanır', () {
      AsyncDuelNudgeError c(String m) => classifyAsyncDuelNudgeError(m);
      expect(
        c('PostgrestException(message: Nudge cooldown)'),
        AsyncDuelNudgeError.cooldown,
      );
      expect(c('Nudge limit'), AsyncDuelNudgeError.limit);
      expect(c('Blocked'), AsyncDuelNudgeError.blocked);
      expect(c('Duel closed'), AsyncDuelNudgeError.closed);
      expect(c('Not a duel player'), AsyncDuelNudgeError.notAllowed);
      expect(c('Opponent already finished'), AsyncDuelNudgeError.notAllowed);
      expect(c('SocketException'), AsyncDuelNudgeError.other);
    });
  });

  group('sahte depo sunucu kuralını taklit eder', () {
    test('ikinci dürtme 12 saat dolmadan reddedilir', () async {
      final repo = freshMockRepository();
      final id = repo.addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 9),
        myTurn: false,
      );
      await repo.nudgeAsyncDuel(id);
      await expectLater(repo.nudgeAsyncDuel(id), throwsException);
      final list = await repo.loadMyAsyncDuels();
      expect(list.single.lastNudgedAt, isNotNull);
      expect(repo.nudgedDuelIdsForTesting, [id]);
    });

    test('turunu bitirmemiş oyuncu dürtemez', () async {
      final repo = freshMockRepository();
      final id = repo.addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 9),
      );
      await expectLater(repo.nudgeAsyncDuel(id), throwsException);
    });
  });

  group('"Dürt" düğmesi (düello listesi)', () {
    testWidgets(
      'Rakip bekleniyor satırında çıkar, dokununca gider ve pasifleşir',
      (tester) async {
        final repo = freshMockRepository();
        final id = repo.addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 9),
          myTurn: false,
        );
        await tester.pumpWidget(_list(repo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Rakip bekleniyor'), findsOneWidget);
        expect(find.text('Dürt'), findsOneWidget);
        expect(_enabled(tester), isTrue);

        await tester.tap(find.byKey(_nudgeKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(repo.nudgedDuelIdsForTesting, [id]);
        expect(find.text('Dürtme gönderildi'), findsOneWidget);
        expect(find.text('12 sa sonra tekrar'), findsOneWidget);
        expect(_enabled(tester), isFalse);
      },
    );

    testWidgets('daha önce dürtülmüşse açılışta pasif ve süre yazar', (
      tester,
    ) async {
      final repo = freshMockRepository();
      final id = repo.addOpenAsyncDuelForTesting(
        expiresIn: const Duration(hours: 9),
        myTurn: false,
      );
      await repo.nudgeAsyncDuel(id);
      await tester.pumpWidget(_list(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dürt'), findsNothing);
      expect(find.text('12 sa sonra tekrar'), findsOneWidget);
      expect(_enabled(tester), isFalse);
    });

    for (final nudged in [false, true]) {
      testWidgets('Kurmancî metinler (${nudged ? 'pasif' : 'etkin'})', (
        tester,
      ) async {
        final repo = freshMockRepository();
        final id = repo.addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 9),
          myTurn: false,
        );
        if (nudged) await repo.nudgeAsyncDuel(id);
        await tester.pumpWidget(_list(repo, ku: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text(nudged ? 'Piştî 12 saetan dîsa' : 'Bîr bixe'),
          findsOneWidget,
        );
      });
    }

    testWidgets('sırası bende olan satırda düğme yok', (tester) async {
      final repo = freshMockRepository()
        ..addOpenAsyncDuelForTesting(expiresIn: const Duration(hours: 9));
      await tester.pumpWidget(_list(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_nudgeKey), findsNothing);
    });

    testWidgets('ret: tek cümle söylenir, düğme açık kalır', (tester) async {
      final repo = _RejectingRepository('Nudge cooldown')
        ..addOpenAsyncDuelForTesting(
          expiresIn: const Duration(hours: 9),
          myTurn: false,
        );
      await tester.pumpWidget(_list(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(_nudgeKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.attempts, 1);
      expect(find.text('Dürtme gönderilemedi'), findsOneWidget);
      expect(_enabled(tester), isTrue);
    });
  });

  group('bekleme etiketi', () {
    testWidgets('saat yukarı, dakika yukarı yuvarlanır', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        testShell(
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        asyncDuelNudgeCooldownLabel(
          ctx,
          const Duration(hours: 11, minutes: 59),
        ),
        '12 sa sonra tekrar',
      );
      expect(
        asyncDuelNudgeCooldownLabel(ctx, const Duration(hours: 3)),
        '3 sa sonra tekrar',
      );
      expect(
        asyncDuelNudgeCooldownLabel(
          ctx,
          const Duration(minutes: 34, seconds: 10),
        ),
        '35 dk sonra tekrar',
      );
      expect(
        asyncDuelNudgeCooldownLabel(ctx, const Duration(seconds: 5)),
        '1 dk sonra tekrar',
      );
    });
  });

  group('taşma yok', () {
    Future<void> noOverflow(
      WidgetTester tester,
      MockZanKurdRepository repo, {
      required Size size,
      required double textScale,
      required bool ku,
    }) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = size * 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : null,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: AsyncDuelListScreen(repository: repo),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    }

    for (final (name, size, scale) in [
      ('390x844 %200', const Size(390, 844), 2.0),
      ('320x568 %100', const Size(320, 568), 1.0),
      ('320x568 %200', const Size(320, 568), 2.0),
    ]) {
      for (final ku in [false, true]) {
        for (final nudged in [false, true]) {
          testWidgets('düello listesi $name ${ku ? 'KU' : 'TR'} '
              '${nudged ? 'pasif' : 'etkin'}', (tester) async {
            final repo = freshMockRepository();
            final id = repo.addOpenAsyncDuelForTesting(
              expiresIn: const Duration(hours: 9),
              myTurn: false,
              opponentName: 'Şivanê Çiyayî Yê Mezin',
            );
            if (nudged) await repo.nudgeAsyncDuel(id);
            await noOverflow(
              tester,
              repo,
              size: size,
              textScale: scale,
              ku: ku,
            );
            expect(find.byKey(_nudgeKey), findsOneWidget);
          });
        }
      }
    }
  });
}
