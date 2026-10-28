/// Sırayla düello: çıkış diyaloğu açıkken soru sayacı DURUR.
///
/// ## Kusur
///
/// "Yarıştan çık?" diyaloğu açıkken geri sayım akmaya devam ediyordu
/// (simülatör karesi: 19 → 7). Oyuncu "çık mı, kalayım mı?" diye düşünürken
/// sorunun süresi yanıyor, "Devam et" dediğinde soru zaten bitmiş oluyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Diyalog sayaçtan bağımsız bir rota; hiçbir test diyalog açıkken saati
/// ilerletip sayacı okumuyordu. Bu bekçi diyalog açıkken 6 sn pompalar:
/// kalan saniye değişmemeli; "Devam et"ten sonra kaldığı yerden akmalı.
///
/// ## 2026-10-29 (Codex denetimi, hata #7): sunucu saati durmuyor
///
/// Süreyi sunucu sunum anından ölçer ve diyalog sırasında akar. Yalnız
/// görsel sayaç duruyor, kronometre de duruyordu: dönüşte ekranda süre
/// varmış gibi görünüp sunucuda 25 sn'yi aşmış doğru cevap YANLIŞ
/// sayılıyordu. Artık kronometre akar; dönüşte sayaç duvar saatine eşitlenir
/// (ikinci testi bkz.).
library;

import 'support/play_hub_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Yanıt vermeyen ağ: her cevap çağrısı sonsuza dek asılı kalır.
class _HangingAnswersRepository extends MockZanKurdRepository {
  int calls = 0;

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) {
    calls++;
    return Completer<AsyncDuelAnswer>().future;
  }
}

int _secondsLeft(WidgetTester tester) =>
    tester.widget<SahneStageTimer>(find.byType(SahneStageTimer)).secondsLeft;

void main() {
  testWidgets('çıkış diyaloğu açıkken sayaç durur, devamda sürer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
      ),
    );
    await tester.pumpAndSettle();
    await openAsyncOpponentSheet(tester);
    await tester.tap(find.byKey(const ValueKey('opponent-sheet-random')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Düellodan çıkılsın mı?'), findsOneWidget);

    final frozen = _secondsLeft(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(
      _secondsLeft(tester),
      frozen,
      reason: 'diyalog açıkken süre akmamalı',
    );

    await tester.tap(find.text('Devam et'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final resumedAt = _secondsLeft(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(
      _secondsLeft(tester),
      lessThan(resumedAt),
      reason: 'diyalog kapanınca sayaç kaldığı yerden sürmeli',
    );
    // Sayaç sıfıra inip TIMEOUT tetiklemesin.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'çıkış gönderimleri paralel ve süre sınırlı: ağ asılsa da ekran kapanır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saved = asyncDuelQuitSendTimeout;
      asyncDuelQuitSendTimeout = const Duration(seconds: 2);
      addTearDown(() => asyncDuelQuitSendTimeout = saved);
      final repository = _HangingAnswersRepository();

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await openAsyncOpponentSheet(tester);
      await tester.tap(find.byKey(const ValueKey('opponent-sheet-random')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Çık'));
      await tester.pump();
      // Tüm kalan sorular aynı anda gönderilmiş olmalı (sırayla olsaydı 1).
      expect(repository.calls, greaterThan(1));
      // Süre sınırı dolunca ekran kapanır.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play-hub-async-duel')), findsOneWidget);
    },
  );

  testWidgets('diyalogda geçen gerçek süre dönüşte sayaca yansır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
      ),
    );
    await tester.pumpAndSettle();
    await openAsyncOpponentSheet(tester);
    await tester.tap(find.byKey(const ValueKey('opponent-sheet-random')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final frozen = _secondsLeft(tester);

    // Duvar saati (sunucu saatinin istemcideki karşılığı) 3 sn ilerler.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3200)),
    );
    await tester.tap(find.text('Devam et'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      _secondsLeft(tester),
      lessThanOrEqualTo(frozen - 3),
      reason: 'diyalogda akan sunucu süresi sayaca eklenmeli',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
