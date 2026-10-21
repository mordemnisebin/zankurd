import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_moderation_button.dart';

/// İki simülatörlü gerçek oyun turu (2026-10-21) bekçileri.
///
/// 1. Lobide oyuncu menüsünden bildir/engelle ONAYSIZ uygulanıyordu;
///    sıralama ekranı onay soruyordu. Artık aynı onay penceresi var ve
///    Vazgeç hiçbir şey yapmaz.
/// 3. Odadan ayrılan oyuncunun bekleyen sonucu yoktur; yoksa oda sonradan
///    bitince bayat bir "0 puan" sonuç ekranı kendiliğinden açılıyordu.
void main() {
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Future<MockZanKurdRepository> open(WidgetTester tester) async {
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        PlayerModerationButton(
          repository: repo,
          playerId: 'other-player',
          playerName: 'Berfin',
          quiet: true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
    await tester.pumpAndSettle();
    return repo;
  }

  group('lobi bildir/engelle onayı', () {
    testWidgets('engelle: onaydan ÖNCE uygulanmaz, Vazgeç hiçbir şey yapmaz', (
      tester,
    ) async {
      final repo = await open(tester);
      await tester.tap(find.byKey(const ValueKey('player-block-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('block-player-dialog')), findsOneWidget);
      expect(await repo.loadBlockedPlayerIds(), isEmpty);

      await tester.tap(find.byKey(const ValueKey('player-moderation-cancel')));
      await tester.pumpAndSettle();
      expect(await repo.loadBlockedPlayerIds(), isEmpty);
    });

    testWidgets('engelle: onayda uygulanır', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.byKey(const ValueKey('player-block-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-moderation-confirm')));
      await tester.pumpAndSettle();
      expect(await repo.loadBlockedPlayerIds(), contains('other-player'));
    });

    testWidgets('bildir: Vazgeç bildirim göndermez, onay gönderir', (
      tester,
    ) async {
      final repo = await open(tester);
      await tester.tap(find.byKey(const ValueKey('player-report-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('report-profile-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('player-moderation-cancel')));
      await tester.pumpAndSettle();
      expect(repo.reportedProfileIds, isEmpty);

      await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-report-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-moderation-confirm')));
      await tester.pumpAndSettle();
      expect(repo.reportedProfileIds, contains('other-player'));
    });
  });

  test('ayrılan oyuncunun bekleyen sonucu yok sayılır', () {
    RoomResultSnapshot snap({required bool left}) => RoomResultSnapshot(
      room: GameRoom(
        id: 'r1',
        name: 'oda',
        code: 'ZK-X',
        category: 'Ziman',
        players: [
          Player(id: 'me', name: 'Ben', score: 0, state: 'x', left: left),
          const Player(id: 'o', name: 'O', score: 5, state: 'x'),
        ],
        status: RoomStatus.finished,
      ),
      ownPlayerId: 'me',
      questionIds: const [],
      answers: const [],
      winnerId: null,
      endedReason: 'completed',
      forfeitedBy: null,
      finishedAt: DateTime(2026),
    );
    expect(pendingResultOwnerLeft(snap(left: true), 'me'), isTrue);
    expect(pendingResultOwnerLeft(snap(left: false), 'me'), isFalse);
  });
}
