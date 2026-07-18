import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider()..setLang('tr'),
    child: MaterialApp(home: child),
  );
}

const _room = GameRoom(
  name: 'Oda',
  code: 'ZK-TEST',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
  questionCount: 3,
);

void main() {
  testWidgets('boş kayıt listesinde boş durum mesajı gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: [], room: _room)),
    );

    expect(find.text('Hiç cevap kaydı yok.'), findsOneWidget);
  });

  testWidgets('doğru, yanlış ve boş cevap sayılarını özetler', (tester) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Soru 1',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: '',
      ),
      AnswerRecord(
        id: 'q2',
        category: 'Ziman',
        prompt: 'Soru 2',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: '',
      ),
      AnswerRecord(
        id: 'q3',
        category: 'Ziman',
        prompt: 'Soru 3',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: null,
        explanation: '',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    expect(find.text('1 doğru · 1 yanlış · 1 boş'), findsOneWidget);
    expect(find.text('DOĞRU'), findsOneWidget);
    expect(find.text('YANLIŞ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('BOŞ BIRAKILDI'), 300);
    expect(find.text('BOŞ BIRAKILDI'), findsOneWidget);
  });

  testWidgets('şıkta doğru/yanlış işaretleme ve açıklama panelini gösterir', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'Şaş',
        explanation: 'Açıklama metni burada.',
      ),
    ];

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    expect(find.text('Hilbijêre'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Açıklama metni burada.'), findsOneWidget);
  });
}
