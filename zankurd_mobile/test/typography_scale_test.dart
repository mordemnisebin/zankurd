import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Tipografi ölçeğinin bekçisi.
///
/// ## Kusur
///
/// `AppTypography` düzgün bir ölçek tanımlıyor — display, heading1,
/// heading2, subtitle, bodyLarge, bodyMedium, caption, quizQuestion,
/// quizAnswer — ama çağrı yerleri onu büyük ölçüde atlıyor: 2026-07-31
/// denetiminde `lib/src` içinde 233 elle yazılmış `fontSize` ve 22 farklı
/// değer sayıldı (10, 10.5, 11, 12, 12.5, 13, 13.5, …).
///
/// Sonuç, ekranlar arası boyut kayması: aynı görevdeki iki etiket bir
/// ekranda 12, ötekinde 13 px oluyor. Ölçekten sapan her değer, ölçeğin
/// kendisini biraz daha anlamsızlaştırıyor.
///
/// ## Niçin toplu değişiklik yapılmadı
///
/// 233 çağrı yerini elle ölçeğe çekmek, her birinin görsel boyutunu
/// değiştirmek demektir — düzinelerce yerleşim testini ve gözle
/// doğrulanmış ekranı riske atar. Bunun yerine l10n göçündeki desen
/// kullanılıyor: sayı bir tavana sabitlenir ve YALNIZ AZALABİLİR. Yeni
/// kod ölçeği kullanmak zorunda; eski kod ekran ekran göç eder.
void main() {
  /// Elle yazılmış `fontSize` sayısı. Bu sayı YALNIZ AZALTILABİLİR.
  ///
  /// Geçmiş: 248 (2026-07-31 ilk ölçüm) → 233 (mağaza kataloğu
  /// temizliği ve çocuk modunun kaldırılmasıyla).
  ///
  /// En yoğun dosyalar: quiz_result_screen (21), app_theme (19 — ölçeğin
  /// KENDİ tanımı, meşru), profile_widgets (17), matchmaking_screen (16).
  const inlineFontSizeCeiling = 233;

  test('elle yazılmış fontSize sayısı tavanı aşmıyor', () {
    final pattern = RegExp(r'fontSize: [0-9.]+');
    var count = 0;
    final perFile = <String, int>{};

    for (final entity in Directory('lib/src').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final hits = pattern.allMatches(entity.readAsStringSync()).length;
      if (hits > 0) {
        perFile[entity.path] = hits;
        count += hits;
      }
    }

    final worst = perFile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    expect(
      count,
      lessThanOrEqualTo(inlineFontSizeCeiling),
      reason:
          'Elle fontSize kullanımı arttı ($count > $inlineFontSizeCeiling).\n'
          'Yeni metinler için AppTypography ölçeğini kullanın '
          '(display / heading1 / heading2 / subtitle / bodyLarge / '
          'bodyMedium / caption).\n'
          'En yoğun dosyalar: '
          '${worst.take(5).map((e) => "${e.key}: ${e.value}").join(", ")}',
    );
  });

  test('ölçek gerçekten tanımlı ve tutarlı', () {
    // Ölçek kendisi bozulursa göç etmenin anlamı kalmaz.
    final steps = <String, double>{
      'display': AppTypography.display.fontSize!,
      'heading1': AppTypography.heading1.fontSize!,
      'heading2': AppTypography.heading2.fontSize!,
      'bodyLarge': AppTypography.bodyLarge.fontSize!,
      'bodyMedium': AppTypography.bodyMedium.fontSize!,
      'caption': AppTypography.caption.fontSize!,
    };

    // Basamaklar büyükten küçüğe kesin azalmalı; eşit iki basamak
    // ölçeğin bir adımını anlamsız kılar.
    final ordered = steps.values.toList();
    for (var i = 1; i < ordered.length; i++) {
      expect(
        ordered[i],
        lessThan(ordered[i - 1]),
        reason: 'Ölçek basamakları kesin azalmalı: $steps',
      );
    }

    // Her basamak okunabilir alt sınırın üstünde.
    for (final entry in steps.entries) {
      expect(
        entry.value,
        greaterThanOrEqualTo(11),
        reason: '${entry.key} 11 px altında — %200 ölçekte bile küçük kalır.',
      );
    }
  });

  test('yazı tipi ailesi tek yerden geliyor', () {
    // `CustomPainter` içinde çizilen metin temadan aile almaz; aile
    // yazılmazsa sistem varsayılanına düşer ve tek ekranda iki font
    // görünür (2026-07-26 kusuru).
    expect(AppTypography.fontFamily, 'Rubik');
  });
}
