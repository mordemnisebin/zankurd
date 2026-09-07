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
