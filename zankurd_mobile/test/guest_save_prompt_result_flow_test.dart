/// Misafir "hesabını kaydet" sayfasının GERÇEK sonuç ekranından görünmesi.
///
/// ## Kusur
///
/// 2.1.1+37 simülatör turunda taze bir misafir dört oyun bitirdi (ilk oturum
/// alıştırması, Günün turu, solo, Kurmancî solo) ve sayfa hiç çıkmadı. Sayaç
/// ve sayfa birim testleri yeşildi çünkü `GuestSavePrompt.afterGame`i doğrudan
/// çağırıyorlardı; sonuç ekranının onu gerçekten çağırıp çağırmadığını hiçbir
/// test sormuyordu.
///
/// Bu dosya taze bir misafirin üç oyunu sonuç ekranından bitirmesini kurar:
/// sayfa tam 3. oyunda, bir kez çıkmalıdır.
///
/// Tur 1 (I4, 2026-10-29): sayfa sonuç ekranı açılır açılmaz çıkıp skoru
/// örtüyordu (simülatör, TR + KU). Artık sonuç ekranı AÇIKKEN çıkmaz; oyuncu
/// sonuçtan ayrılınca döndüğü ekranın üstünde açılır. Testler iki şeyi de
/// sorar: sonuç açıkken sayfa yok, ayrılınca var.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

const _solo = GameRoom(
  name: 'solo',
  code: 'SOLO',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
  questionCount: 1,
);

/// Bir oyunu bitirir: ana sayfadan sonuç ekranı açılır, [checkOnResult]
/// sonuç ekranı açıkken çağrılır, sonra oyuncu sonuçtan ayrılır.
Future<void> _finishGame(
  WidgetTester tester, {
  bool practice = false,
  bool dailyQuiz = false,
  void Function()? checkOnResult,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final auth = AuthProvider.offline();
  await auth.signInAsGuest();
  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    testShell(
      authProvider: auth,
      child: Navigator(
        key: navKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('ana-sayfa')),
        ),
      ),
    ),
  );
  navKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => QuizResultScreen(
        repository: MockZanKurdRepository(),
        room: _solo,
        score: 60,
        correctCount: 1,
        wrongCount: 0,
        totalQuestions: 1,
        bestStreak: 1,
        answerRecords: const [],
        coinsAwarded: 0,
        practice: practice,
        dailyQuiz: dailyQuiz,
      ),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Sonuç ekranı açıkken öneri sayfası ASLA yok (skoru örtmez).
  expect(
    find.text(_title),
    findsNothing,
    reason: 'sayfa sonuç ekranını örtüyor',
  );
  checkOnResult?.call();
  navKey.currentState!.pop();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _title = 'İlerlemeni kaybetme — hesabını kaydet';

void main() {
  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
    DailyMissionStore.resetInstance();
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    StreakStore.resetInstance();
    XPStore.resetInstance();
  });

  const title = _title;

  testWidgets(
    'taze misafir: sayfa tam 3. oyundan sonra, sonuçtan ayrılınca çıkar',
    (tester) async {
      await _finishGame(tester, practice: true);
      expect(find.text(title), findsNothing, reason: '1. oyun');
      await _finishGame(tester, dailyQuiz: true);
      expect(find.text(title), findsNothing, reason: '2. oyun');
      await _finishGame(tester);
      expect(find.text(title), findsOneWidget, reason: '3. oyun');
      await tester.tap(find.text('Şimdi değil'));
      await tester.pumpAndSettle();
      await _finishGame(tester);
      expect(find.text(title), findsNothing, reason: '4. oyun: bekleme');
    },
  );

  testWidgets('seviye atlatan oyun da sayılır: sayfa yine 3. oyunda çıkar', (
    tester,
  ) async {
    // Seviye atlama kutusunun üstüne sayfa binmez; ama oyun sayaçtan
    // düşmemeli, yoksa öneri bir oyun geç gelir.
    await XPStore.loadForTest(950);
    await _finishGame(tester);
    expect(find.text(title), findsNothing, reason: '1. oyun (seviye atladı)');
    await _finishGame(tester);
    expect(find.text(title), findsNothing, reason: '2. oyun');
    await _finishGame(tester);
    expect(find.text(title), findsOneWidget, reason: '3. oyun');
  });
}
