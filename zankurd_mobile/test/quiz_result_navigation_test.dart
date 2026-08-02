import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

const _rootMarker = 'ROOT_HOME';
const _staleRoomMarker = 'STALE_FINISHED_ROOM';

QuizResultScreen _resultScreen(
  MockZanKurdRepository repository, {
  required String? roomId,
}) {
  final room = repository.createRoom().copyWith(
    id: roomId,
    status: RoomStatus.finished,
  );
  return QuizResultScreen(
    repository: repository,
    room: room,
    score: 1000,
    correctCount: 10,
    wrongCount: 0,
    totalQuestions: 10,
    bestStreak: 10,
    answerRecords: const [],
    coinsAwarded: 50,
  );
}

Future<void> _pumpResultOnFinishedRoomStack(
  WidgetTester tester, {
  required String language,
  required String? roomId,
}) async {
  final repository = freshMockRepository();

  await tester.pumpWidget(
    testShell(
      languageProvider: LanguageProvider()..setLang(language),
      child: const Scaffold(body: Text(_rootMarker)),
    ),
  );
  await tester.pumpAndSettle();

  final navigator = Navigator.of(tester.element(find.text(_rootMarker)));
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text(_staleRoomMarker)),
    ),
  );
  await tester.pumpAndSettle();
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => _resultScreen(repository, roomId: roomId),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('result-play-again-button')),
    500,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  testWidgets(
    'çevrimiçi sonuç ana eylemi eve döner ve bitmiş oda rotasını temizler',
    (tester) async {
      await _pumpResultOnFinishedRoomStack(
        tester,
        language: 'tr',
        roomId: 'online-room-id',
      );

      final action = find.byKey(const ValueKey('result-play-again-button'));
      expect(
        find.descendant(of: action, matching: find.text('Ana Sayfa')),
        findsOneWidget,
      );

      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.text(_rootMarker), findsOneWidget);
      expect(find.text(_staleRoomMarker), findsNothing);
      expect(find.byType(QuizResultScreen), findsNothing);
    },
  );

  testWidgets('çevrimiçi ana eylem Kurmancîde Sereke olarak görünür', (
    tester,
  ) async {
    await _pumpResultOnFinishedRoomStack(
      tester,
      language: 'ku',
      roomId: 'online-room-id',
    );

    final action = find.byKey(const ValueKey('result-play-again-button'));
    expect(
      find.descendant(of: action, matching: find.text('Sereke')),
      findsOneWidget,
    );
  });

  testWidgets('çevrimiçi AppBar geri bitmiş oda rotasını temizler', (
    tester,
  ) async {
    await _pumpResultOnFinishedRoomStack(
      tester,
      language: 'tr',
      roomId: 'online-room-id',
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text(_rootMarker), findsOneWidget);
    expect(find.text(_staleRoomMarker), findsNothing);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('çevrimiçi sistem geri bitmiş oda rotasını temizler', (
    tester,
  ) async {
    await _pumpResultOnFinishedRoomStack(
      tester,
      language: 'tr',
      roomId: 'online-room-id',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(_rootMarker), findsOneWidget);
    expect(find.text(_staleRoomMarker), findsNothing);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('solo sistem geri yalnız sonuç rotasını kapatır', (tester) async {
    await _pumpResultOnFinishedRoomStack(tester, language: 'tr', roomId: null);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(_rootMarker), findsNothing);
    expect(find.text(_staleRoomMarker), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('solo sonuç eylemi Tekrar oyna davranışını korur', (
    tester,
  ) async {
    await _pumpResultOnFinishedRoomStack(tester, language: 'tr', roomId: null);

    final action = find.byKey(const ValueKey('result-play-again-button'));
    expect(
      find.descendant(of: action, matching: find.text('Tekrar oyna')),
      findsOneWidget,
    );

    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text(_rootMarker), findsOneWidget);
    expect(find.text(_staleRoomMarker), findsNothing);
  });
}
