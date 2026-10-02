import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_board.dart';
import 'package:zankurd_mobile/src/widgets/share_result_card.dart';

/// Paylaşım kartındaki kategori çipi.
///
/// `category` çağırandan (result_sharer.dart → `room.category`) Kurmancî
/// kimlik olarak gelir (bkz. `CategoryNames`, kimlik veri katmanının
/// sabitidir). Kart bunu `isKu` parametresini zaten taşırken hiç
/// çevirmeden basıyordu — Türkçe modda paylaşılan görselde "Ziman"
/// yazıyordu, kartı gören herkes (uygulama dışı) görüyordu (2026-08-14
/// denetimi). `CategoryNames.localized` diğer tüm kategori gösteren
/// ekranlarla aynı deseni kurar.
void main() {
  testWidgets('Türkçe modda kategori çevrilmiş gösterilir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ShareResultCard(
            isKu: false,
            score: 120,
            correctCount: 4,
            totalQuestions: 5,
            bestStreak: 3,
            category: 'Ziman',
          ),
        ),
      ),
    );

    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Ziman'), findsNothing);
  });

  testWidgets(
    'Kurmancî modda kategori kimliği kendi ekran etiketiyle gösterilir',
    (tester) async {
      // `CategoryNames._kuDisplay` bazı kimlikler için ayrı bir Kurmancî
      // ekran etiketi tutar (ör. "Cografya" → "Erdnîgarî"); kart bunu da
      // atlamamalı.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ShareResultCard(
              isKu: true,
              score: 120,
              correctCount: 4,
              totalQuestions: 5,
              bestStreak: 3,
              category: 'Cografya',
            ),
          ),
        ),
      );

      expect(find.text('Erdnîgarî'), findsOneWidget);
      expect(find.text('Cografya'), findsNothing);
    },
  );

  testWidgets('paylaşım kartı turun kilimini taşır', (tester) async {
    // Kart eskiden yalnız SAYI paylaşıyordu (puan, isabet, seri). Sayı
    // paylaşılabilir bir nesne değildir: her turun kartı aynı görünür ve
    // görene turla ilgili hiçbir şey söylemez. Şerit turun kendisidir ve
    // her turda başkadır — Wordle ızgarasının işlevi, kilim diliyle.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShareResultCard(
            isKu: false,
            score: 340,
            correctCount: 3,
            totalQuestions: 4,
            bestStreak: 2,
            category: 'Ziman',
            results: [true, false, true, true],
          ),
        ),
      ),
    );

    final board = tester.widget<KilimBoard>(find.byType(KilimBoard));
    expect(board.results, [true, false, true, true]);
    expect(
      board.showCurrent,
      isFalse,
      reason: 'tur bitti; "sıradaki soru" vurgusu yalan olurdu',
    );
  });

  testWidgets('sonuç listesi yoksa kart şeritsiz çizilir', (tester) async {
    // Varsayılan boş liste geriye dönük uyum içindir: `results` vermeyen
    // eski çağıranlar çökmemeli, yalnız şeritsiz kart üretmeli.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShareResultCard(
            isKu: false,
            score: 0,
            correctCount: 0,
            totalQuestions: 0,
            bestStreak: 0,
            category: 'Ziman',
          ),
        ),
      ),
    );

    expect(find.byType(KilimBoard), findsNothing);
  });
}
