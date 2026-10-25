import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';

/// Arkadaş listesini kaç kez okuduğunu sayan depo.
class _CountingFriendsRepository extends MockZanKurdRepository {
  int loadFriendsCalls = 0;

  @override
  Future<List<Friend>> loadFriends() async {
    loadFriendsCalls++;
    return const [];
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];
}

/// Arkadaşlar ekranının 20 sn'lik yoklaması uygulama arka plandayken
/// durur; dönüşte bir kez tazelenir ve TEK zamanlayıcıyla sürer.
///
/// Eskiden yalnız `resumed` dinleniyordu: zamanlayıcı arka planda da
/// Supabase'e istek atmaya devam ediyordu (pil, veri, kota).
// Gerçek platform sırası: AppLifecycleListener geçersiz geçişte assert eder.
void _toBackground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

void _toForeground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

void main() {
  testWidgets('arka planda yoklama durur, dönüşte bir kez tazelenir', (
    tester,
  ) async {
    final repository = _CountingFriendsRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(initialLang: 'tr'),
          ),
        ],
        child: MaterialApp(home: FriendsScreen(repository: repository)),
      ),
    );
    await tester.pump();

    // Önde: 20 sn'de bir yeniden okur.
    final afterStart = repository.loadFriendsCalls;
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(repository.loadFriendsCalls, afterStart + 1);

    // Arka plan: periyodik süreler geçse de istek yok.
    _toBackground(tester);
    final afterPause = repository.loadFriendsCalls;
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause);

    // Dönüş: bir kez hemen tazelenir.
    _toForeground(tester);
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause + 1);

    // 10 sn sonra ikinci bir dönüş: döngü yeniden kurulur. Eski zamanlayıcı
    // iptal edilmeseydi 20. saniyede o da tetiklenirdi.
    await tester.pump(const Duration(seconds: 10));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause + 2);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(
      repository.loadFriendsCalls,
      afterPause + 2,
      reason: 'İlk dönüşün zamanlayıcısı iptal edilmeli (tek zamanlayıcı).',
    );

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause + 3);

    await tester.pumpWidget(const SizedBox());
  });
}
