import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Lucide ikon yazı tipi uygulamanın KENDİ varlığıdır; paket değil.
///
/// ## Kusur ve niçin sessizdi
///
/// `lucide_icons_flutter` paketi, kullandığımız statik `Lucide` ailesinin
/// yanında 6 değişken ağırlıklı yazı tipini (`Lucide100`…`Lucide600`,
/// toplam 2,86 MB) de `pubspec`inde bildirir. Flutter bir bağımlılığın
/// bildirdiği her yazı tipini pakete koyar; release derlemedeki ikon
/// budaması yalnız kodda GEÇEN glifleri küçültür, hiç geçmeyen aileye
/// dokunmaz. `flutter build ios --analyze-size` (2026-10-02):
/// `packages/lucide_icons_flutter` 2,9 MB, uygulama yalnız 43 KB'lık
/// budanmış `lucide.ttf`yi kullanıyordu. Hiçbir ekran bozuk görünmediği
/// için kimse fark etmedi.
///
/// ## Bu dosya neyi korur
///
/// Yazı tipini `assets/fonts/Lucide.ttf` olarak taşımak, "ikon kare çizilir"
/// riskini getirir (kod noktası yazı tipinde yoksa Flutter sessizce boş
/// kutu çizer). Bu yüzden her `AppIcons` kod noktası yazı tipinin `cmap`
/// tablosunda aranır.
void main() {
  test('pubspec Lucide ailesini kendi dosyasından bildirir', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains(
        RegExp(
          r'- family: Lucide\s+fonts:\s+- asset: assets/fonts/Lucide\.ttf',
        ),
      ),
    );
    expect(File('assets/fonts/Lucide.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/LICENSE-Lucide.txt').existsSync(), isTrue);
  });

  test('AppIcons paket önekli Lucide ailesine atıf yapmaz', () {
    final source = File('lib/src/theme/app_icons.dart').readAsStringSync();
    expect(
      source,
      isNot(contains("fontPackage: 'lucide_icons_flutter'")),
      reason:
          '`fontPackage` verilirse Flutter ailesi `packages/'
          'lucide_icons_flutter/Lucide` diye arar; paket artık yok, ikonlar '
          'kare çizilir.',
    );
  });

  test('her AppIcons Lucide kod noktası yazı tipinde var', () {
    final source = File('lib/src/theme/app_icons.dart').readAsStringSync();
    final used = RegExp(
      r"IconData\(\s*0x([0-9a-fA-F]+),\s*fontFamily: 'Lucide',?\s*\)",
    ).allMatches(source).map((m) => int.parse(m[1]!, radix: 16)).toSet();
    expect(used.length, greaterThan(100), reason: 'AppIcons ayrıştırılamadı');

    final glyphs = _cmapCodePoints(File('assets/fonts/Lucide.ttf'));
    expect(glyphs.length, greaterThan(1000), reason: 'cmap ayrıştırılamadı');
    final missing = used.where((c) => !glyphs.contains(c)).toList()..sort();
    expect(
      missing.map((c) => 'U+${c.toRadixString(16)}').toList(),
      isEmpty,
      reason: 'Bu kod noktaları Lucide.ttf içinde yok: ikon kare çizilir.',
    );
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
