// Kusur: Pêşbirk ekranındaki hızlı düello başlığı "Hevrikekî nêzîkî asta te"
// 320 pt'de "… asta / te" diye tamlamanın ortasından kırılıyordu.
// Niçin sessiz: geniş ekranda tek satıra sığar; yalnız dar telefonda görünür.
// Bekçi: son iki sözcük bölünmez boşlukla bağlı, başlık "… / asta te" kırılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

void main() {
  test('son iki sözcük bölünmez boşlukla bağlanır', () {
    expect(
      glueLastWords('Hevrikekî nêzîkî asta te'),
      'Hevrikekî nêzîkî asta te',
    );
    expect(glueLastWords('Tek'), 'Tek');
  });
}
