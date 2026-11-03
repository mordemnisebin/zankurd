/// T2 (2026-11-03) Rövanş ve oda sahipliği — istemci bekçileri.
///
/// ## Kusurlar
///
/// * Lobi yalnız oda DURUMUNU izlerdi. Sahip devredilse ya da sahip
///   kategori/süre/soru sayısını değiştirse bile diğer üyeler odadan çıkıp
///   girene kadar eski ayarı ve eski sahibi görürdü.
/// * Lobide oda ayarlarını değiştirmenin hiçbir yolu yoktu (yanlış kategoriyle
///   kurulan oda baştan kurulurdu).
///
/// ## Niçin sessiz kalırdı
///
/// Sunucu doğru çalışır, hata fırlamaz; yalnız ekran bayat kalır. Hiçbir
/// derleme ya da eski test "sahip rozetinin yerinin değiştiğini" ya da "ayar
/// bandının çıktığını" sınamaz. Bu dosya canlı lobi durumunu (heartbeat
/// yanıtı) ekrana bağlayan sözleşmeyi sabitler:
///
///   * başkası sahip olunca bant + taç, ayar değişince "Ayarlar değişti";
///   * düzenleme düğmesi YALNIZ sahipte, YALNIZ lobide, YALNIZ sunucu
///     destekliyorsa görünür; ücret ve kapasite düzenleyicide yoktur;
///   * sunucuda yeni RPC yoksa (PGRST202/42883) ekran eski davranışta kalır:
///     düğme yok, hata yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

Player _p(String id, String name) =>
    Player(id: id, name: name, score: 0, state: 'Hazır', streak: 0);

class _T2Repo extends MockZanKurdRepository {
  _T2Repo({required this.me});

  final String me;
  RoomLobbyState? heartbeat;
  bool editable = true;
  int heartbeatCalls = 0;
  final List<(String, int, int)> updates = [];
  Object? updateError;

  @override
  String? get currentUserId => me;

  @override
  bool get roomSettingsEditable => editable;

  @override
  Future<RoomLobbyState?> roomHeartbeat(GameRoom room) async {
    heartbeatCalls++;
    return heartbeat;
  }

  @override
  Future<RoomLobbyState> updateRoomSettings({
    required GameRoom room,
    required String category,
    required int secondsPerQuestion,
    required int questionCount,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    updates.add((category, secondsPerQuestion, questionCount));
    return RoomLobbyState(
      hostId: room.hostId,
      status: RoomStatus.lobby,
      category: category,
      secondsPerQuestion: secondsPerQuestion,
      questionCount: questionCount,
    );
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => [
    _p('host-user', 'Mêvandar'),
    _p('guest-1', 'Rojda'),
    _p('guest-2', 'Azad'),
  ];

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(_players());

  List<Player> _players() => [
    _p('host-user', 'Mêvandar'),
    _p('guest-1', 'Rojda'),
    _p('guest-2', 'Azad'),
  ];

  GameRoom room() => GameRoom(
    id: 'room-t2',
    name: 'crowd',
    code: '482913',
    category: 'Ziman',
    players: _players(),
    status: RoomStatus.lobby,
    questionCount: 10,
    secondsPerQuestion: 20,
    hostId: 'host-user',
    maxPlayers: 8,
    isCustom: true,
  );
}

Future<void> _mount(
  WidgetTester tester,
  _T2Repo repo, {
  Size size = const Size(375, 667),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: RoomScreen(repository: repo, initialRoom: repo.room()),
    ),
  );
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tick(WidgetTester tester) async {
  // Kalabalık odada yoklama 20 sn.
  await tester.pump(const Duration(seconds: 20));
  await tester.pump();
}

void main() {
  const editKey = ValueKey('room-edit-settings');
  const bannerKey = ValueKey('room-lobby-banner');

  testWidgets('başkası sahip olunca "Oda sahibi artık X" bandı çıkar', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'guest-2')
      ..heartbeat = const RoomLobbyState(
        hostId: 'guest-1',
        status: RoomStatus.lobby,
        category: 'Ziman',
        secondsPerQuestion: 20,
        questionCount: 10,
      );
    await _mount(tester, repo);
    await _tick(tester);

    expect(repo.heartbeatCalls, greaterThan(0));
    expect(find.byKey(bannerKey), findsOneWidget);
    expect(find.textContaining('Oda sahibi artık'), findsOneWidget);
    expect(find.textContaining('Rojda'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Bant 6 sn sonra kendiliğinden kalkar.
    await tester.pump(const Duration(seconds: 7));
    expect(find.byKey(bannerKey), findsNothing);
  });

  testWidgets('devirle sahip BEN olursam bant bunu söyler ve düğme çıkar', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'guest-1')
      ..heartbeat = const RoomLobbyState(
        hostId: 'guest-1',
        category: 'Ziman',
        secondsPerQuestion: 20,
        questionCount: 10,
      );
    await _mount(tester, repo);
    expect(find.byKey(editKey), findsNothing);
    await _tick(tester);

    expect(find.text('Oda sahibi ayrıldı; artık oda sahibi sensin.'), findsOne);
    expect(find.byKey(editKey), findsOneWidget);
  });

  testWidgets('ayar başkası tarafından değişince canlı yansır + bant', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'guest-1')
      ..heartbeat = const RoomLobbyState(
        hostId: 'host-user',
        category: 'Dîrok',
        secondsPerQuestion: 30,
        questionCount: 20,
      );
    await _mount(tester, repo);
    await _tick(tester);

    expect(find.text('Ayarlar değişti'), findsOneWidget);
    expect(find.text('30 sn'), findsOneWidget);
    expect(find.text('20 soru'), findsOneWidget);
    // Sahip değil: düzenleme düğmesi yok.
    expect(find.byKey(editKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lobi kaydırılmışken "Ayarlar değişti" görünen alanda durur', (
    tester,
  ) async {
    // 2026-11-03 turu: bant liste İÇİNDEydi; liste kaydırılmışsa ekran
    // dışında kalıyor, oyuncu ayarın değiştiğini hiç görmüyordu.
    final repo = _T2Repo(me: 'guest-1')
      ..heartbeat = const RoomLobbyState(
        hostId: 'host-user',
        category: 'Dîrok',
        secondsPerQuestion: 30,
        questionCount: 20,
      );
    await _mount(tester, repo);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pump();
    await _tick(tester);

    final banner = find.byKey(bannerKey);
    expect(banner, findsOneWidget);
    final rect = tester.getRect(banner);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(667), reason: 'bant ekran dışında');
    expect(rect.top, lessThan(200), reason: 'bant görünen alanın tepesinde');
  });

  testWidgets('düzenleme düğmesi yalnız sahipte; ücret/kapasite seçici yok', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'host-user');
    await _mount(tester, repo);

    expect(find.byKey(editKey), findsOneWidget);
    await tester.tap(find.byKey(editKey));
    await tester.pumpAndSettle();

    // Düzenleyicide kategori, soru sayısı ve süre var…
    expect(find.byKey(const ValueKey('custom-room-cat-mixed')), findsOne);
    expect(find.byKey(const ValueKey('custom-room-count-10')), findsOne);
    expect(find.byKey(const ValueKey('custom-room-duration-20')), findsOne);
    // …giriş ücreti ve kapasite KİLİTLİ: hiç çizilmez.
    expect(find.byKey(const ValueKey('custom-room-fee-0')), findsNothing);
    expect(find.byKey(const ValueKey('custom-room-capacity-8')), findsNothing);
    expect(
      find.byKey(const ValueKey('custom-room-settings-row')),
      findsNothing,
    );
  });

  testWidgets('sahip kaydedince RPC çağrılır, kendi değişikliğine bant yok', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'host-user');
    await _mount(tester, repo);

    await tester.tap(find.byKey(editKey));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('custom-room-duration-30')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('custom-room-count-20')),
    );
    await _tapVisible(tester, find.byKey(const ValueKey('custom-room-open')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single.$2, 30);
    expect(repo.updates.single.$3, 20);
    expect(find.text('30 sn'), findsOneWidget);
    expect(find.text('20 soru'), findsOneWidget);
    expect(find.byKey(bannerKey), findsNothing);
  });

  testWidgets('sunucuda RPC yoksa düğme yok, hata yok (eski davranış)', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'host-user')..editable = false;
    await _mount(tester, repo);
    await _tick(tester);

    expect(find.byKey(editKey), findsNothing);
    expect(find.byKey(bannerKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kaydetme sırasında RPC kaybolursa sessizce eski hâle döner', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'host-user')
      ..updateError = const RoomLiveUnsupported();
    await _mount(tester, repo);

    await tester.tap(find.byKey(editKey));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('custom-room-duration-30')),
    );
    await _tapVisible(tester, find.byKey(const ValueKey('custom-room-open')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // Ekranda eski değer kalır (sunucu değiştirmedi).
    expect(find.text('20 sn'), findsOneWidget);
  });

  testWidgets('375×667 + büyük yazıda banner ve düğme taşma yapmaz', (
    tester,
  ) async {
    final repo = _T2Repo(me: 'host-user')
      ..heartbeat = const RoomLobbyState(
        hostId: 'host-user',
        category: 'Dîrok',
        secondsPerQuestion: 45,
        questionCount: 25,
      );
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            textScaler: TextScaler.linear(2),
          ),
          child: RoomScreen(repository: repo, initialRoom: repo.room()),
        ),
      ),
    );
    await tester.pump();
    await _tick(tester);

    expect(find.byKey(bannerKey), findsOneWidget);
    expect(find.byKey(editKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
