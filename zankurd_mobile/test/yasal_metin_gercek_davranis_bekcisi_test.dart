/// Yasal sayfalar uygulamanın GERÇEK davranışıyla aynı kalsın (GPT-6 Pro 2.1.2
/// alan 7 bulguları 1.2, 1.4, 1.5, 1.8, 1.10).
///
/// ## Kusurlar
///
/// * Koşullar, sunulmayan Pro aboneliğini mevcut hizmet gibi anlatıyordu.
/// * Gizlilik metni analitik kapalıyken yazılan günlük etkinlik kaydını
///   söylemiyordu.
/// * RevenueCat için "silme talebi iletilir" deniyordu; uygulama iletmiyor.
/// * Avatar dosyası silinemezse saatlik süpürmeye dek erişilebilir kalıyordu;
///   silme sayfası koşulsuz "silindi" diyordu.
/// * "Ebeveyn onayıyla kullanabilir" deniyordu; uygulama onay doğrulamıyor.
///
/// ## Niçin sessiz kalırdı
///
/// Metin bir HTML dosyasıdır; kodla çelişse hiçbir derleme ya da test
/// kırılmaz. Bekçi çelişen eski cümlelerin geri gelmediğini ve yeni doğru
/// cümlelerin yerinde durduğunu doğrular.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String ad) => File('web/$ad').readAsStringSync();

void main() {
  final privacy = _oku('privacy.html');
  final terms = _oku('terms.html');
  final silme = _oku('delete-account.html');

  test('13 yaş altı: doğrulanamayan ebeveyn onayı iddiası yok', () {
    for (final metin in [privacy, terms]) {
      expect(
        metin,
        isNot(contains('ebeveyninin ya da yasal vasisinin onayıyla')),
      );
      expect(metin, isNot(contains('razîbûna dê û bavê xwe')));
      expect(metin, isNot(contains('razîbûn û çavdêriya dê û bavê')));
    }
    expect(privacy, contains('Yaş beyanım'));
    expect(privacy, contains('Daxuyaniya temenê min'));
    expect(terms, contains('Yaş beyanım'));
  });

  test('Pro: koşullar "şu anda sunulmuyor" der', () {
    expect(terms, contains('Şu anda abonelik sunulmuyor'));
    expect(terms, contains('Niha abonetî nayê pêşkêşkirin'));
    expect(terms, isNot(contains('İsteğe bağlı bir abonelik vardır')));
    expect(terms, isNot(contains('Abonetiyek bijarte heye')));
  });

  test('etkinlik sayacı: kapalıyken yazılmaz, metinde var', () {
    expect(privacy, contains('Günlük etkinlik sayacı'));
    expect(privacy, contains('Jimarkera çalakiya rojane'));
    expect(privacy, contains('Kullanım analizi kapalıyken bu kayıt yazılmaz'));
  });

  test('RevenueCat: otomatik silme vaadi yok, talep üzerine denir', () {
    for (final metin in [privacy, silme]) {
      expect(metin, isNot(contains('silme talebi iletilir')));
      expect(
        metin,
        isNot(contains('daxwaza jêbirinê ji RevenueCat re jî tê şandin')),
      );
    }
    expect(privacy, contains('otomatik silmez'));
    expect(silme, contains('otomatik silmez'));
  });

  test('avatar: koşulsuz "silindi" yok, süpürme süresi söylenir', () {
    expect(silme, contains('saatlik temizlikle en geç yaklaşık bir saat'));
    expect(
      privacy,
      contains('saatlik temizlik işiyle en geç yaklaşık bir saat'),
    );
    expect(
      silme,
      isNot(contains('yüklediğin profil fotoğrafı kalıcı olarak silinir')),
    );
  });

  test('iletişim adresi her yasal sayfada iletisim@zankurd.com', () {
    for (final metin in [privacy, terms, silme]) {
      final adresler = RegExp(
        r'[\w.+-]+@zankurd\.com',
      ).allMatches(metin).map((m) => m.group(0)).toSet();
      expect(adresler, {'iletisim@zankurd.com'});
    }
  });
}
