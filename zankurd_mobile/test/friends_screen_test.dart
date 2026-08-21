import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class _TestFriendsRepository extends MockZanKurdRepository {
  _TestFriendsRepository({this.requesterName = 'Diyar'});

  final String requesterName;

  @override
  Future<List<Friend>> loadFriends() async {
    return [
      Friend(
        id: 'friend1',
        userId: 'user1',
        friendId: 'friend-user-1',
        friendName: 'ZanînBot',
        friendAvatarColor: '#E94560',
        createdAt: DateTime.now(),
        totalScore: 2450,
        level: 12,
        gamesPlayed: 48,
        lastActiveAt: DateTime.now().toUtc(),
      ),
      Friend(
        id: 'friend2',
        userId: 'user1',
        friendId: 'friend-user-2',
        friendName: 'KurdBot',
        friendAvatarColor: '#6F61C0',
        createdAt: DateTime.now(),
        totalScore: 1820,
        level: 9,
        gamesPlayed: 31,
        lastActiveAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 10),
        ),
      ),
    ];
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    return [
      FriendRequest(
        id: 'req1',
        fromUserId: 'friend-user-3',
        fromUserName: requesterName,
        toUserId: 'user1',
        createdAt: DateTime.now(),
        status: 'pending',
      ),
    ];
  }

  // `MockZanKurdRepository.searchPlayers` 2026-07-31'de boşaltıldı: bir
  // ağ hatası düşünce gerçek deponun kullandığı fallback, hayalet
  // profilleri gerçek oyuncuya arkadaş olarak öneriyordu. Bu testin arama
  // akışını sınaması için sahte sonuç kümesi artık burada, üretim kodunda
  // değil.
  @override
  Future<List<PlayerSearchResult>> searchPlayers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    const pool = [
      PlayerSearchResult(
        id: 'search-user-1',
        displayName: 'Rojda',
        avatarColor: '#2AA6A1',
      ),
      PlayerSearchResult(
        id: 'search-user-2',
        displayName: 'Rojhat',
        avatarColor: '#E94560',
      ),
      PlayerSearchResult(
        id: 'search-user-3',
        displayName: 'Berçem',
        avatarColor: '#6F61C0',
      ),
    ];
    return pool.where((p) => p.displayName.toLowerCase().contains(q)).toList();
  }
}

/// `searchPlayers` her zaman ağ hatası fırlatan depo.
///
/// `SupabaseZanKurdRepository.searchPlayers` 2026-08-14'e kadar hatayı
/// yutup `_offline.searchPlayers` (boş liste) dönüyordu; bu ekranın
/// gözünde "ağ hatası" ile "gerçekten kimse yok" ayırt edilemez oluyordu
/// — ikisi de boş sonuç olarak görünüyordu ve `K.searchFailed` metni bu
/// yüzden hiçbir zaman gösterilemiyordu.
class _SearchFailsRepository extends MockZanKurdRepository {
  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];

  @override
  Future<List<PlayerSearchResult>> searchPlayers(String query) async {
    throw Exception('network down');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _TestFriendsRepository();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(initialLang: 'tr'),
        ),
        ChangeNotifierProvider<ChildSafetyProvider>(
          create: (_) => ChildSafetyProvider(),
        ),
      ],
      child: MaterialApp(home: FriendsScreen(repository: repository)),
    );
  }

  group('FriendsScreen', () {
    testWidgets('arkadaslar ve bekleyen istekler listelenir', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ZanînBot'), findsOneWidget);
      expect(find.text('KurdBot'), findsOneWidget);
      expect(find.text('Diyar'), findsOneWidget);
      expect(find.text('Kabul'), findsOneWidget);
      expect(find.byIcon(AppIcons.xmark), findsOneWidget);
      expect(
        find.byKey(const ValueKey('friends-search-panel')),
        findsOneWidget,
      );
      // Anahtar arkadaş adını taşır: tek bir sabit anahtar iki satırda da
      // yinelendiği için hangi satırın düğmesine bakıldığı belirsizdi.
      expect(
        find.byKey(const ValueKey('friend-action-ZanînBot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('friend-action-KurdBot')),
        findsOneWidget,
      );
      // Düğmenin sözü ile işi aynı olmalı: oyun başlatmıyor, oda kurup
      // kodu paylaştırıyor.
      expect(find.text('Odaya çağır'), findsNWidgets(2));
      expect(find.text('Oyna'), findsNothing);
    });

    testWidgets(
      'bekleyen istek karti buyuk metinde kimlik ve eylemleri korur',
      (tester) async {
        const requesterName = 'Berîvanê Zimanê Kurdî';
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<LanguageProvider>(
                  create: (_) => LanguageProvider(initialLang: 'tr'),
                ),
                ChangeNotifierProvider<ChildSafetyProvider>(
                  create: (_) => ChildSafetyProvider(),
                ),
              ],
              child: MaterialApp(
                home: FriendsScreen(
                  repository: _TestFriendsRepository(
                    requesterName: requesterName,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final requesterText = tester.renderObject<RenderParagraph>(
          find.text(requesterName),
        );
        expect(
          requesterText.didExceedMaxLines,
          isFalse,
          reason:
              'Büyük metinde istek sahibinin kimliği ellipsis ile '
              'kaybolmamalı; normal test boyutu bu kusuru sessiz bırakıyor.',
        );
        expect(find.text('Kabul'), findsOneWidget);
        expect(find.byIcon(AppIcons.xmark), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('oyuncu arama sonuclari ve ekleme akisi calisir', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'roj');
      await tester.tap(find.text('Ara'));
      await tester.pumpAndSettle();

      expect(find.text('Rojda'), findsOneWidget);
      expect(find.text('Rojhat'), findsOneWidget);
      expect(find.text('Ekle'), findsNWidgets(2));

      await tester.tap(find.text('Ekle').first);
      await tester.pumpAndSettle();

      // İstek gönderilen oyuncuda buton onay ikonuna dönüşür.
      expect(find.text('Ekle'), findsOneWidget);
      expect(find.byIcon(AppIcons.circleCheck), findsOneWidget);
      expect(find.text('İstek gönderildi'), findsOneWidget);
    });

    testWidgets('istek reddetme akisi calisir', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.xmark));
      await tester.pumpAndSettle();

      expect(find.text('İstek reddedildi'), findsOneWidget);
    });

    testWidgets('kisa aramada uyari gosterilir', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'r');
      await tester.tap(find.text('Ara'));
      await tester.pumpAndSettle();

      expect(find.text('En az 2 harf yaz'), findsOneWidget);
    });

    testWidgets(
      'ağ hatasında "bulunamadı" değil "arama başarısız" gösterilir',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LanguageProvider>(
                create: (_) => LanguageProvider(initialLang: 'tr'),
              ),
              ChangeNotifierProvider<ChildSafetyProvider>(
                create: (_) => ChildSafetyProvider(),
              ),
            ],
            child: MaterialApp(
              home: FriendsScreen(repository: _SearchFailsRepository()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'roj');
        await tester.tap(find.text('Ara'));
        await tester.pumpAndSettle();

        expect(find.text('Arama başarısız oldu.'), findsOneWidget);
        expect(find.text('Oyuncu bulunamadı'), findsNothing);
      },
    );
  });
}
