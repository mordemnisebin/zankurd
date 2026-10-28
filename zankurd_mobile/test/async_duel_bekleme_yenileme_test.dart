/// Sırayla düello bekleme ekranı kendini yeniler bekçisi.
///
/// ## Kusur
///
/// Turunu bitiren oyuncu "Rakibin oynayınca sonuç burada görünecek." ekranında
/// kalıyordu; ekran durağandı. Rakip bitirdiği halde kum saati sürüyordu ve
/// sonuç ancak ekran kapatılıp gelen kutusu açılınca görünüyordu
/// (iki simülatörlü tur, 2026-10-27).
///
/// ## Niçin sessiz kalırdı
///
/// Bekleme görünümü yalnız `answerAsyncDuel`ın son cevabından kurulur;
/// testler ekranı tek pompalayıp metni okuyordu. Kimse "rakip bitirince ne
/// olur" diye zamanı ilerletmedi.
///
/// ## Kural
///
/// Bekleme ekranı açıkken düello listesine düzenli bakar; düello bitince
/// sonuç ekranına kendiliğinden geçer. Bitmediyse bekleme ekranı kalır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';

import 'support/widget_test_helpers.dart';

class _ListRepository extends MockZanKurdRepository {
  List<AsyncDuelSummary> duels = const [];
  int loads = 0;

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async {
    loads++;
    return duels;
  }
}

AsyncDuelSummary _summary({required bool done}) => AsyncDuelSummary(
  duelId: 'd1',
  status: done ? AsyncDuelStatus.completed : AsyncDuelStatus.open,
  role: AsyncDuelRole.creator,
  opponentName: 'Rojda',
  myCorrect: 2,
  opponentCorrect: done ? 1 : null,
  outcome: done ? AsyncDuelOutcome.win : null,
  createdAt: DateTime.utc(2026, 10, 27),
  seen: false,
);

AsyncDuelSummary _expired() => AsyncDuelSummary(
  duelId: 'd1',
  status: AsyncDuelStatus.expired,
  role: AsyncDuelRole.creator,
  myCorrect: 2,
  createdAt: DateTime.utc(2026, 10, 27),
  seen: false,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
  });

  testWidgets('rakip bitirince bekleme ekranı sonuca geçer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _ListRepository()..duels = [_summary(done: false)];
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelResultScreen(
          repository: repo,
          view: AsyncDuelResultView.fromSummary(_summary(done: false)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Rakibin oynayınca sonuç burada görünecek.'), findsOne);

    // Rakip henüz bitirmedi: bir tık sonra ekran yerinde kalır.
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(repo.loads, greaterThanOrEqualTo(1));
    expect(find.text('Rakibin oynayınca sonuç burada görünecek.'), findsOne);

    // Rakip bitirdi: sonraki tıkta sonuç ekranı gelir.
    repo.duels = [_summary(done: true)];
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(
      find.text('Rakibin oynayınca sonuç burada görünecek.'),
      findsNothing,
    );
    expect(find.textContaining('Kazandın'), findsWidgets);
  });

  testWidgets('rakip hiç oynamadan süre dolunca da bekleme biter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _ListRepository()..duels = [_summary(done: false)];
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelResultScreen(
          repository: repo,
          view: AsyncDuelResultView.fromSummary(_summary(done: false)),
        ),
      ),
    );
    await tester.pump();
    repo.duels = [_expired()];
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(
      find.text('Rakibin oynayınca sonuç burada görünecek.'),
      findsNothing,
    );
  });
}
