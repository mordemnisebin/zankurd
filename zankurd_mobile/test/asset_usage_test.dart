import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pakete giren ama hiç kullanılmayan varlıkların bekçisi.
///
/// `pubspec.yaml`da bildirilen her şey APK/AAB'ye girer — kod ona hiç
/// dokunmasa bile. Bu sessiz bir sızıntıdır: özellik kaldırılır, görseli
/// kalır ve kullanıcı onu indirmeye devam eder.
///
/// 2026-07-30 taramasında üç örnek bulundu:
///
///   `assets/illustrations/treasure_chest.png` (113 KB) sonuç ekranı ödül
///   kartı için eklenmişti (`6c7278b`, "mockup 8"). Kart sonradan
///   sadeleştirildi, illüstrasyon öksüz kaldı ama `pubspec`te bildirilmeye
///   ve pakete girmeye devam etti. `daily_coins.png` (99 KB) aynı klasörde
///   aynı durumdaydı — klasörün tamamı ölüydü.
///
///   `assets/question_images/halk_mutfagi.webp` (30 KB) sorusu kopya
///   ayıklamasında bankadan çıkınca referanssız kaldı.
///
/// Eşleştirme dosya adı üzerinden yapılır, tam yol üzerinden değil. Sebep:
/// varlıklara üç ayrı biçimde atıf var ve hepsi geçerli —
///
///   * `AppIcons`/`CategoryVisuals`: tam yol (`assets/question_images/…`)
///   * `audioplayers`: `assets/` öneki olmadan (`sounds/correct.mp3`)
///   * soru bankası: `imageUrl` alanında
///
/// Ad üzerinden aramak üçünü de yakalar. Yanlış negatif riski (aynı adın
/// başka bir bağlamda geçmesi) bilinçli seçim: bekçi ölü varlığı kaçırsa
/// da yaşayan varlığı asla suçlamaz.
void main() {
  test('bildirilen her varlığa koddan ya da bankadan atıf var', () {
    final root = Directory('assets');
    expect(root.existsSync(), isTrue, reason: 'assets/ bulunamadı');

    // Atıf taşıyabilecek her yer: kaynak kod, testler, araçlar, pubspec ve
    // soru bankalarının kendisi.
    final haystack = StringBuffer();
    for (final dir in ['lib', 'test', 'tool']) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('.dart') || f.path.endsWith('.py')) {
          haystack.write(f.readAsStringSync());
        }
      }
    }
    haystack.write(File('pubspec.yaml').readAsStringSync());
    for (final f in Directory('assets/data').listSync().whereType<File>()) {
      if (f.path.endsWith('.json')) haystack.write(f.readAsStringSync());
    }
    final text = haystack.toString();

    final orphans = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      final name = file.uri.pathSegments.last;
      // Belgeler pakete girse de ölü varlık değildir.
      if (name == 'README.md' || name.startsWith('.')) continue;
      // Lisans metni koddan çağrılmaz ama kaldırılamaz: Rubik SIL Open
      // Font License altında dağıtılır ve lisans, yazı tipiyle birlikte
      // bulundurulmayı şart koşar. "Kullanılmıyor" değil, "yasal olarak
      // orada durmak zorunda".
      if (name == 'OFL.txt') continue;
      // Soru bankalarının kendisi `assets/data/` altında; onlara atıf
      // yükleyici üzerinden dolaylıdır.
      if (file.path.contains('assets/data/')) continue;
      if (!text.contains(name)) {
        orphans.add('${file.path} (${(file.lengthSync() / 1024).round()} KB)');
      }
    }

    expect(
      orphans,
      isEmpty,
      reason:
          '${orphans.length} varlık pakete giriyor ama hiçbir yerden '
          'kullanılmıyor. Ya kullan ya sil — ve `pubspec.yaml` '
          'bildirimini de kaldır.\n${orphans.join("\n")}',
    );
  });

  test('pubspec bildirimi olmayan varlık koddan çağrılmıyor', () {
    // Ters yön: kod var olmayan ya da bildirilmemiş bir yola atıf yaparsa
    // çalışma zamanında sessizce boş kutu görünür — test değil, kullanıcı
    // bulur.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^\s+- (assets/[^\s]*)$',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m[1]!).toList();

    final referenced = <String>{};
    for (final dir in ['lib']) {
      for (final f
          in Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        referenced.addAll(
          RegExp(
            r"'(assets/[A-Za-z0-9_/.-]+\.[a-z0-9]+)'",
          ).allMatches(f.readAsStringSync()).map((m) => m[1]!),
        );
      }
    }
    for (final f in Directory('assets/data').listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      // Bankalar liste, `image_credits.json` haritadır; ikisi de bu
      // klasörde durur, yani tür kontrolsüz cast burada patlar.
      final decoded = jsonDecode(f.readAsStringSync());
      if (decoded is! List) continue;
      for (final row in decoded) {
        if (row is! Map<String, dynamic>) continue;
        final url = row['imageUrl'];
        if (url is String && url.startsWith('assets/')) referenced.add(url);
      }
    }

    final missing = <String>[];
    for (final path in referenced) {
      if (!File(path).existsSync()) {
        missing.add('$path: dosya yok');
        continue;
      }
      final covered = declared.any(
        (d) => d.endsWith('/') ? path.startsWith(d) : d == path,
      );
      if (!covered) missing.add('$path: pubspec bildirimi yok');
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Koddan/bankadan çağrılan ama pakete girmeyen varlık:\n'
          '${missing.join("\n")}',
    );
  });
}
