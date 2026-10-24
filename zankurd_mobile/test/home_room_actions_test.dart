// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:async';

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
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'support/widget_test_helpers.dart';

class _CapturingJoinRepository extends MockZanKurdRepository {
  String? joinedCode;

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    joinedCode = code;
    return createRoom().copyWith(code: normalizeRoomCode(code));
  }
}

/// Katılma isteği testin elinde bekler: bekleme hâli gözlenebilsin.
class _SlowJoinRepository extends MockZanKurdRepository {
  final gate = Completer<GameRoom>();
  int calls = 0;

  @override
  Future<GameRoom> joinOnlineRoom(String code) {
    calls++;
    return gate.future;
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
    // Sheet kaydırılabilir; onay düğmesi görünür alanın altında kalıyor.
    // `ensureVisible` olmadan `tap` sessizce boşa düşer.
    final openButton = find.text('Odayı aç');
    expect(openButton, findsOneWidget);
    await tester.ensureVisible(openButton);
    await tester.pump();
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    // Kur sayfasında varsayılan kapasite 8: lobi kalabalık odanın başlığını
    // taşır (oda adı "Hevalên Zanînê" yalnız 1v1/yerel oda başlığıdır).
    expect(find.text('Grup yarışı'), findsOneWidget);
    expect(find.text('Yarışı başlat'), findsOneWidget);

    await tester.ensureVisible(find.text('Yarışı başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarışı başlat'));
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

    await tester.scrollUntilVisible(find.text('Günün turu'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günün turu'));
    await tester.pumpAndSettle();

    // Mock her gün etkinlik döner → etkinlik lobisi; oradan quiz başlar.
    expect(find.byType(ContestScreen), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);

    await tester.tap(find.text('Başla'));
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
        languageProvider: LanguageProvider(initialLang: 'ku'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();

    expect(find.text('Bi kodê têkeve'), findsOneWidget);
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

    expect(find.text('Odaya katıl'), findsOneWidget);
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
      final current = tester.widget<SahneField>(field).controller!.text;
      await tester.enterText(field, '$current${String.fromCharCode(rune)}');
      await tester.pump();
    }

    expect(tester.widget<SahneField>(field).controller!.text, 'ZK-ABCDEF0123');
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
      final current = tester.widget<SahneField>(field).controller!.text;
      await tester.enterText(field, '$current${String.fromCharCode(rune)}');
      await tester.pump();
    }
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    expect(repository.joinedCode, 'ZK-ZKAB');
  });

  // 2026-10-22 Android turu: Katıl'a basınca 1–2 sn geri bildirim yoktu,
  // oyuncu yeniden dokunuyordu.
  testWidgets('katılma beklerken düğme kilitli ve gösterge döner', (
    tester,
  ) async {
    final repository = _SlowJoinRepository();
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
    await tester.enterText(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      '482913',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('play-hub-join-submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('play-hub-join-submit')));
    await tester.pump();
    expect(repository.calls, 1, reason: 'beklerken ikinci istek gitmez');

    repository.gate.complete(repository.createRoom().copyWith(code: '482913'));
    await tester.pumpAndSettle();
  });
}
