/// Oda lobisinin görsel hiyerarşisi (A7, 2026-10-01).
///
/// ## Kusur
///
/// Lobi bir ekranda aynı ağırlıkta beş şey söylüyordu: kodun üstünde uzun
/// bir "dokun ve kopyala" yazısı, kodun altında tam genişlikte ikinci bir
/// düğme ("Arkadaşlarını davet et"), kartın üstünde bir "Ev sahibi" çipi
/// (oyuncu satırındaki "Ev sahibi" rozetinin tekrarı), oyuncu sayısı hiçbir
/// yerde yoktu, kalabalık dışında kimsenin olmadığı odada bile tepki rayı
/// duruyordu, sohbet de "Hazırım" kartıyla aynı yüzey ağırlığında bir
/// liste kartıydı. Kahraman kart ekranın %40'ını yiyordu.
///
/// ## Niçin sessiz kaldı
///
/// Her parça tek tek doğruydu ve kendi bekçisi vardı (kod tam görünüyor,
/// kopyalanıyor, davet paylaşıyor). "Bu ekranda kaç şey birbirine
/// rakip?" sorusunu soran hiçbir test yoktu; ekran yeni bir eylem aldıkça
/// kimse ötekini geri çekmedi.
///
/// Bu dosya hiyerarşiyi ölçülebilir kurallara bağlar: kartın boyu, kartın
/// içindeki düğme türü, ev sahibi işaretinin sayısı, oyuncu sayısı,
/// yalnız kalan ev sahibinde tepki rayının yokluğu, sohbetin yüzeysizliği
/// ve konuğun bekleme durumunun bir "ölü düğme" olmaması.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';

import 'support/widget_test_helpers.dart';

const _me = Player(
  id: 'host-user',
  name: 'Sen',
  score: 0,
  state: Player.readyState,
);
const _guest = Player(
  id: 'guest-user',
  name: 'Berfin',
  score: 0,
  state: Player.readyState,
);

class _LobbyRepository extends MockZanKurdRepository {
  _LobbyRepository({required this.userId, required this.players});

  final String userId;
  final List<Player> players;

  @override
  String? get currentUserId => userId;

  GameRoom room() => GameRoom(
    id: 'room-hierarchy',
    name: 'Hevalên Zanînê',
    code: 'ZK-HIERARCHY',
    category: 'Ziman',
    players: players,
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => players;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(players);
}

Future<void> _open(
  WidgetTester tester,
  _LobbyRepository repository, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: RoomScreen(repository: repository, initialRoom: repository.room()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('kahraman kart kompakt: boyu 300 mp\'yi aşmaz', (tester) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    final hero = tester.getRect(find.byType(SahneStageCard));
    expect(
      hero.height,
      lessThanOrEqualTo(300),
      reason:
          'Kart eskiden ~340 mp idi (çip sırası + ikinci düğme + uzun '
          'kod yazısı); künye tek satır, davet düz bağlantı olmalı.',
    );
  });

  testWidgets('kartta dolgulu ya da ikincil düğme yok; davet düz bağlantı', (
    tester,
  ) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    final hero = find.byType(SahneStageCard);
    expect(
      find.descendant(of: hero, matching: find.byType(SahneButton)),
      findsNothing,
      reason: 'Kod çipi + tam genişlik davet düğmesi birbirine rakipti.',
    );
    expect(
      find.descendant(of: hero, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: hero,
        matching: find.byKey(const ValueKey('room-invite-share')),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Oda kodu, dokun ve kopyala'),
      findsNothing,
      reason: 'Uzun ipucu görünür yazı değil, ekran okuyucu ipucudur.',
    );
    expect(find.text('Oda kodu'), findsOneWidget);
  });

  testWidgets('ev sahibi tek yerde işaretlenir: oyuncu satırındaki rozet', (
    tester,
  ) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    expect(
      find.text('Ev sahibi'),
      findsOneWidget,
      reason:
          'Kartta ayrıca bir "Ev sahibi" çipi çiziliyordu; aynı bilgi iki '
          'yerde olunca hangisinin asıl olduğu belli olmuyordu.',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-player-tile-1')),
        matching: find.text('Ev sahibi'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('oyuncu sayısı kartın başlığında durur ve duyurulur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    final count = find.byKey(const ValueKey('room-player-count'));
    expect(count, findsOneWidget);
    expect(
      find.descendant(of: count, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(count).label,
      contains('Oyuncular: 2'),
      reason: 'Yalnız simge + rakam çizilir; söz ekran okuyucuya kalır.',
    );
    handle.dispose();
  });

  testWidgets('yalnız bekleyen ev sahibinde tepki rayı yok', (tester) async {
    await _open(tester, _LobbyRepository(userId: 'host-user', players: [_me]));
    expect(
      find.byType(SahneRailChip),
      findsNothing,
      reason: 'Karşıda kimse yokken tepki göndermek anlamsız bir eylem yığını.',
    );
  });

  testWidgets('iki oyuncu varken tepki rayı görünür', (tester) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    expect(find.byType(SahneRailChip), findsWidgets);
  });

  testWidgets('sohbet satırı yüzeysiz metin eylemi, kart içinde değil', (
    tester,
  ) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    final toggle = find.byKey(const ValueKey('room-chat-toggle'));
    expect(toggle, findsOneWidget);
    expect(
      find.ancestor(of: toggle, matching: find.byType(SahneListGroup)),
      findsNothing,
      reason: 'Sohbet "Hazırım" kartıyla aynı yüzey ağırlığındaydı.',
    );
    expect(
      find.ancestor(of: toggle, matching: find.byType(SahneSurfaceCard)),
      findsNothing,
    );
  });

  testWidgets('konuğun alt perdesi ölü düğme değil, bekleme satırı', (
    tester,
  ) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'guest-user', players: [_me, _guest]),
    );
    expect(
      find.byType(GeometricGradientButton),
      findsNothing,
      reason: 'Konuk başlatamaz; pasif "Yarışı başlat" düğmesi ölü eylemdi.',
    );
    expect(find.textContaining('Ev sahibi bekleniyor'), findsOneWidget);
  });

  testWidgets('ev sahibinin tek birincil eylemi başlat düğmesidir', (
    tester,
  ) async {
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
    );
    final start = find.widgetWithText(GeometricGradientButton, 'Yarışı başlat');
    expect(start, findsOneWidget);
    expect(tester.widget<GeometricGradientButton>(start).onPressed, isNotNull);
    expect(find.byType(GeometricGradientButton), findsOneWidget);
  });

  testWidgets('320 px ve %200 yazıda lobi taşmaz', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _open(
      tester,
      _LobbyRepository(userId: 'host-user', players: [_me, _guest]),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('room-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-player-count')), findsOneWidget);
  });
}
