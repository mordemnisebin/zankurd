import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/brand_icons.dart';
import 'package:zankurd_mobile/src/utils/bundled_font_licenses.dart';

/// Marka glifleri (Google, Apple) uygulamanın KENDİ yazı tipinden gelir.
///
/// ## Kusur ve niçin sessizdi
///
/// `font_awesome_flutter` paketi Solid + Regular + Brands (~718 KB) yazı tipi
/// taşıyordu; uygulama yalnız Brands'ten Google (0xf1a0) ve Apple (0xf179)
/// glifini kullanıyordu (ölü `AppIcons.starSolid` da Solid'i canlı
/// tutuyordu). Flutter bir bağımlılığın bildirdiği her yazı tipini pakete
/// koyar; hiçbir ekran bozuk görünmediği için kimse fark etmedi.
///
/// Yazı tipini `assets/fonts/` altına almak, "ikon kare çizilir" riskini
/// getirir: kod noktası yazı tipinde yoksa ya da aile adı pubspec ile
/// koddaki `fontFamily` arasında ayrışırsa Flutter sessizce boş kutu çizer.
/// Lisans da paketle birlikte gidebilir: Font Awesome atıf ister (ikonlar
/// CC BY 4.0, yazı tipi SIL OFL 1.1) ve metin lisans sayfasına kayıtlı olmalı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pubspec Brands ailesini kendi dosyasından bildirir, paket yok', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains(
        RegExp(
          r'- family: FontAwesomeBrands\s+fonts:\s+- asset: '
          r'assets/fonts/Font-Awesome-7-Brands-Regular-400\.otf',
        ),
      ),
    );
    expect(pubspec, isNot(contains('font_awesome_flutter:')));
    expect(
      File('assets/fonts/Font-Awesome-7-Brands-Regular-400.otf').existsSync(),
      isTrue,
    );
  });

  test('BrandIcons paket önekli aileye atıf yapmaz', () {
    for (final icon in [BrandIcons.google, BrandIcons.apple]) {
      expect(icon.fontFamily, 'FontAwesomeBrands');
      expect(
        icon.fontPackage,
        isNull,
        reason:
            '`fontPackage` verilirse Flutter ailesi `packages/..` diye arar; '
            'paket artık yok, glif kare çizilir.',
      );
    }
  });

  test('Google ve Apple kod noktaları Brands yazı tipinin cmap tablosunda', () {
    final glyphs = _cmapCodePoints(
      File('assets/fonts/Font-Awesome-7-Brands-Regular-400.otf'),
    );
    expect(glyphs.length, greaterThan(400), reason: 'cmap ayrıştırılamadı');
    expect(glyphs, contains(0xf1a0), reason: 'Google glifi yok');
    expect(glyphs, contains(0xf179), reason: 'Apple glifi yok');
    expect(BrandIcons.google.codePoint, 0xf1a0);
    expect(BrandIcons.apple.codePoint, 0xf179);
  });

  test('Font Awesome lisansı yazı tipiyle birlikte durur ve kayıtlıdır', () {
    final license = File('assets/fonts/LICENSE-FontAwesome.txt');
    expect(license.existsSync(), isTrue);
    final text = license.readAsStringSync();
    expect(text, contains('CC BY 4.0'));
    expect(text, contains('SIL OPEN FONT LICENSE'));
    expect(
      bundledFontLicenses.map((l) => l.asset),
      contains('assets/fonts/LICENSE-FontAwesome.txt'),
    );
    // Lisans sayfasına koddan gerçekten düşer (rootBundle'dan okunabilir).
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final license in bundledFontLicenses) {
      expect(pubspec, contains(license.asset), reason: license.asset);
    }
  });

  testWidgets('registerBundledFontLicenses lisansı LicenseRegistry e ekler', (
    tester,
  ) async {
    registerBundledFontLicenses();
    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }
    expect(packages, contains('Font Awesome Free (Brands)'));
  });
}

/// TrueType `cmap` tablosundaki (biçim 4 ve 12) bütün kod noktaları.
Set<int> _cmapCodePoints(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  final tableCount = data.getUint16(4);
  int? cmapOffset;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmapOffset = data.getUint32(record + 8);
  }
  if (cmapOffset == null) throw StateError('cmap tablosu yok');
  final result = <int>{};
  final subtableCount = data.getUint16(cmapOffset + 2);
  for (var i = 0; i < subtableCount; i++) {
    final sub = cmapOffset + data.getUint32(cmapOffset + 4 + i * 8 + 4);
    final format = data.getUint16(sub);
    if (format == 4) {
      final segCount = data.getUint16(sub + 6) ~/ 2;
      final endBase = sub + 14;
      final startBase = endBase + segCount * 2 + 2;
      for (var s = 0; s < segCount; s++) {
        final end = data.getUint16(endBase + s * 2);
        final start = data.getUint16(startBase + s * 2);
        if (start == 0xFFFF) continue;
        for (var c = start; c <= end; c++) {
          result.add(c);
        }
      }
    } else if (format == 12) {
      final groups = data.getUint32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final base = sub + 16 + g * 12;
        final start = data.getUint32(base);
        final end = data.getUint32(base + 4);
        for (var c = start; c <= end; c++) {
          result.add(c);
        }
      }
    }
  }
  return result;
}
