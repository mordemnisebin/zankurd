// KULLANICI İSTEĞİ (2026-10-21): "Fotoğraf ekleme artık çalışıyor; odaya
// girince, 1v1'de, sıralamalarda — her yerde o fotoğraf görünsün. Bazı
// yerlerde kişi adı yerine hep 'Oyuncu' gibi kalıp şeyler var; biriyle
// oynuyorsam onun adı yazsın, her yerde."
//
// ## Kusurlar (hepsi sessizdi: ekran çökmüyor, yalnız yanlış kişi çiziliyordu)
//
//  1. `profiles` RLS'si yalnız kendi satırını okutur. Arkadaş listesi,
//     arkadaş istekleri, oda davetleri, oda sonucu, sıralama ve turnuva
//     RPC'leri ya yalnız ad ya da eski/boş ad döndürüyor; fotoğraf (avatar_url)
//     ve oyuncu kodu (player_tag) HİÇ gelmiyordu. Depo artık id'si bilinen
//     oyuncuları `get_public_profiles` ile tamamlar.
//  2. 1v1/oda içinde rakibin canlı satırı her broadcast'te SIFIRDAN bir
//     `Player(...)` ile yeniden kuruluyordu: ilk yayında fotoğraf/simge/çerçeve
//     kayboluyor, sunucudan gelen gerçek ad yayındaki yer tutucu adla
//     eziliyordu. Artık `copyWith` kimliği korur.
//  3. Adsız oyuncu bir ekranda "Oyuncu", ötekinde baş harf çiziyordu; kural
//     tek: `PlayerIdentity.resolveNameWithTag` (ad > "Oyuncu ZK-XXXX" >
//     "Oyuncu"), avatar `PlayerAvatar.fromIdentity` (fotoğraf > simge > harf).
//
// Bu dosya: (a) ortak avatar bileşeni ve ad kuralı, (b) deponun kimlik
// tamamlaması (sahte HTTP), (c) lobi / sıralama / 1v1 rakip göstergesinin
// sahte veriyle fotoğraf ve adı çizdiği bekçiler.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/public_profile.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/utils/player_identity.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

import 'support/widget_test_helpers.dart';

const _photo = 'https://example.com/rojda.jpg';

// 1x1 PNG — ağ olmadan Image testi için.
final _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Yalnız bu dosyanın kullandığı RPC'leri taklit eden HTTP istemcisi.
/// `list_*` yanıtları BAYAT/EKSİK (ad yer tutucu, fotoğraf yok);
/// `get_public_profiles` gerçek kimliği verir.
class _Http extends http.BaseClient {
  final paths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    paths.add(path);
    final Object body = switch (path) {
      '/rest/v1/rpc/list_friends' => [
        {
          'id': 'row-1',
          'friend_id': 'f1',
          'friend_name': 'ZanKurd Oyuncusu',
          'friend_avatar_color': null,
          'created_at': '2026-10-01T10:00:00Z',
          'total_score': 10,
          'last_active_at': null,
        },
      ],
      '/rest/v1/rpc/list_pending_friend_requests' => [
        {
          'id': 'req-1',
          'from_user_id': 'f1',
          'from_user_name': 'Oyuncu',
          'created_at': '2026-10-01T10:00:00Z',
        },
      ],
      '/rest/v1/rpc/get_leaderboard' => [
        {
          'player_id': 'f1',
          'display_name': 'ZanKurd Oyuncusu',
          'total_score': 50,
          'best_streak': 3,
          'rooms_played': 2,
        },
      ],
      '/rest/v1/rpc/list_my_async_duels' => [
        {
          'duel_id': 'd1',
          'status': 'matched',
          'role': 'creator',
          'opponent_name': null,
          'opponent_id': 'f1',
          'category_name': 'Ziman',
          'my_correct': null,
          'opponent_correct': null,
          'outcome': null,
          'created_at': '2026-10-01T10:00:00Z',
          'completed_at': null,
          'seen': true,
        },
      ],
      '/rest/v1/rpc/get_public_profiles' => [
        {
          'id': 'f1',
          'display_name': 'Rojda',
          'player_tag': 'AB12',
          'avatar_icon': null,
          'avatar_color': '#336699',
          'avatar_url': _photo,
          'avatar_frame': null,
          'showcase_title': null,
        },
      ],
      _ => <Object>[],
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

SupabaseZanKurdRepository _repo(_Http client) => SupabaseZanKurdRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: client,
  ),
);

Widget _shell(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ortak avatar bileşeni (fotoğraf > simge > harf)', () {
    testWidgets('url -> fotoğraf, harf yok', (tester) async {
      await tester.pumpWidget(
        _shell(
          PlayerAvatar.fromIdentity(
            radius: 24,
            identity: const AvatarIdentity(photoUrl: _photo),
            displayName: 'Rojda',
            imageProviderFactory: (_) => MemoryImage(_tinyPng),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('R'), findsNothing);
    });

    testWidgets('yalnız simge -> simge', (tester) async {
      await tester.pumpWidget(
        _shell(
          PlayerAvatar.fromIdentity(
            radius: 24,
            identity: const AvatarIdentity(iconId: 'tembur'),
            displayName: 'Rojda',
          ),
        ),
      );
      expect(find.byIcon(AppIcons.music), findsOneWidget);
      expect(find.text('R'), findsNothing);
    });

    testWidgets('hiçbiri yok -> baş harf; kimlik null da olur', (tester) async {
      await tester.pumpWidget(
        _shell(PlayerAvatar.fromIdentity(radius: 24, displayName: 'Rojda')),
      );
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('yedek renk, kimlikte renk yokken kullanılır', (tester) async {
      final avatar = PlayerAvatar.fromIdentity(
        radius: 24,
        identity: const AvatarIdentity(),
        fallbackColorHex: '#336699',
        displayName: 'Rojda',
      );
      expect(avatar.colorHex, '#336699');
    });

    test('yer tutucu adın renk tohumu dilden bağımsızdır', () {
      final tr = PlayerAvatar.fromIdentity(radius: 20, displayName: 'Oyuncu');
      final ku = PlayerAvatar.fromIdentity(
        radius: 20,
        displayName: 'Lîstikvan',
      );
      expect(tr.colorSeed, ku.colorSeed);
    });
  });

  group('ad kuralı: gerçek ad > "Oyuncu ZK-XXXX" > "Oyuncu"', () {
    test('gerçek ad olduğu gibi', () {
      expect(
        PlayerIdentity.resolveNameWithTag('Rojda', isKu: false, tag: 'AB12'),
        'Rojda',
      );
    });
    test('yer tutucu ad + kod', () {
      expect(
        PlayerIdentity.resolveNameWithTag(
          'ZanKurd Oyuncusu',
          isKu: false,
          tag: 'AB12',
        ),
        'Oyuncu ZK-AB12',
      );
    });
    test('kod da yoksa yalnız Oyuncu', () {
      expect(PlayerIdentity.resolveNameWithTag(null, isKu: false), 'Oyuncu');
    });
  });

  group('depo: liste RPC\'leri herkese açık profille tamamlanır', () {
    test('arkadaş: güncel ad, fotoğraf ve kod gelir', () async {
      final http = _Http();
      final friends = await _repo(http).loadFriends();
      expect(friends, hasLength(1));
      expect(friends.single.friendName, 'Rojda');
      expect(friends.single.friendAvatar?.photoUrl, _photo);
      expect(friends.single.friendTag, 'AB12');
      expect(http.paths, contains('/rest/v1/rpc/get_public_profiles'));
    });

    test('bekleyen istek: gönderenin adı ve fotoğrafı gelir', () async {
      final requests = await _repo(_Http()).loadPendingFriendRequests();
      expect(requests.single.fromUserName, 'Rojda');
      expect(requests.single.fromProfile?.avatar.photoUrl, _photo);
    });

    test('sıralama: oyuncu kodu gelir (adsız oyuncu için)', () async {
      final entries = await _repo(_Http()).loadLeaderboard();
      expect(entries.single.playerTag, 'AB12');
    });

    test('düello gelen kutusu: rakip kimliği id ile tamamlanır', () async {
      final duels = await _repo(_Http()).loadMyAsyncDuels();
      expect(duels.single.opponentId, 'f1');
      expect(duels.single.opponentName, 'Rojda');
      expect(duels.single.opponentProfile?.avatar.photoUrl, _photo);
    });

    test('SQL uygulanmamışsa (id yok) eski davranış: profil yok', () async {
      // opponent_id yok -> profil aranmaz, ad olduğu gibi kalır.
      final duel = PublicProfile.fromJson(const {'id': 'x'});
      expect(duel.avatar.photoUrl, isNull);
      expect(duel.nameOr('Oyuncu'), 'Oyuncu');
    });
  });

  group('ekranlar sahte veriyle fotoğraf ve adı çizer', () {
    testWidgets('sıralama: fotoğraf avatara iner, adsız oyuncu kodla yazılır', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: LeaderboardScreen(repository: _BoardRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatars = tester.widgetList<PlayerAvatar>(
        find.byType(PlayerAvatar),
      );
      expect(avatars.any((a) => a.photoUrl == _photo), isTrue);
      expect(find.textContaining('Oyuncu ZK-AB12'), findsWidgets);
    });

    testWidgets('lobi: oyuncunun fotoğrafı ve kodlu adı çizilir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _LobbyRepository();
      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: repository.lobby(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is PlayerAvatar && w.photoUrl == _photo,
        ),
        findsWidgets,
      );
      expect(find.text('Oyuncu ZK-AB12'), findsWidgets);
    });

    testWidgets('1v1: rakip yayın gönderince fotoğrafı ve gerçek adı kaybolmaz', (
      tester,
    ) async {
      final repository = _DuelRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider(create: (_) => AuthProvider.test()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => SoundProvider()),
            ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuizScreen(
                repository: repository,
                room: repository.duelRoom(),
                questions: [repository.questions.first],
                is1v1: true,
                enableTimer: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Rakip, yer tutucu adıyla ("Oyuncu") hazır yayını + cevap yayını yollar.
      repository.emit({
        'sender': 'Oyuncu',
        'sender_id': 'opp-1',
        'ready': true,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      repository.emit({
        'sender': 'Oyuncu',
        'sender_id': 'opp-1',
        'answered': true,
        'score': 10,
        'streak': 1,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byWidgetPredicate(
          (w) => w is PlayerAvatar && w.photoUrl == _photo,
        ),
        findsWidgets,
        reason: 'rakibin fotoğrafı ilk yayında kaybolmamalı',
      );
      expect(find.textContaining('Rojda'), findsWidgets);
    });
  });
}

class _BoardRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => const [
    LeaderboardEntry(
      rank: 1,
      playerId: 'p1',
      displayName: 'ZanKurd Oyuncusu',
      totalScore: 900,
      bestStreak: 5,
      roomsPlayed: 10,
      avatarUrl: _photo,
      playerTag: 'AB12',
    ),
    LeaderboardEntry(
      rank: 2,
      playerId: 'p2',
      displayName: 'Newroz',
      totalScore: 800,
      bestStreak: 4,
      roomsPlayed: 9,
    ),
    LeaderboardEntry(
      rank: 3,
      playerId: 'p3',
      displayName: 'Sara',
      totalScore: 700,
      bestStreak: 3,
      roomsPlayed: 8,
    ),
    LeaderboardEntry(
      rank: 4,
      playerId: 'p4',
      displayName: 'Diyar',
      totalScore: 600,
      bestStreak: 2,
      roomsPlayed: 7,
    ),
  ];

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

const _guest = Player(
  id: 'guest-1',
  name: 'ZanKurd Oyuncusu',
  score: 0,
  state: 'Hazır',
  avatarUrl: _photo,
  tag: 'AB12',
);

class _LobbyRepository extends MockZanKurdRepository {
  @override
  String? get currentUserId => 'host-user';

  static const _host = Player(
    id: 'host-user',
    name: 'Ez',
    score: 0,
    state: 'Hazır',
  );

  GameRoom lobby() => const GameRoom(
    id: 'room-kimlik',
    name: 'Oda',
    code: 'ZK-KIMLIK',
    category: 'Ziman',
    players: [_host, _guest],
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => const [
    _host,
    _guest,
  ];

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(const [_host, _guest]);
}

class _DuelRepository extends MockZanKurdRepository {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  void emit(Map<String, dynamic> payload) => _controller.add(payload);

  @override
  String? get currentUserId => 'me-1';

  GameRoom duelRoom() => GameRoom(
    id: 'room-duel',
    name: '1v1',
    code: 'ZK-DUEL',
    category: questions.first.category,
    status: RoomStatus.active,
    questionCount: 1,
    players: const [
      Player(id: 'me-1', name: 'Ez', score: 0, state: 'Hazır'),
      Player(
        id: 'opp-1',
        name: 'Rojda',
        score: 0,
        state: 'Hazır',
        avatarUrl: _photo,
        tag: 'AB12',
      ),
    ],
  );

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      _controller.stream;

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {}
}
