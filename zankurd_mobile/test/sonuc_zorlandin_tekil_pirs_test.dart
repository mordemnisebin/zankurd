// 2026-10-20 (tur 9b): "Nerelerde zorlandın?" Kurmancî şablonu tek soruda.
//
// ## Kusur
//
// '{name}: di {answered} pirsan de ...' şablonu sayı 1 iken "di 1 pirsan de"
// diyordu; Kurmancîde tekil oblik "pirsê" gerekir. Kurmancî kurulu (Grok 4.7
// + Muse Spark) uyuştu.
//
// ## Niçin sessiz kalırdı
//
// Şablon sayıdan habersiz tek dizedir; çoğul biçim her sayıda geçerli
// görünür ve testler yalnız çoğul örnek (3+) kullanıyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

void main() {
  test('tekil anahtar "pirsê", çoğul anahtar "pirsan" (Kurmancî)', () {
    final one = Tr.forKu(K.outcomeReviewOne, true, {
      'name': 'Dil',
      'answered': '1',
      'wrong': '1',
    });
    final many = Tr.forKu(K.outcomeReview, true, {
      'name': 'Dil',
      'answered': '3',
      'wrong': '2',
    });
    expect(one, contains('di 1 pirsê de'));
    expect(one, isNot(contains('pirsan')));
    expect(many, contains('di 3 pirsan de'));
  });

  test('Türkçe tekil şablon çoğulla aynı', () {
    final args = {'name': 'Dil', 'answered': '1', 'wrong': '1'};
    expect(
      Tr.forKu(K.outcomeReviewOne, false, args),
      Tr.forKu(K.outcomeReview, false, args),
    );
  });
}
