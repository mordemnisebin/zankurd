import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

class _CapturingJoinRepository extends MockZanKurdRepository {
  String? joinedCode;

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    joinedCode = code;
    return createRoom().copyWith(code: normalizeRoomCode(code));
  }
}

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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubScreen), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-create-room')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();

    // Oda kurucusu artık soru başına süreyi seçtiği bir sheet görür.
    expect(find.text('Odayı Aç'), findsOneWidget);
    await tester.tap(find.text('Odayı Aç'));
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

    // Günlük ilerleme etkinliği yalnızca Bilîze (Oyna) sekmesinde.
    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Günün Etkinliği'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günün Etkinliği'));
    await tester.pumpAndSettle();

    // Mock her gün etkinlik döner → etkinlik lobisi; oradan quiz başlar.
    expect(find.byType(ContestScreen), findsOneWidget);
    expect(find.text('Etkinliğe başla'), findsOneWidget);

    await tester.tap(find.text('Etkinliğe başla'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('play hub does not duplicate the shop entry point', (
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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();

    // Çark bir ödüldür: yarışma grid'inden çıkarıldı.
    expect(find.byKey(const ValueKey('quick-play-wheel')), findsNothing);
    // Mağazaya Yarış sekmesinden, profilden ve kendi rotasından olmak üzere
    // üç ayrı giriş vardı; "burası neresi?" hissini kırmak için tek ev
    // profildeki HESAP bölümü oldu (2026-07-25 canlı denetimi).
    expect(find.byKey(const ValueKey('play-hub-shop-card')), findsNothing);
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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();

    expect(find.text('Bi kodê tevlî bibe'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
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

  testWidgets('join room sheet accepts pasted room code text', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();

    const code = 'ZK-ABCDEF0123';
    await tester.enterText(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      'zk–abcdef0123',
    );
    await tester.pumpAndSettle();

    expect(find.text(code), findsOneWidget);
  });

  testWidgets('join room code can be typed one character at a time', (
    tester,
  ) async {
    final repository = _CapturingJoinRepository();
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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('play-hub-join-room-code-field'));
    for (final rune in 'ZK-ABCDEF0123'.runes) {
      final current = tester.widget<TextFormField>(field).controller!.text;
      await tester.enterText(field, '$current${String.fromCharCode(rune)}');
      await tester.pump();
    }

    expect(
      tester.widget<TextFormField>(field).controller!.text,
      'ZK-ABCDEF0123',
    );
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();
    expect(repository.joinedCode, 'ZK-ABCDEF0123');
  });

  testWidgets('legacy suffix beginning with ZK is submitted intact', (
    tester,
  ) async {
    final repository = _CapturingJoinRepository();
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

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('play-hub-join-room-code-field'));
    for (final rune in 'ZKAB'.runes) {
      final current = tester.widget<TextFormField>(field).controller!.text;
      await tester.enterText(field, '$current${String.fromCharCode(rune)}');
      await tester.pump();
    }
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    expect(repository.joinedCode, 'ZK-ZKAB');
  });
}
