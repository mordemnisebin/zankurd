import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';
import 'support/widget_test_helpers.dart';

class _RoomQuizBroadcastRepository extends MockZanKurdRepository {
  final broadcasts = <Map<String, dynamic>>[];
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get currentUserId => 'user';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return controller.stream;
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    broadcasts.add(payload);
    controller.add(payload);
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('quiz screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(question.prompt), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quiz-landscape-content')),
      findsOneWidget,
    );
    expect(find.text(question.displayAnswers.first), findsWidgets);

    await tester.ensureVisible(find.text(question.displayAnswers.first).first);
    await tester.tap(find.text(question.displayAnswers.first).first);
    await tester.pumpAndSettle();

    // Yarışma modunda tur içi açıklama gösterilmez (çözümler oyun sonunda).
    expect(find.text('Doğru cevap'), findsNothing);
  });

  testWidgets('quiz question panel renders the polished visual accents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quiz-question-icon-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quiz-question-ghost-icon')),
      findsOneWidget,
    );
  });

  testWidgets('online room answer broadcasts readiness outside 1vs1', (
    tester,
  ) async {
    final roomRepository = _RoomQuizBroadcastRepository();
    addTearDown(roomRepository.controller.close);
    final questions = repository.questions.take(2).toList();
    const room = GameRoom(
      id: 'online-room',
      name: 'Oda',
      code: 'ZK-ROOM',
      category: 'Ziman',
      players: [
        Player(id: 'user', name: 'ZanKurd Oyuncusu', score: 0, state: 'Hazır'),
        Player(id: 'guest', name: 'Misafir', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 2,
      hostId: 'user',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: roomRepository,
          room: room,
          questions: questions,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(questions.first.displayAnswers.first).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      roomRepository.broadcasts.any(
        (payload) =>
            payload['question_index'] == 0 && payload['answered'] == true,
      ),
      isTrue,
    );
  });

  testWidgets('short portrait quiz scrolls without shrinking its content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const question = QuizQuestion(
      id: 'compact-portrait-fit',
      category: 'Çand',
      prompt: 'Kurmancî kültüründe dengbêjlerin temel görevi hangisidir?',
      answers: [
        'Sözlü kültürü aktarmak',
        'Yalnızca dans etmek',
        'Resmî belge hazırlamak',
        'Spor karşılaşması düzenlemek',
      ],
      correctAnswer: 'Sözlü kültürü aktarmak',
      explanation: 'Dengbêjler sözlü kültürü kuşaktan kuşağa aktarır.',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-fitted-content')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-portrait-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('quiz-portrait-scroll')),
      matching: find.byType(Scrollable),
    );
    final nextButton = find.byKey(const ValueKey('quiz-next-button'));
    final beforeScroll = tester.getRect(nextButton);
    expect(beforeScroll.bottom, greaterThan(640));

    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();

    final afterScroll = tester.getRect(nextButton);
    expect(afterScroll.top, lessThan(beforeScroll.top));
    expect(afterScroll.top, greaterThanOrEqualTo(0));
    expect(afterScroll.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiz tutorial keeps its second target and tooltip on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
      'zankurd.navTour.seen': true,
    });

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = find.byType(CoachMarkOverlay);
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.text('Süre + Cevap')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('1/2')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: overlay, matching: find.text('İleri')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: overlay, matching: find.text('Seri + Sonraki Soru')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('2/2')),
      findsOneWidget,
    );
    final target = tester.getRect(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    final tooltip = tester.getRect(
      find.descendant(of: overlay, matching: find.text('Seri + Sonraki Soru')),
    );
    expect(target.top, greaterThanOrEqualTo(0));
    expect(target.bottom, lessThanOrEqualTo(640));
    expect(tooltip.top, greaterThanOrEqualTo(0));
    expect(tooltip.bottom, lessThanOrEqualTo(640));
  });

  testWidgets('wide portrait quiz centers content within 800 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final content = find.byKey(const ValueKey('quiz-landscape-content'));
    expect(content, findsOneWidget);
    expect(tester.getSize(content).width, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('visual quiz keeps the next action visible in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const question = QuizQuestion(
      id: 'visual-landscape-fit',
      category: 'Çand',
      prompt: 'Görseldeki etkinlik hangi kültürel kategoriyle ilgilidir?',
      answers: ['Coğrafya', 'Ziman', 'Müzik', 'Edebiyat'],
      correctAnswer: 'Müzik',
      explanation: 'Govend kültürel bir dans ve müzik etkinliğidir.',
      type: QuestionType.visual,
      imageUrl: 'asset://assets/zankurd.webp',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const ValueKey('quiz-next-button'));
    final nextRect = tester.getRect(nextButton);
    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);
    expect(nextRect.top, greaterThanOrEqualTo(0));
    expect(nextRect.bottom, lessThanOrEqualTo(390));
    expect(tester.takeException(), isNull);
  });
}
