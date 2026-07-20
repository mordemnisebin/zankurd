import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/explanation_ku.dart';

void main() {
  test('"X" Y demektir. kalıbı Kurmancî\'ye çevrilir', () {
    expect(
      explanationToKu('"av" "su" demektir.'),
      'Peyva "av" tê wateya "su".',
    );
  });

  test('"X" kelimesi "Y" anlamına gelmez. kalıbı Kurmancî\'ye çevrilir', () {
    expect(
      explanationToKu('"mase" kelimesi "sandalye" anlamına gelmez.'),
      'Peyva "mase" nayê wateya "sandalye".',
    );
  });

  test('eşleşmeyen serbest metin ham Türkçe kalmaz, çerçevelenir', () {
    expect(
      explanationToKu('Tamamen bilinmeyen bir cümle burada.'),
      'Şirove: Tamamen bilinmeyen bir cümle burada.',
    );
  });
}
