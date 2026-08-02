import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

class _ResumeRepository extends MockZanKurdRepository {
  String userId = 'user';
  final List<String> resumeCalls = [];
  final List<String> pendingCalls = [];
  int roomQuestionCalls = 0;
  late Future<RoomResumeSnapshot?> Function(String userId) onLoadResume =
      (_) async => null;
  late Future<RoomResultSnapshot?> Function(String userId) onLoadPending =
      (_) async => null;
  Future<List<QuizQuestion>> Function(GameRoom room)? onLoadQuestions;

  @override
  String get currentUserId => userId;

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() {
    resumeCalls.add(userId);
    return onLoadResume(userId);
  }

  @override
  Future<RoomResultSnapshot?> loadMyPendingRoomResult() {
    pendingCalls.add(userId);
    return onLoadPending(userId);
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    roomQuestionCalls++;
    final loader = onLoadQuestions;
    if (loader != null) return loader(room);
    return questions.take(room.questionCount).toList(growable: false);
  }
}

class _RebuildAuthProvider extends FakeAuthProvider {
  void rebuildShell() => notifyListeners();
}

class _ControlledConnectivityMonitor implements ConnectivityMonitor {
  _ControlledConnectivityMonitor(this.initial);

  List<ConnectivityResult> initial;
  final controller = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => initial;

  void emit(List<ConnectivityResult> results) {
    initial = results;
    controller.add(results);
  }
}

GameRoom _room(RoomStatus status, {String userId = 'user'}) {
  return GameRoom(
    id: 'room-resume',
    name: 'Duel',
    code: 'ZK-RSME',
    category: 'Ziman',
    players: [
      Player(
        id: userId,
        name: 'Tu',
        score: 120,
        state: Player.readyState,
        streak: 2,
      ),
      const Player(
        id: 'opponent',
        name: 'Heval',
        score: 90,
        state: Player.readyState,
      ),
    ],
    status: status,
    questionCount: 2,
    hostId: userId,
  );
}

RoomResumeSnapshot _snapshot(RoomStatus status) {
  return RoomResumeSnapshot(
    room: _room(status),
    currentQuestionIndex: status == RoomStatus.active ? 1 : 0,
    ownScore: 120,
    streak: 2,
    bestStreak: 3,
    correctCount: 1,
    wrongCount: 0,
    answers: const [],
    serverNow: DateTime.utc(2026, 8, 2, 12),
    questionStartedAt: null,
    deadline: null,
    remainingMs: 12000,
  );
}

RoomResultSnapshot _resultSnapshot({
  String userId = 'user',
  String? ownPlayerId,
}) {
  return RoomResultSnapshot(
    room: _room(RoomStatus.finished, userId: userId),
    ownPlayerId: ownPlayerId ?? userId,
    questionIds: const ['resume-q-1', 'resume-q-2'],
    answers: const [
      ResumedAnswer(
        questionId: 'resume-q-1',
        questionIndex: 0,
        selectedOptionKey: 'A',
        correctOptionKey: 'A',
        isCorrect: true,
        pointsAwarded: 60,
        responseMs: 1000,
      ),
      ResumedAnswer(
        questionId: 'resume-q-2',
        questionIndex: 1,
        selectedOptionKey: 'B',
        correctOptionKey: 'B',
        isCorrect: true,
        pointsAwarded: 60,
        responseMs: 1200,
      ),
    ],
    winnerId: userId,
    endedReason: 'completed',
    forfeitedBy: null,
    finishedAt: DateTime.utc(2026, 8, 2, 12, 30),
  );
}

const _resultQuestions = [
  QuizQuestion(
    id: 'resume-q-1',
    category: 'Ziman',
    prompt: 'Pirs 1',
    answers: ['A1', 'B1', 'C1', 'D1'],
    correctAnswer: 'A1',
    explanation: 'Şirove 1',
  ),
  QuizQuestion(
    id: 'resume-q-2',
    category: 'Ziman',
    prompt: 'Pirs 2',
    answers: ['A2', 'B2', 'C2', 'D2'],
    correctAnswer: 'B2',
    explanation: 'Şirove 2',
  ),
];

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await tester.pump();
  }
}

Future<void> _pushManualCover(WidgetTester tester) async {
  unawaited(
    Navigator.of(tester.element(find.byType(AppShell))).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => const Scaffold(body: Text('manual-cover')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ResumeRepository repository;
  late _RebuildAuthProvider authProvider;

  setUp(() {
    // Ortak yardımcı aynı zamanda kullanıcıya bağlı yerel depoları sıfırlar.
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.profileName.completed.account-a': true,
      'zankurd.profileName.completed.account-b': true,
    });
    repository = _ResumeRepository();
    authProvider = _RebuildAuthProvider();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    ConnectivityMonitor connectivityMonitor =
        const AlwaysOnlineConnectivityMonitor(),
    AppShellErrorRecorder? errorRecorder,
  }) async {
    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: connectivityMonitor,
          errorRecorder: errorRecorder,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'oda sorgusu ana ekranı bekletmez ve kullanıcı başına bir kez çalışır',
    (tester) async {
      final pending = Completer<RoomResumeSnapshot?>();
      repository.onLoadResume = (_) => pending.future;

      await pumpShell(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repository.resumeCalls, ['user']);

      authProvider.rebuildShell();
      await tester.pump();
      expect(repository.resumeCalls, ['user']);

      pending.complete(null);
      await tester.pump();
      await tester.pump();
      authProvider.rebuildShell();
      await tester.pump();

      expect(repository.resumeCalls, ['user']);
      expect(repository.pendingCalls, ['user']);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('lobi snapshotı aynı yetkili oda ile RoomScreen açar', (
    tester,
  ) async {
    final snapshot = _snapshot(RoomStatus.lobby);
    repository.onLoadResume = (_) async => snapshot;

    await pumpShell(tester);

    final screen = tester.widget<RoomScreen>(find.byType(RoomScreen));
    expect(screen.initialRoom, same(snapshot.room));
    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, isEmpty);
  });

  testWidgets('resume null ise pending sonucu ikinci asamada sorgular', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => null;

    await pumpShell(tester);

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
  });

  testWidgets('valid pending sonuc RoomResultRecoveryScreen acar', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => _resultSnapshot();

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    for (
      var i = 0;
      i < 12 && find.byType(RoomResultRecoveryScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
    }

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
    expect(find.byType(RoomResultRecoveryScreen), findsOneWidget);
  });

  testWidgets(
    'pending yaniti manual rota altinda gelirse pop sonrasi tek full retry yapar',
    (tester) async {
      final firstPending = Completer<RoomResultSnapshot?>();
      var pendingAttempt = 0;
      repository.onLoadResume = (_) async => null;
      repository.onLoadPending = (_) {
        pendingAttempt++;
        return pendingAttempt == 1
            ? firstPending.future
            : Future<RoomResultSnapshot?>.value(null);
      };

      await tester.pumpWidget(
        testShell(
          authProvider: authProvider,
          child: AppShell(
            repository: repository,
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      );
      await _pumpUntil(tester, () => repository.pendingCalls.length == 1);

      await _pushManualCover(tester);
      firstPending.complete(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('manual-cover'), findsOneWidget);

      Navigator.of(tester.element(find.text('manual-cover'))).pop();
      await _pumpUntil(tester, () => repository.pendingCalls.length == 2);

      expect(repository.resumeCalls, ['user', 'user']);
      expect(repository.pendingCalls, ['user', 'user']);
    },
  );

  testWidgets(
    'manual rota sorgudan once pop olursa in-flight finally tek retry yapar',
    (tester) async {
      final firstPending = Completer<RoomResultSnapshot?>();
      var pendingAttempt = 0;
      repository.onLoadResume = (_) async => null;
      repository.onLoadPending = (_) {
        pendingAttempt++;
        return pendingAttempt == 1
            ? firstPending.future
            : Future<RoomResultSnapshot?>.value(null);
      };

      await tester.pumpWidget(
        testShell(
          authProvider: authProvider,
          child: AppShell(
            repository: repository,
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      );
      await _pumpUntil(tester, () => repository.pendingCalls.length == 1);
      await _pushManualCover(tester);
      Navigator.of(tester.element(find.text('manual-cover'))).pop();
      await tester.pumpAndSettle();

      firstPending.complete(null);
      await tester.pumpAndSettle();

      expect(repository.resumeCalls, ['user', 'user']);
      expect(repository.pendingCalls, ['user', 'user']);
    },
  );

  testWidgets('owned pending rota pop ve rebuild ile yeniden acilmaz', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => _resultSnapshot();

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(RoomResultRecoveryScreen).evaluate().isNotEmpty,
    );
    Navigator.of(tester.element(find.byType(RoomResultRecoveryScreen))).pop();
    await tester.pumpAndSettle();

    authProvider.rebuildShell();
    await tester.pump();
    await tester.pump();

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
  });

  testWidgets('recovery replacement sonrasi final pop owned statei korur', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => _resultSnapshot();
    repository.onLoadQuestions = (_) async => _resultQuestions;
    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(QuizResultScreen).evaluate().isNotEmpty,
    );

    expect(find.byType(QuizResultScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(QuizResultScreen))).pop();
    await tester.pumpAndSettle();
    authProvider.rebuildShell();
    await tester.pump();

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('shell visible lifecycle resume tek yeni pipeline baslatir', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => null;
    await pumpShell(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUntil(tester, () => repository.pendingCalls.length == 2);

    expect(repository.resumeCalls, ['user', 'user']);
    expect(repository.pendingCalls, ['user', 'user']);
  });

  testWidgets(
    'manual rota altindaki lifecycle resume pop sonrasi tek retry yapar',
    (tester) async {
      repository.onLoadResume = (_) async => null;
      repository.onLoadPending = (_) async => null;
      await pumpShell(tester);

      await _pushManualCover(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repository.pendingCalls, ['user']);

      Navigator.of(tester.element(find.text('manual-cover'))).pop();
      await tester.pumpAndSettle();

      expect(repository.resumeCalls, ['user', 'user']);
      expect(repository.pendingCalls, ['user', 'user']);
    },
  );

  testWidgets('owned pending acikken lifecycle resume popta reopen yapmaz', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => _resultSnapshot();
    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(RoomResultRecoveryScreen).evaluate().isNotEmpty,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    Navigator.of(tester.element(find.byType(RoomResultRecoveryScreen))).pop();
    await tester.pumpAndSettle();
    authProvider.rebuildShell();
    await tester.pump();

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
  });

  testWidgets('malformed pending raporlanir ve wake ile retry spam yapmaz', (
    tester,
  ) async {
    final reported = <({Object error, String? reason})>[];
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async =>
        _resultSnapshot(ownPlayerId: 'other-user');

    await pumpShell(
      tester,
      errorRecorder: (error, _, {reason}) {
        reported.add((error: error, reason: reason));
      },
    );
    authProvider.rebuildShell();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
    expect(reported, hasLength(1));
    expect(reported.single.reason, 'app_shell_pending_room_result');
  });

  testWidgets('manual pop race malformed pending icin ikinci sorgu acmaz', (
    tester,
  ) async {
    final pending = Completer<RoomResultSnapshot?>();
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) => pending.future;
    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          errorRecorder: (_, _, {reason}) {},
        ),
      ),
    );
    await _pumpUntil(tester, () => repository.pendingCalls.isNotEmpty);

    await _pushManualCover(tester);
    Navigator.of(tester.element(find.text('manual-cover'))).pop();
    await tester.pumpAndSettle();
    pending.complete(_resultSnapshot(ownPlayerId: 'other-user'));
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
  });

  testWidgets('A stale response B hesabinda rota acamaz', (tester) async {
    final accountA = Completer<RoomResumeSnapshot?>();
    repository.userId = 'account-a';
    repository.onLoadResume = (userId) => userId == 'account-a'
        ? accountA.future
        : Future<RoomResumeSnapshot?>.value(null);
    repository.onLoadPending = (_) async => null;

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await _pumpUntil(tester, () => repository.resumeCalls.isNotEmpty);

    repository.userId = 'account-b';
    authProvider.rebuildShell();
    await _pumpUntil(
      tester,
      () => repository.pendingCalls.contains('account-b'),
    );
    accountA.complete(_snapshot(RoomStatus.lobby));
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['account-a', 'account-b']);
    expect(repository.pendingCalls, ['account-b']);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('owned A rotasi pop olunca B hesap kontrolunu yutmaz', (
    tester,
  ) async {
    repository.userId = 'account-a';
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (userId) async =>
        userId == 'account-a' ? _resultSnapshot(userId: 'account-a') : null;
    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(RoomResultRecoveryScreen).evaluate().isNotEmpty,
    );

    repository.userId = 'account-b';
    authProvider.rebuildShell();
    await tester.pump();
    Navigator.of(tester.element(find.byType(RoomResultRecoveryScreen))).pop();
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['account-a', 'account-b']);
    expect(repository.pendingCalls, ['account-a', 'account-b']);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
  });

  testWidgets('A-B-A gecisinde eski A epochesi yeni A rotasini bozamaz', (
    tester,
  ) async {
    final firstA = Completer<RoomResumeSnapshot?>();
    final secondA = Completer<RoomResumeSnapshot?>();
    var aAttempt = 0;
    repository.userId = 'account-a';
    repository.onLoadResume = (userId) {
      if (userId != 'account-a') {
        return Future<RoomResumeSnapshot?>.value(null);
      }
      aAttempt++;
      return aAttempt == 1 ? firstA.future : secondA.future;
    };
    repository.onLoadPending = (_) async => null;

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await _pumpUntil(tester, () => repository.resumeCalls.length == 1);
    repository.userId = 'account-b';
    authProvider.rebuildShell();
    await _pumpUntil(
      tester,
      () => repository.pendingCalls.contains('account-b'),
    );
    repository.userId = 'account-a';
    authProvider.rebuildShell();
    await _pumpUntil(
      tester,
      () => repository.resumeCalls.where((id) => id == 'account-a').length == 2,
    );

    firstA.complete(_snapshot(RoomStatus.lobby));
    await tester.pump();
    expect(find.byType(RoomScreen), findsNothing);
    secondA.complete(null);
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['account-a', 'account-b', 'account-a']);
    expect(repository.pendingCalls, ['account-b', 'account-a']);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('finished resume pending sonuc sorgusuna devam eder', (
    tester,
  ) async {
    repository.onLoadResume = (_) async => _snapshot(RoomStatus.finished);
    repository.onLoadPending = (_) async => null;

    await pumpShell(tester);

    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
  });

  testWidgets('visible shell real reconnect ile tek yeni pipeline baslatir', (
    tester,
  ) async {
    final connectivity = _ControlledConnectivityMonitor(const [
      ConnectivityResult.wifi,
    ]);
    addTearDown(connectivity.controller.close);
    repository.onLoadResume = (_) async => null;
    repository.onLoadPending = (_) async => null;
    await pumpShell(tester, connectivityMonitor: connectivity);

    connectivity.emit(const [ConnectivityResult.none]);
    await tester.pump();
    connectivity.emit(const [ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['user', 'user']);
    expect(repository.pendingCalls, ['user', 'user']);
  });

  testWidgets('concurrent rebuild wake ve reconnect tek in-flight korur', (
    tester,
  ) async {
    final gate = Completer<RoomResumeSnapshot?>();
    final connectivity = _ControlledConnectivityMonitor(const [
      ConnectivityResult.wifi,
    ]);
    addTearDown(connectivity.controller.close);
    repository.onLoadResume = (_) => gate.future;
    repository.onLoadPending = (_) async => null;

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: connectivity,
        ),
      ),
    );
    await _pumpUntil(tester, () => repository.resumeCalls.isNotEmpty);
    authProvider.rebuildShell();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    connectivity.emit(const [ConnectivityResult.none]);
    connectivity.emit(const [ConnectivityResult.mobile]);
    await tester.pump();
    await tester.pump();

    expect(repository.resumeCalls, ['user']);
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(repository.resumeCalls, ['user']);
    expect(repository.pendingCalls, ['user']);
  });

  testWidgets('aktif snapshot soruları yükleyip 1v1 QuizScreen açar', (
    tester,
  ) async {
    final snapshot = _snapshot(RoomStatus.active);
    repository.onLoadResume = (_) async => snapshot;

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    for (var i = 0; i < 10 && find.byType(QuizScreen).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final screen = tester.widget<QuizScreen>(find.byType(QuizScreen));
    expect(screen.room, same(snapshot.room));
    expect(screen.resumeSnapshot, same(snapshot));
    expect(screen.is1v1, isTrue);
    expect(repository.roomQuestionCalls, 1);
  });

  testWidgets('resume hatası ana ekranı bozmaz ve hata kaydedilir', (
    tester,
  ) async {
    final failure = StateError('resume unavailable');
    final reported = <({Object error, String? reason})>[];
    repository.onLoadResume = (_) async => throw failure;

    await pumpShell(
      tester,
      errorRecorder: (error, _, {reason}) {
        reported.add((error: error, reason: reason));
      },
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(reported, [(error: failure, reason: 'app_shell_room_resume')]);
  });

  testWidgets('hesap değişince yeni kullanıcı için bağımsız kontrol yapar', (
    tester,
  ) async {
    repository.userId = 'account-a';

    await pumpShell(tester);
    expect(repository.resumeCalls, ['account-a']);

    repository.userId = 'account-b';
    authProvider.rebuildShell();
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['account-a', 'account-b']);

    authProvider.rebuildShell();
    await tester.pump();
    expect(repository.resumeCalls, ['account-a', 'account-b']);
  });

  testWidgets('çevrimdışı açılış çevrimiçi olunca bir kez kontrol eder', (
    tester,
  ) async {
    final connectivity = _ControlledConnectivityMonitor(const [
      ConnectivityResult.none,
    ]);
    addTearDown(connectivity.controller.close);
    repository.onLoadResume = (_) async => _snapshot(RoomStatus.lobby);

    await pumpShell(tester, connectivityMonitor: connectivity);
    expect(repository.resumeCalls, isEmpty);

    connectivity.emit(const [ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, ['user']);
    expect(find.byType(RoomScreen), findsOneWidget);

    connectivity.emit(const [ConnectivityResult.wifi]);
    await tester.pump();
    expect(repository.resumeCalls, ['user']);
    expect(find.byType(RoomScreen), findsOneWidget);
  });

  testWidgets('başarısız kontrol yalnız yeniden bağlantıda güvenle denenir', (
    tester,
  ) async {
    final connectivity = _ControlledConnectivityMonitor(const [
      ConnectivityResult.wifi,
    ]);
    addTearDown(connectivity.controller.close);
    var attempt = 0;
    repository.onLoadResume = (_) async {
      attempt++;
      if (attempt == 1) throw StateError('temporary outage');
      return null;
    };

    await pumpShell(tester, connectivityMonitor: connectivity);
    expect(repository.resumeCalls, ['user']);

    authProvider.rebuildShell();
    await tester.pump();
    expect(repository.resumeCalls, ['user']);

    connectivity.emit(const [ConnectivityResult.none]);
    await tester.pump();
    connectivity.emit(const [ConnectivityResult.mobile]);
    await tester.pump();
    await tester.pump();

    expect(repository.resumeCalls, ['user', 'user']);
  });
}
