import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';

/// Arkadaş isteğini KABUL etme akışı, baştan sona.
///
/// ## Kusur (kapsam boşluğu)
///
/// `friends_screen_test` isteği REDDETME akışını sürüyor ("İstek reddedildi"
/// mesajına kadar), ama kabul etmeyi hiç sürmüyordu. `acceptFriendRequest`
/// testlerde yalnız `no_fake_write_success_test` içinde geçiyor ve orada
/// ölçülen şey ekran akışı değil, deponun sahte başarı raporlamaması.
///
/// Asimetri kolay gözden kaçar çünkü iki düğme yan yana durur ve biri
/// test edilmiştir; "arkadaş ekleme test edilmiş" hissi verir. Oysa kabul
/// yolunda reddetmede olmayan bir adım var: `_acceptRequest` başarıdan sonra
/// `setState(_loadFriends)` ile listeyi TAZELER. O tazeleme kopsa —
/// yeniden yükleme çağrılmasa ya da `mounted` kapısına takılsa — kullanıcı
/// "Arkadaş eklendi" mesajını görür ama arkadaş listede belirmez. Ekran
/// hata vermez; kullanıcı isteği kabul etmediğini sanır ve bir daha dener.
///
/// ## Kural
///
/// Kabul yalnız mesaj göstermez; üç şeyi birden yapar ve üçü de ölçülür:
/// bekleyen istek listeden düşer, kişi arkadaş listesinde belirir ve
/// onay mesajı görünür.
class _AcceptFlowRepository extends MockZanKurdRepository {
  _AcceptFlowRepository();

  bool accepted = false;
  int acceptCalls = 0;

  @override
  Future<List<Friend>> loadFriends() async {
    if (!accepted) return const [];
    return [
      Friend(
        id: 'friend-diyar',
        userId: 'user1',
        friendId: 'friend-user-3',
        friendName: 'Diyar',
        friendAvatarColor: '#2AA6A1',
        createdAt: DateTime.now(),
        totalScore: 120,
        level: 2,
        gamesPlayed: 3,
        lastActiveAt: DateTime.now().toUtc(),
      ),
    ];
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    if (accepted) return const [];
    return [
      FriendRequest(
        id: 'req1',
        fromUserId: 'friend-user-3',
        fromUserName: 'Diyar',
        toUserId: 'user1',
        createdAt: DateTime.now(),
        status: 'pending',
      ),
    ];
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    acceptCalls++;
    // Gerçek depo isteği kabul edip ilişkiyi kurar; burada aynı sonuç
    // taklit edilir: istek düşer, arkadaş belirir.
    accepted = true;
    return true;
  }
}

/// Kabul çağrısı sunucuda başarısız olan depo.
class _AcceptFailsRepository extends _AcceptFlowRepository {
  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    acceptCalls++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget shell(MockZanKurdRepository repository) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(initialLang: 'tr'),
        ),
      ],
      child: MaterialApp(home: FriendsScreen(repository: repository)),
    );
  }

  testWidgets('kabul: istek düşer, arkadaş belirir, onay gösterilir', (
    tester,
  ) async {
    final repository = _AcceptFlowRepository();
    await tester.pumpWidget(shell(repository));
    await tester.pumpAndSettle();

    // Başlangıç: Diyar bekleyen istek olarak duruyor, arkadaş listesi boş.
    expect(find.text('Diyar'), findsOneWidget);

    // Düğme metnine göre bulunur: ekranda başka `FilledButton`lar da var
    // (arama, boş durum eylemi) ve tipe göre aramak onları da yakalıyordu.
    final acceptButton = find.widgetWithText(FilledButton, 'Kabul');
    expect(
      acceptButton,
      findsOneWidget,
      reason: 'Bekleyen istek satırında kabul düğmesi bulunamadı.',
    );
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(find.text('Arkadaş eklendi'), findsOneWidget);

    // Asıl ölçüm: liste gerçekten tazelendi mi. Mesaj göstermek yetmez —
    // kullanıcı arkadaşını listede görmeli.
    expect(
      find.widgetWithText(FilledButton, 'Kabul'),
      findsNothing,
      reason: 'Kabul edilen istek bekleyenler listesinden düşmedi.',
    );
    expect(
      find.text('Diyar'),
      findsOneWidget,
      reason:
          'Kabulden sonra Diyar arkadaş listesinde görünmeli; liste '
          'tazelenmemiş olabilir.',
    );
  });

  testWidgets('kabul sunucuda başarısızsa istek listede kalır', (tester) async {
    final repository = _AcceptFailsRepository();
    await tester.pumpWidget(shell(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Kabul'));
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    // Başarısızlıkta kullanıcıya "eklendi" DENMEMELİ; istek de düşmemeli.
    expect(find.text('Arkadaş eklendi'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Kabul'),
      findsOneWidget,
      reason:
          'Sunucu reddettiği hâlde istek listeden düştüyse kullanıcı '
          'kurulmamış bir arkadaşlığı kurulmuş sanır.',
    );
  });
}
