import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

class _FailingRoomRepository extends MockZanKurdRepository {
  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
  }) {
    return Future<GameRoom>.error(StateError('online room unavailable'));
  }
}

class _FailingJoinRoomRepository extends MockZanKurdRepository {
  int joinCalls = 0;

  @override
  Future<GameRoom> joinOnlineRoom(String code) {
    joinCalls += 1;
    return Future<GameRoom>.error(StateError('online room join unavailable'));
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets(
    'home does not open a demo room when online room creation fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ZanKurdApp(
          repository: _FailingRoomRepository(),
          authProvider: FakeAuthProvider(),
          languageProvider: turkishLang(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yarış'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('play-hub-create-room')),
      );
      await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsNothing);
      expect(find.text('Rojda'), findsNothing);
      expect(find.text('Baran'), findsNothing);
      expect(
        find.text('Oda açılamadı. Bağlantını kontrol et.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('home does not open a demo room when online room join fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: _FailingJoinRoomRepository(),
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      'ABCD12',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.text('Rojda'), findsNothing);
    expect(find.text('Baran'), findsNothing);
    expect(find.text('Bu kodla oda bulunamadı.'), findsOneWidget);
  });

  testWidgets('empty room code is validated locally before online join', (
    tester,
  ) async {
    final repository = _FailingJoinRoomRepository();
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    expect(repository.joinCalls, 0);
    expect(find.text('Kod zorunlu'), findsOneWidget);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('settings updates the online player name', (tester) async {
    final repository = NeedsNameRepository()..savedName = 'Eski Ad';

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oyuncu Adı'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('settings-player-name-field')),
      'Yeni Ad',
    );
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repository.savedName, 'Yeni Ad');
    expect(find.text('Oyuncu adı güncellendi.'), findsOneWidget);
  });

  testWidgets('profile shows player name without inline editing', (
    tester,
  ) async {
    final repository = NeedsNameRepository()..savedName = 'Zana';

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zana'), findsOneWidget);
    expect(find.text('Oyuncu Adı'), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-player-name-field')),
      findsNothing,
    );
  });

  testWidgets('quiz screen shows circular timer', (tester) async {
    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-circular-timer')), findsOneWidget);
    // Sayaç artık odanın gerçek süresini gösterir (varsayılan 30 sn);
    // önceden sabit 15'e kilitliydi ve lobi çipiyle çelişiyordu.
    expect(
      find.text('${repository.createRoom().secondsPerQuestion}'),
      findsOneWidget,
    );
  });

  // testWidgets('explanation box is displayed after 800ms delay', (tester) async {
  //   final question = repository.questions.first;
  //   await tester.pumpWidget(
  //     testShell(
  //       child: QuizScreen(
  //         repository: repository,
  //         room: repository.createRoom(),
  //         questions: [question],
  //         enableTimer: false,
  //       ),
  //     ),
  //   );
  //   await tester.pumpAndSettle();
  //
  //   final answerText = question.displayAnswers.first;
  //   await tester.ensureVisible(find.text(answerText).first);
  //   await tester.tap(find.text(answerText).first);
  //   await tester.pump();
  //
  //   final shown = question.getLocalizedExplanation(false);
  //   await tester.pump(const Duration(milliseconds: 400));
  //   expect(find.text(shown), findsNothing);
  //
  //   await tester.pump(const Duration(milliseconds: 600));
  //   await tester.pumpAndSettle();
  //
  //   expect(find.text(shown), findsOneWidget);
  // });
}
