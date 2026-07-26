import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Soru fotoğraflarının lisans bekçisi.
///
/// Fotoğraflar Wikimedia Commons'tan alındı; lisans politikası kamu malı,
/// CC0 ve CC BY (2026-07-26 kararı). CC BY **atıf ister** — künyesiz bir
/// fotoğraf yayımlamak lisans ihlalidir ve uygulamayı mağazada riske sokar.
///
/// Bu testler ihlali derleme zamanına çeker: bankada başvurulan her yerel
/// görselin dosyası, her dosyanın künyesi, her künyenin izinli bir lisansı
/// olmak zorunda.
void main() {
  const bankPath = 'assets/data/offline_questions.json';
  const creditsPath = 'assets/data/image_credits.json';
  const imageDir = 'assets/question_images';

  /// Yalnız atıf isteyen ya da hiç yükümlülük doğurmayan lisanslar.
  /// CC BY-SA bilerek dışarıda: share-alike, yayımlanan üründe türev
  /// yükümlülüğü doğurur.
  final allowed = RegExp(
    r'^(cc0|public domain|pd[- ]|cc by \d)',
    caseSensitive: false,
  );

  Map<String, dynamic> loadCredits() =>
      jsonDecode(File(creditsPath).readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> loadBank() =>
      (jsonDecode(File(bankPath).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  test('bankada başvurulan her yerel görselin dosyası var', () {
    final missing = <String>{};
    for (final row in loadBank()) {
      final url = (row['imageUrl'] as String?) ?? '';
      if (!url.startsWith('asset://')) continue;
      final path = url.replaceFirst('asset://', '');
      if (!File(path).existsSync()) missing.add(path);
    }

    expect(
      missing,
      isEmpty,
      reason: 'Var olmayan görsele başvuruluyor: ${missing.join(", ")}',
    );
  });

  test('Commons kaynaklı her görselin künyesi var', () {
    // Künye, projeye 2026-07-26'da Commons'tan eklenen dosyalar için
    // zorunlu. Ondan önce elde bulunan dosyalar bu kuralın dışında; onların
    // kaynağı proje geçmişinde ayrıca kayıtlı değil.
    final credits = loadCredits();
    final referenced = <String>{};
    for (final row in loadBank()) {
      final url = (row['imageUrl'] as String?) ?? '';
      if (!url.startsWith('asset://')) continue;
      referenced.add(
        url.split('/').last.replaceAll('.webp', '').replaceAll('.png', ''),
      );
    }

    final commonsSlugs = credits.keys.toSet();
    final orphaned = commonsSlugs.difference(referenced);
    expect(
      orphaned,
      isEmpty,
      reason:
          'Künyesi olan ama hiçbir soruda kullanılmayan görsel: '
          '${orphaned.join(", ")}. Kullanılmayan dosya künyeyi şişirir.',
    );
  });

  test('her künye izinli bir lisans taşıyor', () {
    final violations = <String>[];
    loadCredits().forEach((slug, value) {
      final entry = value as Map<String, dynamic>;
      final license = (entry['license'] as String?) ?? '';
      if (!allowed.hasMatch(license)) {
        violations.add('$slug: "$license"');
      }
    });

    expect(
      violations,
      isEmpty,
      reason:
          'İzin verilmeyen lisans (CC BY-SA / NC / bilinmeyen): '
          '${violations.join(", ")}',
    );
  });

  test('her künyede fotoğrafçı ve kaynak sayfası var', () {
    // CC BY atfın *kime* yapıldığını ve nereden alındığını göstermeyi
    // şart koşar; boş bir alan atfı geçersiz kılar.
    final incomplete = <String>[];
    loadCredits().forEach((slug, value) {
      final entry = value as Map<String, dynamic>;
      final artist = ((entry['artist'] as String?) ?? '').trim();
      final source = ((entry['source'] as String?) ?? '').trim();
      if (artist.isEmpty || source.isEmpty) incomplete.add(slug);
    });

    expect(
      incomplete,
      isEmpty,
      reason: 'Fotoğrafçı ya da kaynak eksik: ${incomplete.join(", ")}',
    );
  });

  test('künyedeki her dosya diskte duruyor', () {
    final missing = loadCredits().keys
        .where((slug) => !File('$imageDir/$slug.webp').existsSync())
        .toList();

    expect(
      missing,
      isEmpty,
      reason: 'Künyesi var ama dosyası yok: ${missing.join(", ")}',
    );
  });
}
