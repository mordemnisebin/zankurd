import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 1v1 eşleşme canlılığı: bekleyen oyuncu eşleşmeyi tek bir sessiz yoldan
/// öğreniyordu ve eşleşme sonrası hata onu odada mahsur bırakıyordu.
///
/// ## Kusur (canlı, 2026-10-15)
///
/// - Bekleyen taraf eşleşmeyi yalnız `matchmaking_queue` realtime akışından
///   öğreniyordu (`onError` yok, yoklama yok); akış koparsa ~20 sn sonraki
///   zaman aşımına kadar haber yoktu.
/// - Olay gelince akış ve zamanlayıcı İPTAL ediliyordu. Oda/snapshot/soru
///   yüklemesi düşerse yalnız "eşleşme başarısız" yazıyordu; oyuncu sunucuda
///   hâlâ aktif üyeydi ve rakip boş bir maçı bekleyip çıkıyordu.
/// - Eşleşti-1,5 sn penceresinde geri çıkmak odayı terk etmiyordu
///   (`dispose` yalnız `!_found` iken iptal ediyordu).
///
/// ## Neden sessizdi
///
/// Testlerin sahte depoları hep anında ve hatasız yanıt veriyordu; akışın
/// koptuğu, snapshot'ın düştüğü ya da ekranın 1,5 sn penceresinde kapandığı
/// bir senaryo yoktu.
///
/// ## Düzeltme
///
/// `touchMatchmaking` yoklaması (3 sn) akışla aynı kapıdan (`_openReceivedRoom`)
/// geçer ve tek kez açar; yükleme 3 kez yeniden denenir, hâlâ düşerse
/// `leaveOnlineRoom` çağrılıp hata gösterilir; dispose odayı terk eder.
const _roomId = '00000000-0000-0000-0000-0000000000a1';

const _snapshot = GameRoom(
  id: _roomId,
  name: 'Sunucudaki düello',
  code: 'ZK-LIVE',
  category: 'Çand',
  players: [
    Player(id: 'opponent-id', name: 'Berfin', score: 0, state: 'Hazır'),
    Player(id: 'me-id', name: 'Ez', score: 0, state: 'Hazır'),
  ],
  status: RoomStatus.active,
  questionCount: 1,
  secondsPerQuestion: 20,
  hostId: 'opponent-id',
);

const _question = QuizQuestion(
  id: 'room-question',
  category: 'Çand',
  prompt: 'Dengbêj çi dike?',
  answers: ['Stranan dibêje', 'Derdikeve avê'],
  correctAnswer: 'Stranan dibêje',
  explanation: 'Dengbêj stran dibêje.',
);

class _LiveRepository extends MockZanKurdRepository {
  _LiveRepository({
    this.joinResult = const {'status': 'waiting'},
    this.snapshotFailures = 0,
    this.hidden = false,
    this.questionsAlwaysFail = false,
  });

  Map<String, dynamic> joinResult;
  int joinCalls = 0;
  final bool hidden;
  final bool questionsAlwaysFail;
  int snapshotFailures;
  final queue = StreamController<Map<String, dynamic>?>.broadcast();
  MatchmakingTouch touchResult = const MatchmakingTouch.waiting();
  int touchCalls = 0;
  int snapshotCalls = 0;
  int questionCalls = 0;
  int leaveCalls = 0;
  int cancelCalls = 0;

  @override
  String? get currentUserId => 'me-id';

  @override
  bool get usesServerHiddenAnswers => hidden;

  @override
  Future<String> getProfileName() async => 'Ez';

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    joinCalls++;
    return joinResult;
  }

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() => queue.stream;

  @override
  Future<MatchmakingTouch> touchMatchmaking() async {
    touchCalls++;
    return touchResult;
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    cancelCalls++;
    return const {'status': 'cancelled'};
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    snapshotCalls++;
    if (snapshotFailures > 0) {
      snapshotFailures--;
      throw StateError('snapshot unavailable');
    }
    return _snapshot;
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    questionCalls++;
    if (questionsAlwaysFail) throw StateError('questions unavailable');
    return const [_question];
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    expect(room.id, _roomId);
    leaveCalls++;
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'forfeit',
      forfeitedBy: 'player',
    );
  }
}

Widget _shell(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
    ),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
  ],
  child: MaterialApp(theme: AppTheme.dark(), home: child),
);

const _retryDelays = [
  Duration(milliseconds: 10),
  Duration(milliseconds: 10),
  Duration(milliseconds: 10),
];

Future<void> _startSearch(
  WidgetTester tester,
  _LiveRepository repository,
) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _shell(
      MatchmakingScreen(repository: repository, loadRetryDelays: _retryDelays),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rastgele eşleşme'));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets('yoklama eşleşmeyi bulur; akış da ateşlense oda bir kez açılır', (
    tester,
  ) async {
    final repository = _LiveRepository()
      ..touchResult = const MatchmakingTouch.matched(roomId: _roomId);
    await _startSearch(tester, repository);

    // Akış da aynı odayı bildirir; ikinci açılış yok sayılmalı.
    repository.queue.add({'room_id': _roomId});
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(repository.touchCalls, greaterThanOrEqualTo(1));
    expect(repository.snapshotCalls, 1);
    expect(repository.questionCalls, 1);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(repository.leaveCalls, 0);
    expect(repository.cancelCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.queue.close();
  });

  // Uygulama 12 sn'den uzun arka planda kalınca bekleyen satır bayat diye
  // silinir; yoklama "none" alır. Yeniden girmeyen istemci boş kuyrukta 20 sn
  // bekliyordu. "unknown" (RPC yok) ise yeniden girme döngüsü başlatmamalı.
  testWidgets('sunucu "none" derse kuyruğa yeniden girer ve eşleşir', (
    tester,
  ) async {
    final repository = _LiveRepository();
    await _startSearch(tester, repository);
    expect(repository.joinCalls, 1);

    repository
      ..touchResult = const MatchmakingTouch.none()
      ..joinResult = const {
        'status': 'matched',
        'room_id': _roomId,
        'opponent_name': 'Rojda',
      };
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(repository.joinCalls, 2);
    expect(find.byType(QuizScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.queue.close();
  });

  testWidgets('RPC yoksa ("unknown") yeniden girme döngüsü başlamaz', (
    tester,
  ) async {
    final repository = _LiveRepository()
      ..touchResult = const MatchmakingTouch.unknown();
    await _startSearch(tester, repository);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(repository.joinCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.queue.close();
  });

  testWidgets('akış hatası eşleşmeyi engellemez, yoklama devralır', (
    tester,
  ) async {
    final repository = _LiveRepository();
    await _startSearch(tester, repository);

    repository.queue.addError(StateError('realtime dropped'));
    await tester.pump();
    repository.touchResult = const MatchmakingTouch.matched(roomId: _roomId);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.byType(QuizScreen), findsOneWidget);
    expect(repository.snapshotCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.queue.close();
  });

  testWidgets(
    'eşleşme sonrası snapshot düşerse üç kez dener, sonra odayı terk eder',
    (tester) async {
      final repository = _LiveRepository(snapshotFailures: 99);
      await _startSearch(tester, repository);

      repository.queue.add({'room_id': _roomId});
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        repository.snapshotCalls,
        4,
        reason: '1 deneme + 3 yeniden deneme',
      );
      expect(repository.leaveCalls, 1);
      expect(find.byType(QuizScreen), findsNothing);
      expect(find.text('Eşleşme olmadı, tekrar dene.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.queue.close();
    },
  );

  testWidgets('geçici snapshot hatası yeniden denemeyle toparlanır', (
    tester,
  ) async {
    final repository = _LiveRepository(snapshotFailures: 2);
    await _startSearch(tester, repository);

    repository.queue.add({'room_id': _roomId});
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(repository.snapshotCalls, 3);
    expect(repository.leaveCalls, 0);
    expect(find.byType(QuizScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.queue.close();
  });

  testWidgets(
    'sorular yüklenemezse (gizli cevap) yeniden dener ve odayı terk eder',
    (tester) async {
      final repository = _LiveRepository(
        hidden: true,
        questionsAlwaysFail: true,
      );
      await _startSearch(tester, repository);

      repository.queue.add({'room_id': _roomId});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(repository.questionCalls, 4);
      expect(repository.leaveCalls, 1);
      expect(find.byType(QuizScreen), findsNothing);
      expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.queue.close();
    },
  );

  testWidgets(
    'oda kimliği alındı ama geçiş olmadan ekran kapanırsa oda terk edilir',
    (tester) async {
      final repository = _LiveRepository(
        joinResult: const {
          'status': 'matched',
          'room_id': _roomId,
          'opponent_name': 'Berfin',
        },
      );
      await _startSearch(tester, repository);
      // "Rakip bulundu" 1,5 sn penceresinin içindeyiz.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(QuizScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1600));

      expect(repository.leaveCalls, 1);
      expect(repository.cancelCalls, 0);
      await repository.queue.close();
    },
  );

  testWidgets(
    'hâlâ beklerken kapanırsa kuyruk iptal edilir, oda terk edilmez',
    (tester) async {
      final repository = _LiveRepository();
      await _startSearch(tester, repository);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(repository.cancelCalls, 1);
      expect(repository.leaveCalls, 0);
      await repository.queue.close();
    },
  );
}
