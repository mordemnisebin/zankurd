import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Ne Kurmancî ne Türkçe metinde çıplak İngilizce kelime durur.
///
/// ## Kusur
///
/// Ders yolu ekranının altındaki şerit "Armanca **mastery** ya
/// kategoriyê" diyordu — ve Türkçesi de "Kategori **mastery** hedefi".
/// İki dilde de çıplak İngilizce, üstelik gereksiz: ustalık
/// SEVİYELERİNİN Kurmancî adları zaten var (`xwendekar`, `pispor`,
/// `mamoste` — bkz. `mastery_level.dart`). Genel terim İngilizce kalınca
/// aynı kavram ekranda iki ayrı dilde anılıyordu.
///
/// 2026-08-01'de canlı Kurmancî ders yolu ekranında görüldü. Mevcut l10n
/// bekçileri bunu yakalamıyordu: onlar çevirinin VAR olup olmadığına ve
/// satır içi `ku ? … : …` kalıplarına bakıyor, çevirinin İÇERİĞİNE değil.
///
/// ## Muafiyetler niçin var
///
/// Her yabancı kökenli kelime kusur değildir. Aşağıdaki liste iki
/// gerekçeyle sınırlıdır:
///
///   * **Ürün/marka adı** — "Premium" bir abonelik kademesinin adı,
///     Türkçede de aynen kullanılıyor; çevrilirse mağaza sayfasıyla
///     çelişir.
///   * **Yerleşik alıntı** — "quiz" iki dilde de Kurmancî ekleriyle
///     çekimleniyor ("Quizê biqedîne", "Quiz-a Kurt"), yani dile
///     girmiş. "Streak" muaf değildi: parantez içi açımlama ürün
///     terimini (zincîr / seri) İngilizceyle yeniden adlandırıyordu.
///
/// Listeye ekleme yapmak, o kelimenin niçin çevrilemediğini yazmayı
/// gerektirir. Yeni bir İngilizce kelime sessizce sızarsa bekçi düşer.
void main() {
  // Dile göre muafiyet: bir kelime bir dilde meşru, diğerinde sızıntı
  // olabilir. "bonus" Türkçeye girmiş bir kelimedir (TDK'de var);
  // Kurmancî metinde görünseydi kusur olurdu. Para birimi de böyle —
  // Türkçe "coin", Kurmancî "zêr" — ama o çifti
  // `currency_naming_test.dart` iki yönde birden koruyor, burada
  // tekrarlanmıyor.
  const allowedByLanguage = <String, Set<String>>{
    'ku': {
      'premium', // abonelik kademesinin adı; mağaza sayfasıyla aynı olmalı
      'quiz', // Kurmancî eklerle çekimleniyor: "Quizê biqedîne", "Quiz-a Kurt"
      'xp', // birim kısaltması, iki dilde de aynı
      'zankurd', // ürünün kendi adı
    },
    'tr': {
      'premium',
      'quiz',
      'xp',
      'zankurd',
      'avatar', // Türkçe ürün adı; Kurmancî karşılığı `rû` (`K.myAvatar`)
      // 'bonus' YOK: Türkçe metin çekimli hâlini kullanıyor ("seri
      // bonusu artırır"), yani çıplak kelime hiç geçmiyor. Muafiyet
      // eklemek kuralı gereksiz yere gevşetirdi.
    },
  };

  // Sızıntının tipik yolları. Liste kapsamlı olmak zorunda değil; ölçüm
  // (2026-08-01) bunlardan yalnız "mastery"nin sızdığını gösterdi ve o
  // düzeltildi. Liste, aynı sınıfın geri gelmesini yakalamak için durur.
  const flagged = [
    'mastery',
    'level',
    'score',
    'bonus',
    'combo',
    'badge',
    'daily',
    'weekly',
    'challenge',
    'player',
    'profile',
    'settings',
    'share',
    'leaderboard',
    'achievement',
    'reward',
    'lobby',
    'room',
    'match',
    'premium',
    'quiz',
    'streak',
    'xp',
    'coin',
    'flashcard',
    'chat',
    'avatar',
    'cloud',
  ];

  for (final language in AppLanguage.values) {
    final allowed = allowedByLanguage[language.code] ?? const <String>{};
    test('${language.code} metinlerinde çıplak İngilizce yok', () {
      final offenders = <String>[];
      for (final key in Tr.keys) {
        // Yer tutucular (`{level}`, `{coins}`) kullanıcıya görünmez;
        // gördüğü şey yerlerine geçen değerdir.
        final text = Tr.of(key, language).replaceAll(RegExp(r'\{[^}]*\}'), ' ');
        for (final word in flagged) {
          if (allowed.contains(word)) continue;
          if (RegExp('\\b$word\\b', caseSensitive: false).hasMatch(text)) {
            offenders.add('$key: $text  ← "$word"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Bu metinlerde çevrilmemiş İngilizce kelime var:\n'
            '${offenders.join("\n")}',
      );
    });
  }

  test('rozet terimi Kurmancîde rozet olarak kalır', () {
    // Ürün terimi zaten `Rozet` (`K.rozetler`). Çerçeve koşulu
    // "nîşan" deyince aynı rozet iki adla duruyordu. `nîşan bide`
    // göstermek, `nav û nîşan` unvan; kök taraması kör kalır.
    expect(Tr.of(K.rozetler, AppLanguage.ku), 'Rozet');
    expect(Tr.of(K.frameReqBronze, AppLanguage.ku), '1 rozet veke');
    expect(Tr.of(K.frameReqSilver, AppLanguage.ku), '5 rozetan veke');

    final nisanVeke = RegExp(r'nîşan(an)?\s+veke', caseSensitive: false);
    for (final key in Tr.keys) {
      expect(
        nisanVeke.hasMatch(Tr.of(key, AppLanguage.ku)),
        isFalse,
        reason: '$key: Kurmancî metinde "nîşan" rozet; karşılığı "rozet"',
      );
    }
  });

  test('ustalık terimi iki dilde de yerel', () {
    // Bekçi kör kalmasın: düzeltilen örnek gerçekten yerinde durmalı.
    expect(
      Tr.of(K.categoryMasteryGoal, AppLanguage.ku),
      'Armanca serweriya kategoriyê',
    );
    expect(
      Tr.of(K.categoryMasteryGoal, AppLanguage.tr),
      'Kategori ustalık hedefi',
    );
    // Profil bölüm başlığı "Ustalîya" deyince aynı kavram iki adla durur.
    expect(Tr.of(K.kategoriUstaligi, AppLanguage.ku), 'Serweriya Kategoriyê');
    expect(Tr.of(K.kategoriUstaligi, AppLanguage.tr), 'Kategori Ustalığı');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('ustal')),
        reason: '$key: Kurmancî metinde Türkçe "ustalık"; karşılığı "serwerî"',
      );
    }
  });

  test('bulut senkronu İngilizce cloud taşımaz', () {
    // Durum çipi Türkçe "Bulut" taşıyordu; karşılığı `ewr`.
    // İngilizce `cloud` aynı sınıfın diğer yüzü.
    expect(Tr.of(K.bulutlaSenkronize, AppLanguage.ku), 'Tev rêzkirî ye (Ewr)');
    expect(Tr.of(K.bulutlaSenkronize, AppLanguage.tr), 'Bulutla senkronize');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('cloud')),
        reason: '$key: Kurmancî metinde İngilizce "cloud"; karşılığı "ewr"',
      );
      expect(
        kurmanci,
        isNot(contains('bulut')),
        reason: '$key: Kurmancî metinde Türkçe "bulut"; karşılığı "ewr"',
      );
    }
  });

  test('para birimi Kurmancîde zêr olarak kalır', () {
    // Ürün terimi zaten `Zêr` (`K.coinWord`). Günlük tavan "jetonan"
    // deyince aynı para iki adla duruyordu. Türkçe `jeton` kökü
    // İngilizce `\bcoin\b` taramasını kör eder — turnûva ile aynı sınıf.
    expect(Tr.of(K.coinWord, AppLanguage.ku), 'Zêr');
    expect(Tr.of(K.coinWord, AppLanguage.tr), 'jeton');
    expect(Tr.of(K.soloDailyCapReached, AppLanguage.ku), contains('zêran'));

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('jeton')),
        reason: '$key: Kurmancî metinde Türkçe "jeton"; karşılığı "zêr"',
      );
    }
  });

  test('açıklama terimi Kurmancîde şîrove olarak kalır', () {
    // Ürün terimi zaten `Şîrove` (`K.explanationTitle`). İnceleme
    // etiketi "Ravahî" deyince aynı açıklama iki adla duruyordu.
    // Tanıtım/rehber "ravekirin" deyince etiket taraması kör kalıyordu.
    expect(Tr.of(K.aciklama, AppLanguage.ku), 'Şîrove:');
    expect(Tr.of(K.explanationTitle, AppLanguage.ku), 'Şîrove');
    expect(Tr.of(K.viewExplanation, AppLanguage.ku), 'Şîrove bibîne');
    expect(
      Tr.of(K.onbDailyBullet, AppLanguage.ku),
      'Dersa rojane: bê dem, bi şîroveyê',
    );

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('ravahî')),
        reason: '$key: Kurmancî metinde "ravahî"; karşılığı "şîrove"',
      );
      expect(
        kurmanci,
        isNot(contains('ravekirin')),
        reason: '$key: Kurmancî metinde "ravekirin"; ürün terimi "şîrove"',
      );
    }
  });

  test('mağaza terimi Kurmancîde dukan olarak kalır', () {
    // Ürün terimi zaten `Dukan` (`K.shop`). Çerçeve koşulu "dikanê"
    // deyince aynı mağaza iki yazımla duruyordu. `i`/`u` farkı
    // `contains('dukan')` taramasını kör eder — turnûva ile aynı sınıf.
    expect(Tr.of(K.shop, AppLanguage.ku), 'Dukan');
    expect(Tr.of(K.shop, AppLanguage.tr), 'Mağaza');
    expect(Tr.of(K.frameReqNeon, AppLanguage.ku), 'Ji dukanê bikire');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        RegExp(r'dikan', caseSensitive: false).hasMatch(kurmanci),
        isFalse,
        reason: '$key: Kurmancî metinde "dikan"; karşılığı "dukan"',
      );
    }
  });

  test('davet kodu Kurmancîde vexwendin olarak kalır', () {
    // Ürün terimi zaten `Koda Vexwendinê` (`K.enterReferralCode`).
    // Misafir yasağı "davetê" deyince aynı kod iki adla duruyordu.
    // Türkçe `davet` kökü `contains('vexwend')` taramasını kör eder.
    expect(Tr.of(K.enterReferralCode, AppLanguage.ku), 'Koda Vexwendinê');
    expect(Tr.of(K.enterReferralCode, AppLanguage.tr), 'Davet Kodu Gir');
    expect(
      Tr.of(K.referralGuestBlocked, AppLanguage.ku),
      contains('Koda vexwendinê'),
    );

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        RegExp(r'davet', caseSensitive: false).hasMatch(kurmanci),
        isFalse,
        reason: '$key: Kurmancî metinde Türkçe "davet"; karşılığı "vexwendin"',
      );
    }
  });

  test('50/50 yardımcısı Kurmancîde nîv bi nîv olarak kalır', () {
    // Ürün terimi zaten `Nîv bi Nîv` (`K.metin`). Rehber "Joker 50/50"
    // deyince aynı yardımcı iki adla duruyordu. Türkçe `joker` kökü
    // İngilizce `\bflashcard\b` sınıfındaki taramayı da kör eder.
    expect(Tr.of(K.metin, AppLanguage.ku), 'Nîv bi Nîv');
    expect(Tr.of(K.metin, AppLanguage.tr), '50/50');
    expect(Tr.of(K.howToPlayBody, AppLanguage.ku), contains('Nîv bi Nîv'));

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        RegExp(r'joker\s*50', caseSensitive: false).hasMatch(kurmanci),
        isFalse,
        reason: '$key: Kurmancî metinde "Joker 50/50"; karşılığı "Nîv bi Nîv"',
      );
    }
  });

  test('joker yardımcısı Kurmancîde alîkarî olarak kalır', () {
    // Ürün terimi zaten `Alîkariya Bersivê` (`K.sikIpucu`). Bitirme
    // ipucu "jokeran" deyince aynı yardımcı Türkçe adla duruyordu.
    // `jokeran` çekimi `joker\s*50` taramasını kör eder — turnûva
    // ile aynı sınıf.
    expect(Tr.of(K.finishQuizHint, AppLanguage.ku), contains('alîkariyan'));
    expect(Tr.of(K.onbRewardBullet, AppLanguage.ku), 'Xelat, zêr û alîkarî');
    expect(Tr.of(K.sikIpucu, AppLanguage.ku), 'Alîkariya Bersivê');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        RegExp(r'joker', caseSensitive: false).hasMatch(kurmanci),
        isFalse,
        reason: '$key: Kurmancî metinde Türkçe "joker"; karşılığı "alîkarî"',
      );
    }
  });

  test('devam düğmesi Kurmancîde bidomîne olarak kalır', () {
    // Ürün terimi zaten `Bidomîne` (`K.continueAction`, `K.devamEt`).
    // Seviye kutusu "Berdawam bike" deyince aynı eylem iki adla
    // duruyordu. Türkçe `devam` kökü `ber-` ile gizlenir.
    expect(Tr.of(K.continueAction, AppLanguage.ku), 'Bidomîne');
    expect(Tr.of(K.devamEt, AppLanguage.ku), 'Bidomîne');
    expect(Tr.of(K.devamEt2, AppLanguage.ku), 'Bidomîne');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        RegExp(r'berdawam', caseSensitive: false).hasMatch(kurmanci),
        isFalse,
        reason: '$key: Kurmancî metinde "berdawam"; karşılığı "bidomîne"',
      );
    }
  });

  test('Google/Apple bağlama Türkçe ile kalıbı taşımaz', () {
    // Giriş `Bi Google têkeve` der. Bağlama "Bi Google ve" deyince
    // Türkçe "ile" `ve` olarak sızar. `ji nû ve` doğru postposition;
    // marka + ve kalıbı şart.
    expect(Tr.of(K.linkGoogle, AppLanguage.ku), 'Bi Google Girêde');
    expect(Tr.of(K.connectingGoogle, AppLanguage.ku), 'Bi Google tê girêdan…');
    expect(Tr.of(K.connectingApple, AppLanguage.ku), 'Bi Apple tê girêdan…');

    final ileCalque = RegExp(r'bi (google|apple) ve\b', caseSensitive: false);
    for (final key in Tr.keys) {
      expect(
        ileCalque.hasMatch(Tr.of(key, AppLanguage.ku)),
        isFalse,
        reason: '$key: Kurmancî metinde Türkçe "ile"; karşılığı "bi X"',
      );
    }
  });

  test('kart görünümü İngilizce flashcard taşımaz', () {
    // Özellik adı `K.flashcards` ile zaten yerel; kip tooltip'i
    // "Flashcard modu" deyince aynı ekranda iki dil duruyordu.
    expect(Tr.of(K.flashcardMode, AppLanguage.ku), 'Moda kartan');
    expect(Tr.of(K.flashcardMode, AppLanguage.tr), 'Kart modu');
    expect(Tr.of(K.flashcards, AppLanguage.ku), 'Kartên Hînbûnê');
    expect(Tr.of(K.flashcards, AppLanguage.tr), 'Hafıza Kartları');
  });

  test('günlük zincîr başlığı İngilizce streak taşımaz', () {
    // Muafiyet parantez içi "(Streak)"i gizliyordu; başlık zaten
    // zincîr / seri diyordu, İngilizce köprü terimin yerini alıyordu.
    expect(Tr.of(K.gunlukSeriStreak, AppLanguage.ku), 'Zincîra Pêşketinê');
    expect(Tr.of(K.gunlukSeriStreak, AppLanguage.tr), 'Günlük Seri');
    expect(Tr.of(K.badgeStreak30Title, AppLanguage.tr), '30 Günlük Seri');
  });

  test('kupa terimi Kurmancîde kûpa olarak kalır', () {
    // Ürün terimi zaten `Kûpa` (`K.tournament`). Avatar simgesi
    // "Kupa" deyince û düşer; `contains('kûpa')` onu görmez — puan
    // ile aynı sınıf.
    expect(Tr.of(K.tournament, AppLanguage.ku), 'Kûpa');
    expect(Tr.of(K.avatarIconKupa, AppLanguage.ku), 'Kûpa');

    final kupaBare = RegExp(r'kupa', caseSensitive: false);
    for (final key in Tr.keys) {
      expect(
        kupaBare.hasMatch(Tr.of(key, AppLanguage.ku)),
        isFalse,
        reason: '$key: Kurmancî metinde û\'süz "kupa"; karşılığı "kûpa"',
      );
    }
  });

  test('çevrimdışı terimi Kurmancîde ne li serhêl olarak kalır', () {
    // Ürün terimi zaten `Ne li serhêl` (`K.offline`). Dondurma çipi
    // "Negirêdayî" deyince aynı durum iki adla duruyordu. 12 harf
    // eşiği birebir Türkçe "Çevrimdışı" çiftini kaçırıyordu.
    expect(Tr.of(K.offline, AppLanguage.ku), 'Ne li serhêl');
    expect(Tr.of(K.streakFreezeOffline, AppLanguage.ku), 'Ne li serhêl');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku);
      expect(
        RegExp(r'negirêdayî', caseSensitive: false).hasMatch(kurmanci),
        isFalse,
        reason: '$key: Kurmancî metinde "negirêdayî"; karşılığı "ne li serhêl"',
      );
    }
  });

  test('oda sohbeti İngilizce chat taşımaz', () {
    // Ürün terimi zaten `Suhbet` (`K.chat`). Türkçe `sohbeta` çekimi
    // `\bchat\b` taramasını da kör eder — serverê ile aynı sınıf.
    expect(Tr.of(K.chat, AppLanguage.ku), 'Suhbet');
    expect(Tr.of(K.chatNoLinks, AppLanguage.ku), contains('suhbeta'));

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('chat')),
        reason: '$key: Kurmancî metinde İngilizce "chat"; karşılığı "suhbet"',
      );
    }
  });

  test('profil rûyê İngilizce avatar taşımaz', () {
    // Ürün terimi zaten `rû` (`K.myAvatar`). Düğme "Avatarê" deyince
    // oyuncu aynı yüzeyi iki adla görür. `Avatarê` çekimi `\bavatar\b`
    // taramasını kör eder — serverê ile aynı sınıf.
    expect(Tr.of(K.myAvatar, AppLanguage.ku), 'Rûyê Min');
    expect(Tr.of(K.editAvatar, AppLanguage.ku), 'Rûyê xwe biguherîne');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('avatar')),
        reason: '$key: Kurmancî metinde İngilizce "avatar"; karşılığı "rû"',
      );
    }
  });

  test('bildirim terimi Kurmancîde ragihandin olarak kalır', () {
    // Ürün terimi zaten `ragihîne` (`K.reportAction`, `K.reportQuestion`).
    // Quiz tostu "Rapor" deyince oyuncu aynı eylemi iki adla görür.
    // Türkçe `rapor` kökü İngilizce `\breport\b` taramasını da kör eder.
    expect(Tr.of(K.reportAction, AppLanguage.ku), 'Ragihîne');
    expect(Tr.of(K.reportSent, AppLanguage.ku), 'Ragihandin hat şandin.');
    expect(Tr.of(K.reportFailed, AppLanguage.ku), 'Ragihandin nehat şandin.');

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('rapor')),
        reason: '$key: Kurmancî metinde Türkçe "rapor"; karşılığı "ragihandin"',
      );
    }
  });

  test('kayıt terimi Kurmancîde tomar olarak kalır', () {
    // Ürün terimi zaten `tomar` (`K.save`, `K.questionSaved`). Quiz tostu
    // "qeydkirin" deyince oyuncu aynı eylemi iki adla görür. Türkçe
    // `kayıt` kökü `qeyd` olarak sızar; İngilizce `save` taraması onu
    // görmez — `sohbeta` ile aynı sınıf.
    expect(Tr.of(K.save, AppLanguage.ku), 'Tomar bike');
    expect(Tr.of(K.questionSaved, AppLanguage.ku), 'Pirs hat tomarkirin.');
    expect(
      Tr.of(K.cevabinKaydedildi, AppLanguage.ku),
      'Bersiva te hat tomarkirin',
    );

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('qeyd')),
        reason: '$key: Kurmancî metinde Türkçe "kayıt"; karşılığı "tomar"',
      );
    }
  });

  test('sunucu terimi İngilizce server taşımaz', () {
    // Ürün terimi zaten `pêşkêşkar` (`K.serverUnreachableTitle`).
    // `serverê` çekimi `\bserver\b` taramasını kör eder — turnûva
    // ile aynı sınıf. Maç gönderilemedi ve gizli favori cevabı
    // İngilizce kalınca aynı kavram iki adla duruyordu.
    expect(
      Tr.of(K.serverUnreachableTitle, AppLanguage.ku),
      contains('Pêşkêşkar'),
    );
    expect(
      Tr.of(K.tournamentMatchSubmitFailed, AppLanguage.ku),
      contains('pêşkêşkarê'),
    );
    expect(
      Tr.of(K.favoriteAnswerHiddenHint, AppLanguage.ku),
      contains('pêşkêşkarê'),
    );

    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      expect(
        kurmanci,
        isNot(contains('server')),
        reason:
            '$key: Kurmancî metinde İngilizce "server"; karşılığı "pêşkêşkar"',
      );
    }
  });

  test('şampiyon ve bronz yerleşik alıntı olarak belgeli', () {
    // Sözlük kararı (2026-09): `şampiyon` ve `bronz` Kurmancî medyada
    // yerleşik alıntılardır. Kanıt: Kurmancî ek alırlar (`şampiyonê`,
    // `şampiyoniyê` — `quiz`→`Quizê` emsali). Arılaştırma kavramı
    // değiştirirdi (`qehreman` = kahraman, `tunc` = bakır alaşımı).
    //
    // Bu test iki şeyi sabitler: kararın dayandığı biçimler yerinde
    // durmalı, ve YENİ bir TR/FR alıntı gözden kaçmamalı. Aşağıdaki
    // liste, Kurmancî karşılığı üründe zaten olan kavramların Türkçe
    // biçimleridir — hiçbiri bugün Ku metinde geçmiyor; biri geçerse
    // ya karşılığı kullanılmalı ya da buraya gerekçesi yazılmalı.
    expect(Tr.of(K.botRaceHint, AppLanguage.ku), 'Şampiyon kûpayê digire!');
    expect(Tr.of(K.champion, AppLanguage.ku), 'Şampiyon!');
    expect(
      Tr.of(K.championCongrats, AppLanguage.ku),
      'Pîroz be! Tu şampiyonê Kûpaya ZanKurdê yî!',
    );
    expect(Tr.of(K.bronzLig, AppLanguage.ku), 'Lîga Bronz');
    expect(Tr.of(K.bronze, AppLanguage.ku), 'Bronz');

    const reviewedLoans = {'şampiyon', 'bronz'};
    const unreviewedLoanPattern = {
      'maç': 'pêşbirk',
      'lig': 'lîg',
      'final': 'dawî',
      'puan': 'pûan',
      'ödül': 'xelat',
      'seviye': 'ast',
      'yarış': 'pêşbirk',
      'turnuva': 'kûpa',
      'sezon': 'demsal',
      'madalya': 'medalya',
      'şampiyonluk': 'şampiyonî',
      'heyecan': 'kelecan',
      'macera': 'serpêhatî',
      'görev': 'erk',
      'sıralama': 'rêzkirin',
      'hediye': 'diyarî',
      'başarı': 'serkeftin',
    };

    final offenders = <String>[];
    for (final key in Tr.keys) {
      final kurmanci = Tr.of(key, AppLanguage.ku).toLowerCase();
      for (final entry in unreviewedLoanPattern.entries) {
        if (reviewedLoans.contains(entry.key)) continue;
        if (kurmanci.contains(entry.key)) {
          offenders.add(
            '$key: Kurmancî metinde gözden geçirilmemiş "${entry.key}"; '
            'karşılığı "${entry.value}" ya da gerekçe gerekli',
          );
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(6).join('\n'));
  });

  test('muafiyet listesi ölü kelime taşımıyor', () {
    // Muaf sayılan bir kelime hiçbir metinde geçmiyorsa liste ölüdür ve
    // gereksiz yere kuralı gevşetir.
    for (final entry in allowedByLanguage.entries) {
      final language = AppLanguage.values.firstWhere(
        (l) => l.code == entry.key,
      );
      final live = <String>{};
      for (final key in Tr.keys) {
        final text = Tr.of(key, language).toLowerCase();
        for (final word in entry.value) {
          if (RegExp('\\b$word\\b').hasMatch(text)) live.add(word);
        }
      }
      final dead = entry.value.difference(live);
      expect(
        dead,
        isEmpty,
        reason:
            '${entry.key}: bu kelimeler hiçbir metinde geçmiyor; '
            'muafiyetlerini kaldırın: ${dead.join(", ")}',
      );
    }
  });
}
