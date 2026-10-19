/// Arkadaş satırının birincil eylemi: sırayla meydan okuma.
///
/// ## Kusur
///
/// Arkadaş listesindeki tek eylem "Odaya çağır"dı: canlı bir oda kurup
/// oyuncuyu lobide bekletiyordu. Ürünün günlük aktif oyuncusu 3-25; iki
/// arkadaşın aynı anda çevrimiçi olması neredeyse hiç yok, yani satırın tek
/// eylemi çoğu kez boş bir lobiyle bitiyordu. Oysa uygulamada sırayla
/// "arkadaşa meydan oku" akışı zaten vardı (seçim sayfasındaki "Arkadaş seç"
/// yolu) ve arkadaş listesinden ulaşılamıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// "Odaya çağır" çalışıyordu: oda kuruluyor, kod paylaşılıyordu. Kusur
/// işlevde değil yön seçiminde; hiçbir test "bu satırın birincil eylemi ne
/// olmalı" diye sormuyordu, ve tek kullanıcılı simülatörde arkadaş hep
/// çevrimiçi sayıldığı için bekleme sorunu görülmüyordu.
///
/// Bu dosya: (1) meydan okuma destekliyken satırın yazılı eyleminin
/// "Meydan oku" olduğunu ve dokununca O arkadaşın kimliğiyle
/// `createAsyncDuelChallenge`e gittiğini, (2) canlı oda davetinin yine
/// erişilebilir ama simge düğmesine indiğini (ekran okuyucu adı + 48 dokunma
/// kutusu), (3) sunucuda RPC'ler yokken ya da bayrak kapalıyken eski yazılı
/// "Odaya çağır"ın birincil kaldığını sabitler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class _RequestRepo extends _Repo {
  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => [
    FriendRequest(
      id: 'r1',
      fromUserId: 'u-rojin',
      fromUserName: 'Rojîn',
      toUserId: 'me',
      createdAt: DateTime(2026, 10, 1),
    ),
  ];
}

class _Repo extends MockZanKurdRepository {
  final List<String?> challengedFriendIds = [];
  int roomsCreated = 0;

  @override
  Future<List<Friend>> loadFriends() async => [
    Friend(
      id: 'f1',
      userId: 'me',
      friendId: 'friend-rojda',
      friendName: 'Rojda',
      createdAt: DateTime(2026, 10, 1),
    ),
    Friend(
      id: 'f2',
      userId: 'me',
      friendId: 'friend-diyar',
      friendName: 'Diyar',
      createdAt: DateTime(2026, 10, 1),
    ),
  ];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];

  @override
  Future<AsyncDuelStart> createAsyncDuelChallenge({
    String? category,
    String? friendId,
  }) {
    challengedFriendIds.add(friendId);
    return super.createAsyncDuelChallenge(
      category: category,
      friendId: friendId,
    );
  }

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
    int maxPlayers = 2,
  }) {
    roomsCreated++;
    return super.createOnlineRoom(
      category: category,
      secondsPerQuestion: secondsPerQuestion,
      questionCount: questionCount,
      entryFee: entryFee,
      maxPlayers: maxPlayers,
    );
  }
}

Widget _app(_Repo repo, {bool asyncDuelEnabled = true}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(initialLang: 'tr'),
    ),
  ],
  child: MaterialApp(
    home: FriendsScreen(repository: repo, asyncDuelEnabled: asyncDuelEnabled),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('meydan okuma destekliyken satırın yazılı eylemi "Meydan oku"', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Repo()));
    await tester.pumpAndSettle();

    expect(find.text('Meydan oku'), findsNWidgets(2));
    // Tasarım kurulu tüm ekranlar 2026-10-20: kapı simgesi neyi yaptığını
    // söylemiyordu; canlı oda daveti artık yazılı SESSİZ metin eylemi
    // ("Meydan oku" ikincil düğme kalır, bu ikincisi metin).
    final roomButton = find.byKey(const ValueKey('friend-room-Rojda'));
    expect(roomButton, findsOneWidget);
    expect(find.text('Odaya çağır'), findsNWidgets(2));
    expect(find.byIcon(AppIcons.doorOpen), findsNothing);
    expect(tester.getSize(roomButton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(roomButton).height, greaterThanOrEqualTo(48));
  });

  // Tasarım kurulu tüm ekranlar 2026-10-20: bekleyen isteğin "Kabul"ü
  // ekranın birincil (turuncu) eylemidir.
  testWidgets('bekleyen isteğin Kabul düğmesi birincil (turuncu) eylemdir', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_RequestRepo()));
    await tester.pumpAndSettle();
    final accept = find.ancestor(
      of: find.text('Kabul'),
      matching: find.byType(FilledButton),
    );
    expect(accept, findsOneWidget);
    final style = tester.widget<FilledButton>(accept).style;
    // Birincil düğme arka planı tema (Agir) dolgusundan gelir; ikincil
    // (Kulis) kendi `backgroundColor`ını yazar.
    expect(style?.backgroundColor, isNull);
  });

  testWidgets(
    '"Meydan oku" o arkadaşın kimliğiyle meydan okuma akışına girer',
    (tester) async {
      final repo = _Repo();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('friend-action-Diyar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
      // Seçim sayfası atlandı ve satırdaki arkadaşın kimliği gitti (ilk satır
      // değil, dokunulan satır).
      expect(repo.challengedFriendIds, ['friend-diyar']);
      expect(repo.roomsCreated, 0);
    },
  );

  testWidgets('simge düğmesi hâlâ canlı oda açar', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('friend-room-Rojda')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.roomsCreated, 1);
    expect(repo.challengedFriendIds, isEmpty);
    expect(find.byType(RoomScreen), findsOneWidget);
  });

  testWidgets('sunucuda meydan okuma yokken "Odaya çağır" birincil kalır', (
    tester,
  ) async {
    final repo = _Repo()..challengeSupportedForTesting = false;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Odaya çağır'), findsNWidgets(2));
    expect(find.text('Meydan oku'), findsNothing);
    expect(find.byKey(const ValueKey('friend-room-Rojda')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('friend-action-Rojda')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.roomsCreated, 1);
    expect(repo.challengedFriendIds, isEmpty);
  });

  testWidgets('sırayla düello bayrağı kapalıyken meydan okuma çizilmez', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Repo(), asyncDuelEnabled: false));
    await tester.pumpAndSettle();

    expect(find.text('Meydan oku'), findsNothing);
    expect(find.text('Odaya çağır'), findsNWidgets(2));
  });
}
