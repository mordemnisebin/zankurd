import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

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
      // Lisans metni koddan çağrılmaz ama kaldırılamaz: Onest ve Bricolage
      // Grotesque SIL Open Font License altında dağıtılır ve lisans, yazı
      // tipiyle birlikte bulundurulmayı şart koşar. "Kullanılmıyor" değil,
      // "yasal olarak orada durmak zorunda".
      if (name.startsWith('OFL') && name.endsWith('.txt')) continue;
      // Aynı gerekçe: `LICENSE-Lucide.txt` (MIT) ikon yazı tipinin lisansıdır.
      if (name.startsWith('LICENSE') && name.endsWith('.txt')) continue;
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

  // ---------------------------------------------------------------------
  // Paket boyutu bekçileri (2026-10-02 ölçümü, `flutter build ios --release
  // --analyze-size`: flutter_assets 15,4 MB).
  //
  // Birinci kusur: `assets/data/` klasörü bildirilince karantinadaki
  // `deepseek_2026_08_18_questions.json` (1,5 MB) da pakete giriyordu —
  // çalışma zamanında hiç okunmaz (`question_bank_assets.dart` yorumuna
  // bkz.), yalnız testler dosyayı diskten tarar. Sessizdi: karantina
  // testleri "oyuncuya açık değil" diyordu ve doğruydu; ama dosya yine de
  // her cihaza iniyordu.
  //
  // İkinci kusur: kullanılmayan yazı tipleri release derlemede BUDANMAZ
  // (budama yalnız kodda geçen glifler için çalışır; hiç geçmeyen yazı
  // tipi olduğu gibi pakete girer). `cupertino_icons` (258 KB) hiçbir
  // yerde kullanılmıyordu; `lucide_icons_flutter` paketi ise kullandığımız
  // statik `Lucide` ailesinin yanında 6 değişken ağırlıklı yazı tipini
  // (2,86 MB) de bildiriyordu.
  group('paket boyutu', () {
    String pubspec() => File('pubspec.yaml').readAsStringSync();

    List<String> declared() => RegExp(
      r'^\s+- (assets/[^\s]*)$',
      multiLine: true,
    ).allMatches(pubspec()).map((m) => m[1]!).toList();

    test('assets/data klasörü bildirilmez; her banka tek tek sayılır', () {
      final dataDeclared = declared()
          .where((d) => d.startsWith('assets/data/'))
          .toSet();
      expect(
        dataDeclared.contains('assets/data/'),
        isFalse,
        reason:
            'Klasör bildirimi karantinadaki 1,5 MB DeepSeek dosyasını '
            'da pakete sokar. Bankaları tek tek yaz.',
      );
      // Pakete giren veri = çalışma zamanı bankaları + kaynak künyesi.
      final expected = {
        ...questionBankAssets,
        'assets/data/image_credits.json',
      };
      expect(
        dataDeclared,
        expected,
        reason:
            'pubspec.yaml ile question_bank_assets.dart ayrıştı. Yeni banka '
            'iki yere de eklenmeli; eksik kalan banka uygulamada sessizce '
            'boş kategori olur (failedAssets).',
      );
    });

    test('diskteki her veri dosyası ya pakette ya bilinçli karantinada', () {
      const quarantined = {'deepseek_2026_08_18_questions.json'};
      final shipped = {...questionBankAssets, 'assets/data/image_credits.json'};
      final stray = <String>[
        for (final f in Directory('assets/data').listSync().whereType<File>())
          if (f.path.endsWith('.json') &&
              !shipped.contains(f.path) &&
              !quarantined.contains(f.uri.pathSegments.last))
            f.path,
      ];
      expect(
        stray,
        isEmpty,
        reason:
            'Bu dosyalar ne çalışma zamanı listesinde ne karantina '
            'listesinde: yeni bankayı question_bank_assets.dart + pubspec.yaml\'a '
            'ekle ya da buradaki karantina kümesine bilinçle yaz.\n'
            '${stray.join("\n")}',
      );
    });

    // Regex değil GERÇEK paket: `flutter test` pubspec'ten varlık paketini
    // kurar; `rootBundle` uygulamanın göreceği şeyi görür.
    test(
      'rootBundle: her banka okunur, karantina dosyası pakette yok',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        for (final asset in [
          ...questionBankAssets,
          'assets/data/image_credits.json',
        ]) {
          final raw = await rootBundle.loadString(asset);
          expect(raw, isNotEmpty, reason: asset);
        }
        await expectLater(
          rootBundle.loadString(
            'assets/data/deepseek_2026_08_18_questions.json',
          ),
          throwsA(anything),
          reason: 'Karantina dosyası pakete girmemeli (1,5 MB ölü yük).',
        );
      },
    );

    test('kullanılmayan ikon yazı tipi paketleri bağımlılık değil', () {
      final text = pubspec();
      expect(
        text,
        isNot(contains(RegExp(r'^\s+cupertino_icons:', multiLine: true))),
        reason:
            'Cupertino ikonu kullanılmıyor; 258 KB budanmadan pakete girer.',
      );
      expect(
        text,
        isNot(contains(RegExp(r'^\s+lucide_icons_flutter:', multiLine: true))),
        reason:
            'Paket 6 değişken ağırlıklı yazı tipini (2,86 MB) de pakete '
            'sokuyor. Lucide `assets/fonts/Lucide.ttf` olarak taşınır.',
      );
    });
  });
}
