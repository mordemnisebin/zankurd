import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Şahnê tasarım sisteminin ekran bekçisi.
///
/// ## Kusur
///
/// 2026-09-28 ölçümünde uygulamada ortak bir görsel kural yoktu: sekiz
/// ekranda altı ayrı başlık biçimi, 14 köşe yarıçapı ve temanın dışında 68
/// ham renk. Her ekran kendi `Color(0x…)`sını, `BorderRadius.circular`ını ve
/// bulanık gölgesini yazıyordu; beyaz yazılı turuncu düğmeler (Agir üstünde
/// `Colors.white`, 2,3:1) dört ekranda ayrı ayrı elle kurulmuştu.
///
/// 2026-09-29'da altı ekran grubu Şahnê'ye taşındı: renk `SahneTokens`tan,
/// şekil `SahneShape`ten (pah), gölge yalnız birincil düğmede (bileşenin
/// içinde). Taşıma bittiğinde ekranlarda kalan istisnalar sayıldı ve
/// buraya sabitlendi.
///
/// ## Niçin tavan, niçin sıfır değil
///
/// Kalan birkaç istisna meşrudur: Google ve Apple giriş düğmelerinin
/// markalı renkleri (sağlayıcıların kendi kuralları, `sign_in_screen`),
/// profilde Google hesabı işareti. Sayı bu yüzden bugünkü değere sabitlenir
/// ve YALNIZ AZALABİLİR (`typography_scale_test`teki desen). Yeni bir ekran
/// ham renk, yuvarlak köşe ya da bulanık gölge yazamaz; gereken değer önce
/// `theme/sahne.dart`a ya da `widgets/sahne/` bileşenine eklenir.
///
/// Bileşen kütüphanesinin kendisi (`lib/src/widgets/sahne/`) ham renk
/// taşımaz: her renk belirteçtir (`SahneTokens`, `SahneStageColors`); tek
/// istisna saydamlık (`Colors.transparent`).
void main() {
  /// `lib/src/screens/` altında kalan istisnaların tavanı. Bu sayılar YALNIZ
  /// AZALTILABİLİR.
  ///
  /// 2026-09-29 (birleştirme): `Color(0x` 4 — üçü Google giriş düğmesinin
  /// markalı yüzey/kenar/mürekkebi, biri profildeki Google işareti.
  const ceilings = <String, int>{
    'Color(0x': 4,
    'BorderRadius.circular(': 0,
    'bulanık BoxShadow': 0,
    'Colors.white + Agir/marka dolgusu': 0,
    'LinearGradient(': 2,
  };

  final screens = <File>[
    for (final entity in Directory('lib/src/screens').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));

  for (final MapEntry(key: pattern, value: ceiling) in ceilings.entries) {
    test('ekranlarda "$pattern" sayısı tavanı ($ceiling) aşmıyor', () {
      final perFile = <String, int>{};
      for (final file in screens) {
        final hits = _count(pattern, _code(file.readAsStringSync()));
        if (hits > 0) perFile[file.path] = hits;
      }
      final total = perFile.values.fold(0, (a, b) => a + b);
      expect(
        total,
        lessThanOrEqualTo(ceiling),
        reason:
            '"$pattern" ekranlarda $total kez geçiyor (tavan $ceiling). '
            'Değeri `theme/sahne.dart` belirtecinden ya da bir Şahnê '
            'bileşeninden al. Dosyalar: $perFile',
      );
      if (total < ceiling) {
        // Azaldıysa tavanı da indir: bekçi kazanılanı kilitlemeli.
        // ignore: avoid_print
        print('"$pattern" $total\'e indi; tavanı ($ceiling) güncelle.');
      }
    });
  }

  test('Şahnê bileşenlerinde ham renk yok', () {
    final raw = RegExp(
      r'Color\(0x|Color\.fromARGB|Color\.fromRGBO|(?<![A-Za-z])Colors\.(?!transparent\b)',
    );
    final hits = <String>[];
    for (final entity in Directory(
      'lib/src/widgets/sahne',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = _code(entity.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (raw.hasMatch(lines[i])) {
          hits.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}

/// Yorum satırları sayılmaz: kararın niçini yorumda anlatılır ve eski
/// değeri anabilir.
String _code(String source) => source
    .split('\n')
    .map((line) => line.trimLeft().startsWith('//') ? '' : line)
    .join('\n');

int _count(String pattern, String code) => switch (pattern) {
  'bulanık BoxShadow' => _blurredShadows(code),
  'Colors.white + Agir/marka dolgusu' => _whiteOnAct(code),
  _ => pattern.allMatches(code).length,
};

/// `BoxShadow(` çağrıları içinde `blurRadius` sıfırdan büyük olanlar. Sayı
/// değilse (ör. belirteç) bulanık sayılır.
int _blurredShadows(String code) {
  var count = 0;
  var from = 0;
  while (true) {
    final start = code.indexOf('BoxShadow(', from);
    if (start < 0) return count;
    var depth = 0;
    var end = start + 'BoxShadow'.length;
    for (; end < code.length; end++) {
      final c = code[end];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    final call = code.substring(start, end);
    final blur = RegExp(r'blurRadius:\s*([^,\)\n]+)').firstMatch(call);
    if (blur != null) {
      final value = double.tryParse(blur.group(1)!.trim());
      if (value == null || value > 0) count++;
    }
    from = end;
  }
}

/// Agir/marka dolgusunun (`.act`, `AppTheme.brand`, `primaryCtaColor`)
/// sekiz satır yakınında elle yazılmış `Colors.white`: turuncu üstünde beyaz
/// metin (2,3:1). Agir üstünde metin HER ZAMAN koyu `onAct`tır.
int _whiteOnAct(String code) {
  final lines = code.split('\n');
  final fill = RegExp(r'\.act\b|AppTheme\.brand\b|primaryCtaColor');
  var count = 0;
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains('Colors.white')) continue;
    final lo = i - 8 < 0 ? 0 : i - 8;
    final hi = i + 8 >= lines.length ? lines.length - 1 : i + 8;
    if (lines.sublist(lo, hi + 1).any(fill.hasMatch)) count++;
  }
  return count;
}
