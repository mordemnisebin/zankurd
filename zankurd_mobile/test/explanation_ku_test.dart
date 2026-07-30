import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/explanation_ku.dart';

/// 2026-07-30: çıktı artık ürünün «guillemet» biçimini taşıyor.
///
/// Banka üç ayrı tırnak kuralını birden taşıyordu (düz tek, düz çift ve
/// «»); oyuncu arka arkaya iki soru çözünce alıntı işareti değişiyordu.
/// Banka «» kuralında birleştirilince motorun çıktısı da ona uydu —
/// çevrilen açıklama, çevrilmeyenin yanında yabancı durmasın.
///
/// Motor girişte tırnaktan bağımsızdır: kurallar tarihsel olarak iki
/// biçimle yazıldığı için metin her iki varyantta da denenir.
void main() {
  test('"X" Y demektir. kalıbı Kurmancî\'ye çevrilir', () {
    expect(
      explanationToKu('«av» «su» demektir.'),
      'Peyva «av» tê wateya «su».',
    );
  });

  test('"X" kelimesi "Y" anlamına gelmez. kalıbı Kurmancî\'ye çevrilir', () {
    expect(
      explanationToKu('«mase» kelimesi «sandalye» anlamına gelmez.'),
      'Peyva «mase» nayê wateya «sandalye».',
    );
  });

  test('eşleşmeyen serbest metin ham Türkçe kalmaz, çerçevelenir', () {
    expect(
      explanationToKu('Tamamen bilinmeyen bir cümle burada.'),
      'Şirove: Tamamen bilinmeyen bir cümle burada.',
    );
  });
}
