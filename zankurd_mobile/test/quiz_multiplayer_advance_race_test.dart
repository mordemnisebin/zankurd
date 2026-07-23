import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-21 canlı denetiminde bulunan hata: "hem odada hem de 1v1'de
/// bazen sorular kendi kendine atlıyor". Kök neden: `_syncToQuestionIndex()`
/// (dışarıdan/rakipten gelen bir index senkronizasyonunda çağrılır) eski
/// sorunun 5sn'lik `_revealTimer`'ını iptal etmiyor. Rakip erken ilerlerse
/// (peer-broadcast ile yeni index'e senkronize oluruz), eski timer hâlâ
/// yaşıyor olur; süresi dolduğunda ARTIK GÜNCEL (bir adım ilerlemiş) index
/// üzerinden bir adım DAHA ilerletir — kullanıcı yeni soruyu hiç görmeden
/// bir sonrakine atlar.
class _RaceRepository extends MockZanKurdRepository {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get currentUserId => 'host-uid';

  // _myId eşleşmesi room.players'daki isimle getProfileName() üzerinden
  // yapılıyor (bkz. quiz_screen.dart initState) — mock varsayılanı
  // ('ZanKurd Oyuncusu') host oyuncumun adıyla eşleşmediği için _myId
  // hep null kalıyor ve _checkMultiplayerSync reveal fazına hiç geçmiyordu.
  @override
  Future<String> getProfileName() async => 'Ez';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      controller.stream;

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {}
}

void main() {
  testWidgets(
    'rakip erken senkronize olsa bile eski reveal timer bir soruyu atlamamalı',
    (tester) async {
      final repository = _RaceRepository();
      addTearDown(repository.controller.close);

      final questions = repository.questions.take(3).toList();
      final room = GameRoom(
        id: 'race-room',
        name: 'Oda',
        code: 'ZK-RACE',
        category: questions.first.category,
        players: const [
          Player(id: 'host-uid', name: 'Ez', score: 0, state: 'Hazır'),
          Player(id: 'guest-uid', name: 'Rakip', score: 0, state: 'Hazır'),
        ],
        status: RoomStatus.active,
        questionCount: questions.length,
        hostId: 'host-uid',
      );

      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: room,
            questions: questions,
            enableTimer: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Ben (host) 0. soruyu cevaplıyorum.
      await tester.tap(find.text(questions[0].displayAnswers.first).first);
      await tester.pump(const Duration(milliseconds: 500));

      // Rakip de aynı soruyu cevapladı (reveal fazını tetikler; 5sn'lik
      // _revealTimer 0. soru için burada kurulur).
      repository.controller.add({
        'sender': 'Rakip',
        'sender_id': 'guest-uid',
        'score': 0,
        'streak': 0,
        'question_index': 0,
        'answered': true,
        'selected_answer': questions[0].correctAnswer,
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Rakip erken ilerleyip 1. soruya geçmiş gibi görünüyor (peer-broadcast
      // ile senkronize oluruz) — 0. sorunun 5sn'lik reveal timer'ı hâlâ canlı.
      repository.controller.add({
        'sender': 'Rakip',
        'sender_id': 'guest-uid',
        'score': 0,
        'streak': 0,
        'question_index': 1,
        'answered': false,
      });
      await tester.pump(const Duration(milliseconds: 100));

      // 0. sorunun eski reveal timer'ı (5sn) şimdi dolar — artık 1. soruda
      // olduğumuz hâlde tetiklenir.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 100));

      // Beklenen: yalnızca 1. soruya (index 1) geçilmiş olmalı.
      expect(find.text(questions[1].prompt), findsOneWidget);
      // Hatalı davranış: index doğrudan 2'ye atlar, 1. soru hiç gösterilmez.
      expect(find.text(questions[2].prompt), findsNothing);
    },
  );
}
