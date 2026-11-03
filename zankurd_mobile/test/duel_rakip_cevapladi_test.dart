// Canlı düello: rakip cevaplar cevaplamaz üst kartta "cevapladı" işareti çıkar.
//
// Niçin var (tasarım kurulu 2026-11-03, QuizUp kıyası): düello kartı iki
// oyuncuyu ve puanlarını gösteriyordu ama rakip ilk cevap verdiğinde
// oyuncu bunu hiçbir yerden göremezdi; "rakibim burada mı" hissi yoktu.
// Rakibin cevap yayını zaten geliyordu, yalnız çizilmiyordu.
//
// Bekçi iki şeyi korur: (1) işaret yayın gelince belirir, yeni soruda söner;
// (2) belirmesi HİÇBİR ŞEYİ kaydırmaz — işaret durum satırındaki sabit 16 pt
// yuvaya çizilir (soru ekranı 375x667'de kaydırmasız sığar kuralının parçası).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

class _Repo extends MockZanKurdRepository {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  void emit(Map<String, dynamic> payload) => _controller.add(payload);

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      _controller.stream;

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {}
}

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => SoundProvider()),
    ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('rakip cevap yayını işareti açar ve hiçbir şeyi kaydırmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    final question = repo.questions.first;
    final room = GameRoom(
      id: 'room-1',
      name: '1v1',
      code: 'ZK-TEST',
      category: question.category,
      status: RoomStatus.active,
      questionCount: 1,
      players: const [
        Player(id: 'user', name: 'Tolhildan Mawal', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rakip', score: 0, state: 'Hazır'),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        QuizScreen(
          repository: repo,
          room: room,
          questions: [question],
          is1v1: true,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    repo.emit({'sender': 'Rakip', 'sender_id': 'opponent-1', 'ready': true});
    await tester.pump(const Duration(milliseconds: 400));

    const mark = ValueKey('duel-opponent-answered');
    const slot = ValueKey('duel-opponent-answered-slot');
    expect(find.byKey(slot), findsOneWidget);
    expect(find.byKey(mark), findsNothing);
    final slotBefore = tester.getRect(find.byKey(slot));
    final scoreBefore = tester.getRect(
      find.byKey(const ValueKey('duel-opponent-score')),
    );
    final answersBefore = tester.getTopLeft(
      find.byKey(const ValueKey('quiz-answer-content')),
    );

    repo.emit({
      'sender': 'Rakip',
      'sender_id': 'opponent-1',
      'answered': true,
      'question_index': 0,
      'score': 0,
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(mark), findsOneWidget);
    expect(find.bySemanticsLabel('Cevapladı'), findsOneWidget);
    expect(tester.getRect(find.byKey(slot)), slotBefore);
    expect(
      tester.getRect(find.byKey(const ValueKey('duel-opponent-score'))),
      scoreBefore,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('quiz-answer-content'))),
      answersBefore,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
