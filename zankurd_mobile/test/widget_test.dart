import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/main.dart';

void main() {
  const repository = MockZanKurdRepository();

  testWidgets('creates a room and opens the quiz flow', (tester) async {
    await tester.pumpWidget(const ZanKurdApp(repository: repository));

    expect(find.text('ZanKurd'), findsOneWidget);
    expect(find.text('Oda Kur'), findsOneWidget);
    expect(find.text('Kurmancî yarış merkezi.'), findsOneWidget);

    await tester.tap(find.text('Oda Kur'));
    await tester.pumpAndSettle();

    expect(find.text('Hevalên Zanînê'), findsOneWidget);
    expect(find.text('Yarışı Başlat'), findsOneWidget);

    await tester.ensureVisible(find.text('Yarışı Başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarışı Başlat'));
    await tester.pumpAndSettle();

    expect(
      find.text('Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?'),
      findsOneWidget,
    );
  });

  testWidgets('opens the leaderboard from the home screen', (tester) async {
    await tester.pumpWidget(const ZanKurdApp(repository: repository));

    await tester.ensureVisible(find.text('Liderlik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();

    expect(find.text('Liderlik Tablosu'), findsOneWidget);
    expect(find.text('Rojda'), findsWidgets);
  });

  testWidgets('opens category levels from the home screen', (tester) async {
    await tester.pumpWidget(const ZanKurdApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ziman').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ziman').last);
    await tester.pumpAndSettle();

    expect(find.text('Destpêk'), findsOneWidget);
    expect(find.text('Bingeh'), findsOneWidget);
    expect(find.text('10 soru · Zorluk 1/5'), findsOneWidget);
  });

  testWidgets('finishes a quiz and opens the result screen', (tester) async {
    final room = repository.createRoom();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: QuizScreen(
          repository: repository,
          room: room,
          questions: repository.questions.take(3).toList(),
        ),
      ),
    );

    await tester.tap(find.text('Bilmek'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sonraki'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('21 Adar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21 Adar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sonraki'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ehmedê Xanî'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ehmedê Xanî'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();

    expect(find.text('Sonuç'), findsOneWidget);
    expect(find.text('Yarış tamamlandı'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);
  });
}
