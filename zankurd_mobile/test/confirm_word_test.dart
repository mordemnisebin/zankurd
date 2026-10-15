/// Hesap silme onay sözcüğü (`ConfirmWord`) bekçisi.
///
/// Kusur: `value.trim() == 'SIL'` Türkçe klavyenin ürettiği `SİL`i ve
/// Kurmancî `JÊ BIBE` için `Ê` olmayan klavyeyi reddediyordu; Apple'ın
/// zorunlu hesap silme akışının son düğmesi hiç açılmıyordu. Testler hep
/// tam `SIL` yazdığı için sessiz kaldı.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/confirm_word.dart';

void main() {
  test('Türkçe "SIL" için Türkçe klavye çeşitleri kabul edilir', () {
    for (final typed in ['SIL', 'sil', 'SİL', 'Sil', 'sıl', ' SİL ', 'S İ L']) {
      // Son örnek (araya boşluk) bilerek REDDEDİLİR: boşluklar tek boşluğa
      // iner ama silinmez.
      final expected = typed != 'S İ L';
      expect(ConfirmWord.matches(typed, 'SIL'), expected, reason: typed);
    }
  });

  test('Kurmancî "JÊ BIBE" aksansız ve küçük harfle de kabul edilir', () {
    for (final typed in [
      'JÊ BIBE',
      'je bibe',
      'Je Bibe',
      'JE BIBE',
      'jê bibe',
      'JÊ  BIBE',
      '  jê   bibe ',
      // e + birleşik circumflex (bazı klavyeler/yapıştırma)
      'JÊ BIBE',
    ]) {
      expect(ConfirmWord.matches(typed, 'JÊ BIBE'), isTrue, reason: typed);
    }
  });

  test('yanlış sözcük ve boş giriş reddedilir', () {
    expect(ConfirmWord.matches('', 'SIL'), isFalse);
    expect(ConfirmWord.matches('SI', 'SIL'), isFalse);
    expect(ConfirmWord.matches('SILL', 'SIL'), isFalse);
    expect(ConfirmWord.matches('JÊ', 'JÊ BIBE'), isFalse);
    expect(ConfirmWord.matches('', ''), isFalse);
  });

  test('Türkçe katlama: İ ı I i, ê î û ç ş', () {
    expect(ConfirmWord.normalize('İIıi'), 'iiii');
    expect(ConfirmWord.normalize('ÊêÎîÛûÇçŞş'), 'eeiiuuccss');
  });
}
