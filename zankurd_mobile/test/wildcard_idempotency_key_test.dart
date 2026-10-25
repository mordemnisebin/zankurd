import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/durable_write.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

const _question = QuizQuestion(
  id: 'joker-key-1',
  category: 'Ziman',
  prompt: 'Pirsa jokerê?',
  answers: ['rast', 'şaş-a', 'şaş-b', 'şaş-c'],
  correctAnswer: 'rast',
  explanation: '',
);

class _KeyRecordingRepository extends MockZanKurdRepository {
  final keys = <String>[];

  @override
  Future<int> loadCoinBalance() async => 500;

  @override
  Future<DurableCoinSpend> spendCoinsDurable(
    int amount,
    String reason,
    String idempotencyKey,
  ) async {
    keys.add(idempotencyKey);
    return const DurableCoinSpend(success: true, retryable: false);
  }
}

/// Joker ücretinin tekillik anahtarı yalnız soru+türdü: aynı soru başka bir
/// turda yeniden çıkınca sunucu "zaten ödendi" deyip jokeri bedava
/// veriyordu (2026-10-25). Anahtar artık turu da taşır.
void main() {
  Future<void> playJokerRound(
    WidgetTester tester,
    _KeyRecordingRepository repository,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          key: UniqueKey(),
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Çift cevap'));
    await tester.pumpAndSettle();
  }

  testWidgets('aynı soru ve joker iki turda iki ayrı anahtar üretir', (
    tester,
  ) async {
    final repository = _KeyRecordingRepository();
    await playJokerRound(tester, repository);
    await playJokerRound(tester, repository);

    expect(repository.keys, hasLength(2));
    expect(repository.keys.toSet(), hasLength(2));
    for (final key in repository.keys) {
      expect(key, startsWith('wildcard:'));
      expect(key, endsWith(':joker-key-1:doubleAnswer'));
    }
  });
}
