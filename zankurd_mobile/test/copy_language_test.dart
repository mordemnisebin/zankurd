import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Kurmancî terim tutarlılığı.
///
/// Bu test önce ekran kaynaklarını grep'liyordu (`ku ? 'Kûpa' : ...`).
/// Metinler anahtar tabanlı kayda taşınınca (2026-07-25 i18n göçü) kaynak
/// artık metni içermiyor; kontrol de doğru yere, yani tek doğruluk kaynağı
/// olan [Tr] defterine taşındı. Henüz göç etmemiş ekranlar için kaynak
/// kontrolü sürüyor.
void main() {
  test('turnuva terimi Kurmancî\'de "Kûpa" olarak kalır', () {
    // Türkçe "Turnuva" sözcüğü Kurmancî metne sızmamalı; karşılığı Kûpa.
    expect(Tr.of(K.tournament, AppLanguage.ku), 'Kûpa');
    expect(Tr.of(K.tournament, AppLanguage.tr), 'Turnuva Modu');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        kurmanci.toLowerCase(),
        isNot(contains('turnuva')),
        reason: '$key: Kurmancî metinde Türkçe "turnuva" geçiyor',
      );
    }
  });

  test('arkadaş durumu terimleri kayıt defterinde korunuyor', () {
    // Bu kontroller de `friends_screen.dart` kaynağını grep'liyordu;
    // ekran göç edince (2026-07-25) metin kaynakta kalmadı. Terimler artık
    // tek doğruluk kaynağından doğrulanır.
    expect(Tr.of(K.online, AppLanguage.ku), 'Serhêl');
    expect(Tr.of(K.online, AppLanguage.tr), 'Çevrimiçi');
    expect(Tr.of(K.offline, AppLanguage.ku), 'Ne li serhêl');
    expect(Tr.of(K.offline, AppLanguage.tr), 'Çevrimdışı');
    // 2026-07-30: burası "Jûr nehat avakirin" bekliyordu. `jûr` ve `ode`
    // ikisi de "oda" demek, ama defterde `ode` 50 yerde, `jûr` yalnız iki
    // yerde geçiyordu — üstelik bu testin kendisi birkaç satır altta
    // `peyamên odeyê` ve `odeyên serhêl` bekliyor. Yani aynı dosya aynı
    // kavramı iki adla sabitliyordu. Azınlıkta kalan iki metin `ode`ye
    // çevrildi; oyuncu odayı bir ekranda "ode", hata mesajında "jûr" diye
    // görmesin.
    expect(Tr.of(K.roomCreateFailed, AppLanguage.ku), 'Ode nehat avakirin');
  });

  test('hızlı düello bütün girişlerde aynı Kurmancî terimi kullanır', () {
    expect(Tr.of(K.quickDuel, AppLanguage.ku), 'Pêşbirka bilez');
    expect(Tr.of(K.homeQuickDuel, AppLanguage.ku), 'Pêşbirka bilez');
  });

  test('quiz açıklama seslendirmesi dinleme anlamını korur', () {
    expect(Tr.of(K.listenExplanation, AppLanguage.ku), 'Şîroveyê bibihîze');
  });

  test('quiz soru seslendirmesi dinleme anlamını korur', () {
    expect(Tr.of(K.listenQuestion, AppLanguage.ku), 'Pirsê bibihîze');
  });

  test('quiz bitirme düğmesi Kurmancîde emir kipindedir', () {
    expect(Tr.of(K.finishAction, AppLanguage.ku), 'Biqedîne');
  });

  test('çift cevap ipucu ikinci hakkı doğru açıklar', () {
    expect(
      Tr.of(K.wildcardDoubleHint, AppLanguage.ku),
      'Du derfetên bersivdanê: heke bersiva yekem şaş be, '
      'derfetek din heye.',
    );
  });

  test('ana öğrenme ve oyuncu adı metinleri doğal Kurmancî kullanır', () {
    // 2026-07-30: `K.learningPaths` ve `K.homeLearningSection` Türkçede
    // birebir aynı metni ("Öğrenme yolları") taşıyor ama Kurmancîde biri
    // `hînbûn` biri `fêrbûn` diyordu; bölüm başlığı `Hînbûn` iken büyük
    // harfli hâli `FÊRBÛN` çıkıyordu. İkisi de doğru sözcük, ama tek üründe
    // tek kök olmalı — uygulamanın sloganı da `hîn bibe` diyor.
    expect(Tr.of(K.homeLearningSection, AppLanguage.ku), 'Rêyên hînbûnê');
    expect(Tr.of(K.learningPaths, AppLanguage.ku), 'Rêyên hînbûnê');
    expect(Tr.of(K.secLearning, AppLanguage.ku), 'Hînbûn');
    expect(Tr.of(K.secLearningCaps, AppLanguage.ku), 'HÎNBÛN');
    expect(
      Tr.of(K.nameGateValueQuests, AppLanguage.ku),
      'Lîstikan biqedîne, xelatan bi dest bixe',
    );
    expect(
      Tr.of(K.onbLearnBody, AppLanguage.ku),
      'Bi pirsên kurt peyvên Kurmancî, çand û zanînê hîn bibe.',
    );
    // 2026-07-30: bu satır "Bi lîstikvanên rastî re pêşbirkê bike — şampiyon
    // kûpayê digire!" diyordu. "Gerçek oyuncular" ifadesi turnuva kartında üç
    // kez geçiyordu: kimlik bandı alt metni, biçim satırı ve bu slogan. Bilgi
    // bir kez söylenir; slogan yalnız kendi taşıdığı bilgiyi bıraktı.
    expect(Tr.of(K.botRaceHint, AppLanguage.ku), 'Şampiyon kûpayê digire!');
    expect(
      Tr.of(K.tournamentSub, AppLanguage.ku),
      contains('lîstikvanên rastî'),
      reason: 'Bilgi bir yerde durmalı — kimlik bandında.',
    );
    expect(
      Tr.of(K.duel1v1Sub, AppLanguage.ku),
      'Bi hevalan re an bi lîstikvanên din re bi awayekî zindî pêşbirkê bike.',
    );
    expect(
      Tr.of(K.nameGateValueFriends, AppLanguage.ku),
      'Bi hevalan re pêşbirkê bike',
    );
    expect(Tr.of(K.onbCompeteBody, AppLanguage.ku), contains('ode an kûpa'));
    expect(Tr.of(K.howToPlayBody, AppLanguage.ku), contains('9 kategoriyan'));
    expect(Tr.of(K.howToPlayBody, AppLanguage.ku), contains('coin didin'));
    expect(Tr.of(K.howToPlayBody, AppLanguage.tr), contains('9 kategori'));
  });

  test('premium metni yalnız gerçekten verilen faydaları vaat eder', () {
    expect(
      Tr.of(K.paywallSubtitle, AppLanguage.ku),
      'Piştgirî bide ZanKurdê, zincîra xwe biparêze',
    );
    expect(
      Tr.of(K.paywallSubtitle, AppLanguage.tr),
      "ZanKurd'u destekle, serini koru",
    );
    expect(Tr.of(K.paywallFeatures, AppLanguage.ku), 'Taybetmendiyên Premium');
  });

  test('gizlilik özeti saklanan verileri ve uygulama içi silmeyi açıklar', () {
    final turkish = Tr.of(K.privacyBody, AppLanguage.tr);
    expect(turkish, contains('oyun ve eşleştirme'));
    expect(turkish, contains('oda mesajları'));
    expect(turkish, contains('soru önerileri'));
    expect(turkish, contains('Ayarlar > Hesap > Hesabımı Sil'));
    expect(turkish, contains('liderlik tablosunda'));
    expect(turkish, contains('arkadaş araması ve isteklerinde'));
    expect(turkish, contains('çevrimiçi odalarda'));
    expect(turkish, isNot(contains('@')));

    final kurmanci = Tr.of(K.privacyBody, AppLanguage.ku);
    expect(kurmanci, contains('lîstik û hevberkirinê'));
    expect(kurmanci, contains('peyamên odeyê'));
    expect(kurmanci, contains('pêşniyarên pirsan'));
    // 2026-07-30: metin kullanıcıyı "Sazkarî" menüsüne yolluyordu; oysa
    // ayarlar ekranının Kurmancî adı `Mîheng` (K.settings). Hesabını silmek
    // isteyen oyuncu var olmayan bir menü arıyordu — yasal metnin tarif
    // ettiği yol uygulamada bulunmuyordu.
    expect(kurmanci, contains('Mîheng > Hesab > Hesabê Min Jê Bibe'));
    expect(kurmanci, contains(Tr.of(K.settings, AppLanguage.ku)));
    expect(kurmanci, contains('tabloya pêşderçûnê'));
    expect(kurmanci, contains('lêgerîna hevalan'));
    expect(kurmanci, contains('odeyên serhêl'));
    expect(kurmanci, isNot(contains('@')));
  });

  // 2026-07-30 dil taraması: defterde Türkçe sözcükler Kurmancî yuvalarda
  // duruyordu — "E-posta", "rastgele", "Bakiye", "sînav", "Unvan", "mesaj".
  // Tek tek düzeltmek yetmez; bir sonraki metin aynı yoldan girer. Harf
  // bekçisi (`kurmanci_alphabet_test`) bunları yakalayamıyor çünkü hepsi
  // Kurmancî alfabesindeki harflerle yazılıyor. Bu liste sözcüğün kendisini
  // yasaklar ve her birinin karşılığını gösterir.
  test('Kurmancî yuvalara Türkçe sözcük sızmaz', () {
    const forbidden = <String, String>{
      'e-posta': 'e-peyam',
      'rastgele': 'rasthatî',
      'bakiye': 'hejmara coinan',
      'sînav': 'azmûn',
      'unvan': 'nav û nîşan',
      'mesaj': 'peyam',
      'jûr': 'ode',
      'eşleş': 'lihevanîn',
    };

    final offenders = <String>[];
    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      for (final entry in forbidden.entries) {
        if (kurmanci.contains(entry.key)) {
          offenders.add('$key: "${entry.key}" → "${entry.value}"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Kurmancî metinde Türkçe sözcük:\n${offenders.join("\n")}',
    );
  });

  // Aynı Türkçe metnin iki farklı Kurmancî karşılığı olması, oyuncunun aynı
  // şeyi iki ad altında görmesi demektir: "Öğrenme yolları" bir ekranda
  // `Rêyên hînbûnê`, ötekinde `Rêyên fêrbûnê` çıkıyordu (2026-07-30). Aynı
  // kaynak metin, aynı çeviri.
  test('aynı Türkçe metnin tek Kurmancî karşılığı var', () {
    final byTurkish = <String, Map<String, String>>{};
    for (final key in Tr.keys) {
      final turkish = Tr.of(key, AppLanguage.tr).trim();
      // Kısa etiketler ("Boş", "Evet") bağlama göre haklı olarak ayrışabilir;
      // kural cümle uzunluğundaki metinler için anlamlı.
      if (turkish.length < 12) continue;
      byTurkish.putIfAbsent(turkish, () => {})[key] = Tr.of(
        key,
        AppLanguage.ku,
      );
    }

    final offenders = <String>[];
    byTurkish.forEach((turkish, translations) {
      final distinct = translations.values.toSet();
      if (distinct.length > 1) {
        offenders.add('"$turkish" → ${distinct.join(" / ")}');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Tek Türkçe metne birden çok Kurmancî karşılık:\n'
          '${offenders.join("\n")}',
    );
  });

  // 2026-07-26'da ölçülmüştü: Rubik U+2192 (→) taşımıyor, ok sistem yazı
  // tipine düşüyor ve cümlenin ortasında tip değişiyor. O gün yalnız
  // `explanationToKu` kural motorundan çıkarılmıştı — bankada yazılı 861
  // alanda ve gizlilik metninin kendisinde ok kalmıştı ("Ayarlar → Hesap →
  // Hesabımı Sil"). Dört Rubik kesitinin cmap tablosu doğrulandı: hiçbirinde
  // glif yok.
  //
  // Kural yalnız oka değil, ürünün yazı tipinin taşımadığı her karaktere
  // bakar: yeni bir simge eklendiğinde aynı kusur sessizce dönmesin.
  test('metinlerde ürünün yazı tipinde olmayan karakter yok', () {
    // Rubik'te bulunmayan, metne kolayca sızabilen tipografik simgeler.
    const missingGlyphs = {
      '\u2192': 'ok (→) — yerine ">" ya da "·"',
      '\u2190': 'sol ok (←)',
      '\u21D2': 'çift ok (⇒)',
      '\u2713': 'onay (✓) — ikon kullanın',
      '\u2717': 'çarpı (✗) — ikon kullanın',
    };

    final offenders = <String>[];
    for (final key in Tr.keys) {
      for (final language in AppLanguage.values) {
        final text = Tr.of(key, language);
        missingGlyphs.forEach((glyph, hint) {
          if (text.contains(glyph)) offenders.add('$key: $hint');
        });
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Yazı tipinde olmayan karakter cümlenin ortasında tip değiştirir:\n'
          '${offenders.join("\n")}',
    );
  });

  test('göç etmemiş ekranlarda terim sözlüğü korunuyor', () {
    final shell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    final onboarding = File(
      'lib/src/screens/onboarding_screen.dart',
    ).readAsStringSync();

    expect(shell, isNot(contains('hevalên te, Turnuva')));
    expect(onboarding, isNot(contains("ku ? 'Turnuva")));
  });
}
