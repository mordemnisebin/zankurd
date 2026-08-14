import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Arkadaş sistemi ilk arkadaştan sonra da erişilebilir kalır.
///
/// ## Kusur
///
/// `FriendsScreen` — oyuncu arama, istek gönderme, gelen istekleri
/// kabul/ret, arkadaşla oda kurma — uygulamanın tamamında yalnız TEK
/// yerden açılıyordu: Liderlik > Arkadaşlar sekmesinin **boş durum**
/// düğmesinden.
///
/// Kullanıcı bir arkadaş edindiği anda `friends.isEmpty` false oluyor,
/// `AppEmptyState` kayboluyor ve yerine dokunulamayan bir sıralama listesi
/// geliyordu. O andan sonra ekrana giden hiçbir yol kalmıyordu:
///
/// * yeni arkadaş aranamıyor,
/// * gelen arkadaşlık istekleri hiçbir yerde görülemiyor
///   (`loadPendingFriendRequests` yalnız o ekranda çağrılıyordu),
/// * arkadaşla oda kurulamıyor.
///
/// Alt sekmelerde de sosyal bir sekme yok (Öğren/Yarış/Liderlik/Profil).
/// Yani tüm sosyal katman ilk arkadaştan sonra sessizce ölüyordu ve
/// gönderilen istekler cevapsız kalıyordu (2026-07-31 denetimi).
///
/// Bu bekçi düğmenin **boş/dolu durumdan bağımsız** var olduğunu ölçer —
/// kusurun tam kalbi buydu.
class _FriendsRepository extends MockZanKurdRepository {
  _FriendsRepository({this.friends = const [], this.pending = const []});

  final List<Friend> friends;
  final List<FriendRequest> pending;

  @override
  Future<List<Friend>> loadFriendsLeaderboard() async => friends;

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => pending;
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(initialLang: 'tr'),
      ),
      // FriendsScreen oyuncu aramayı çocuk moduna göre kapatıyor; sağlayıcı
      // olmadan açılamıyor.
      ChangeNotifierProvider<ChildSafetyProvider>(
        create: (_) => ChildSafetyProvider(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  const friendsButton = ValueKey('leaderboard-friends-button');
  const badge = ValueKey('leaderboard-friends-badge');

  testWidgets('arkadaş girişi arkadaş listesi BOŞKEN görünür', (tester) async {
    await tester.pumpWidget(
      _wrap(LeaderboardScreen(repository: _FriendsRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(friendsButton), findsOneWidget);
  });

  testWidgets('arkadaş girişi arkadaş listesi DOLUYKEN de görünür', (
    tester,
  ) async {
    // Kusurun tam hâli: boş durum kaybolunca giriş de kayboluyordu.
    await tester.pumpWidget(
      _wrap(
        LeaderboardScreen(
          repository: _FriendsRepository(
            friends: [
              Friend(
                id: 'f1',
                userId: 'me',
                friendId: 'u-zelal',
                friendName: 'Zelal',
                createdAt: DateTime(2026, 7, 1),
                totalScore: 900,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(friendsButton),
      findsOneWidget,
      reason:
          'İlk arkadaştan sonra arkadaş sistemine giden yol kapanıyordu: '
          'yeni arkadaş aranamıyor, gelen istekler görülemiyordu.',
    );
  });

  testWidgets('arkadaş düğmesi FriendsScreen açar', (tester) async {
    await tester.pumpWidget(
      _wrap(LeaderboardScreen(repository: _FriendsRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(friendsButton));
    await tester.pumpAndSettle();

    expect(find.byType(FriendsScreen), findsOneWidget);
  });

  testWidgets('arkadaş sekmesi ilk açılışta boş duruma iner', (tester) async {
    await tester.pumpWidget(
      _wrap(LeaderboardScreen(repository: _FriendsRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arkadaş'));
    await tester.pumpAndSettle();

    expect(find.text('Arkadaş yok'), findsOneWidget);
    expect(find.text('Bir hata oluştu'), findsNothing);
  });

  testWidgets('bekleyen istek yokken rozet çizilmez', (tester) async {
    await tester.pumpWidget(
      _wrap(LeaderboardScreen(repository: _FriendsRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(badge),
      findsNothing,
      reason: 'Boş rozet "bir şey var" der ama ne olduğunu söylemez.',
    );
  });

  testWidgets('bekleyen istek varsa rozet sayıyı gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LeaderboardScreen(
          repository: _FriendsRepository(
            pending: [
              FriendRequest(
                id: 'r1',
                fromUserId: 'u1',
                fromUserName: 'Baran',
                toUserId: 'me',
                createdAt: DateTime(2026, 7, 30),
              ),
              FriendRequest(
                id: 'r2',
                fromUserId: 'u2',
                fromUserName: 'Rojda',
                toUserId: 'me',
                createdAt: DateTime(2026, 7, 30),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(badge), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('dokuzdan çok istek 9+ olarak kısalır', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LeaderboardScreen(
          repository: _FriendsRepository(
            pending: List.generate(
              12,
              (i) => FriendRequest(
                id: 'r$i',
                fromUserId: 'u$i',
                fromUserName: 'Oyuncu $i',
                toUserId: 'me',
                createdAt: DateTime(2026, 7, 30),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9+'), findsOneWidget);
  });
}
