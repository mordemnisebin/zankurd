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
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/player.dart';
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
    SharedPreferences.setMockInitialValues(values);
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
  }) {
    return tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: _room,
          score: 60,
          correctCount: 1,
          wrongCount: 0,
          totalQuestions: 1,
          bestStreak: 1,
          answerRecords: const [],
          coinsAwarded: 10,
          resultOwnerUserId: userId,
          rewardSettlementState: QuizRewardSettlementState.claimed,
          receiptStages: stages,
        ),
      ),
    );
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

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.spendCalls, 0);
  });

  // ── 9. Coin harcama hatası ─────────────────────────────────────────
  testWidgets('harcama hatası ilerlemeyi düşürmez', (tester) async {
    await reset(breakingStreak());
    final repository = _FreezeRepository(balance: 500, spendThrows: true);
    await pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    expect(repository.spendCalls, 1);
    // Dondurma başarısız oldu ama tur boşa gitmedi: ekran ayakta ve
    // ilerleme yazıldı.
    expect(find.byType(QuizResultScreen), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect((preferences.getInt('zankurd.xp.total') ?? 0) > 0, isTrue);
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
  _FreezeRepository({required this.balance, this.spendThrows = false});

  final int balance;
  final bool spendThrows;
  int spendCalls = 0;
  int ackCalls = 0;

  @override
  String? get currentUserId => 'user-freeze';

  @override
  Future<int> loadCoinBalance() async => balance;

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    spendCalls++;
    if (spendThrows) throw StateError('injected: spend failed');
    return true;
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async => ackCalls++;
}
