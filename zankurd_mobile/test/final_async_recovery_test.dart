import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';

class _RequestRepository extends MockZanKurdRepository {
  final response = Completer<bool>();
  int actionCalls = 0;

  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => [
    FriendRequest(
      id: 'request-1',
      fromUserId: 'player-2',
      fromUserName: 'Diyar',
      toUserId: 'player-1',
      createdAt: DateTime(2026, 10, 21),
      status: 'pending',
    ),
  ];

  Future<bool> _respond() {
    actionCalls++;
    return actionCalls == 1 ? response.future : Future.value(false);
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) => _respond();

  @override
  Future<bool> rejectFriendRequest(String requestId) => _respond();
}

class _ContestRepository extends MockZanKurdRepository {
  final response = Completer<Contest?>();
  int loadCalls = 0;

  @override
  Future<Contest?> loadTodayContest() {
    loadCalls++;
    return response.future;
  }
}

Widget _app(Widget screen) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider(initialLang: 'tr')),
    ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
  ],
  child: MaterialApp(home: screen),
);

String _tr(String key) => Tr.of(key, AppLanguage.tr);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final accept in [true, false]) {
    for (final throws in [false, true]) {
      testWidgets(
        '${accept ? 'kabul' : 'red'}: gecikmeli ${throws ? 'exception' : 'false'} sonrası hemen tekrar denenir',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 1200);
          addTearDown(tester.view.reset);
          final repository = _RequestRepository();
          await tester.pumpWidget(_app(FriendsScreen(repository: repository)));
          await tester.pumpAndSettle();
          final action = accept
              ? find.widgetWithText(FilledButton, _tr(K.acceptAction))
              : find.byTooltip(_tr(K.rejectAction));
          await tester.ensureVisible(action);
          await tester.tap(action);
          await tester.pump();
          expect(repository.actionCalls, 1);
          final acceptButton = find.widgetWithText(
            FilledButton,
            _tr(K.acceptAction),
          );
          expect(tester.widget<FilledButton>(acceptButton).onPressed, isNull);

          if (throws) {
            repository.response.completeError(
              StateError('network unavailable'),
            );
          } else {
            repository.response.complete(false);
          }
          await tester.pumpAndSettle();
          expect(
            find.text(_tr(accept ? K.acceptFailed : K.rejectFailed)),
            findsOneWidget,
          );
          expect(
            tester.widget<FilledButton>(acceptButton).onPressed,
            isNotNull,
            reason: 'İşlem başarısızlığı sonrası Kabul hemen etkinleşmeli.',
          );
          await tester.tap(action);
          await tester.pump();
          expect(repository.actionCalls, 2);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('günlük tur zaman aşımı hata ve yeniden dene gösterir', (
    tester,
  ) async {
    final repository = _ContestRepository();
    await tester.pumpWidget(_app(ContestScreen(repository: repository)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text(_tr(K.contestLoadFailed)), findsOneWidget);
    expect(find.text(_tr(K.contestNoneToday)), findsNothing);
    await tester.tap(find.text(_tr(K.retryTiny)));
    await tester.pump();
    expect(repository.loadCalls, 2);
    repository.response.complete(null);
    await tester.pumpAndSettle();
    expect(find.text(_tr(K.contestNoneToday)), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('günlük tur gerçek null sonucunda boş durum korunur', (
    tester,
  ) async {
    final repository = _ContestRepository();
    repository.response.complete(null);
    await tester.pumpWidget(_app(ContestScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text(_tr(K.contestNoneToday)), findsOneWidget);
    expect(find.text(_tr(K.contestLoadFailed)), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
