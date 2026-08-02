import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mağazadaki bir ürün sunucuda satın alınamıyordu (2026-08-02, A-01).
///
/// `avatar_frame_neon` üç yerde birden vardı — `shop_items` seed'inde 600
/// coin fiyatıyla, istemci kataloğunda ve `_supportedItemIds` kümesinde —
/// ama `spend_coins`in izin listesinde YOKTU. Kullanıcı ürünü görüyor,
/// satın almaya basıyor ve `{'success': false, 'error': 'product not
/// available'}` alıyordu; `spendCoins` bu dizeyi atıp yalnız `false`
/// döndürdüğü için ekranda gerekçesiz bir "satın alma başarısız" çıkıyordu.
///
/// Kusurun sinsi yanı: istemci tarafı 2026-07-31'de ZATEN düzeltilmişti
/// (`AvatarFrame.neon` eklendi, `avatar_editor_screen` çerçeveyi
/// `hasPurchased` ile açıyor). Yani iki taraf ayrı ayrı doğru görünüyordu;
/// kusur yalnız aralarındaki sözleşmedeydi ve hiçbir test o sözleşmeye
/// bakmıyordu.
///
/// Bu bekçi tam olarak oraya bakar: istemcinin sattığı her ürün, sunucunun
/// izin listesinde bulunmalıdır. Kaynak olarak en güncel `spend_coins`
/// tanımını taşıyan göç dosyası okunur — birim testi canlı veritabanına
/// bağlanamaz, ama göç dosyası uygulanacak sözleşmenin ta kendisidir.
void main() {
  /// `spend_coins`i tanımlayan göçler arasında en yeni tarihli olanı seçer.
  /// Dosya adları `YYYY-MM-DD_...` biçiminde olduğu için alfabetik sıra
  /// kronolojik sıradır.
  File latestSpendCoinsMigration() {
    final dir = Directory('supabase');
    final matches =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .where(
              (f) =>
                  f.readAsStringSync().contains('function public.spend_coins'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(
      matches,
      isNotEmpty,
      reason: 'spend_coins tanımlayan hiçbir göç bulunamadı',
    );
    return matches.last;
  }

  /// `purchase_` dalındaki `array[...]` bloğundan ürün kimliklerini çıkarır.
  Set<String> serverAllowlist(String sql) {
    final guard = RegExp(
      r"left\(p_reason,\s*9\)\s*=\s*'purchase_'(.*?)\)\s*\)\s*then",
      dotAll: true,
    ).firstMatch(sql);
    expect(
      guard,
      isNotNull,
      reason: 'spend_coins içinde purchase_ izin listesi bulunamadı',
    );
    return RegExp(
      "'([a-z0-9_]+)'",
    ).allMatches(guard!.group(1)!).map((m) => m.group(1)!).toSet();
  }

  /// İstemcinin gerçekten sattığı ürünler: `_supportedItemIds` kümesi.
  /// Bu küme dosyanın kendi yorumuna göre "o ürün gerçekten bir şey yapıyor"
  /// anlamına gelir, yani satın alınabilir olması beklenir.
  Set<String> clientCatalogue() {
    final src = File('lib/src/screens/shop_screen.dart').readAsStringSync();
    final block = RegExp(
      r'_supportedItemIds\s*=\s*\{(.*?)\}',
      dotAll: true,
    ).firstMatch(src);
    expect(
      block,
      isNotNull,
      reason: 'shop_screen.dart içinde _supportedItemIds bulunamadı',
    );
    return RegExp(
      "'([a-z0-9_]+)'",
    ).allMatches(block!.group(1)!).map((m) => m.group(1)!).toSet();
  }

  test('istemcinin sattığı her ürün sunucu izin listesinde var', () {
    final migration = latestSpendCoinsMigration();
    final allowed = serverAllowlist(migration.readAsStringSync());
    final offered = clientCatalogue();

    final unpurchasable = offered.difference(allowed);
    expect(
      unpurchasable,
      isEmpty,
      reason:
          'Bu ürünler mağazada görünüyor ama ${migration.path} içindeki '
          'spend_coins izin listesinde yok; satın alma "product not '
          'available" ile reddedilir: $unpurchasable',
    );
  });

  test('izin listesi katalogda olmayan ürün taşımıyor', () {
    final allowed = serverAllowlist(
      latestSpendCoinsMigration().readAsStringSync(),
    );
    final offered = clientCatalogue();

    // Ters yön de anlamlıdır: sunucunun tanıdığı ama istemcinin satmadığı
    // bir kimlik ya ölü koddur ya da kaldırılmış bir ürünün kalıntısıdır.
    expect(
      allowed.difference(offered),
      isEmpty,
      reason: 'sunucu izin listesinde katalogda karşılığı olmayan ürün var',
    );
  });

  test('neon çerçeve özelinde regresyon bekçisi', () {
    // Kusur tam olarak bu kimlikteydi; adıyla sabitlemek, genel testin
    // yanlışlıkla gevşetilmesi hâlinde bile ikinci bir kapı bırakır.
    final allowed = serverAllowlist(
      latestSpendCoinsMigration().readAsStringSync(),
    );
    expect(
      allowed,
      contains('avatar_frame_neon'),
      reason:
          '600 coinlik Neon çerçeve yeniden satın alınamaz hâle geldi '
          '(bkz. 2026-08-02 denetimi, P1-006)',
    );
  });
}
