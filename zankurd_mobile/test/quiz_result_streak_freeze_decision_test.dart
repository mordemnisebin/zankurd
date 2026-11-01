import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/services/paid_freeze_recovery_service.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';

import 'support/widget_test_helpers.dart';

/// Dondurma kararı, makbuzun kritik bölümünün DIŞINDA alınmalı.
///
/// İki adım da orada duramaz: diyalog sınırsız süre insan girdisi bekler,
/// `spend_coins` ise sunucuda idempotent değildir — `streak_freeze` için
/// hiçbir dedup anahtarı yok, her çağrı yeni bir `-50` satırı yazar
/// (`supabase/2026-08-02_shop_neon_frame_allowlist.sql`).
///
/// Bu dosya kararın kendisini ve coinin tek-seferliğini ölçer.
void main() {
  const roomId = 'room-freeze';
  const userId = 'user-freeze';
  tearDown(LocalProgressScope.debugReset);

  /// Dün oynanmış ve bugün oynanmamış bir seri: `willBreakOnPlay()` true
  /// döner, yani dondurma teklifi tam olarak bu kurulumda çıkar.
  Map<String, Object> breakingStreak() {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    return {
      'zankurd.streak.current': 7,
      'zankurd.streak.best': 7,
      'zankurd.streak.lastDay':
          '${twoDaysAgo.year.toString().padLeft(4, '0')}-'
          '${twoDaysAgo.month.toString().padLeft(2, '0')}-'
          '${twoDaysAgo.day.toString().padLeft(2, '0')}',
    };
  }

  Future<void> reset(Map<String, Object> values) async {
    QuizResultProgressReceiptStore.debugResetInFlight();
    SharedPreferences.resetStatic();
    LocalProgressScope.bind(userId);
    SharedPreferences.setMockInitialValues({
      for (final entry in values.entries)
        (entry.key.startsWith('zankurd.streak.') ||
                    entry.key.startsWith('zankurd.xp.')
                ? LocalProgressScope.physicalFor(userId, entry.key)
                : entry.key):
            entry.value,
    });
    AchievementStore.resetInstance();
    DailyMissionStore.resetInstance();
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    StreakStore.resetInstance();
    XPStore.resetInstance();
  }

  Future<void> pump(
    WidgetTester tester,
    _FreezeRepository repository, {
    QuizResultProgressReceiptStore? stages,
    bool solo = false,
    String? roundId,
  }) {
    return tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: solo
              ? const GameRoom(
                  name: 'Solo',
                  code: '',
                  category: 'Ziman',
                  players: [],
                  status: RoomStatus.finished,
                )
              : _room,
          score: 60,
          correctCount: 1,
          wrongCount: 0,
          totalQuestions: 1,
          bestStreak: 1,
          answerRecords: const [
            AnswerRecord(
              id: 'freeze-progress-question',
              category: 'Ziman',
              prompt: 'p',
              answers: ['A', 'B'],
              correctAnswer: 'A',
              selectedAnswer: 'A',
              explanation: '',
              responseMs: 4000,
            ),
          ],
          coinsAwarded: 10,
          resultOwnerUserId: solo ? null : userId,
          rewardSettlementState: solo
              ? null
              : QuizRewardSettlementState.claimed,
          roundId: roundId,
          receiptStages: stages,
        ),
      ),
    );
  }

  testWidgets(
    'bekçi: belirsiz solo ödeme XP ustalık görevini yutmaz; yalnız seri kurtarması kaybı gizliyordu',
    (tester) async {
      await reset(breakingStreak());
      final repository = _FreezeRepository(balance: 500, loseEveryReply: true);
      await pump(tester, repository, solo: true, roundId: 'pending-progress');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koru (50)'));
      await tester.pumpAndSettle();
      expect(repository.spendCalls, 2);
      expect((await XPStore.load()).totalXP, 90);
      expect((await MasteryStore.load()).correctCount('Ziman'), 1);
      expect((await DailyMissionStore.load()).correctAnswersToday, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      repository.loseEveryReply = false;
      StreakStore.resetInstance();
      XPStore.resetInstance();
      MasteryStore.resetInstance();
      DailyMissionStore.resetInstance();
      expect(
        await PaidFreezeRecoveryService.recoverPendingSolo(repository),
        isTrue,
      );
      expect((await StreakStore.load()).effectiveStreak(), 8);
      await pump(tester, repository, solo: true, roundId: 'pending-progress');
      await tester.pumpAndSettle();
      expect(
        (await XPStore.load()).totalXP,
        90,
        reason: 'yeniden açılış iki kez ödüllendirmez',
      );
      expect((await MasteryStore.load()).correctCount('Ziman'), 1);
      expect((await DailyMissionStore.load()).correctAnswersToday, 1);
      expect(repository.charged, hasLength(1));
    },
  );

  testWidgets(
    'bekçi: ikinci tur aynı seri için yeniden ücretlenmez; tur bazlı anahtar çift tahsilatı gizliyordu',
    (tester) async {
      await reset(breakingStreak());
      final repository = _FreezeRepository(balance: 500, loseEveryReply: true);
      await pump(tester, repository, solo: true, roundId: 'first-pending');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koru (50)'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      await pump(tester, repository, solo: true, roundId: 'second-pending');
      await tester.pumpAndSettle();
      expect(find.text('Koru (50)'), findsNothing);
      expect(repository.keysSeen.toSet(), hasLength(1));
      expect(
        (await XPStore.load()).totalXP,
        150,
        reason: 'ikinci tur ilerler; günlük bonus yinelenmez',
      );
      expect((await MasteryStore.load()).correctCount('Ziman'), 2);

      repository.loseEveryReply = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(repository.keysSeen.toSet(), hasLength(1));
      expect(repository.charged, hasLength(1));
      expect((await StreakStore.load()).effectiveStreak(), 8);
      expect((await XPStore.load()).totalXP, 150);
      expect((await DailyMissionStore.load()).correctAnswersToday, 2);
    },
  );

  testWidgets(
    'bekçi: bekleyen oda tahsilatı solo turda yinelenmez; yalnız solo taraması oda borcunu gizliyordu',
    (tester) async {
      await reset(breakingStreak());
      final repository = _FreezeRepository(balance: 500, loseEveryReply: true);
      await pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koru (50)'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, repository, solo: true, roundId: 'after-room');
      await tester.pumpAndSettle();
      expect(find.text('Koru (50)'), findsNothing);
      expect(repository.keysSeen.toSet(), hasLength(1));
      expect(repository.charged, hasLength(1));
      expect((await XPStore.load()).totalXP, 90);
    },
  );

  testWidgets('solo koruma boş olmayan tur kimliğiyle seriyi korur', (
    tester,
  ) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500);
    await pump(tester, repository, solo: true, roundId: 'solo-round-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    expect(repository.keysSeen.single, contains('solo-round-1'));
    expect(repository.keysSeen.single.trim(), isNotEmpty);
    expect((await StreakStore.load()).effectiveStreak(), 8);
  });

  testWidgets('tahsilat yanıtı kaybolunca aynı anahtarla korumayı tamamlar', (
    tester,
  ) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500, loseFirstReply: true);
    await pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    expect(repository.charged.length, 1);
    expect(repository.keysSeen, hasLength(2));
    expect(repository.keysSeen.toSet(), hasLength(1));
    expect((await StreakStore.load()).effectiveStreak(), 8);
    expect(repository.ackCalls, 1);
  });

  testWidgets('belirsiz tahsilat kalıcı bekler ve yeniden açılışta çözülür', (
    tester,
  ) async {
    final initial = breakingStreak();
    await reset(initial);
    final repository = _FreezeRepository(balance: 500, loseEveryReply: true);
    final stages = QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    );
    await pump(tester, repository, stages: stages);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    expect(repository.spendCalls, 2, reason: 'otomatik deneme sınırlıdır');
    expect(repository.ackCalls, 0);
    expect(
      (await StreakStore.load()).lastDay,
      initial['zankurd.streak.lastDay'],
    );
    expect(
      (await stages.read(userId: userId, roomId: roomId))!.stage.name,
      'freezeChargePending',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    repository.loseEveryReply = false;
    StreakStore.resetInstance();
    await pump(tester, repository, stages: stages);
    await tester.pumpAndSettle();

    expect(repository.charged.length, 1);
    expect(repository.keysSeen.toSet(), hasLength(1));
    expect((await StreakStore.load()).effectiveStreak(), 8);
    expect(repository.ackCalls, 1);
  });

  for (final outcome in [
    StreakFreezeChargeOutcome.failed,
    StreakFreezeChargeOutcome.charged,
  ]) {
    testWidgets('hesap değişince bekleyen $outcome başka hesaba uygulanmaz', (
      tester,
    ) async {
      final initial = breakingStreak();
      await reset(initial);
      final gate = Completer<StreakFreezeChargeResult>();
      final repository = _FreezeRepository(balance: 500, firstReply: gate);
      await pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koru (50)'));
      await tester.pump();
      expect(repository.spendCalls, 1);
      repository.ownerId = 'user-b';
      LocalProgressScope.bind('user-b');
      gate.complete(
        StreakFreezeChargeResult(outcome: outcome, idempotent: true),
      );
      await tester.pumpAndSettle();

      expect(repository.spendCalls, 1);
      expect(repository.ackCalls, 0);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt('zankurd.scope.user-b.zankurd.streak.current'),
        isNull,
      );
      expect(
        preferences.getString(
          LocalProgressScope.physicalFor(userId, 'zankurd.streak.lastDay'),
        ),
        initial['zankurd.streak.lastDay'],
      );
      expect(
        (await QuizResultProgressReceiptStore(
          preferences,
        ).read(userId: userId, roomId: roomId))!.stage.name,
        'freezeChargePending',
      );
    });
  }

  // ── 7. Kullanıcı dondurma kullanmadan devam ediyor ─────────────────
  testWidgets('kullanıcı reddederse coin harcanmaz', (tester) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500);
    await pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Hayır, sıfırlansın'));
    await tester.pumpAndSettle();

    expect(repository.spendCalls, 0);
    expect(find.byType(QuizResultScreen), findsOneWidget);
  });

  // ── 8. Bakiye yetersiz ─────────────────────────────────────────────
  testWidgets('bakiye yetersizse teklif hiç gösterilmez', (tester) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 10);
    await pump(tester, repository);
    await tester.pumpAndSettle();

    // Teklif yok (koruma satın alınamaz) ama sessizlik de yok: seri bu
    // turda kırılıyor ve oyuncuya eksik miktar söylenir (bkz.
    // `streak_shortfall_notice_test`). Yalnız bilgidir: harcama olmaz,
    // kapatılınca akış sürer.
    expect(find.text('Koru (50)'), findsNothing);
    expect(find.byKey(const ValueKey('result-streak-shortfall')), findsOne);
    expect(repository.spendCalls, 0);
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.spendCalls, 0);
    expect(find.byType(QuizResultScreen), findsOneWidget);
  });

  testWidgets('günlük seri uyarısı nedenini ve kaçırılan günleri gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500);
    await pump(tester, repository, solo: true);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Günlük seri')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Her gün en az bir tur ya da ders'),
      findsOneWidget,
    );
    final missed = tester
        .widget<Text>(find.byKey(const ValueKey('streak-freeze-missed-days')))
        .data!;
    final last = DateTime.parse(
      breakingStreak()['zankurd.streak.lastDay']! as String,
    );
    final first = DateTime(last.year, last.month, last.day + 1);
    expect(
      missed,
      contains(
        '${first.day.toString().padLeft(2, '0')}.${first.month.toString().padLeft(2, '0')}.${first.year}',
      ),
    );
    expect(missed, startsWith('Kaçırıldı:'));
    expect(find.text('Koru (50)').hitTestable(), findsOneWidget);
    expect(repository.spendCalls, 0);
    await tester.tap(find.text('Hayır, sıfırlansın'));
    await tester.pumpAndSettle();
    expect(repository.spendCalls, 0);
    expect(tester.takeException(), isNull);
  });

  // ── 9. Coin harcama hatası ─────────────────────────────────────────
  testWidgets('belirsiz harcama seriyi kırmadan yeniden denenebilir kalır', (
    tester,
  ) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500, spendThrows: true);
    await pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    expect(repository.spendCalls, 2);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(repository.ackCalls, 0);
    final receipt = await QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    ).read(userId: userId, roomId: roomId);
    expect(receipt!.stage.name, 'freezeChargePending');
  });

  // ── Coin tek-seferliği: belirsiz harcama tekrar denenmez ───────────
  testWidgets('freezeApplying aşamasından sonra coin yeniden harcanmaz', (
    tester,
  ) async {
    // Süreç, `spend_coins` isteği gönderildikten sonra öldü. Diskte
    // `freezeApplying` var ve harcamanın gerçekleşip gerçekleşmediği
    // bilinmiyor.
    await reset({
      ...breakingStreak(),
      QuizResultProgressReceiptStore.keyFor(userId: userId, roomId: roomId):
          '{"v":2,"stage":"freezeApplying","freeze":true}',
    });
    final repository = _FreezeRepository(balance: 500);
    final stages = QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    );
    await pump(tester, repository, stages: stages);
    await tester.pumpAndSettle();

    // Ne soru tekrar sorulur ne de coin tekrar harcanır.
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.spendCalls, 0, reason: 'coin en fazla bir kez');

    // Ve akış kilitlenmez: onaya kadar gider.
    expect(repository.ackCalls, 1);
    final receipt = await stages.read(userId: userId, roomId: roomId);
    expect(receipt!.stage, QuizResultReceiptStage.completed);
  });

  // ── 1. Karar beklerken ölen süreç: soru güvenle yeniden sorulur ────
  testWidgets('pendingUserDecision aşaması teklifi yeniden gösterir', (
    tester,
  ) async {
    await reset({
      ...breakingStreak(),
      QuizResultProgressReceiptStore.keyFor(userId: userId, roomId: roomId):
          '{"v":2,"stage":"pendingUserDecision"}',
    });
    final repository = _FreezeRepository(balance: 500);
    final stages = QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    );
    await pump(tester, repository, stages: stages);
    await tester.pumpAndSettle();

    // Bu aşamada hiçbir yan etki oluşmamıştı, bu yüzden yeniden sormak
    // güvenli — ve kullanıcının kararı kaybolmuş sayılmaz.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.spendCalls, 0);
  });

  // ── 10. Karar adımı hata verirse seri kaybolmaz ────────────────────
  testWidgets('bakiye okunamazsa bile seri kaydedilir', (tester) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500, balanceThrows: true);
    await pump(tester, repository);
    await tester.pumpAndSettle();

    // Teklif gösterilemedi ama tur yazıldı: `streak: 0` ile ilerlemek,
    // kullanıcının hatası olmayan bir hatayı onun serisine yansıtırdı.
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.spendCalls, 0);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt(
        LocalProgressScope.physicalFor(userId, 'zankurd.streak.current'),
      ),
      1,
    );
    expect(preferences.getInt('zankurd.streak.current'), isNull);
    expect(
      (preferences.getInt(
                LocalProgressScope.physicalFor(userId, 'zankurd.xp.total'),
              ) ??
              0) >
          0,
      isTrue,
    );
  });

  // ── Tahsilat, makbuzla AYNI degismez kimlikten turer ───────────────
  testWidgets('idempotency anahtari makbuz anahtariyla aynidir', (
    tester,
  ) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500);
    final stages = QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    );
    await pump(tester, repository, stages: stages);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    // Anahtar rastgele degil: ayni sonuc icin yapilan her tekrar ayni
    // anahtari tasir, sunucu da bu yuzden ikinci kez cekmez.
    expect(repository.keysSeen, [
      QuizResultProgressReceiptStore.keyFor(userId: userId, roomId: roomId),
    ]);
    expect(repository.spendCalls, 1);
  });

  // ── Tamamlanmış makbuz hiçbir şeyi tekrarlamaz ─────────────────────
  testWidgets('completed makbuz ne sorar ne harcar ne ACK eder', (
    tester,
  ) async {
    await reset({
      ...breakingStreak(),
      QuizResultProgressReceiptStore.keyFor(userId: userId, roomId: roomId):
          '{"v":2,"stage":"completed"}',
    });
    final repository = _FreezeRepository(balance: 500);
    final stages = QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    );
    await pump(tester, repository, stages: stages);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.spendCalls, 0);
  });
}

const _room = GameRoom(
  id: 'room-freeze',
  name: '1vs1',
  code: 'ZK-FRZ',
  category: 'Ziman',
  players: [
    Player(id: 'user-freeze', name: 'Ben', score: 60, state: 'Hazır'),
    Player(id: 'rakip', name: 'Rakip', score: 40, state: 'Hazır'),
  ],
  status: RoomStatus.finished,
  questionCount: 1,
);

class _FreezeRepository extends MockZanKurdRepository {
  _FreezeRepository({
    required this.balance,
    this.spendThrows = false,
    this.balanceThrows = false,
    this.loseFirstReply = false,
    this.loseEveryReply = false,
    this.firstReply,
  });

  final int balance;
  final Completer<StreakFreezeChargeResult>? firstReply;
  String ownerId = 'user-freeze';
  final bool spendThrows;
  final bool balanceThrows;
  final bool loseFirstReply;
  bool loseEveryReply;
  int spendCalls = 0;
  int ackCalls = 0;
  final List<String> keysSeen = [];
  final Set<String> charged = {};

  @override
  String? get currentUserId => ownerId;

  @override
  Future<int> loadCoinBalance() async {
    if (balanceThrows) throw StateError('injected: balance unavailable');
    return balance;
  }

  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
    bool allowLegacyFallback = true,
  }) async {
    spendCalls++;
    keysSeen.add(idempotencyKey);
    if (spendCalls == 1 && firstReply != null) return firstReply!.future;
    if (idempotencyKey.trim().isEmpty) {
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.failed,
        idempotent: true,
      );
    }
    if (spendThrows) throw StateError('injected: spend failed');
    if (loseEveryReply) {
      charged.add(idempotencyKey);
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.failed,
        idempotent: true,
      );
    }
    if (charged.contains(idempotencyKey)) {
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.alreadyCharged,
        idempotent: true,
      );
    }
    charged.add(idempotencyKey);
    if (loseFirstReply && spendCalls == 1) {
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.failed,
        idempotent: true,
      );
    }
    return const StreakFreezeChargeResult(
      outcome: StreakFreezeChargeOutcome.charged,
      idempotent: true,
    );
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async => ackCalls++;
}
