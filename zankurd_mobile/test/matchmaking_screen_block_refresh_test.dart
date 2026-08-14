import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Eşleştirme VS kartında rakibi engellemek fotoğrafını/adını ANINDA
/// gizlemeli.
///
/// ## Kusur
///
/// `PlayerModerationButton.onBlocked`, `room_screen.dart`taki gibi burada
/// da hiçbir yere bağlı değildi. Rakip engellendiğinde düğme "Oyuncu
/// engellendi" diyordu, sunucudaki engel de kuruluyordu, ama rakibin
/// YÜKLEDİĞİ fotoğraf ve adı VS kartında tam ekran gösterilmeye devam
/// ediyordu — kullanıcı tam da engellemek istediği UGC'yi görmeye devam
/// ediyordu (2026-08-14 denetimi).
///
/// ## Bekçi
///
/// Rakibi engelleyip aynı VS kartında fotoğraf/ad yerine nötr bir
/// "engellendi" göstergesinin geçtiğini doğrular.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  Widget shell(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang('tr'),
        ),
        ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: child),
    );
  }

  testWidgets('rakibi engelleyince VS kartındaki adı/fotoğrafı gizlenir', (
    tester,
  ) async {
    final repository = _FoundOpponentRepository();
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rastgele eşleşme'));
    // "Zafer geçişi" (1500 ms) tamamlanmadan, "eşleşti" durumunun
    // KENDİSİNİ yakala — asıl VS kartı burada.
    await tester.pump();
    await tester.pump();

    expect(find.text('Rojda'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-block-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Rojda'),
      findsNothing,
      reason:
          'Engelleme sunucuda başarılı oldu ama rakibin adı/fotoğrafı VS '
          'kartında görünmeye devam ediyordu; onBlocked artık yereldeki '
          'kartı da günceller',
    );
    expect(repository.blockedPlayerIds, contains('opponent-id'));

    // "Zafer geçişi" zamanlayıcısını tükterek testi temiz bırak.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
  });
}

class _FoundOpponentRepository extends MockZanKurdRepository {
  final List<String> blockedPlayerIds = [];

  @override
  String? get currentUserId => 'me-id';

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {
      'status': 'matched',
      'room_id': '00000000-0000-0000-0000-000000000099',
      'opponent_name': 'Rojda',
    };
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    return const GameRoom(
      id: '00000000-0000-0000-0000-000000000099',
      name: '1vs1',
      code: 'ZK-BLK1',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'ZanKurd Oyuncusu', score: 0, state: 'Hazır'),
        Player(id: 'opponent-id', name: 'Rojda', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 10,
      hostId: 'me-id',
    );
  }

  @override
  Future<bool> blockPlayer(String playerId) async {
    blockedPlayerIds.add(playerId);
    return true;
  }
}
