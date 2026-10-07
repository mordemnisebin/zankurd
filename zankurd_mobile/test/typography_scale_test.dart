import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

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
    //
    // Şahnê (2026-09-29): beş boyut, her birinin tek satır yüksekliği
    // (64/64 · 28/32 · 22/28 · 16/24 · 14/20). Eski yedi ad bu beş boyuta
    // eşlendi; iki ad aynı boyuta düşebilir (display = heading1), ama hiçbir
    // ad ölçeğin dışında bir boyut taşıyamaz.
    final scale = [
      SahneType.screen,
      SahneType.title,
      SahneType.headline,
      SahneType.body,
      SahneType.caption,
    ].map((s) => s.fontSize!).toList();
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], lessThan(scale[i - 1]), reason: 'basamaklar: $scale');
    }

    final legacy = <String, double>{
      'display': AppTypography.display.fontSize!,
      'heading1': AppTypography.heading1.fontSize!,
      'heading2': AppTypography.heading2.fontSize!,
      'subtitle': AppTypography.subtitle.fontSize!,
      'bodyLarge': AppTypography.bodyLarge.fontSize!,
      'bodyMedium': AppTypography.bodyMedium.fontSize!,
      'caption': AppTypography.caption.fontSize!,
      'quizQuestion': AppTypography.quizQuestion.fontSize!,
      'quizAnswer': AppTypography.quizAnswer.fontSize!,
    };
    for (final entry in legacy.entries) {
      expect(scale, contains(entry.value), reason: '${entry.key} ölçek dışı');
    }

    // Her basamak okunabilir alt sınırın üstünde; açıklama bile 14.
    expect(scale.last, greaterThanOrEqualTo(14));
  });

  // 2026-09-29 doğallık (K8): ağırlık hiyerarşisi. 800 yalnız sekme
  // başlığında (title), soru metninde (title) ve skorda (screen). Her başlık
  // ve düğme 800 olunca sayfada hiyerarşi kalmıyordu. Karar bölüm başlığı
  // için 20/700 diyordu; 20 beş boyutlu ölçeğin dışında kaldığı için boyut
  // değil ağırlık düştü: bölüm/kart başlığı Manşet 22/700. Ölçek beş boyut
  // kalır (yukarıdaki bekçi).
  test('ağırlık hiyerarşisi: 800 yalnız başlık, soru ve skorda', () {
    expect(SahneType.screen.fontWeight, FontWeight.w800);
    expect(SahneType.title.fontWeight, FontWeight.w800);
    expect(SahneType.headline.fontWeight, FontWeight.w700);
    expect(SahneType.headline.fontSize, 22);
    expect(SahneType.button.fontWeight, FontWeight.w700);
    expect(SahneType.captionStrong.fontWeight, FontWeight.w700);
    // Büyük harfli künye yalnız soru ekranının üst satırı içindir; bileşen
    // olarak kalır.
    expect(SahneType.eyebrow.fontSize, SahneType.caption.fontSize);
  });

  test('yazı tipi ailesi tek yerden geliyor', () {
    // `CustomPainter` içinde çizilen metin temadan aile almaz; aile
    // yazılmazsa sistem varsayılanına düşer ve tek ekranda iki font
    // görünür (2026-07-26 kusuru).
    expect(AppTypography.fontFamily, SahneType.text);
    expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily, SahneType.text);
  });
}
