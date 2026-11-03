/// Solo tur sonucundan "Meydan oku": yalnız açık dokunuşla düello açılır.
///
/// ## Kusur (önlenen)
///
/// Paylaşım kartı `/join/D…` bağlantısını yalnız bir meydan okuma kodu
/// verilirse yazar; sonuç ekranı hiç kod vermiyordu, bu yüzden normal turdan
/// "skorumu geç" bağlantısı üretilemiyordu. Ama kodu her Paylaş'ta üretmek
/// de yanlış olurdu: her paylaşım sunucuda açık bir düello bırakır (günde
/// 5 açık düello sınırı).
///
/// ## Niçin sessiz kalırdı
///
/// İki yönde de ekran düzgün görünür; fark yalnız sunucuda biriken
/// hayalet düellolardır.
///
/// ## Kural
///
/// * "⋯" sayfasında "Meydan oku" satırı vardır (solo, ödüllü, rakipsiz tur).
/// * Düz Paylaş düello açmaz; satıra dokunmak tam BİR düello açar.
/// * Alıştırma turunda satır yoktur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

const _room = GameRoom(
  name: 'Solo',
  code: 'ZK-TEST000000',
  category: 'Ziman',
  questionCount: 2,
  status: RoomStatus.finished,
  players: [],
);

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  AnswerRecord record(int i) => AnswerRecord(
    id: 'q$i',
    category: 'Ziman',
    prompt: 'p$i',
    answers: const ['A', 'B'],
    correctAnswer: 'A',
    selectedAnswer: 'A',
    explanation: '',
    responseMs: 3000,
  );

  Future<MockZanKurdRepository> pump(
    WidgetTester tester, {
    bool practice = false,
  }) async {
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repo,
          room: _room,
          score: 100,
          correctCount: 2,
          wrongCount: 0,
          totalQuestions: 2,
          bestStreak: 2,
          answerRecords: [record(1), record(2)],
          coinsAwarded: 0,
          practice: practice,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('result-more-options')));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('solo turda satır var, görünmesi düello AÇMAZ', (tester) async {
    final repo = await pump(tester);
    expect(find.byKey(const ValueKey('result-challenge-button')), findsOne);
    expect(await repo.loadMyAsyncDuels(), isEmpty);
  });

  testWidgets('satıra dokunmak tam bir düello açar', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('result-challenge-button')));
    await tester.pumpAndSettle();
    expect(await repo.loadMyAsyncDuels(), hasLength(1));
  });

  testWidgets('alıştırma turunda satır yok', (tester) async {
    await pump(tester, practice: true);
    expect(find.byKey(const ValueKey('result-challenge-button')), findsNothing);
  });
}
