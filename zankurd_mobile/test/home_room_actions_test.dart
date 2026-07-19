import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('creates a room and opens the quiz flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubScreen), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-create-room')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();

    expect(find.text('Hevalên Zanînê'), findsOneWidget);
    expect(find.text('Yarışı Başlat'), findsOneWidget);

    await tester.ensureVisible(find.text('Yarışı Başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarışı Başlat'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('opens the daily quiz from the play hub tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    // Günlük yarışma modu artık yalnızca Bilîze (Oyna) sekmesinde.
    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Günün Yarışması'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günün Yarışması'));
    await tester.pumpAndSettle();

    // Mock her gün contest döner → etkinlik lobisi; oradan quiz başlar.
    expect(find.byType(ContestScreen), findsOneWidget);
    expect(find.text('Etkinliğe başla'), findsOneWidget);

    await tester.tap(find.text('Etkinliğe başla'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('play hub routes rewards through the shop card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();

    // Çark bir ödüldür: yarışma grid'inden çıkarıldı, mağaza kartından erişilir.
    expect(find.byKey(const ValueKey('play-hub-shop-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-play-wheel')), findsNothing);
  });

  testWidgets('kurdish home room join action uses compact label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: LanguageProvider(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pêşbazî'));
    await tester.pumpAndSettle();

    expect(find.text('Kodê tevlî bibe'), findsOneWidget);
    expect(find.text('Bi Kodê Tevlî Bibe'), findsNothing);
    expect(find.text('Bi Kodê Bikeve'), findsNothing);
  });

  testWidgets('join by code opens the room code sheet from the hero', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();

    expect(find.text('Odaya Katıl'), findsOneWidget);
    expect(find.text('Oda kodu'), findsOneWidget);
    expect(find.text('Katıl'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      findsOneWidget,
    );
  });

  testWidgets('join room sheet accepts typed room code text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();

    const code = 'ZK-ABCD';
    await tester.enterText(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      code,
    );
    await tester.pumpAndSettle();

    expect(find.text(code), findsOneWidget);
  });
}
