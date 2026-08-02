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
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
    DailyMissionStore.resetInstance();
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    StreakStore.resetInstance();
    XPStore.resetInstance();
  });

  testWidgets('online receipt ilk frame tamamlandıktan sonra başlar', (
    tester,
  ) async {
    final repository = _DeliveryRepository();
    var firstFrameSeen = false;
    tester.binding.addPostFrameCallback((_) => firstFrameSeen = true);

    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner:
          ({required userId, required roomId, required action}) async {
            expect(firstFrameSeen, isTrue);
            return QuizResultProgressReceiptOutcome.skippedCompleted;
          },
    );
    await tester.pump();

    expect(repository.ackCalls, 1);
  });

  testWidgets('receipt terminal olmadan claimed sonuç ACK edilmez', (
    tester,
  ) async {
    final repository = _DeliveryRepository();
    final receiptGate = Completer<QuizResultProgressReceiptOutcome>();
    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner: ({required userId, required roomId, required action}) =>
          receiptGate.future,
    );
    await tester.pump();

    expect(repository.ackCalls, 0);

    receiptGate.complete(QuizResultProgressReceiptOutcome.skippedCompleted);
    await tester.pump();
    await tester.pump();
    expect(repository.ackCalls, 1);
  });

  testWidgets('claimed ve terminal receipt sonucu yalnız bir kez ACK eder', (
    tester,
  ) async {
    final repository = _DeliveryRepository();
    String? receivedUserId;
    String? receivedRoomId;
    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner:
          ({required userId, required roomId, required action}) async {
            receivedUserId = userId;
            receivedRoomId = roomId;
            return QuizResultProgressReceiptOutcome.skippedCompleted;
          },
    );
    await tester.pump();
    await tester.pump();

    expect(repository.ackCalls, 1);
    expect(receivedUserId, 'user-1');
    expect(receivedRoomId, 'room-1');
  });

  testWidgets('analytics tamamlanmadan receipt ve ACK tamamlanmaz', (
    tester,
  ) async {
    final analyticsGate = Completer<bool>();
    final repository = _DeliveryRepository(analyticsGate: analyticsGate);
    var receiptCompleted = false;
    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner:
          ({required userId, required roomId, required action}) async {
            await action();
            receiptCompleted = true;
            return QuizResultProgressReceiptOutcome.executed;
          },
    );
    for (var i = 0; i < 10 && repository.analyticsCalls == 0; i++) {
      await tester.pump();
    }

    expect(repository.analyticsCalls, 1);
    expect(repository.progressPersistedWhenAnalyticsCalled, isTrue);
    expect(receiptCompleted, isFalse);
    expect(repository.ackCalls, 0);

    analyticsGate.complete(true);
    await tester.pumpAndSettle();
    expect(receiptCompleted, isTrue);
    expect(repository.ackCalls, 1);
  });

  for (final state in [
    QuizRewardSettlementState.queued,
    QuizRewardSettlementState.unresolved,
  ]) {
    testWidgets('$state sonuç ekranını korur ama ACK etmez', (tester) async {
      final repository = _DeliveryRepository();
      await _pumpResult(tester, repository: repository, rewardState: state);
      await tester.pump();
      await tester.pump();

      expect(repository.ackCalls, 0);
      expect(find.byType(QuizResultScreen), findsOneWidget);
      if (state == QuizRewardSettlementState.queued) {
        expect(
          find.text('Bağlantı yok — ödülün kaydedildi, bağlanınca verilecek.'),
          findsOneWidget,
        );
      } else {
        expect(
          find.text(
            'Ödül henüz kaydedilemedi. Sonraki açılışta tekrar denenecek.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('ödülün kaydedildi'), findsNothing);
      }
    });
  }

  testWidgets('Kurmancî unresolved ileti kayıt garantisi vermez', (
    tester,
  ) async {
    final repository = _DeliveryRepository();
    await _pumpResult(
      tester,
      repository: repository,
      rewardState: QuizRewardSettlementState.unresolved,
      isKu: true,
    );
    await tester.pump();

    expect(
      find.text(
        'Xelat hîn nehatiye tomarkirin. Di vekirina din de dê dîsa bê '
        'ceribandin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('başlangıç owner uyuşmazlığında receipt ve ACK çalışmaz', (
    tester,
  ) async {
    final repository = _DeliveryRepository()..userId = 'other-user';
    var receiptCalls = 0;
    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner:
          ({required userId, required roomId, required action}) async {
            receiptCalls++;
            return QuizResultProgressReceiptOutcome.skippedCompleted;
          },
    );
    await tester.pump();

    expect(receiptCalls, 0);
    expect(repository.ackCalls, 0);
  });

  testWidgets('partial online delivery context receipt ve ACK çalıştırmaz', (
    tester,
  ) async {
    for (final delivery in <(String?, QuizRewardSettlementState?)>[
      ('user-1', null),
      (null, QuizRewardSettlementState.claimed),
    ]) {
      final repository = _DeliveryRepository();
      var receiptCalls = 0;
      await _pumpResult(
        tester,
        repository: repository,
        resultOwnerUserId: delivery.$1,
        rewardState: delivery.$2,
        receiptRunner:
            ({required userId, required roomId, required action}) async {
              receiptCalls++;
              return QuizResultProgressReceiptOutcome.skippedCompleted;
            },
      );
      await tester.pump();

      expect(receiptCalls, 0);
      expect(repository.ackCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('terminal olmayan veya owner üyesi eksik oda teslim edilmez', (
    tester,
  ) async {
    final invalidRooms = [
      _room.copyWith(status: RoomStatus.active),
      _room.copyWith(players: const []),
      _room.copyWith(
        players: const [
          Player(id: 'user-1', name: 'Ez', score: 60, state: Player.readyState),
          Player(
            id: 'user-1',
            name: 'Dublîkat',
            score: 60,
            state: Player.readyState,
          ),
        ],
      ),
      _room.copyWith(
        players: const [
          Player(id: 'user-1', name: 'Ez', score: 60, state: Player.readyState),
          Player(
            id: 'opponent',
            name: 'Hevrik',
            score: 20,
            state: Player.readyState,
          ),
          Player(
            id: 'opponent',
            name: 'Hevrik dublîkat',
            score: 20,
            state: Player.readyState,
          ),
        ],
      ),
    ];
    for (final room in invalidRooms) {
      final repository = _DeliveryRepository();
      var receiptCalls = 0;
      await _pumpResult(
        tester,
        repository: repository,
        room: room,
        receiptRunner:
            ({required userId, required roomId, required action}) async {
              receiptCalls++;
              return QuizResultProgressReceiptOutcome.skippedCompleted;
            },
      );
      await tester.pump();
      expect(receiptCalls, 0);
      expect(repository.ackCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('receipt hatası ekranı düşürmez ve ACK etmez', (tester) async {
    final repository = _DeliveryRepository();
    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner:
          ({required userId, required roomId, required action}) async =>
              throw StateError('receipt failed'),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.ackCalls, 0);
    expect(find.byType(QuizResultScreen), findsOneWidget);
  });

  testWidgets('receipt sonrasında owner değişirse ACK edilmez', (tester) async {
    final repository = _DeliveryRepository();
    final receiptGate = Completer<QuizResultProgressReceiptOutcome>();
    await _pumpResult(
      tester,
      repository: repository,
      receiptRunner: ({required userId, required roomId, required action}) =>
          receiptGate.future,
    );
    await tester.pump();

    repository.userId = 'other-user';
    receiptGate.complete(QuizResultProgressReceiptOutcome.executed);
    await tester.pump();
    await tester.pump();

    expect(repository.ackCalls, 0);
  });

  testWidgets('persisted receipt remountta local actionı atlar ama ACK dener', (
    tester,
  ) async {
    final repository = _DeliveryRepository(ackError: StateError('offline'));
    await _pumpResult(tester, repository: repository, receiptRunner: null);
    await tester.pumpAndSettle();
    expect(repository.analyticsCalls, 1);
    expect(repository.ackCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.ackError = null;
    await _pumpResult(tester, repository: repository, receiptRunner: null);
    await tester.pumpAndSettle();

    expect(repository.analyticsCalls, 1);
    expect(repository.ackCalls, 2);
  });

  testWidgets('ACK hatası sonuç ekranını bozmaz', (tester) async {
    final repository = _DeliveryRepository(ackError: StateError('offline'));
    await _pumpResult(tester, repository: repository);
    await tester.pump();
    await tester.pump();

    expect(repository.ackCalls, 1);
    expect(find.byType(QuizResultScreen), findsOneWidget);
  });
}

Future<void> _pumpResult(
  WidgetTester tester, {
  required _DeliveryRepository repository,
  String? resultOwnerUserId = 'user-1',
  QuizRewardSettlementState? rewardState = QuizRewardSettlementState.claimed,
  QuizResultReceiptRunner? receiptRunner = _skippedReceipt,
  GameRoom room = _room,
  bool isKu = false,
}) {
  return tester.pumpWidget(
    testShell(
      languageProvider: isKu ? kurmanciLang() : null,
      child: QuizResultScreen(
        repository: repository,
        room: room,
        score: 60,
        correctCount: 1,
        wrongCount: 0,
        totalQuestions: 1,
        bestStreak: 1,
        answerRecords: const [],
        coinsAwarded: 10,
        resultOwnerUserId: resultOwnerUserId,
        rewardSettlementState: rewardState,
        receiptRunner: receiptRunner,
      ),
    ),
  );
}

Future<QuizResultProgressReceiptOutcome> _skippedReceipt({
  required String userId,
  required String roomId,
  required Future<void> Function() action,
}) async => QuizResultProgressReceiptOutcome.skippedCompleted;

class _DeliveryRepository extends MockZanKurdRepository {
  _DeliveryRepository({this.ackError, this.analyticsGate});

  String userId = 'user-1';
  Object? ackError;
  final Completer<bool>? analyticsGate;
  int ackCalls = 0;
  int analyticsCalls = 0;
  bool? progressPersistedWhenAnalyticsCalled;

  @override
  String? get currentUserId => userId;

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {
    ackCalls++;
    if (ackError case final error?) throw error;
  }

  @override
  Future<bool> logAnalyticsEvent(
    String eventName,
    Map<String, dynamic>? params,
  ) async {
    if (eventName == 'quiz_complete') analyticsCalls++;
    final preferences = await SharedPreferences.getInstance();
    progressPersistedWhenAnalyticsCalled =
        (preferences.getInt('zankurd.xp.total') ?? 0) > 0;
    final gate = analyticsGate;
    if (gate != null) return gate.future;
    return true;
  }
}

const _room = GameRoom(
  id: 'room-1',
  name: '1vs1',
  code: 'ZK-TEST',
  category: 'Ziman',
  players: [
    Player(id: 'user-1', name: 'Ez', score: 60, state: Player.readyState),
    Player(id: 'opponent', name: 'Hevrik', score: 20, state: Player.readyState),
  ],
  status: RoomStatus.finished,
  questionCount: 1,
);
