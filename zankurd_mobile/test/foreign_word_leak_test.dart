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
///     girmiş. "Streak" ise parantez içinde AÇIMLAMA olarak duruyor
///     ("Zincîra Pêşketinê (Streak)") — kavramı başka uygulamalardan
///     tanıyan oyuncuya köprü kuruyor, terimin yerini almıyor.
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
      'streak', // yalnız parantez içi açımlama: "Zincîra Pêşketinê (Streak)"
      'xp', // birim kısaltması, iki dilde de aynı
      'zankurd', // ürünün kendi adı
    },
    'tr': {
      'premium',
      'quiz',
      'streak',
      'xp',
      'zankurd',
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
