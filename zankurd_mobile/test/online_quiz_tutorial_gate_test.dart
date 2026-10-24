import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';

import 'support/widget_test_helpers.dart';

/// Online 1v1'de ilk-çalıştırma öğreticisi hazır sinyalini tutuyordu.
///
/// ## Kusur
///
/// `QuizScreen._tutorialGateReady` yalnız `QuizTutorialOverlay.onReady` ile
/// açılıyordu; öğretici ise ilk kez quiz açan oyuncuya gösterilip KAPATILANA
/// kadar (zaman aşımı yok) onReady vermiyordu. `mark_room_client_ready` de
/// bu kapıya bağlıydı. Canlıda (2026-10-15) terk edilen 6 1v1 odasının 6'sında
/// bir oyuncu `quiz_ready_at`ı hiç yazmamıştı, öteki başlangıçtan 3 sn sonra
/// hazırdı: yeni oyuncu rehbere bakarken rakibi boş ekranda bekleyip çıkıyordu.
///
/// ## Neden sessizdi
///
/// Her test `zankurd.quiz_tutorial.seen: true` ile başlıyordu (bkz.
/// `freshMockRepository`), yani öğretici hiçbir testte hiç görünmedi.
///
/// ## Düzeltme
///
/// Online (odalı) oyunda öğretici kapalıdır ve hazır sinyali hemen gider;
/// görüldü bayrağına dokunulmaz, oyuncu öğreticiyi ilk solo oyununda görür.
class _ReadyTrackingRepository extends MockZanKurdRepository {
  int markCalls = 0;

  @override
  String? get currentUserId => 'me';

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async {
    markCalls++;
    return null;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => room.players;
}

const _question = QuizQuestion(
  id: 'q1',
  category: 'Ziman',
  prompt: 'Pirs 1',
  answers: ['A1', 'B1', 'C1', 'D1'],
  correctAnswer: '',
  explanation: '',
);

const _onlineRoom = GameRoom(
  id: 'room-1',
  name: '1v1',
  code: 'ZK-TUTOR',
  category: 'Ziman',
  players: [
    Player(id: 'me', name: 'Ez', score: 0, state: Player.readyState),
    Player(id: 'opp', name: 'Rakip', score: 0, state: Player.readyState),
  ],
  status: RoomStatus.active,
  questionCount: 1,
  secondsPerQuestion: 30,
  hostId: 'opp',
);

void main() {
  setUp(() {
    // Öğretici GÖRÜLMEDİ: yeni oyuncu.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('online odada öğretici kapatılmadan hazır sinyali gider', (
    tester,
  ) async {
    final repository = _ReadyTrackingRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: _onlineRoom,
          questions: const [_question],
          is1v1: true,
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.byType(CoachMarkOverlay), findsNothing);
    expect(repository.markCalls, greaterThanOrEqualTo(1));

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('zankurd.quiz_tutorial.seen'),
      isNull,
      reason: 'bayrak yazılmamalı: öğretici ilk solo oyunda gösterilecek',
    );
  });

  testWidgets('solo oyunda öğretici hâlâ gösterilir', (tester) async {
    final repository = freshMockRepository();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [repository.questions.first],
          enableTimer: false,
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.byType(CoachMarkOverlay), findsOneWidget);
  });
}
