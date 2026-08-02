import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

class _ResumeRepository extends MockZanKurdRepository {
  String userId = 'user';
  final List<String> resumeCalls = [];
  int roomQuestionCalls = 0;
  late Future<RoomResumeSnapshot?> Function(String userId) onLoadResume =
      (_) async => null;

  @override
  String get currentUserId => userId;

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() {
    resumeCalls.add(userId);
    return onLoadResume(userId);
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    roomQuestionCalls++;
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
