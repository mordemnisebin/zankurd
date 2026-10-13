import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uygulamanın KENDİ varlığı olarak taşıdığı ikon yazı tiplerinin lisanslarını
/// Flutter'ın lisans sayfasına (`showLicensePage`) kaydeder.
///
/// ## Kusur
///
/// Font Awesome ve Lucide eskiden pub paketiydi (`font_awesome_flutter`,
/// `lucide_icons_flutter`); Flutter paket lisanslarını lisans sayfasına
/// kendisi toplar. Yazı tipleri `assets/fonts/` altına alınıp paketler
/// kaldırılınca lisans metinleri dosya olarak kaldı ama sayfadan düştü.
/// Font Awesome ikonları CC BY 4.0 ve yazı tipi SIL OFL 1.1 altındadır; ikisi
/// de atıf ve lisansın dağıtımla birlikte bulunmasını şart koşar.
///
/// ## Niçin sessizdi
///
/// Ekranlar doğru çiziliyordu, hiçbir test lisans sayfasının içeriğine
/// bakmıyordu ve eksiklik yalnız lisans sayfasını açan biri için görünürdü.
void registerBundledFontLicenses() {
  for (final font in bundledFontLicenses) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        font.package,
      ], await rootBundle.loadString(font.asset));
    });
  }
}

/// (lisans sayfasında görünen ad, lisans metninin varlık yolu).
@visibleForTesting
const List<({String package, String asset})> bundledFontLicenses = [
  (
    package: 'Font Awesome Free (Brands)',
    asset: 'assets/fonts/LICENSE-FontAwesome.txt',
  ),
  (package: 'Lucide', asset: 'assets/fonts/LICENSE-Lucide.txt'),
];
