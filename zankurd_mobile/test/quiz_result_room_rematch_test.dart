import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

/// Özel oda sonucunda "Tekrar oyna" (2026-10-23).
///
/// ## Kusur
///
/// Özel oda bitince sonuç ekranında yalnız "Ana sayfa" vardı: aynı kişilerle
/// yeniden oynamak için oda kur, kodu yeniden paylaş, herkes yeniden gir —
/// 2.1.0'ın ilk gecesi dolu oynanan odalar bu yüzden tek maçta bitiyordu.
///
/// ## Niçin sessiz kalabilirdi
///
/// Düğme yoksa hata da yoktur; eksik bir eylem hiçbir testi kırmaz. Düğme
/// eklenirken de üç şey sessiz bozulabilirdi: (1) hızlı düello/rastgele
/// eşleşme odasında (sunucu reddeder) düğmenin çıkması, (2) düğmenin yanlış
/// oda kimliğiyle çağrılması, (3) çift basışın iki istek (iki lobi, iki
/// giriş ücreti) göndermesi.
///
/// ## Bekçi
///
/// (a) özel odada düğme görünür, basınca `createRoomRematch` o oda kimliğiyle
/// çağrılır ve yeni lobi `RoomScreen` olarak açılır; (b) özel olmayan odada
/// düğme yoktur, "Ana sayfa" birincil kalır; (c) süren istekte ikinci
/// dokunuş yeni çağrı üretmez.
class _RematchRepo extends MockZanKurdRepository {
  final calls = <String>[];
  Completer<GameRoom>? gate;

  @override
  Future<GameRoom> createRoomRematch(String roomId) {
    calls.add(roomId);
    final g = gate;
    if (g != null) return g.future;
    return super.createRoomRematch(roomId);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _RematchRepo repo, {
  required bool isCustom,
}) async {
  final room = repo.createRoom().copyWith(
    id: 'finished-room-1',
    status: RoomStatus.finished,
    isCustom: isCustom,
  );
  await tester.pumpWidget(
    testShell(
      child: QuizResultScreen(
        repository: repo,
        room: room,
        score: 100,
        correctCount: 10,
        wrongCount: 0,
        totalQuestions: 10,
        bestStreak: 10,
        answerRecords: const [],
        coinsAwarded: 0,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

_RematchRepo _repo() {
  freshMockRepository(); // ortak store sıfırlaması
  return _RematchRepo();
}

void main() {
  final rematch = find.byKey(const ValueKey('result-room-rematch-button'));

  testWidgets('özel oda: Tekrar oyna doğru oda kimliğiyle yeni lobiyi açar', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo, isCustom: true);

    expect(rematch, findsOneWidget);
    expect(
      find.descendant(of: rematch, matching: find.text('Tekrar oyna')),
      findsOneWidget,
    );
    // W2 (2026-10-28 tur 5): alt perde = tam genişlik "Tekrar oyna" + simge
    // olarak Paylaş; "Ana sayfa" "Diğer seçenekler"e indi.
    expect(find.byKey(const ValueKey('result-primary-home')), findsNothing);
    expect(find.byKey(const ValueKey('result-share-button')), findsOneWidget);
    // Özel odada ikinci bir "Yeni oda" yok: Tekrar oyna aynı işi görür.
    expect(find.byKey(const ValueKey('result-new-room-button')), findsNothing);

    await tester.tap(rematch);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.calls, ['finished-room-1']);
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  // Kurul 3 D9: rastgele 1v1 odada birincil eylem "Rakip bul" (Ana sayfa
  // "⋯" menüsünde).
  testWidgets('özel olmayan oda: Tekrar oyna yok, Rakip bul birincil', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo, isCustom: false);

    expect(rematch, findsNothing);
    expect(
      find.byKey(const ValueKey('result-primary-find-opponent')),
      findsOneWidget,
    );
    expect(repo.calls, isEmpty);
  });

  testWidgets('çift basış tek createRoomRematch çağrısı yapar', (tester) async {
    final repo = _repo()..gate = Completer<GameRoom>();
    await _pump(tester, repo, isCustom: true);

    await tester.tap(rematch);
    await tester.pump();
    await tester.tap(rematch, warnIfMissed: false);
    await tester.pump();

    expect(repo.calls, ['finished-room-1']);
    repo.gate!.complete(repo.createRoom().copyWith(id: 'next', isCustom: true));
    await tester.pump(const Duration(seconds: 1));
  });

  // 2026-10-23 simülatör: yeni lobiden geri çıkan, yığında kalan BİTMİŞ
  // odanın lobisine düşüyordu (orada "Başlat" bile etkindi). Yeni lobi
  // açılırken ana kabuğa kadar yığın temizlenir.
  testWidgets('Tekrar oyna sonrası geri, bitmiş odaya değil ana ekrana döner', (
    tester,
  ) async {
    final repo = _repo();
    final room = repo.createRoom().copyWith(
      id: 'finished-room-1',
      status: RoomStatus.finished,
      isCustom: true,
    );
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      testShell(
        child: Navigator(
          key: nav,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const Text('ana-kabuk')),
        ),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('bitmis-oda')),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => QuizResultScreen(
          repository: repo,
          room: room,
          score: 100,
          correctCount: 10,
          wrongCount: 0,
          totalQuestions: 10,
          bestStreak: 10,
          answerRecords: const [],
          coinsAwarded: 0,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(rematch);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RoomScreen), findsOneWidget);

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('bitmis-oda'), findsNothing);
    expect(find.text('ana-kabuk'), findsOneWidget);
  });
}
