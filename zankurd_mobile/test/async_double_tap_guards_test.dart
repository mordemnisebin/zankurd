import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/widget_test_helpers.dart';

/// Eşzamansız eylem bekçileri (2026-10-21 çift denetimi).
///
/// Kusurlar sessizdi çünkü hiçbiri tek dokunuşta görünmez:
///  * Ders "Biqedîne"ye çift dokunuş iki RPC gönderir ve iki kez
///    `Navigator.pop` yapar — kullanıcı bir ekran fazla geri atılırdı.
///  * Arkadaş isteği gönder/kabul/reddet çift dokunuşta çift RPC.
///  * Ad kapısının `onCompleted`ı hata fırlatırsa `_saving` takılı kalır,
///    düğme bir daha basılamazdı.
///  * Teklif yükleme takılırsa paywall yükleyicisi sonsuza dek dönerdi.
class _CountingLessonRepository extends MockZanKurdRepository {
  final Completer<bool> gate = Completer<bool>();
  int completeCalls = 0;

  @override
  Future<bool> markLessonCompleted(String lessonId) {
    completeCalls++;
    return gate.future;
  }
}

class _CountingFriendsRepository extends MockZanKurdRepository {
  final Completer<bool> gate = Completer<bool>();
  int acceptCalls = 0;

  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => [
    FriendRequest(
      id: 'req1',
      fromUserId: 'u3',
      fromUserName: 'Diyar',
      toUserId: 'me',
      createdAt: DateTime.now(),
      status: 'pending',
    ),
  ];

  @override
  Future<bool> acceptFriendRequest(String requestId) {
    acceptCalls++;
    return gate.future;
  }
}

Widget _wrap(Widget child, {String lang = 'tr'}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang(lang),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ders tamamlama çift dokunuşta tek RPC gönderir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _CountingLessonRepository();
    await tester.pumpWidget(
      _wrap(
        lang: 'ku',
        LessonDetailScreen(
          lesson: const Lesson(
            id: 'everyday_1',
            slug: 'everyday-1',
            titleKu: 'Ders',
            titleTr: 'Ders',
            category: 'everyday',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 40 && find.text('Dersê biqedîne').evaluate().isEmpty;
      i++
    ) {
      await tester.tap(find.text('Pêş'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Dersê biqedîne'), findsOneWidget);

    await tester.tap(find.text('Dersê biqedîne'));
    await tester.pump();
    await tester.tap(find.text('Dersê biqedîne'), warnIfMissed: false);
    await tester.pump();

    expect(repository.completeCalls, 1);
    repository.gate.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('arkadaş isteği kabulü çift dokunuşta tek RPC gönderir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _CountingFriendsRepository();
    await tester.pumpWidget(_wrap(FriendsScreen(repository: repository)));
    await tester.pumpAndSettle();

    final accept = find.byIcon(AppIcons.check);
    expect(accept, findsOneWidget);
    await tester.tap(accept);
    await tester.pump();
    await tester.tap(accept, warnIfMissed: false);
    await tester.pump();

    expect(repository.acceptCalls, 1);
    repository.gate.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('ad kapısı: onCompleted hata verirse düğme yeniden basılabilir', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: MockZanKurdRepository(),
          onCompleted: () async {
            calls++;
            throw StateError('yazma başarısız');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('player-name-field')),
      'Rojhat',
    );
    await tester.tap(find.text('Oyuna başla'));
    await tester.pumpAndSettle();
    expect(calls, 1);

    // `_saving` sıfırlandıysa ikinci dokunuş yeniden dener.
    await tester.tap(find.text('Oyuna başla'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  test('teklif yükleme takılırsa zaman aşımı başarısızlık döndürür', () async {
    final previous = PremiumService.offeringsTimeout;
    PremiumService.offeringsTimeout = const Duration(milliseconds: 50);
    addTearDown(() => PremiumService.offeringsTimeout = previous);
    final service = PremiumService.forTesting(
      isAnonymous: () async => true,
      logOut: () async => throw UnimplementedError(),
      fetchOfferings: () => Completer<Never>().future,
      recordError: (_, _, {reason}) {},
    );

    final result = await service.fetchOfferings();

    expect(result, isA<OfferingsFetchFailure>());
  });
}
