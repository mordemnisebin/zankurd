import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

/// Mağaza fiyatının İKİ kaynağının aynı şeyi söylediğinin bekçisi.
///
/// ## Kusur
///
/// Vitrin fiyatı iki yerden gelebiliyor: uzak `shop_items` tablosu (varsa
/// o kazanır) ve statik `ShopItem.catalog` (yedek). İkisi 2026-08-12'ye
/// kadar hiç karşılaştırılmadı ve karşılaştırılamıyordu da — Dart tarafı
/// tabloyu `shopShopItem.catalog` diye soruyordu, yani bozuk bir adla;
/// sorgu her açılışta hata verip sessizce yedeğe düşüyordu. Uzak katalog
/// çalışmadığı için ayrışma da görünmüyordu.
///
/// Ad düzeltilince ayrışma anlamlı oldu: üretim 2026-08-26'ya kadar
/// 2026-07-13 tohumunun eski fiyatlarını taşıyordu (200/600/750/1000).
/// Göç uygulanmazsa düzeltilmiş istemci uzak tabloyu okuyunca çıpa
/// sessizce ezilirdi. Çıpa 2026-08-26'da canlıya alındı.
///
/// Bu bekçi, göç dosyasındaki fiyatları statik katalogla karşılaştırır.
/// Biri değişip öteki unutulursa test düşer.
void main() {
  final migration = File('supabase/2026-08-12_shop_price_anchor.sql');

  test('göç dosyası duruyor', () {
    expect(
      migration.existsSync(),
      isTrue,
      reason:
          'Fiyat çıpasını uzak tabloya taşıyan göç silinmiş. İstemci artık '
          '`shop_items` okuyor; göç olmadan üretimde eski fiyatlar döner.',
    );
  });

  test('göçteki fiyatlar statik katalogla birebir aynı', () {
    final sql = migration.readAsStringSync();

    // Göç yalnız `cost` sütununa dokunur; her ürün tek bir UPDATE satırıdır.
    //
    // İlk taslak bütün satırı `insert … on conflict do update` ile yeniden
    // yazıyordu — başlık, açıklama, ikon ve renk dahil. Yayındaki uygulama
    // bu alanları tablodan okuduğu için (bkz. `2026-07-23_shop_items_sync
    // .sql` başlığı) fiyat değiştirmek isterken üretimde metin ve renk
    // değiştirme riski taşıyordu. Bu bekçi de o yüzden UPDATE biçimini
    // bekler: göç yeniden genişlerse buradan düşer.
    final entries = RegExp(
      r"update\s+public\.shop_items\s+set\s+cost\s*=\s*(\d+)\s+where\s+id\s*=\s*'([a-z_]+)'",
      caseSensitive: false,
    ).allMatches(sql);

    final costsInSql = {
      for (final match in entries) match.group(2)!: int.parse(match.group(1)!),
    };

    expect(
      costsInSql,
      isNotEmpty,
      reason:
          'Göç dosyasından hiç fiyat okunamadı; dosyanın biçimi değiştiyse '
          'bu bekçi de güncellenmeli, yoksa sessizce hiçbir şey doğrulamaz.',
    );

    final costsInDart = {
      for (final item in ShopItem.catalog) item.id: item.cost,
    };

    for (final entry in costsInSql.entries) {
      expect(
        costsInDart[entry.key],
        entry.value,
        reason:
            '«${entry.key}» göçte ${entry.value}, statik katalogda '
            '${costsInDart[entry.key]}. Uzak tablo varsa o kazanır: iki '
            'kaynak ayrıştığında oyuncu hangi fiyatı göreceğini şansa '
            'bırakır.',
      );
    }

    // Yalnız yönü tek taraflı denetlemek yetmez: statik katalogda olup
    // göçte olmayan bir ürün, uzak tabloya hiç yazılmamış demektir ve
    // uzak katalog devreye girdiğinde vitrinden düşer.
    expect(
      costsInDart.keys.toSet().difference(costsInSql.keys.toSet()),
      isEmpty,
      reason:
          'Bu ürünler statik katalogda var ama göçte yok; uzak katalog '
          'okunduğunda vitrinde görünmezler.',
    );
  });

  test('çark arbitrajı iki kaynakta da kapalı', () {
    // Çarkın azami ödülü 100. `spin_wheel_extra` bir çark hakkı SATTIĞI
    // için fiyatı 100'ün altına inerse döngü kâr eder.
    const wheelMaxReward = 100;
    final spin = ShopItem.catalog.firstWhere(
      (item) => item.id == 'spin_wheel_extra',
    );
    expect(
      spin.cost,
      greaterThan(wheelMaxReward),
      reason:
          'Ekstra çevirme, çarkın azami ödülünden ucuza satılırsa sınırsız '
          'jeton pompası olur.',
    );
    // Veritabanı tarafında da savunulmalı — ve KALICI olarak. Göçün ilk
    // taslağında taban yalnız bir `do` bloğuydu: dosya koştuğu an doğruydu,
    // sonrasında hiçbir şey tutmuyordu. Şimdi bir CHECK kısıtı var; her
    // yazım onun altından geçiyor.
    final sql = migration.readAsStringSync();
    expect(
      sql,
      contains('shop_items_spin_wheel_above_wheel_max'),
      reason:
          'Taban kısıtı kaldırılmış. Tek seferlik bir denetim, ertesi gün '
          'başka bir göçün fiyatı 100\'ün altına çekmesini engellemez.',
    );
    expect(
      sql,
      contains("check (id <> 'spin_wheel_extra' or cost > 100)"),
      reason: 'Kısıtın gövdesi değişmiş; koruduğu değişmez artık başka.',
    );
  });

  test('aşılan eski göçler çıpayı sessizce geri alamıyor', () {
    // `2026-07-13` ve `2026-07-23` aynı birincil anahtarları ESKİ
    // fiyatlarla upsert eder ve ikisi de kendini "yeniden çalıştırma
    // güvenli" ilan eder. 2026-08-12'de yerelde ölçüldü: çıpadan sonra
    // 07-23'ü yeniden koşmak 120/480'i tek komutla 200/750 yaptı ve hiçbir
    // uyarı vermedi.
    //
    // İlk çözüm o dosyaları tümden durduran bir `raise exception` bloğuydu.
    // O çözüm YANLIŞTI ve ikinci bir kusur üretti: `2026-07-13` yalnız
    // katalogu değil `room_messages` ve `suggested_questions` tablolarını da
    // kurar, üstelik onları INSERT'ten SONRA kurar. Durdurma, o iki tabloyu
    // yeniden kurma yolunu da kapatıyordu — fiyatı korumak için başka bir
    // şeyi kırmak.
    //
    // Doğru çözüm dar olanı: `cost` çakışma güncellemesinden çıkarıldı.
    // Dosyalar hâlâ koşar ve metni eşitler; fiyata dokunamazlar.
    for (final path in const [
      'supabase/2026-07-13_shop_chat_suggestions.sql',
      'supabase/2026-07-23_shop_items_sync.sql',
    ]) {
      final superseded = File(path);
      expect(superseded.existsSync(), isTrue, reason: '$path bulunamadı');
      final body = superseded.readAsStringSync();

      final conflictClause = RegExp(
        r'ON CONFLICT \(id\) DO UPDATE SET(.*?);',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(body);
      expect(
        conflictClause,
        isNotNull,
        reason: '$path içindeki upsert biçimi değişmiş; bekçi kör kaldı.',
      );
      expect(
        conflictClause!.group(1),
        isNot(contains('cost')),
        reason:
            '$path çakışmada `cost` güncelliyor. Bu dosya çıpadan ÖNCE '
            'yazıldı ve eski fiyatları taşıyor; yeniden koşulduğunda '
            'ölçülerek belirlenmiş fiyatları sessizce geri alır.',
      );
      expect(
        body,
        isNot(contains('RAISE EXCEPTION')),
        reason:
            '$path yeniden durdurulmuş. Durdurma, dosyanın fiyat DIŞINDAKİ '
            'işlerini de engeller; koruma dar olmalı.',
      );
    }
  });
}
