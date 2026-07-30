import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

class _ServerHiddenAnswerRepository extends MockZanKurdRepository {
  @override
  bool get usesServerHiddenAnswers => true;
}

const _question = QuizQuestion(
  id: 'wildcard-availability',
  category: 'Ziman',
  prompt: 'Pirtûk çi ye?',
  answers: ['Kitêb', 'Mase', 'Av', 'Mal'],
  correctAnswer: 'Kitêb',
  explanation: 'Pirtûk kitêb e.',
);

List<WildcardType> _renderedWildcards(WidgetTester tester) => tester
    .widgetList<WildcardButton>(find.byType(WildcardButton))
    .map((button) => button.type)
    .toList(growable: false);

void main() {
  test('repository doğru cevap gizleme yeteneğini doğru bildirir', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
    );
    addTearDown(client.dispose);

    expect(MockZanKurdRepository().usesServerHiddenAnswers, isFalse);
    expect(SupabaseZanKurdRepository(client).usesServerHiddenAnswers, isTrue);
  });

  testWidgets('sunucu cevabı gizliyorsa cevap bağımlı jokerler gizlenir', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _ServerHiddenAnswerRepository();
    final room = repository.createRoom().copyWith(id: 'server-room');

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: [_question.copyWith(correctAnswer: '')],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();

    expect(_renderedWildcards(tester), isEmpty);
  });

  testWidgets('solo turda çift cevap ve soru değiştir korunur', (tester) async {
    freshMockRepository();
    final repository = _ServerHiddenAnswerRepository();

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();

    expect(_renderedWildcards(tester), WildcardType.values);
  });

  testWidgets('bot turunda çift cevap ve soru değiştir korunur', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _ServerHiddenAnswerRepository();

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          botRace: true,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();

    expect(_renderedWildcards(tester), WildcardType.values);
  });
}
