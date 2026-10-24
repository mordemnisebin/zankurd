/// Sosyal eylemden sonra bağlamsal bildirim izni istemi.
///
/// ## Kusur
///
/// Bildirim izni yalnız "Günlük hatırlatıcı" açılınca isteniyordu; arkadaşlık
/// isteği gönderen, oda kuran ya da meydan okuyan oyuncu cevap/davet
/// bildirimlerini ALMAK için hiçbir yerde izin vermiyordu (25 kullanıcıdan
/// yalnız 7'sinde FCM token vardı). Sunucu kuyruğu ve `send-push` sağlamdı;
/// kırık halka izindi.
///
/// ## Niçin sessiz kalırdı
///
/// Gönderim tarafı hata vermez: token yoksa satır sessizce atlanır. Ekranda
/// da hiçbir şey eksik görünmez. İstem eklendikten sonra da iki hata sessiz
/// kalabilir: her eylemde yeniden sorup kullanıcıyı bıktırmak, ya da
/// "Şimdi değil"i unutup bir daha hiç sormamak.
///
/// ## Bekçi
///
/// Bu dosya: sosyal eylemden sonra diyalogun BİR kez çıktığını, izin
/// verilince sistem izninin istendiğini ve token'ın hemen yazıldığını,
/// "Şimdi değil"de 7 gün sorulmadığını (7 gün sonra sorulduğunu), izin
/// zaten varken / push yokken / aynı oturumda ikinci kez çıkmadığını ölçer.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';
import 'package:zankurd_mobile/src/services/social_push_prompt.dart';

class FakePushGateway implements PushMessagingGateway {
  FakePushGateway({
    this.available = true,
    this.permitted = false,
    this.grantOnRequest = true,
  });

  bool available;
  bool permitted;
  bool grantOnRequest;
  int requestCalls = 0;
  final controller = StreamController<ForegroundPush>.broadcast();

  @override
  bool get isAvailable => available;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    if (grantOnRequest) permitted = true;
    return grantOnRequest;
  }

  @override
  Stream<ForegroundPush> get onForegroundMessage => controller.stream;
}

class _FixedToken implements PushTokenSource {
  const _FixedToken();
  @override
  Future<String?> currentToken() async => 'fcm-token-1';
}

class _AcceptRepository extends MockZanKurdRepository {
  bool accepted = false;

  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => accepted
      ? const []
      : [
          FriendRequest(
            id: 'req1',
            fromUserId: 'friend-user-3',
            fromUserName: 'Diyar',
            toUserId: 'user1',
            createdAt: DateTime.now(),
            status: 'pending',
          ),
        ];

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    accepted = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePushGateway gateway;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SocialPushPrompt.resetForTest();
    gateway = FakePushGateway();
    PushMessaging.gateway = gateway;
  });
  tearDown(() {
    SocialPushPrompt.resetForTest();
    PushMessaging.resetForTest();
  });

  Widget friendsShell(MockZanKurdRepository repository) => MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(initialLang: 'tr'),
      ),
    ],
    child: MaterialApp(home: FriendsScreen(repository: repository)),
  );

  Future<void> acceptRequest(
    WidgetTester tester,
    _AcceptRepository repo,
  ) async {
    await tester.pumpWidget(friendsShell(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kabul'));
    await tester.pumpAndSettle();
  }

  final enable = find.byKey(const ValueKey('social-push-enable'));
  final later = find.byKey(const ValueKey('social-push-later'));

  testWidgets('arkadaşlık isteği kabulünden sonra diyalog çıkar; "aç" sistem '
      'iznini ister ve token hemen yazılır', (tester) async {
    final repo = _AcceptRepository();
    SocialPushPrompt.tokenSync = PushTokenSync(
      source: const _FixedToken(),
      repository: repo,
    );
    await acceptRequest(tester, repo);

    expect(
      find.text(
        'Arkadaşın cevap verince ya da seni davet edince haber verelim mi?',
      ),
      findsOneWidget,
    );
    await tester.tap(enable);
    await tester.pumpAndSettle();

    expect(gateway.requestCalls, 1);
    expect(repo.lastFcmToken, 'fcm-token-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SocialPushPrompt.doneKey), isTrue);
  });

  testWidgets('"Şimdi değil": sistem izni istenmez, 7 gün sorulmaz, 7 gün '
      'sonra sorulur', (tester) async {
    final repo = _AcceptRepository();
    await acceptRequest(tester, repo);
    expect(later, findsOneWidget);
    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(gateway.requestCalls, 0);

    // Yeni oturum, aynı gün: sorulmaz.
    SocialPushPrompt.resetForTest();
    expect(await SocialPushPrompt.shouldAsk(), isFalse);
    // 6 gün sonra hâlâ sorulmaz; 7 gün sonra sorulur.
    expect(
      await SocialPushPrompt.shouldAsk(
        now: DateTime.now().add(const Duration(days: 6)),
      ),
      isFalse,
    );
    expect(
      await SocialPushPrompt.shouldAsk(
        now: DateTime.now().add(const Duration(days: 7, minutes: 1)),
      ),
      isTrue,
    );
  });

  testWidgets('sistem izni reddedilirse bir daha sorulmaz', (tester) async {
    gateway.grantOnRequest = false;
    await acceptRequest(tester, _AcceptRepository());
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(gateway.requestCalls, 1);

    SocialPushPrompt.resetForTest();
    expect(
      await SocialPushPrompt.shouldAsk(
        now: DateTime.now().add(const Duration(days: 30)),
      ),
      isFalse,
    );
  });

  testWidgets('izin zaten varsa ya da push yoksa diyalog çıkmaz', (
    tester,
  ) async {
    gateway.permitted = true;
    await acceptRequest(tester, _AcceptRepository());
    expect(enable, findsNothing);

    SocialPushPrompt.resetForTest();
    gateway
      ..permitted = false
      ..available = false;
    expect(await SocialPushPrompt.shouldAsk(), isFalse);
  });

  testWidgets('aynı oturumda ikinci soru sorulmaz (sonuç ekranı kartıyla '
      'çakışmaz)', (tester) async {
    SocialPushPrompt.markPromptedThisSession();
    await acceptRequest(tester, _AcceptRepository());
    expect(enable, findsNothing);
  });

  test('sonuç ekranı kartı aynı oturum bayrağını kullanır', () {
    final source = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    expect(source, contains('SocialPushPrompt.promptedThisSession'));
    expect(source, contains('SocialPushPrompt.markPromptedThisSession()'));
  });

  test('sosyal eylem çağrı yerleri istemi çağırır', () {
    const sites = {
      'lib/src/screens/friends_screen.dart': 3, // gönder, kabul, odaya çağır
      'lib/src/screens/play_hub_screen.dart': 1, // oda kur
      'lib/src/screens/room_screen.dart': 1, // arkadaşı odaya davet et
      'lib/src/screens/async_duel/async_duel_challenge_sheet.dart': 1,
    };
    sites.forEach((path, minimum) {
      final count = 'SocialPushPrompt.maybeAsk('
          .allMatches(File(path).readAsStringSync())
          .length;
      expect(count, greaterThanOrEqualTo(minimum), reason: path);
    });
  });
}
