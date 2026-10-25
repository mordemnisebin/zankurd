import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Yoklamanın yeniden girişi (touch "none" → `joinMatchmaking`) iptalle
/// yarışır.
///
/// ## Kusur
///
/// Yeniden giriş isteği `_joinRequest`e atanmıyordu; iptal yolları yalnız
/// onu bekliyor. İstek uçuştayken "Vazgeç"e basılınca `cancelMatchmaking`
/// hemen "idle" dönüyor, ardından geç gelen join oyuncuyu kuyruğa yazıyor ya
/// da bir odaya üye yapıyordu: ekrandan çıkmış oyuncu hayalet kayıt kalıyor,
/// rakip boş bir maçı bekliyordu.
///
/// ## Bekçi
///
/// Sahte depo sunucunun `cancel_matchmaking` kuralını taklit eder: canlı oda
/// üyeliği varsa "matched" döner, yoksa kuyruk satırını siler.
const _roomId = '00000000-0000-0000-0000-0000000000b2';

class _RaceRepository extends MockZanKurdRepository {
  int joinCalls = 0;
  int cancelCalls = 0;
  int leaveCalls = 0;
  Completer<Map<String, dynamic>>? pendingRejoin;
  MatchmakingTouch touchResult = const MatchmakingTouch.waiting();

  /// Sunucu durumu: kuyrukta satır ve canlı oda üyeliği.
  bool inQueue = false;
  String? liveRoomId;

  @override
  String? get currentUserId => 'me-id';

  @override
  Future<String> getProfileName() async => 'Ez';

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    joinCalls++;
    final Map<String, dynamic> result;
    if (joinCalls == 1) {
      result = const {'status': 'waiting'};
    } else {
      final completer = Completer<Map<String, dynamic>>();
      pendingRejoin = completer;
      result = await completer.future;
    }
    if (result['status'] == 'matched') {
      inQueue = false;
      liveRoomId = result['room_id'] as String?;
    } else {
      inQueue = true;
    }
    return result;
  }

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() =>
      const Stream.empty();

  @override
  Future<MatchmakingTouch> touchMatchmaking() async => touchResult;

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    cancelCalls++;
    if (liveRoomId != null) {
      return {'status': 'matched', 'room_id': liveRoomId};
    }
    final wasQueued = inQueue;
    inQueue = false;
    return {'status': wasQueued ? 'cancelled' : 'idle'};
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    expect(room.id, _roomId);
    leaveCalls++;
    liveRoomId = null;
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'forfeit',
      forfeitedBy: 'player',
    );
  }
}

class _Host extends StatelessWidget {
  const _Host(this.repository);

  final _RaceRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('open-matchmaking'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MatchmakingScreen(
                repository: repository,
                loadRetryDelays: const [],
              ),
            ),
          ),
          child: const Text('aç'),
        ),
      ),
    );
  }
}

Future<void> _searchUntilRejoinPending(
  WidgetTester tester,
  _RaceRepository repository,
) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang('tr'),
        ),
        ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: _Host(repository)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-matchmaking')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rastgele eşleşme'));
  await tester.pump();
  expect(repository.joinCalls, 1);
  expect(repository.inQueue, isTrue);

  // Satır bayat diye silindi: yoklama "none" alır ve yeniden girer; bu
  // istek bekletilir.
  repository
    ..inQueue = false
    ..touchResult = const MatchmakingTouch.none();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  expect(repository.joinCalls, 2);
  expect(repository.pendingRejoin, isNotNull);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets(
    'yeniden giriş uçuştayken iptal: geç "matched" odası terk edilir',
    (tester) async {
      final repository = _RaceRepository();
      await _searchUntilRejoinPending(tester, repository);

      await tester.tap(find.text('Vazgeç'));
      await tester.pump();
      // İptal, uçuştaki yeniden girişi beklemeli; henüz iptal RPC'si yok.
      expect(repository.cancelCalls, 0);

      repository.pendingRejoin!.complete(const {
        'status': 'matched',
        'room_id': _roomId,
        'opponent_name': 'Rojda',
      });
      await tester.pumpAndSettle();

      expect(repository.cancelCalls, 1);
      expect(repository.leaveCalls, greaterThanOrEqualTo(1));
      expect(repository.liveRoomId, isNull);
      expect(repository.inQueue, isFalse);
      expect(find.byType(MatchmakingScreen), findsNothing);
    },
  );

  testWidgets(
    'yeniden giriş uçuştayken iptal: geç "waiting" kuyruktan silinir',
    (tester) async {
      final repository = _RaceRepository();
      await _searchUntilRejoinPending(tester, repository);

      await tester.tap(find.text('Vazgeç'));
      await tester.pump();
      expect(repository.cancelCalls, 0);

      repository.pendingRejoin!.complete(const {'status': 'waiting'});
      await tester.pumpAndSettle();

      expect(repository.cancelCalls, 1);
      expect(repository.inQueue, isFalse);
      expect(repository.leaveCalls, 0);
      expect(find.byType(MatchmakingScreen), findsNothing);
    },
  );
}
