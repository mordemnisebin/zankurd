import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/utils/app_route.dart';

/// Eşleştirme iptalinin gerçekten çağrıldığını izleyen sahte depo.
class _TrackingRepository extends MockZanKurdRepository {
  int cancelCalls = 0;

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    cancelCalls += 1;
    return const {'status': 'cancelled'};
  }
}

class _PendingJoinRepository extends MockZanKurdRepository {
  _PendingJoinRepository({this.failFirstCancel = false});

  final bool failFirstCancel;
  final List<Completer<Map<String, dynamic>>> joins = [];
  int joinCalls = 0;
  int cancelCalls = 0;
  int snapshotCalls = 0;
  int leaveCalls = 0;

  Completer<Map<String, dynamic>> get latestJoin => joins.last;

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) {
    joinCalls += 1;
    final completer = Completer<Map<String, dynamic>>();
    joins.add(completer);
    return completer.future;
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    cancelCalls += 1;
    if (failFirstCancel && cancelCalls == 1) {
      throw StateError('injected cancel failure');
    }
    return const {'status': 'cancelled'};
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    snapshotCalls += 1;
    return _SnapshotMatchRepository.snapshot;
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    leaveCalls += 1;
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'forfeit',
      forfeitedBy: 'player',
    );
  }
}

class _CancellationRaceRepository extends _SnapshotMatchRepository {
  _CancellationRaceRepository({required this.cancelResult});

  final Map<String, dynamic> cancelResult;
  int leaveCalls = 0;

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {'status': 'waiting'};
  }

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() {
    return const Stream.empty();
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async => cancelResult;

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    expect(room.id, _SnapshotMatchRepository.roomId);
    leaveCalls += 1;
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'forfeit',
      forfeitedBy: 'player',
    );
  }
}

class _RetryableMatchCategoriesRepository extends MockZanKurdRepository {
  bool fail = true;
  bool returnEmpty = false;
  int loadCalls = 0;

  @override
  Future<List<String>> loadMatchmakingCategories() async {
    loadCalls += 1;
    if (fail) throw StateError('match categories unavailable');
    if (returnEmpty) return const [];
    return categories;
  }
}

class _ServerOnlyMatchCategoriesRepository extends MockZanKurdRepository {
  int learningCategoryCalls = 0;
  int matchmakingCategoryCalls = 0;

  @override
  Future<List<String>> loadCategories() async {
    learningCategoryCalls += 1;
    return const ['Sînema'];
  }

  @override
  Future<List<String>> loadMatchmakingCategories() async {
    matchmakingCategoryCalls += 1;
    return const ['Ziman'];
  }
}

enum _RoomQuestionResult { empty, failure }

class _HiddenAnswerMatchRepository extends MockZanKurdRepository {
  _HiddenAnswerMatchRepository(this.result);

  static const roomId = '00000000-0000-0000-0000-000000000001';

  final _RoomQuestionResult result;
  int loadLevelCalls = 0;

  @override
  String? get currentUserId => 'me-id';

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {
      'status': 'matched',
      'room_id': roomId,
      'opponent_name': 'Rojda',
    };
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    return const GameRoom(
      id: _HiddenAnswerMatchRepository.roomId,
      name: '1vs1',
      code: 'ZK-HIDE',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'ZanKurd Oyuncusu', score: 0, state: 'Hazır'),
        Player(id: 'opponent-id', name: 'Rojda', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 10,
      hostId: 'me-id',
    );
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    if (result == _RoomQuestionResult.failure) {
      throw StateError('room questions unavailable');
    }
    return const [];
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  }) async {
    loadLevelCalls += 1;
    return super.loadLevelQuestions(
      category: category,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      subCategory: subCategory,
      limit: limit,
    );
  }
}

/// Hızlı eşleştirmenin döndürdüğü roomId için sunucudaki oda
/// gerçeğini temsil eder. İki oyuncunun adı bilerek aynıdır: oyuncu
/// seçimi görünen ada değil değişmez kimliğe dayanmalıdır.
class _SnapshotMatchRepository extends MockZanKurdRepository {
  static const roomId = '00000000-0000-0000-0000-000000000042';

  int createRoomCalls = 0;
  int snapshotCalls = 0;
  GameRoom? questionsRoom;

  static const snapshot = GameRoom(
    id: roomId,
    name: 'Sunucudaki düello',
    code: 'ZK-R3AL',
    category: 'Çand',
    players: [
      Player(id: 'opponent-id', name: 'Berfin', score: 70, state: 'Hazır'),
      Player(id: 'me-id', name: 'Berfin', score: 10, state: 'Hazır'),
    ],
    status: RoomStatus.active,
    questionCount: 1,
    secondsPerQuestion: 45,
    hostId: 'opponent-id',
  );

  @override
  String? get currentUserId => 'me-id';

  @override
  Future<String> getProfileName() async => 'Berfin';

  @override
  GameRoom createRoom({String category = 'Ziman'}) {
    createRoomCalls += 1;
    return super.createRoom(category: category);
  }

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {
      'status': 'matched',
      'room_id': roomId,
      'opponent_name': 'Berfin',
    };
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    snapshotCalls += 1;
    expect(roomId, _SnapshotMatchRepository.roomId);
    return snapshot;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return snapshot.players;
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    questionsRoom = room;
    return const [
      QuizQuestion(
        id: 'room-question',
        category: 'Çand',
        prompt: 'Dengbêj çi dike?',
        answers: ['Stranan dibêje', 'Derdikeve avê'],
        correctAnswer: 'Stranan dibêje',
        explanation: 'Dengbêj stran û çîran vedibêje.',
      ),
    ];
  }
}

class _ForeignSnapshotMatchRepository extends _SnapshotMatchRepository {
  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    snapshotCalls += 1;
    return _SnapshotMatchRepository.snapshot.copyWith(
      players: const [
        Player(id: 'opponent-id', name: 'Berfin', score: 70, state: 'Hazır'),
        Player(id: 'other-id', name: 'Berfin', score: 10, state: 'Hazır'),
      ],
    );
  }
}

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

class _MatchmakingRouteHost extends StatelessWidget {
  const _MatchmakingRouteHost(this.repository);

  final _PendingJoinRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('open-matchmaking'),
          onPressed: () => Navigator.of(
            context,
          ).push(AppRoute.to(MatchmakingScreen(repository: repository))),
          child: const Text('Eşleştirmeyi aç'),
        ),
      ),
    );
  }
}

Future<void> _startImmediateMatch(
  WidgetTester tester,
  _HiddenAnswerMatchRepository repository,
) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rastgele eşleşme'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1501));
  await tester.pump();
}

Future<void> _startSnapshotMatch(
  WidgetTester tester,
  _SnapshotMatchRepository repository,
) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rastgele eşleşme'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1501));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  test('kanonik rakip adı varsa oda listesinden aynı oyuncu seçilir', () {
    const players = [
      Player(id: 'host', name: 'Ben', score: 0, state: 'Hazır'),
      Player(id: 'wrong', name: 'Dilan', score: 0, state: 'Hazır'),
      Player(id: 'matched', name: 'Hogir', score: 0, state: 'Hazır'),
    ];

    expect(
      selectOpponentPlayer(
        players,
        currentPlayerId: 'host',
        currentName: 'Ben',
        preferredName: 'Hogir',
      )?.id,
      'matched',
    );
  });

  testWidgets('seçim menüsü 1vs1 girişini ve rastgele eşleşmeyi gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _shell(MatchmakingScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1vs1 Düello'), findsOneWidget);
    expect(find.text('Rastgele eşleşme'), findsOneWidget);
    final duelCard = tester.widget<Container>(
      find.byKey(const ValueKey('matchmaking-duel-card')),
    );
    final decoration = duelCard.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.gradient, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekrandan çıkınca eşleştirme kuyruğu iptal edilir', (
    tester,
  ) async {
    final repository = _TrackingRepository();
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rastgele eşleşme'));
    await tester.pump();

    // Ekranı kaldır: dispose, kuyruğu sunucuda da temizlemeli ki oyuncu
    // hayalet kayıt olarak eşleşme kuyruğunda kalmasın.
    await tester.pumpWidget(_shell(const SizedBox()));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('takılan join açık iptali on saniyeden fazla kilitlemez', (
    tester,
  ) async {
    final repository = _PendingJoinRepository();
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(_MatchmakingRouteHost(repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-matchmaking')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rastgele eşleşme'));
    await tester.pump();
    await tester.tap(find.text('İptal Et'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 9999));
    final cancelledBeforeDeadline = repository.cancelCalls;
    final cancellingBeforeDeadline = find
        .byKey(const ValueKey('matchmaking-cancelling-state'))
        .evaluate()
        .length;

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    final cancelledAtDeadline = repository.cancelCalls;

    repository.latestJoin.complete(const {
      'status': 'matched',
      'room_id': _SnapshotMatchRepository.roomId,
    });
    await tester.pumpAndSettle();
    final snapshotCallsAfterLateJoin = repository.snapshotCalls;
    final quizCountAfterLateJoin = find.byType(QuizScreen).evaluate().length;
    final leaveCallsAfterLateJoin = repository.leaveCalls;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cancelledBeforeDeadline, 0);
    expect(cancellingBeforeDeadline, 1);
    expect(cancelledAtDeadline, 1);
    expect(snapshotCallsAfterLateJoin, 0);
    expect(quizCountAfterLateJoin, 0);
    expect(leaveCallsAfterLateJoin, 1);
  });

  testWidgets('eski join iptal hatası sonrası yeni denemeyi ele geçiremez', (
    tester,
  ) async {
    final repository = _PendingJoinRepository(failFirstCancel: true);
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rastgele eşleşme'));
    await tester.pump();
    final firstJoin = repository.latestJoin;
    await tester.tap(find.text('İptal Et'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    final retryVisibleAtDeadline = find.text('Tekrar').evaluate().isNotEmpty;
    if (!retryVisibleAtDeadline) {
      firstJoin.complete(const {'status': 'waiting'});
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(retryVisibleAtDeadline, isTrue);
      return;
    }

    await tester.tap(find.text('Tekrar'));
    await tester.pump();
    expect(repository.joinCalls, 2);

    firstJoin.complete(const {
      'status': 'matched',
      'room_id': _SnapshotMatchRepository.roomId,
    });
    await tester.pump();
    await tester.pump();

    final snapshotCallsAfterStaleJoin = repository.snapshotCalls;
    final quizCountAfterStaleJoin = find.byType(QuizScreen).evaluate().length;
    final leaveCallsAfterStaleJoin = repository.leaveCalls;
    repository.latestJoin.complete(const {'status': 'waiting'});
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(snapshotCallsAfterStaleJoin, 0);
    expect(quizCountAfterStaleJoin, 0);
    expect(leaveCallsAfterStaleJoin, 0);
  });

  testWidgets('gizli cevaplı gerçek eşleşmede boş oda soruları yerele düşmez', (
    tester,
  ) async {
    final repository = _HiddenAnswerMatchRepository(_RoomQuestionResult.empty);
    addTearDown(tester.view.reset);

    await _startImmediateMatch(tester, repository);

    expect(repository.loadLevelCalls, 0);
    expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
  });

  testWidgets(
    'hızlı eşleştirme sahte oda kurmaz, tam sunucu snapshotını kullanır',
    (tester) async {
      final repository = _SnapshotMatchRepository();
      addTearDown(tester.view.reset);

      await _startSnapshotMatch(tester, repository);

      expect(repository.snapshotCalls, 1);
      expect(repository.createRoomCalls, 0);
      expect(find.byType(QuizScreen), findsOneWidget);

      final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
      expect(quiz.room.id, _SnapshotMatchRepository.roomId);
      expect(quiz.room.code, 'ZK-R3AL');
      expect(quiz.room.hostId, 'opponent-id');
      expect(quiz.room.category, 'Çand');
      expect(quiz.room.status, RoomStatus.active);
      expect(quiz.room.secondsPerQuestion, 45);
      expect(quiz.room.questionCount, 1);
      expect(quiz.room.players.map((player) => player.id), [
        'opponent-id',
        'me-id',
      ]);
      expect(repository.questionsRoom, same(quiz.room));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('oturum kimliği snapshot oyuncularında yoksa maç açılmaz', (
    tester,
  ) async {
    final repository = _ForeignSnapshotMatchRepository();
    addTearDown(tester.view.reset);

    await _startSnapshotMatch(tester, repository);

    expect(repository.snapshotCalls, 1);
    expect(repository.createRoomCalls, 0);
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.text('Eşleştirme başarısız oldu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeout ile yarışan eşleşme bot yerine gerçek odaya gider', (
    tester,
  ) async {
    final repository = _CancellationRaceRepository(
      cancelResult: const {
        'status': 'matched',
        'room_id': _SnapshotMatchRepository.roomId,
      },
    );
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rastgele eşleşme'));
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();

    expect(find.byType(QuizScreen), findsOneWidget);
    final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
    expect(quiz.room.id, _SnapshotMatchRepository.roomId);
    expect(repository.leaveCalls, 0);
    expect(find.text('Bot ile oynamak ister misin?'), findsNothing);
  });

  testWidgets('açık iptalle yarışan eşleşmiş oda desteklenen çıkışla kapanır', (
    tester,
  ) async {
    final repository = _CancellationRaceRepository(
      cancelResult: const {
        'status': 'matched',
        'room_id': _SnapshotMatchRepository.roomId,
      },
    );
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rastgele eşleşme'));
    await tester.pump();
    await tester.tap(find.text('İptal Et'));
    await tester.pump();

    expect(repository.snapshotCalls, 0);
    expect(repository.leaveCalls, 1);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets('oda sorusu hatası eşleşti görünümünü kapatıp iptali açar', (
    tester,
  ) async {
    final repository = _HiddenAnswerMatchRepository(
      _RoomQuestionResult.failure,
    );
    addTearDown(tester.view.reset);

    await _startImmediateMatch(tester, repository);

    expect(find.text('Başlamak üzere...'), findsNothing);
    expect(find.text('İptal Et'), findsOneWidget);
    expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
  });

  testWidgets('eşleşme kategorisi hatası görünür ve tekrar denenir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repository = _RetryableMatchCategoriesRepository();
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar'), findsOneWidget);

    repository.fail = false;
    await tester.ensureVisible(find.text('Tekrar'));
    await tester.tap(find.text('Tekrar'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.text('Dil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eşleştirme ekranı çevrimdışı öğrenme kategorisini kullanmaz', (
    tester,
  ) async {
    final repository = _ServerOnlyMatchCategoriesRepository();

    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Sinema'), findsNothing);
    expect(repository.matchmakingCategoryCalls, 1);
    expect(repository.learningCategoryCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eşleşme kategorileri boşsa açıklamalı boş durum gösterilir', (
    tester,
  ) async {
    final repository = _RetryableMatchCategoriesRepository()
      ..fail = false
      ..returnEmpty = true;
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Kategoriler bulunamadı.'), findsOneWidget);
    expect(find.text('Tekrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
