import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/avatar_presets.dart';
import 'package:zankurd_mobile/src/utils/player_identity.dart';

/// Avatar rengi dil değişince oynamamalı.
///
/// ## Kusur
///
/// 2026-08-10, simülatörde: dili Kurmancî'den Türkçe'ye alan oyuncunun
/// avatarı maviden turuncuya döndü.
///
/// Sebep `PlayerIdentity`'nin kendi kuralıydı — "renk daima `resolveName`
/// sonucundan türetilir". `resolveName` yer tutucu adlarda dile göre farklı
/// metin döndürüyor («Oyuncu» / «Lîstikvan») ve renk isim hash'inden geldiği
/// için birlikte kayıyordu.
///
/// Adını gerçekten seçmiş oyuncu etkilenmiyordu; kusur yalnız ad kapısını
/// atlayanlarda görünüyordu — yani ilk açılıştaki en kırılgan anda.
///
/// Baş harf ile renk bilinçli olarak AYRILDI: harf bir etikettir ve
/// gösterilen adı izlemeli (ad «Oyuncu» yazarken «L» göstermek daha kötü
/// olurdu), renk ise kimliktir ve sabit kalmalı.
void main() {
  test('yer tutucu adlarda renk tohumu dilden bağımsız', () {
    // `resolveName`in iki dildeki çıktısı — kusurun tam olarak geçtiği yol.
    const ku = 'Lîstikvan';
    const tr = 'Oyuncu';

    expect(
      PlayerIdentity.resolveColorSeed(ku),
      PlayerIdentity.resolveColorSeed(tr),
      reason: 'Yer tutucu adlar farklı tohum üretiyor; renk dile göre kayar',
    );
    expect(
      avatarColorForName(PlayerIdentity.resolveColorSeed(ku)),
      avatarColorForName(PlayerIdentity.resolveColorSeed(tr)),
    );
  });

  test('ham sunucu varsayılanları da aynı tohuma düşer', () {
    const defaults = [
      'ZanKurd Oyuncusu',
      'Lîstikvanê ZanKurd',
      'ZanKurd',
      'Oyuncu',
      'Lîstikvan',
      '',
      '   ',
      null,
    ];
    final seeds = defaults.map(PlayerIdentity.resolveColorSeed).toSet();
    expect(
      seeds,
      hasLength(1),
      reason: 'Varsayılan adların hepsi tek bir tohumu paylaşmalı: $seeds',
    );
  });

  test('gerçek ad kendi rengini korur', () {
    // Kullanıcı adını seçtiyse renk ondan türemeli — yer tutucu kovasına
    // düşerse bütün oyuncular aynı renge çöker.
    expect(PlayerIdentity.resolveColorSeed('Zelal'), 'Zelal');
    expect(PlayerIdentity.resolveColorSeed('  Zelal  '), 'Zelal');
    expect(
      avatarColorForName(PlayerIdentity.resolveColorSeed('Zelal')),
      isNot(avatarColorForName(PlayerIdentity.resolveColorSeed('Oyuncu'))),
      reason:
          'Seçilmiş ad ile varsayılan aynı rengi almamalı; aksi hâlde tohum '
          'ayrımı hiçbir şey yapmıyor demektir',
    );
  });

  test('baş harf dile göre değişmeye DEVAM eder', () {
    // Bu bir kusur değil, bilinçli ayrım: harf gösterilen adı izler.
    expect(PlayerIdentity.resolveInitial(null, isKu: true), 'L');
    expect(PlayerIdentity.resolveInitial(null, isKu: false), 'O');
  });
}
