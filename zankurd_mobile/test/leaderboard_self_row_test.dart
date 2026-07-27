import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

/// Hiç oynamamış oyuncuya başkasının sırası "senin sıran" diye gösterilmez.
///
/// 2026-07-27, simülatörde: yeni bir misafir hesapla sıralamayı açınca
/// listenin altına sabitlenen "kendi satırın" şunu diyordu —
/// **"ZanKurd Champion · 1. · 5000 puan · 50 oda · 25 seri"**. Aynı
/// oturumda profil "Ast 1 · 0/1000 XP" gösteriyordu; iki ekran birbirini
/// yalanlıyordu.
///
/// Sebep gösterimde değil kaynaktaydı: çevrimdışı depo "benim
/// istatistiğim" sorusuna demo tablosunun birincisini döndürüyordu. Profil
/// ekranı bunu 2026-07-25'te kendi içinde bir kapıyla örtmüştü
/// (`_hasServerScore`), yani kusur biliniyordu ama yalnız bir ekranda
/// bastırılmıştı — sıralamada öyle bir kapı yoktu ve yalan olduğu gibi
/// göründü.
///
/// Bekçi kaynağa bakar: örtülen yerde değil, çıktığı yerde.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('çevrimdışı depo başkasının satırını "benim" diye vermez', () async {
    final stats = await MockZanKurdRepository().getPlayerStats();
    expect(
      stats,
      isNull,
      reason: 'hiç oynamamış oyuncuya sunucu satırı uyduruldu',
    );
  });

  testWidgets('sıralamada sabitlenen kendi satırı çizilmez', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: LeaderboardScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('ZanKurd Champion'),
      findsNothing,
      reason: 'demo şampiyon oyuncunun kendi satırı gibi gösterildi',
    );
  });
}
