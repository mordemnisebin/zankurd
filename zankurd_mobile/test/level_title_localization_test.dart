import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';

import 'support/widget_test_helpers.dart';

/// Kategori KİMLİĞİ hiçbir ekranda kullanıcıya gösterilmez.
///
/// ## Kusur
///
/// Seviye ekranı quiz odasının adını `'${level.category} 1. Seviye'` diye
/// kuruyordu. `level.category` bir kimliktir ve kimlikler Kurmancî kökenli
/// yazılmıştır ('Ziman', 'Çand', 'Dîrok', 'Cografya'). Sonuç: Türkçe
/// arayüzde soru ekranının başlığı **"Ziman 1. Seviye"**, aynı ekranın
/// kategori çipi ise **"Dil"** diyordu — tek ekranda aynı kategori iki adla
/// (2026-08-16 simülatör taraması, iPhone 17).
///
/// ## Niçin sessiz kaldı
///
/// `CategoryNames.localized` projede her yerde doğru kullanılıyor; yalnız bu
/// tek çağrı atlanmıştı. Dil testleri çeviri TABLOSUNU denetliyor, tabloyu
/// hiç kullanmayan bir dizgi birleştirmesini göremez. Ekran turu da seviye
/// akışını quiz'e kadar sürmüyordu.
void main() {
  testWidgets('Türkçe arayüzde seviye başlığı kategori kimliğini göstermez', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: LevelScreen(
          repository: freshMockRepository(),
          category: 'Ziman',
        ),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    // Ekranda görünen bütün metinleri topla.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((value) => value.isNotEmpty)
        .toList();

    // Türkçe karşılığı kimliğinden FARKLI olan kategoriler; 'Edebiyat',
    // 'Siyaset' gibi aynı yazılanlar bu kuralı ölçemez.
    const identifiersWithDistinctTurkishName = [
      'Ziman',
      'Çand',
      'Dîrok',
      'Cografya',
      'Muzîk',
      'Sînema',
      'Teknolojî',
    ];

    final offenders = <String>[];
    for (final text in texts) {
      for (final identifier in identifiersWithDistinctTurkishName) {
        if (text.contains(identifier)) offenders.add('"$text" ← $identifier');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Türkçe arayüzde kategori kimliği görünüyor; '
          'CategoryNames.localized kullanılmalı:\n${offenders.join('\n')}',
    );
  });

  test('Kurmancî kimliklerin Türkçe adı kimlikten farklıdır', () {
    const expected = {
      'Ziman': 'Dil',
      'Çand': 'Kültür',
      'Dîrok': 'Tarih',
      'Cografya': 'Coğrafya',
      'Muzîk': 'Müzik',
      'Sînema': 'Sinema',
      'Teknolojî': 'Teknoloji',
    };

    expected.forEach((identifier, turkish) {
      expect(
        CategoryNames.localized(identifier, false),
        turkish,
        reason: '$identifier Türkçede "$turkish" olmalı',
      );
      // Kurmancî tarafta da kimlik değil, GÖSTERİM adı kullanılır:
      // 'Cografya' kimliğinin Kurmancî adı 'Erdnîgarî'dir. Yani düzeltilen
      // dizgi birleştirmesi yalnız Türkçeyi değil Kurmancî'yi de bozuyordu.
      expect(CategoryNames.localized(identifier, true), isNotEmpty);
    });
  });
}
