import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/floating_reaction_overlay.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';
import 'support/widget_test_helpers.dart';

/// Host-only online lobby for start-gate diagnostics.
class _HostOnlyRoomRepository extends MockZanKurdRepository {
  _HostOnlyRoomRepository([List<Player>? players])
    : _players =
          players ??
          const [
            Player(
              id: 'host-user',
              name: 'HostOyuncu',
              score: 0,
              state: 'Hazır',
              streak: 0,
            ),
          ];

  final List<Player> _players;

  @override
  String? get currentUserId => 'host-user';

  GameRoom hostLobbyRoom() => GameRoom(
    id: 'room-sync-1',
    name: 'Hevalên Zanînê',
    code: 'ZK-SYNC',
    category: 'Ziman',
    players: List<Player>.of(_players),
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return List<Player>.of(_players);
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(List<Player>.of(_players));
  }
}

/// Emits a second participant shortly after subscribe (sync simulation).
class _GrowingPlayersRoomRepository extends _HostOnlyRoomRepository {
  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) async* {
    yield List<Player>.of(_players);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield [
      ..._players,
      const Player(
        id: 'guest',
        name: 'Misafir',
        score: 0,
        state: 'Hazır',
        streak: 0,
      ),
    ];
  }
}

/// Realtime returns stale 1-player list; polling recovers with 2 players.
class _StaleStreamPollRecoveryRepository extends _HostOnlyRoomRepository {
  int pollCalls = 0;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(List<Player>.of(_players));
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    pollCalls += 1;
    return [
      ..._players,
      const Player(
        id: 'guest',
        name: 'Misafir',
        score: 0,
        state: 'Hazır',
        streak: 0,
      ),
    ];
  }
}

/// Oda statusu realtime'a ulaşmadığında katılımcı, host'un başlattığı oyunu
/// tek seferlik durum yoklamasıyla açabilmeli.
class _StaleStatusPollRecoveryRepository extends MockZanKurdRepository {
  int statusPollCalls = 0;

  @override
  String? get currentUserId => 'guest-user';

  GameRoom lobbyRoom() => const GameRoom(
    id: 'room-status-poll',
    name: 'Hevalên Zanînê',
    code: 'ZK-STATUS',
    category: 'Ziman',
    players: [
      Player(id: 'host-user', name: 'Mêvandar', score: 0, state: 'Hazır'),
      Player(id: 'guest-user', name: 'Misafir', score: 0, state: 'Hazır'),
    ],
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    return Stream.value(RoomStatus.lobby);
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    statusPollCalls++;
    return RoomStatus.active;
  }
}

class _BroadcastRoomRepository extends MockZanKurdRepository {
  final StreamController<Map<String, dynamic>> broadcasts =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return broadcasts.stream;
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  test('RoomScreen disposes the reaction controller it owns', () {
    final source = File('lib/src/screens/room_screen.dart').readAsStringSync();
    final disposeBody = RegExp(
      r'void dispose\(\) \{(.*?)super\.dispose\(\);',
      dotAll: true,
    ).firstMatch(source)?.group(1);

    expect(disposeBody, isNotNull);
    expect(
      disposeBody,
      contains('_reactionController.dispose();'),
      reason:
          'RoomScreen creates its reaction controller, so it must release the '
          'ChangeNotifier when the route is disposed.',
    );
  });

  testWidgets('room reaction bubble avoids critical lobby content at 390x844', (
    tester,
  ) async {
    final repository = _BroadcastRoomRepository();
    addTearDown(repository.broadcasts.close);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom().copyWith(
            id: 'room-reaction-layout',
          ),
        ),
      ),
    );
    await tester.pump();

    repository.broadcasts.add(const {
      'type': 'reaction',
      'text': '👏 Destxweş!',
      'sender_id': 'remote-user',
      'sender_name': 'Berfin',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final bubble = // 2026-09-29 Şahnê: balon eskiden görünüşüyle (14/8 dolgu, 20
        // yarıçap) bulunuyordu; pahlı Şahnê balonu anahtarıyla bulunur.
        find.byKey(FloatingReactionOverlay.bubbleKey);
    expect(bubble, findsOneWidget);

    final bubbleRect = tester.getRect(bubble);
    expect(bubbleRect.top, greaterThanOrEqualTo(0));
    expect(bubbleRect.left, greaterThanOrEqualTo(0));
    expect(bubbleRect.right, lessThanOrEqualTo(390));
    expect(bubbleRect.bottom, lessThanOrEqualTo(844));

    final roomLabelRect = tester.getRect(find.text('Özel Oda'));
    expect(
      bubbleRect.bottom,
      lessThanOrEqualTo(roomLabelRect.top - 4),
      reason:
          'Room-header reactions must stay in the compact navigation band; '
          'their height must not depend on a lucky horizontal position.',
    );

    final protectedRects = <Rect>[
      // 2026-09-29 Şahnê: "odadan ayrıl" artık Şahnê ikon düğmesidir
      // (`SahneIconButton`, 48 dokunma); ipucuyla bulunur.
      tester.getRect(find.byTooltip('Odadan ayrıl')),
      tester.getRect(find.text('Özel Oda')),
      tester.getRect(find.text('Hevalên Zanînê')),
      tester.getRect(find.byKey(const ValueKey('room-code-copy'))),
      tester.getRect(find.byKey(const ValueKey('room-player-tile-1'))),
      tester.getRect(find.byKey(const ValueKey('room-player-tile-2'))),
      tester.getRect(find.byType(SwitchListTile)),
      tester.getRect(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      ),
    ];
    for (final rect in protectedRects) {
      expect(
        bubbleRect.overlaps(rect),
        isFalse,
        reason:
            'Transient reaction must not obscure navigation, room identity, '
            'players, readiness, or the primary action.',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('room lobby remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Özel Oda'), findsOneWidget);
    expect(find.text('Oyuncular'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Yarışı Başlat'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Yarışı Başlat'), findsOneWidget);
  });

  testWidgets('wide room lobby centers content within 680 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final content = find.byKey(const ValueKey('room-content-width'));
    expect(content, findsOneWidget);
    expect(tester.getSize(content).width, lessThanOrEqualTo(680));
    // Serbest metin sohbet; raporlama, engelleme ve moderasyon akışı
    // tamamlanana kadar mağaza sürümünde erişilebilir olmamalı.
    expect(find.byKey(const ValueKey('room-chat-toggle')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('13-character room code remains complete at 320 px', (
    tester,
  ) async {
    const code = 'ZK-ABCDEF0123';
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom().copyWith(code: code),
        ),
      ),
    );
    await tester.pump();

    final codeFinder = find.byKey(const ValueKey('room-code'));
    final codeText = tester.widget<Text>(codeFinder);
    final paragraph = tester.renderObject<RenderParagraph>(codeFinder);
    expect(codeText.data, code);
    expect(codeText.overflow, isNot(TextOverflow.ellipsis));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room code copy keeps the complete 13-character value', (
    tester,
  ) async {
    const code = 'ZK-ABCDEF0123';
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom().copyWith(code: code),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-code-copy')));
    await tester.pump();
    expect(copiedText, code);
  });

  testWidgets('room lobby keeps start disabled until two players are present', (
    tester,
  ) async {
    final repository = _HostOnlyRoomRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Yarışı başlatmak için en az 2 oyuncu olmalı.'),
      findsOneWidget,
    );

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('room lobby enables start after player stream adds a guest', (
    tester,
  ) async {
    final repository = _GrowingPlayersRoomRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Misafir'), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('Misafir'), findsOneWidget);
    expect(
      find.text('Yarışı başlatmak için en az 2 oyuncu olmalı.'),
      findsNothing,
    );

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('room lobby keeps start disabled while a guest is not ready', (
    tester,
  ) async {
    final repository = _HostOnlyRoomRepository(const [
      Player(
        id: 'host-user',
        name: 'HostOyuncu',
        score: 0,
        state: Player.readyState,
      ),
      Player(id: 'guest-user', name: 'Misafir', score: 0, state: 'Bekliyor'),
    ]);

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNull);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets('two-player private room opens quiz in 1v1 mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _HostOnlyRoomRepository(const [
      Player(
        id: 'host-user',
        name: 'HostOyuncu',
        score: 0,
        state: Player.readyState,
      ),
      Player(
        id: 'guest-user',
        name: 'Misafir',
        score: 0,
        state: Player.readyState,
      ),
    ]);

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    await tester.pumpAndSettle();

    final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
    expect(quiz.is1v1, isTrue);
  });

  testWidgets('three-player private room opens quiz outside 1v1 mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _HostOnlyRoomRepository(const [
      Player(
        id: 'host-user',
        name: 'HostOyuncu',
        score: 0,
        state: Player.readyState,
      ),
      Player(
        id: 'guest-user',
        name: 'Misafir',
        score: 0,
        state: Player.readyState,
      ),
      Player(
        id: 'third-user',
        name: 'Üçüncü',
        score: 0,
        state: Player.readyState,
      ),
    ]);

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    // Üç oyunculu lobide başlat düğmesi ilk ekranın altında kalabilir
    // (2026-09-27'den beri kod kartının altında davet düğmesi var); oyuncu
    // gibi önce kaydırıp sonra dokunuyoruz.
    final start = find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat');
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pumpAndSettle();

    final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
    expect(quiz.is1v1, isFalse);
  });

  testWidgets(
    'room lobby recovers via polling when realtime player list stays stale',
    (tester) async {
      final repository = _StaleStreamPollRecoveryRepository();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: repository.hostLobbyRoom(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Misafir'), findsNothing);
      final disabledButton = tester.widget<GeometricGradientButton>(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      );
      expect(disabledButton.onPressed, isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(repository.pollCalls, greaterThan(0));
      expect(find.text('Misafir'), findsOneWidget);

      final enabledButton = tester.widget<GeometricGradientButton>(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      );
      expect(enabledButton.onPressed, isNotNull);
      expect(find.byType(QuizScreen), findsNothing);
    },
  );

  testWidgets(
    'room lobby opens quiz when only status polling sees host start',
    (tester) async {
      final repository = _StaleStatusPollRecoveryRepository();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: repository.lobbyRoom(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QuizScreen), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(repository.statusPollCalls, greaterThan(0));
      expect(find.byType(QuizScreen), findsOneWidget);
    },
  );

  testWidgets('yerel oyuncunun adı gösterim anında yerelleştirilir', (
    tester,
  ) async {
    // Depo yerel oyuncuyu sabit 'Tu' yer tutucusuyla üretir. Türkçe
    // arayüzde oyuncu kendi satırında "Tu" görüyordu ve bunu bir kullanıcı
    // adı sanıyordu; sonuç ekranı aynı adı zaten çeviriyordu, oda ekranı
    // atlanmıştı (2026-07-26).
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Tu'), findsNothing);
  });

  testWidgets('gerçek bir oyuncunun adı "Tu" olsa bile değiştirilmez', (
    tester,
  ) async {
    // Yerelleştirme yalnız kimliksiz yer tutucuya uygulanır. Sunucudan
    // gelen, kimliği olan bir oyuncunun adı ona ait bir veridir; onu
    // çevirmek başka birinin adını değiştirmek olurdu.
    final repository = MockZanKurdRepository();
    final room = repository.createRoom().copyWith(
      players: const [
        Player(id: 'p-1', name: 'Tu', score: 0, state: 'Hazır', streak: 0),
      ],
    );
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump();

    expect(find.text('Tu'), findsOneWidget);
  });

  testWidgets(
    'oda ekrani kahraman oda kartinda kilim motifi, PlayerAvatar ve bekleyen slotu gosterir',
    (tester) async {
      // 4.1 Gorsel Kimlik: Oda kodu Jackbox kahramani olarak one cikarilir,
      // arkasina kilim borduru konur, oyuncular PlayerAvatar ile render edilir
      // ve odada 2. oyuncu yokken bekleyen slot cizilir.
      final repository = MockZanKurdRepository();
      final singlePlayerRoom = repository.createRoom().copyWith(
        players: const [
          Player(name: 'Tu', score: 0, state: 'Hazır', streak: 0),
        ],
      );
      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: singlePlayerRoom,
          ),
        ),
      );
      await tester.pump();

      // Oda kodu karti ve kopyalama anahtarlari mevcut
      expect(find.byKey(const ValueKey('room-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-code-copy')), findsOneWidget);

      // PlayerAvatar ile oyuncu cizimi (tek oyuncu)
      expect(find.byType(PlayerAvatar), findsOneWidget);

      // 2. oyuncu henüz yokken bekleyen slot görünür.
      //
      // Beklenen metinler `strings.dart`tan OKUNUR, elle yazılmaz.
      // İlk hâlinde '2. Oyuncu' ve 'Bekleniyor' diye tahmin edilmişti;
      // ikisi de bankada yok — widget `K.waitingOpponent` ve
      // `K.statPending` kullanıyor (proje kuralı: çeviri tek kaynaktan).
      // Elle yazılan etiket, çeviri değişince testi sessizce kırar.
      final slot = find.byKey(const ValueKey('room-waiting-slot'));
      expect(slot, findsOneWidget);
      expect(
        find.descendant(
          of: slot,
          matching: find.text(Tr.forKu(K.waitingOpponent, false)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: slot,
          matching: find.text(Tr.forKu(K.statPending, false)),
        ),
        findsOneWidget,
      );
    },
  );
}
