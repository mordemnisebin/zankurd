import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

String _libRelative(String path) {
  final normalized = path.replaceAll(r'\', '/');
  const marker = '/lib/';
  final at = normalized.indexOf(marker);
  if (at >= 0) {
    return 'lib/${normalized.substring(at + marker.length)}';
  }
  return normalized;
}

/// Çok dillilik göçünün bekçisi.
///
/// Uygulama metinleri tarihsel olarak çağrı yerinde `ku ? 'a' : 'b'` ya da
/// `context.s('a', 'b')` biçiminde, iki dil varsayımı koda gömülü olarak
/// duruyor. Üçüncü bir dil (Soranî, Zazakî, İngilizce) bu imzayı kırar.
///
/// Göç ekran ekran yapılacağı için tek seferlik bir "bitti" testi yazılamaz.
/// Bunun yerine sayaç bir tavana sabitlenir: yeni satır içi kullanım
/// eklemek testi kırar, göç ettikçe tavan düşürülür. Böylece ilerleme
/// ölçülebilir ve geri alınamaz olur.
void main() {
  test('metinlerde kaçırılmış satır sonu kalmadı', () {
    // 2026-07-28: profil ekranı "Henüz çevrimiçi oyun geçmişin yok.\\nBir
    // odaya katıl" yazıyordu — satır atlamak yerine `\\n`i harfi harfine
    // basıyordu. Kaçış iki kez uygulanmıştı, yani dizede gerçek bir ters
    // bölü + n duruyordu.
    //
    // Bu kusur gözle bulunur ama yalnız o ekrana bakınca; ölçüt tarama
    // bütün metinleri bir kerede tarar.
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    final offenders = <String>[];
    for (final line in source.split('\n')) {
      if (line.trimLeft().startsWith('//')) continue;
      if (!line.contains(r"'")) continue;
      if (line.contains(r'\\n')) offenders.add(line.trim());
    }
    expect(
      offenders,
      isEmpty,
      reason: 'kaçırılmış satır sonu: ${offenders.take(3).join(" | ")}',
    );
  });

  group('l10n göç bekçisi', () {
    /// Satır içi kullanım sayısı (`ku ? '...'`, `isKu ? '...'`,
    /// `_isKu ? '...'` ve `context.s('...', '...')` toplamı, `lib/`
    /// altındaki tüm dosyalar). Bu sayı YALNIZ AZALTILABİLİR — göç
    /// ettikçe yeni değeri buraya yazın.
    ///
    /// ## Bekçi bir yıl boyunca yanlış yere baktı
    ///
    /// Desen 2026-07-31'e kadar `\bku\s*\?` idi: hem küçük harfe duyarlı,
    /// hem `\b` kelime sınırı istiyordu. Kod tabanının baskın yazımı olan
    /// `isKu ? '...'` biçiminde "ku" bir kelime başlangıcı değildir ve
    /// büyük K taşır — yani desen bu biçimi HİÇ görmedi. Bekçi 3 sayıp
    /// geçiyordu; gerçek sayı 187, 37 dosyaya yayılmıştı.
    ///
    /// Sessiz kalan yalnız sayı değildi. Tam bu kör noktada üç görünür
    /// kusur yaşıyordu: ana ekranda Kurmancî cümlenin ortasında Türkçe
    /// "sen" zamiri, flaş kartta "Bersiv (Arka Yüz)", ve soru tipi
    /// rozetinde 'Hilbijarin' (bir `t` eksik). Üçü de bu deseni
    /// düzelttikten sonra bulundu.
    ///
    /// Geçmiş (eski, kör ölçüm): 639 → … → 3.
    /// Gerçek ölçüm: 187 (2026-07-31, desen düzeltildi)
    /// → 165 (lang.dart'taki ikinci sözlük kaldırıldı)
    /// → 148 (çok satırlı dizeler de sayıldı — düzeltilmiş desen
    ///   `\s*` ile satır sonunu geçtiği için sayı bir kez yükseldi)
    /// → 145 (paywall ekranı tamamen deftere taşındı)
    /// → 141 (avatar çerçeve kazanım etiketleri)
    /// → 13 (32 dosyada toplu göç; 109 yeni anahtar, 20 kullanım defterde
    ///   zaten var olan anahtarla eşleşti ve yenisi açılmadı)
    /// → 12 (arkadaş davet paylaşım metni `{tag}` ile deftere taşındı)
    /// → 11 (quiz sonuç paylaşım metni `{score}/{correct}/{total}/{percent}`
    ///   ile deftere taşındı)
    /// → 9 (seviye yolundaki `Ast`/`Seviye` ve `pirs`/`soru` birimleri
    ///   defterdeki `progressLevelLabel` ve `soru` anahtarlarına bağlandı).
    ///
    /// ## Kalan 9 bilinçli
    ///
    /// - `strings.dart` (2): göç yolunu anlatan belge yorumunun kendisi.
    /// - `percent_format.dart` (1): yüzde biçiminin TEK kaynağı burasıdır
    ///   ve `percent_and_identity_test` başka hiçbir yerde elle biçim
    ///   yazılmadığını doğrular. Metni deftere taşımak o bekçiyi kör eder.
    /// - `level_screen` (2), `leaderboard_screen` (3),
    ///   `quiz_result_screen` (1): bir kısmı dile göre alan seçer,
    ///   bir kısmı çok satırlı cümledir.
    ///   Harita sapınca tavan yine yalan söylerdi — sayı tek başına yetmez.
    const remainingByFile = {
      'lib/src/l10n/strings.dart': 2,
      'lib/src/utils/percent_format.dart': 1,
      'lib/src/screens/level_screen.dart': 2,
      'lib/src/screens/leaderboard_screen.dart': 3,
      'lib/src/screens/quiz_result_screen.dart': 1,
    };

    test('satır içi iki-dil kullanımı tavanı aşmıyor', () {
      final libDir = Directory('lib');
      // `[Kk]u` — `isKu`, `_isKu`, `widget.isKu` ve düz `ku` biçimlerinin
      // hepsini yakalar. Kelime sınırı BİLEREK yok: kusur tam orada
      // saklanıyordu.
      final pattern = RegExp(r"""([Kk]u\s*\?\s*['"])|(\.s\(\s*['"])""");
      final inlineCeiling = remainingByFile.values.reduce((a, b) => a + b);

      var count = 0;
      final perFile = <String, int>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final hits = pattern.allMatches(entity.readAsStringSync()).length;
        if (hits > 0) {
          perFile[_libRelative(entity.path)] = hits;
          count += hits;
        }
      }

      final worst = perFile.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      expect(
        count,
        lessThanOrEqualTo(inlineCeiling),
        reason:
            'Satır içi iki-dil kullanımı arttı ($count > $inlineCeiling).\n'
            'Yeni metinler için `context.t(K.anahtar)` kullanın '
            '(bkz. lib/src/l10n/strings.dart).\n'
            'En yoğun dosyalar: '
            '${worst.take(5).map((e) => "${e.key}: ${e.value}").join(", ")}',
      );
      expect(
        perFile,
        remainingByFile,
        reason:
            'Kalan dosya haritası sapması. Göç ettiysen haritayı düşür; '
            'yeni dosyaya satır içi metin ekleme.',
      );
    });

    test('kayıtlı her anahtarın her dilde karşılığı var', () {
      for (final language in AppLanguage.values) {
        expect(
          Tr.missingFor(language),
          isEmpty,
          reason:
              '${language.code} için eksik çeviri var. Yeni bir dil '
              'eklendiğinde bu test, unutulan anahtarları listeler.',
        );
      }
    });

    test('bilinen anahtarlar her dilde farklı metin döndürür', () {
      // Kayıt defterinin gerçekten dile göre ayrıştığını doğrular; tablo
      // yanlışlıkla tek dile sabitlenirse burada yakalanır.
      expect(Tr.of(K.settings, AppLanguage.ku), 'Mîheng');
      expect(Tr.of(K.settings, AppLanguage.tr), 'Ayarlar');
      // 2026-07-30: 'Fêr Bibe' bekliyordu. Defterde öğrenme kavramı iki
      // kökle yazılıyordu: gezinme etiketi `fêr`, geri kalan her yer
      // `hîn` (uygulamanın sloganı da 'Kurmancî hîn bibe'). İkisi de
      // doğru sözcük, ama oyuncu aynı şeyi iki adla görmemeli.
      expect(Tr.of(K.navLearn, AppLanguage.ku), 'Hîn Bibe');
      expect(Tr.of(K.navLearn, AppLanguage.tr), 'Öğren');
      expect(Tr.of(K.progressLevelLabel, AppLanguage.ku), 'Ast');
      expect(Tr.of(K.progressLevelLabel, AppLanguage.tr), 'Seviye');
      expect(Tr.of(K.soru, AppLanguage.ku), 'pirs');
      expect(Tr.of(K.soru, AppLanguage.tr), 'soru');
    });

    test('yer tutucular doldurulur', () {
      // Dizgi birleştirme yerine yer tutucu kullanılıyor: her dil kendi
      // sözcük sırasını korumalı. Mekanizma sessizce bozulursa kullanıcı
      // ekranda ham "{name}" görür.
      expect(
        Tr.of(K.currentLevel, AppLanguage.tr, {'name': 'Orta'}),
        'Mevcut seviyen: Orta',
      );
      expect(
        Tr.of(K.currentLevel, AppLanguage.ku, {'name': 'Navîn'}),
        'Asta te ya niha: Navîn',
      );
      expect(
        Tr.of(K.dailyReminderAt, AppLanguage.tr, {'time': '19:00'}),
        'Her gün saat 19:00',
      );
      expect(
        Tr.of(K.inviteShareText, AppLanguage.ku, {'tag': 'ZK-TEST'}),
        'Ez li ZanKurdê bi Kurmancî hîn dibim! Koda min a vexwendinê: ZK-TEST. Tu jî were: https://zankurd.com',
      );
      expect(
        Tr.of(K.inviteShareText, AppLanguage.tr, {'tag': 'ZK-TEST'}),
        'ZanKurd ile Kürtçe öğreniyor ve yarışıyorum! Davet kodum: ZK-TEST. Sen de katıl: https://zankurd.com',
      );
      expect(
        Tr.of(K.resultShareText, AppLanguage.ku, {
          'score': '120',
          'correct': '8',
          'total': '10',
          'percent': '80%',
        }),
        'Min di ZanKurd de 120 pûan girt! Rast: 8/10 (80%). Tu jî bilîze: Play Store: "ZanKurd"',
      );
      expect(
        Tr.of(K.resultShareText, AppLanguage.tr, {
          'score': '120',
          'correct': '8',
          'total': '10',
          'percent': '%80',
        }),
        'ZanKurd\'te 120 puan aldım! Doğru: 8/10 (%80). Sen de oyna: Play Store: "ZanKurd"',
      );
    });

    test('yer tutucusuz metin parametreden etkilenmez', () {
      expect(Tr.of(K.settings, AppLanguage.tr, {'name': 'x'}), 'Ayarlar');
    });

    test('her yer tutuculu anahtar adları bildirilir', () {
      // Çağrı yerinin hangi parametreleri vermesi gerektiği koddan
      // okunabilmeli; eksik parametre assert'e düşmeden önce burada
      // görünür.
      expect(Tr.placeholdersOf(K.currentLevel), {'name'});
      expect(Tr.placeholdersOf(K.dailyReminderAt), {'time'});
      expect(Tr.placeholdersOf(K.deleteTypeWord), {'word'});
      expect(Tr.placeholdersOf(K.inviteShareText), {'tag'});
      expect(Tr.placeholdersOf(K.resultShareText), {
        'score',
        'correct',
        'total',
        'percent',
      });
      expect(Tr.placeholdersOf(K.settings), isEmpty);
    });

    test('yer tutucu içeren metinler her iki dilde aynı adları kullanır', () {
      // Bir dilde {name}, ötekinde {isim} yazılırsa bir dil sessizce
      // doldurulmamış kalır. Bu test kaymayı yakalar.
      for (final key in Tr.keys) {
        final ku = Tr.of(key, AppLanguage.ku);
        final tr = Tr.of(key, AppLanguage.tr);
        final pattern = RegExp(r'\{([a-zA-Z_]+)\}');
        final kuNames = pattern.allMatches(ku).map((m) => m.group(1)).toSet();
        final trNames = pattern.allMatches(tr).map((m) => m.group(1)).toSet();
        expect(
          kuNames,
          trNames,
          reason: '$key: diller farklı yer tutucu adı kullanıyor',
        );
      }
    });
  });

  group('göç betiği çıktısı', () {
    test('kaçışlı dolar işareti kalmadı', () {
      // Göç betiği yer tutucu değerlerini bir kez `'\$degisken'` olarak
      // üretti: Dart'ta bu kaçışlı dizgidir, yani ekranda değerin yerine
      // ham "\$_readyMistakeCount" metni görünürdü. Sözdizimi geçerli
      // olduğu için analyze de testler de yakalamadı; ancak gözle
      // bakınca fark edildi (2026-07-25).
      //
      // Bu tarama aynı hatanın sonraki ekran göçlerinde tekrarlanmasını
      // engeller.
      final offenders = <String>[];
      final escapedInterpolation = RegExp(r"'\\\$[A-Za-z_]");

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (escapedInterpolation.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Kaçışlı değişken bulundu — ekranda ham metin görünür:\n'
            '${offenders.take(5).join("\n")}',
      );
    });
  });

  group('context.t() dil değişimine tepki verir', () {
    testWidgets('dil değişince t() kullanan widget yeniden çizilir', (
      tester,
    ) async {
      // `t()` ilk yazımında dili `listen: false` ile okuyordu; dil
      // değiştiğinde yalnız `t()` kullanan bir ekran eski dilde kalıyordu
      // (2026-07-25). Ayarlar/profil ekranlarında fark edilmemişti çünkü
      // oradaki KU/TR düğmesi `isKu` ile abone olup yeniden çizimi
      // tetikliyordu — yani hata, ekranda başka bir abone varsa gizleniyor.
      // Bu test tek başına `t()` kullanan bir ağaç kurar.
      final provider = LanguageProvider()..setLang('ku');

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(builder: (context) => Text(context.t(K.settings))),
          ),
        ),
      );

      expect(find.text('Mîheng'), findsOneWidget);

      provider.setLang('tr');
      await tester.pumpAndSettle();

      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Mîheng'), findsNothing);
    });
  });
}
