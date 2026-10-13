// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gezinme yüzeyleri marka paletinin dışına çıkmaz.
///
/// ## Kusur
///
/// `playPink` (#A85A7A) ve `playPurple` (#6B5AA6) 2026-07-23'te
/// `shop_screen.dart`taki M24 notuyla "marka dışı" ilan edildi: ZanKurd'ün
/// kimliği turuncu · altın · koyu yeşil. Mağaza o gün düzeltildi, eşleşme
/// ekranının hero'su 2026-07-31'de düzeltildi — ama kararın yazıldığı
/// ekranların *kendisi* atlandı. Oyun merkezinde "Oda kur" moru, "Turnuva
/// Modu" pembeyi taşımaya devam etti; ana ekranda tekrar satırı, ayarlar
/// başlığı ve soru öneri ekranı da öyle.
///
/// Sapma en çok oyun merkezinde görünüyordu çünkü dört satır alt alta
/// duruyor: mor, turkuaz, altın, pembe. Kod okumasıyla fark edilmesi zordu,
/// zira her satır tek başına "bir renk seçilmiş" gibi görünüyor; ancak
/// ekranın tamamına bakınca kimliğin dağıldığı anlaşılıyordu (2026-08-01,
/// iOS ve Android simülatörlerinde canlı bakış).
///
/// ## Bekçi niçin dosya bazlı
///
/// `playPink`/`playPurple` sabitleri silinmedi: çarkıfelek dilimleri,
/// joker türleri ve seviye rozetleri gibi *çok sayıda öğeyi birbirinden
/// ayırması gereken* yüzeylerde ayrık ton kümesi hâlâ gerekli, ve mağazada
/// açıklaması rengi ismen anan üç ürün var ("mor çerçeve"). Bu yüzden
/// kural rengin varlığına değil, hangi ekranda kullanıldığına bakar.
void main() {
  // Kullanıcının gezinirken sürekli gördüğü, kimliği taşıyan yüzeyler.
  const identityScreens = [
    'lib/src/screens/play_hub_screen.dart',
    'lib/src/screens/home_screen.dart',
    'lib/src/screens/settings_screen.dart',
    'lib/src/screens/suggest_question_screen.dart',
    'lib/src/screens/matchmaking_screen.dart',
  ];

  for (final path in identityScreens) {
    test('${path.split('/').last} marka dışı aksan taşımıyor', () {
      final source = File(path).readAsStringSync();
      // Yorum satırları kararın *niçin*ini anlatıyor; kural koda bakar.
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      for (final offBrand in ['AppTheme.playPink', 'AppTheme.playPurple']) {
        expect(
          code,
          isNot(contains(offBrand)),
          reason:
              '$path içinde $offBrand var. Kimlik yüzeyleri turuncu '
              '(brand), altın (gold), koyu yeşil (culturalBrandBg / '
              'playGreen) ve çamurlu turkuaz (playCyan) ile sınırlıdır.',
        );
      }
    });
  }

  test('oyun merkezi aksanları kart değil işlev rolü anlatır', () {
    // 2026-09-10 tasarım grameri: her kartı ayrı renge boyamak ekranı
    // gökkuşağına çeviriyordu. Ayrım artık renk + ikon + başlık birlikte
    // yapılır; renk ise semantik rolü taşır.
    //
    // 2026-09-29 Şahnê: roller ham renkle (`accent: AppTheme.*`) değil
    // `SahneRole` ile verilir. Kural aynı kalır, yeni diliyle: turuncu
    // (Agir) yalnız ekranın TEK birincil düğmesi (hızlı düello), oda ve
    // düello yolları Boyax (yarış), turnuva Zêr (prestij). Ekranda ham
    // aksan rengi kalmaz.
    final source = File(
      'lib/src/screens/play_hub_screen.dart',
    ).readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      RegExp(r'accent: AppTheme\.').allMatches(code),
      isEmpty,
      reason: 'Rol ham renkle değil SahneRole ile verilir.',
    );
    expect(
      'SahneButton.primary('.allMatches(code).length,
      1,
      reason: 'Agir/turuncu yalnız ekranın tek birincil eyleminde kalmalı.',
    );
    final roles = RegExp(
      r'role: SahneRole\.([a-z]+)',
    ).allMatches(code).map((m) => m.group(1)!).toList();
    expect(
      roles.where((r) => r == 'race').length,
      greaterThanOrEqualTo(3),
      reason: 'Oda kurma, kodla katılma ve düello aynı yarış rolüdür.',
    );
    expect(roles, contains('gold'), reason: 'Turnuva prestij (Zêr) rolüdür.');
    expect(
      roles.toSet().difference({'race', 'gold', 'learn', 'neutral'}),
      isEmpty,
    );
  });
}
