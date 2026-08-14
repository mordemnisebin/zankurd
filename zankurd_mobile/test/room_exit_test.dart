import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

class _RoomExitRepository extends MockZanKurdRepository {
  final StreamController<RoomStatus> _statuses =
      StreamController<RoomStatus>.broadcast(sync: true);

  int leaveCalls = 0;
  int updateReadyCalls = 0;
  int playerSubscriptionCount = 0;
  int statusSubscriptionCount = 0;
  int statusPollCount = 0;
  bool failNextLeave = false;
  bool failReadyUpdate = false;
  bool failQuestionLoad = false;
  int questionLoadCalls = 0;
  bool failSubscriptionCancel = false;
  Completer<void>? pendingLeave;

  @override
  String? get currentUserId => 'guest-user';

  @override
  bool get usesServerHiddenAnswers => true;

  GameRoom onlineLobby() => const GameRoom(
    id: 'room-exit-1',
    name: 'Hevalên Zanînê',
    code: 'ZK-EXIT',
    category: 'Ziman',
    players: [
      Player(
        id: 'host-user',
        name: 'Mêvandar',
        score: 0,
        state: Player.readyState,
      ),
      Player(
        id: 'guest-user',
        name: 'Mêvan',
        score: 0,
        state: Player.readyState,
      ),
    ],
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    playerSubscriptionCount++;
    if (failSubscriptionCancel) {
      late StreamController<List<Player>> controller;
      controller = StreamController<List<Player>>(
        onListen: () => controller.add(room.players),
        onCancel: () =>
            Future<void>.error(StateError('subscription cancellation failed')),
      );
      return controller.stream;
    }
    return Stream<List<Player>>.value(room.players);
  }

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    statusSubscriptionCount++;
    return _statuses.stream;
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    leaveCalls++;
    final pending = pendingLeave;
    if (pending != null) {
      await pending.future;
    }
    if (failNextLeave) {
      failNextLeave = false;
      throw StateError('network details must not reach the player');
    }
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'forfeit',
      forfeitedBy: 'player',
    );
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {
    updateReadyCalls++;
    if (failReadyUpdate) throw StateError('offline mock failure');
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    questionLoadCalls++;
    if (failQuestionLoad) throw StateError('question fetch failed');
    return super.loadRoomQuestions(room);
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    statusPollCount++;
    return room.status;
  }

  void emitStatus(RoomStatus status) => _statuses.add(status);

  Future<void> close() => _statuses.close();
}

class _RoomLauncher extends StatelessWidget {
  const _RoomLauncher({required this.repository, required this.room});

  final _RoomExitRepository repository;
  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('open-room'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  RoomScreen(repository: repository, initialRoom: room),
            ),
          ),
          child: const Text('Odayı aç'),
        ),
      ),
    );
  }
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Oda işlemleri abonelik iptali / soru yükleme Future'larından sonra
  // rotayı değiştirir; ikinci tur bu devamı ve yeni rota animasyonunu
  // deterministik olarak tamamlar.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openRoom(
  WidgetTester tester,
  _RoomExitRepository repository,
  GameRoom room,
) async {
  await tester.pumpWidget(
    testShell(
      child: _RoomLauncher(repository: repository, room: room),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-room')));
  // Guest lobisindeki canlı bekleme göstergesi sürekli kare üretir;
  // `pumpAndSettle` bu nedenle doğal olarak hiç tamamlanmaz.
  await _pumpRouteTransition(tester);
  expect(find.byType(RoomScreen), findsOneWidget);
}

void main() {
  testWidgets('online room stays open until server confirms leave', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    final pending = Completer<void>();
    repository.pendingLeave = pending;
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(repository.leaveCalls, 1);
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(find.text('Odadan ayrılıyor…'), findsOneWidget);

    pending.complete();
    await _pumpRouteTransition(tester);

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-room')), findsOneWidget);
  });

  testWidgets('failed online leave restores lobby and allows retry', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failNextLeave = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 1);
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(
      find.text('Odadan ayrılamadın. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    expect(repository.playerSubscriptionCount, 2);
    expect(repository.statusSubscriptionCount, 2);
    expect(find.byTooltip('Odadan ayrıl'), findsOneWidget);

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 2);
    expect(find.byType(RoomScreen), findsNothing);
  });

  // Askıda kalan bir `leave_room`, BAŞARISIZ olan bir `leave_room` gibi
  // davranmalı.
  //
  // Hata yolu zaten bitmiş: snackbar gösteriliyor, lobi geri geliyor, çıkış
  // düğmesi yeniden denenebiliyor (yukarıdaki test). Ama çağrı hata
  // vermeyip yalnız ASILI kalırsa — captive portal ya da kopmuş hücresel
  // bağlantıda soket dakikalarca sessiz durabilir — o yolun hiçbiri
  // çalışmaz: `_leaving` sonsuza dek true kalır ve ekran, geri düğmesi bile
  // olmayan çıplak bir spinner'a dönüşür.
  //
  // Bu diff çevrimiçi çağrıların neredeyse hepsine 15 sn'lik zaman aşımı
  // ekledi (`finishGame`, `loadRoomResult`, `loadRoomEndState`,
  // `loadRoomPlayers`, ödül mutabakatı); iki `leave_room` çağrısı atlanmış.
  testWidgets('asılı kalan online leave zaman aşımıyla lobiye döner', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    // Hiç tamamlanmayan çağrı: ne sonuç, ne hata.
    repository.pendingLeave = Completer<void>();
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await tester.pump();

    expect(repository.leaveCalls, 1);
    expect(find.text('Odadan ayrılıyor…'), findsOneWidget);

    // Zaman aşımı penceresinin ötesine geç.
    await tester.pump(const Duration(seconds: 20));
    await _pumpRouteTransition(tester);

    expect(
      find.text('Odadan ayrılıyor…'),
      findsNothing,
      reason: 'Asılı çağrı ekranı süresiz spinner hâlinde bırakmamalı',
    );
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(
      find.text('Odadan ayrılamadın. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    // Oyuncu yeniden deneyebilmeli: lobi izleme de geri gelmiş olmalı.
    expect(find.byTooltip('Odadan ayrıl'), findsOneWidget);
  });

  testWidgets('subscription cleanup failure does not block online leave', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failSubscriptionCancel = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 1);
    expect(find.byType(RoomScreen), findsNothing);
  });

  /// Kusur: "Hazırım" anahtarı iyimser (optimistic) güncelleniyordu ve
  /// `updateReady` sunucu hatasıyla düşerse anahtar hiç geri alınmıyordu —
  /// kullanıcı "hazır değilim" görürken sunucudaki satır hâlâ eski
  /// değerdeydi ve host'un `allPlayersReady` kontrolü sessizce yanılıyordu.
  /// Düzeltme: hata durumunda önceki değere dönülür ve bir snackbar
  /// gösterilir (bkz. `room_screen.dart` `_toggleReady`).
  testWidgets('ready toggle failure restores the previous value', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failReadyUpdate = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // Sunucu çağrısı burada gerçek bir gecikme içermediği (mock, senkron
    // fırlatır) için iyimser "kapalı" ara durumu ile geri alınmış hâl aynı
    // pump turunda birleşir; asıl doğrulanan şey SON durumun eski değere
    // (true) dönmüş olmasıdır — anahtar yanlış "hazır değilim" göstererek
    // takılı kalmaz.
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(
      find.text('Hazır durumun kaydedilemedi. Önceki durumuna döndürüldü.'),
      findsOneWidget,
    );
    expect(repository.updateReadyCalls, 1);
  });

  testWidgets('local room keeps best-effort ready reset and exits safely', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failReadyUpdate = true;
    addTearDown(repository.close);
    final localRoom = GameRoom(
      name: 'Yerel oda',
      code: 'ZK-LOCAL',
      category: 'Ziman',
      players: repository.onlineLobby().players,
      status: RoomStatus.lobby,
      questionCount: 10,
      hostId: 'guest-user',
    );
    await _openRoom(tester, repository, localRoom);

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 0);
    expect(repository.updateReadyCalls, 1);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('disposing a room does not write an unreliable ready state', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await _pumpRouteTransition(tester);

    expect(repository.updateReadyCalls, 0);
  });

  testWidgets('finished lobby returns guest once with a clear message', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    repository.emitStatus(RoomStatus.finished);
    repository.emitStatus(RoomStatus.finished);
    await _pumpRouteTransition(tester);

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-room')), findsOneWidget);
    expect(find.text('Ev sahibi ayrıldığı için oda kapandı.'), findsOneWidget);
    expect(repository.leaveCalls, 0);
  });

  testWidgets('finished status is ignored after quiz navigation starts', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    repository.emitStatus(RoomStatus.active);
    repository.emitStatus(RoomStatus.finished);
    await _pumpRouteTransition(tester);

    // QuizScreen terminal olayı kendi akışında sonuç rotasına
    // çevirebilir. RoomScreen'in yapmaması gereken şey lobi mesajıyla
    // launcher'a geri atmaktır.
    expect(find.byKey(const ValueKey('open-room')), findsNothing);
    expect(find.text('Ev sahibi ayrıldığı için oda kapandı.'), findsNothing);
  });

  testWidgets('question load failure resumes lobby status monitoring', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failQuestionLoad = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    repository.emitStatus(RoomStatus.active);
    await _pumpRouteTransition(tester);

    expect(find.byType(QuizScreen), findsNothing);
    expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
    expect(repository.statusSubscriptionCount, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(repository.statusPollCount, greaterThan(0));
  });

  /// Kusur: soru yükleme sürekli başarısız olan bir oda, host'u 3 saniyede
  /// bir aynı hatayı sessizce tekrarlayan bir döngüye sokuyordu.
  ///
  /// `_navigateToQuiz` başarısız olunca `_resumeLobbyMonitoring()`ı
  /// çağırıyordu; bu da durum yoklamasını yeniden açıyordu, yoklama da
  /// sunucuda oda hâlâ `active` olduğu için `_navigateToQuiz`ı HEMEN yeniden
  /// tetikliyordu — sınır yoktu. Düzeltme `_questionLoadAttempts` sayacı ve
  /// `_maxQuestionLoadAttempts` (3) sınırıyla döngüyü keser; sınır aşılınca
  /// ekranda görünür bir hata + "Tekrar dene" düğmesi belirir ve otomatik
  /// tetikleme durur (bkz. `room_screen.dart` `_questionLoadExhausted`).
  testWidgets(
    'question load failures stop retrying after a cap and offer manual retry',
    (tester) async {
      // Başarılı yeniden deneme `loadRoomQuestions` → `SeenQuestionStore`
      // üzerinden `SharedPreferences`e ulaşır; mock değerler olmadan bu
      // çağrı testte hiç tamamlanmaz (ne hata ne sonuç — sessizce asılı
      // kalır) ve QuizScreen'e asla geçilmez.
      SharedPreferences.setMockInitialValues({});
      final repository = _RoomExitRepository()..failQuestionLoad = true;
      addTearDown(repository.close);
      await _openRoom(tester, repository, repository.onlineLobby());

      repository.emitStatus(RoomStatus.active);
      await _pumpRouteTransition(tester);
      expect(repository.questionLoadCalls, 1);

      // Yoklama her 3 saniyede sunucudaki 'active' durumunu tekrar görür.
      // Sınır olmasaydı bu döngü `questionLoadCalls`ı sınırsız artırırdı.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
      }

      // Sınıra ulaşana kadar tam üç deneme yapıldı, dördüncüsü yok — asıl
      // kusur (döngünün SINIRSIZ olması) burada kanıtlanıyor. Ekrandaki
      // geçici SnackBar'ın hangi anda göründüğü animasyona bağlıdır ve bu
      // testin konusu değil; kalıcı gösterge aşağıda doğrulanıyor.
      expect(repository.questionLoadCalls, 3);
      expect(
        find.textContaining('Sorular yüklenemedi'),
        findsOneWidget,
      );

      // Sınıra ulaşınca da "Odadan ayrıl" hâlâ çalışır — kullanıcı kilitli
      // kalmaz.
      expect(find.byTooltip('Odadan ayrıl'), findsOneWidget);

      // Elle "Tekrar dene" sayaçları sıfırlar ve sunucu artık cevap
      // verdiğinde yarış normal şekilde açılır.
      repository.failQuestionLoad = false;
      await tester.ensureVisible(find.text('Tekrar dene'));
      await tester.pump();
      await tester.tap(find.text('Tekrar dene'));
      await _pumpRouteTransition(tester);

      expect(find.byType(QuizScreen), findsOneWidget);
    },
  );
}
