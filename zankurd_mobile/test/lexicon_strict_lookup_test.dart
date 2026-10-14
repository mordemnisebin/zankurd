import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';

/// Dokunarak anlam: ayrı Kurmancî harfleri birleşmez (2026-10-14).
///
/// ## Kusur
///
/// `LearnerLexicon.lookup` sözcük dizinini arama katlamasıyla
/// (`foldForSearch`: ê->e, î->i, û->u, ş->s, ç->c) anahtarlıyordu; `putIfAbsent`
/// de sözlükte ilk geleni tutuyordu. Kurmancîde bu harfler AYRI harflerdir:
/// `şêr` (aslan) / `şer` (savaş) / `ser` (baş), `çar` (dört) / `car` (kez),
/// `dîn` (din) / `din` (öteki), `rê` (yol) / `re`, `cîhan` (dünya) / `cih`
/// (yer). Cümledeki `ser`e ya da `caran`a dokunan öğrenen "Aslan" ya da "Dört"
/// görüyordu. Ayrıca `Şêr`in biçimleri aksansız yazılmıştı (`serî`, `seran`):
/// o biçimler de yanlış maddeye çıpalıyordu.
///
/// ## Niçin sessizdi
///
/// Balon her zaman BİR anlam gösteriyordu; yanlış sözcüğün anlamı da düzgün
/// görünür, ne hata ne boş balon çıkar. Testler yalnız doğru yazımı sınadı ve
/// "aksansız da bulur" beklentisi (`dur` -> `Dûr`) kusuru bir özellik gibi
/// kutsuyordu. Arama kutusu ayrı: orada kullanıcı aksansız yazar, katlama
/// doğrudur ve değişmedi (`search` hâlâ `foldForSearch` kullanır).
///
/// ## Bekçi
///
/// Her terim ve biçim, tam yazımıyla aratıldığında, terimi ya da biçimi AYNI
/// yazımla taşıyan bir maddeye gitmelidir; ayrıca yukarıdaki çiftler tek tek
/// sınanır.
void main() {
  // Üretim anahtarından bağımsız, katlamasız karşılaştırma: küçük harf,
  // birleşik harf, harf dışı atılır; `ê` ile `e` HİÇ eşit sayılmaz.
  String literal(String word) => normalizeKurmanciText(
    word,
  ).replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');

  Set<String> wordsOf(LearnerLexiconEntry entry) => {
    for (final alt in entry.termKu.split(' / '))
      if (!alt.trim().contains(' ')) literal(alt),
    for (final form in entry.forms) literal(form),
  };

  test('her terim ve biçim kendi yazımıyla kendi maddesine çıkar', () {
    final bad = <String>[];
    for (final entry in LearnerLexicon.entries) {
      for (final word in wordsOf(entry)) {
        final found = LearnerLexicon.lookup(word);
        if (found == null || !wordsOf(found).contains(word)) {
          bad.add('$word -> ${found?.termKu} (beklenen ${entry.termKu})');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('ayrı Kurmancî harfleri farklı sözcüklerdir', () {
    String? term(String w) => LearnerLexicon.lookup(w)?.termKu;

    expect(term('şêr'), 'Şêr');
    expect(term('şêrê'), 'Şêr');
    expect(term('ser'), 'Ser');
    expect(term('serê'), 'Ser');
    expect(term('şer'), 'Şer');

    expect(term('çar'), 'Çar');
    expect(term('çaran'), 'Çar');
    expect(term('car'), 'Car');
    expect(term('caran'), 'Car');

    expect(term('din'), 'Din');
    expect(term('dînî'), 'Dîn');
    expect(term('cîhan'), 'Cîhan');
    expect(term('cihê'), 'Cih');
    expect(term('rêya'), 'Rê');
    expect(term('dê'), 'Dê');
    expect(term('de'), 'De');
  });

  test('arama kutusu aksansız yazımı hâlâ bulur', () {
    expect(LearnerLexicon.search('ser').map((e) => e.termKu), contains('Şêr'));
    expect(LearnerLexicon.search('dur').map((e) => e.termKu), contains('Dûr'));
  });
}
