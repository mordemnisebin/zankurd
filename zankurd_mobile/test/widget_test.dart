import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/main.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

LanguageProvider _turkishLang() => LanguageProvider()..setLang('tr');

void main() {
  final repository = MockZanKurdRepository();

  testWidgets('creates a room and opens the quiz flow', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pump();

    expect(find.text('ZanKurd'), findsOneWidget);
    expect(find.text('Oda Kur'), findsOneWidget);
    expect(find.textContaining('Kurmancî Yarış'), findsOneWidget);

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
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Liderlik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();

    expect(find.text('Liderlik Tablosu'), findsOneWidget);
    expect(find.text('Rojda'), findsWidgets);
  });

  testWidgets('opens category levels from the home screen', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dil').last);
    await tester.pumpAndSettle();

    expect(find.text('Destpêk'), findsOneWidget);
    expect(find.text('Bingeh'), findsOneWidget);
    expect(find.text('10 soru · Zorluk 1/5'), findsOneWidget);
  });

  testWidgets('finishes a quiz and opens the result screen', (tester) async {
    final room = repository.createRoom();

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => _turkishLang(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: repository.questions.take(3).toList(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bilmek'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.arrow_forward_rounded),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('21 Adar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21 Adar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.arrow_forward_rounded),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ehmedê Xanî'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ehmedê Xanî'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.flag_outlined),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.flag_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('Sonuç'), findsOneWidget);
    expect(find.text('Yarış tamamlandı'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Cevapları İncele'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cevapları İncele'));
    await tester.pumpAndSettle();

    expect(find.text('Cevaplar'), findsOneWidget);
    expect(find.text('Soru 1'), findsOneWidget);
    expect(find.text('DOĞRU'), findsWidgets);
  });
}
