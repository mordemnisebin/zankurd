import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

// 1v1 online eşleşmede matchmaking sonrası iki oyuncu QuizScreen'e ayrı
// ayrı navigasyon yapar. Bariyer olmadan, biri hâlâ geçiş ekranındayken
// diğeri soruları görüp sayaç işlemeye başlayabilir (kullanıcı bildirimi:
// "biri diğerini görmeden sorular başlıyor"). Bu testler karşı taraftan
// "ready" broadcast'i gelene kadar soru akışının beklediğini doğrular.
class _FakeBroadcastRepository extends MockZanKurdRepository {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> sent = [];

  void emitOpponentReady() {
    _controller.add({
      'sender': 'Rakip',
      'sender_id': 'opponent-1',
      'ready': true,
    });
  }

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return _controller.stream;
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    sent.add(payload);
  }
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
      ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late _FakeBroadcastRepository repository;
  late GameRoom room;
  late QuizQuestion question;

  setUp(() {
    repository = _FakeBroadcastRepository();
    question = repository.questions.first;
    room = GameRoom(
      id: 'room-1',
      name: '1v1 Savaş',
      code: 'ZK-TEST',
      category: question.category,
      status: RoomStatus.active,
      questionCount: 1,
      players: const [
        Player(name: 'Tolhildan Mawal', score: 0, state: 'Hazır'),
        Player(name: 'Rakip', score: 0, state: 'Hazır'),
      ],
    );
  });

  testWidgets(
    '1v1 online quiz rakip hazır broadcast\'i gelene kadar sayacı başlatmaz',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          QuizScreen(
            repository: repository,
            room: room,
            questions: [question],
            is1v1: true,
            enableTimer: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Rakip bekleniyor...'), findsOneWidget);
      // Kendi hazır sinyalimiz karşı tarafa gönderilmiş olmalı.
      expect(repository.sent.any((p) => p['ready'] == true), isTrue);

      repository.emitOpponentReady();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rakip bekleniyor...'), findsNothing);
    },
  );

  testWidgets(
    'rakip hiç sinyal göndermezse zaman aşımından sonra yine de başlar',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          QuizScreen(
            repository: repository,
            room: room,
            questions: [question],
            is1v1: true,
            enableTimer: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Rakip bekleniyor...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Rakip bekleniyor...'), findsNothing);
    },
  );
}
