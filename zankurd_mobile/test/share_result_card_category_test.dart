import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
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

  testWidgets('Kurmancî modda kategori kimliği kendi ekran etiketiyle gösterilir', (
    tester,
  ) async {
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
  });
}
