import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';

/// Türkçe klavyeli telefonda `i` noktasız `ı` olarak yazılsa da sözlük bulur.
///
/// ## Kusur
///
/// 2026-10-07 simülatör QA'sında Türkçe klavye `dizanim` yerine `dızanım`,
/// `siv` yerine `sıv` yazdırdı; sözlük aramasında "sonuç yok" çıkacağı
/// kuşkusu doğdu. Kurmancî yazımında noktasız `ı` YOKTUR, yani `ı` her zaman
/// `i`nin klavye gölgesidir ve `i` ile eşlenmelidir (aynı şekilde büyük
/// `İ`/`I`).
///
/// Sessizdi çünkü arama testleri hep ASCII ya da Kurmancî harflerle yazılıyor;
/// Türkçe klavyenin ürettiği harfi sınayan yoktu — ve `toLowerCase()` Dart'ta
/// `I`yı `i` yapar, `ı` ile buluşmasını ancak açık bir katlama sağlar.
void main() {
  test('noktasız ı ve büyük İ/I aramada i gibi eşleşir', () {
    expect(LearnerLexicon.foldForSearch('dızanım'), 'dizanim');
    expect(LearnerLexicon.foldForSearch('SIV'), 'siv');
    expect(LearnerLexicon.foldForSearch('İ'), 'i');

    for (final (typed, expected) in [
      ('dızanım', 'Zanîn'),
      ('sıv', 'Şîv'),
      ('Sıv', 'Şîv'),
      ('SIV', 'Şîv'),
    ]) {
      final terms = LearnerLexicon.search(typed).map((e) => e.termKu);
      expect(terms, contains(expected), reason: '"$typed" aramasında yok');
    }
  });

  test('dokunmayla sözcük arama da ı yazımını bulur', () {
    expect(LearnerLexicon.lookup('Şîv')?.termKu, 'Şîv');
    // `ı` yine `i`'nin klavye gölgesidir (`dızanım` -> `dizanim`); ama dokunma
    // eşlemesi aksan harflerini katlamaz, bu yüzden `sıv` (= `siv`) artık
    // `Şîv` değildir (bkz. lexicon_strict_lookup_test.dart).
    expect(LearnerLexicon.lookup('dızanım')?.termKu, 'Zanîn');
    expect(LearnerLexicon.lookup('sıv')?.termKu, isNot('Şîv'));
  });
}
