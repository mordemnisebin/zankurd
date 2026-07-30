import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

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
    /// Satır içi kullanım sayısı (`ku ? '...'` ve `context.s('...', '...')`
    /// toplamı, `lib/` altındaki tüm dosyalar). Bu sayı YALNIZ
    /// AZALTILABİLİR — göç ettikçe yeni değeri buraya yazın.
    ///
    /// Geçmiş: 639 (2026-07-25 ilk ölçüm) → 630 (alt gezinme etiketleri)
    /// → 576 (ayarlar) → 530 (profil) → 493 (giriş) → 438 (kayıt + yarış)
    /// → 381 (öğrenme + sonuç) → 355 (turnuva)
    /// → 307 (soru öner + arkadaşlar) → 203 (quiz + etkinlik)
    /// → 119 (oda, mağaza, avatar, liderlik) → 3 (kalan tüm ekranlar).
    ///
    /// Kalan 3 kullanım bilinçli olarak duruyor ve göç edilemez:
    /// - `lib/src/l10n/strings.dart` (2): göç yolunu anlatan belge
    ///   yorumunun kendisi; eski imzayı örnek olarak gösteriyor.
    /// - `lib/src/screens/quiz_result_screen.dart` (1): iki dal aynı metnin
    ///   çevirisi değil, *farklı veri alanlarını* (titleKu/titleTr) okuyor;
    ///   anahtar defterine taşınacak bir metin yok.
    ///
    /// Yani tavan artık pratikte sıfırdır: yeni her satır içi kullanım
    /// testi kırar.
    const inlineCeiling = 3;

    test('satır içi iki-dil kullanımı tavanı aşmıyor', () {
      final libDir = Directory('lib');
      final pattern = RegExp(r"""(\bku\s*\?\s*['"])|(\.s\(\s*['"])""");

      var count = 0;
      final perFile = <String, int>{};
      for (final entity in libDir.listSync(recursive: true)) {
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
        lessThanOrEqualTo(inlineCeiling),
        reason:
            'Satır içi iki-dil kullanımı arttı ($count > $inlineCeiling).\n'
            'Yeni metinler için `context.t(K.anahtar)` kullanın '
            '(bkz. lib/src/l10n/strings.dart).\n'
            'En yoğun dosyalar: '
            '${worst.take(5).map((e) => "${e.key}: ${e.value}").join(", ")}',
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
