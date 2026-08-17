import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/coin_prices.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';

/// İstemcinin ödediği tutar ile sunucunun beklediği tutar aynı olmalı.
///
/// ## Kusur sınıfı
///
/// `spend_coins` RPC'si tutarı KENDİ tablosundan doğrular:
///
/// ```sql
/// v_expected := case p_reason
///   when 'wildcard_fifty_fifty' then 20
///   ...
/// if p_amount is distinct from v_expected then
///   return jsonb_build_object('success', false, 'error', 'invalid price');
/// ```
///
/// İstemci bir joker fiyatını değiştirir de göç yazılmazsa (ya da tersi),
/// her satın alma sunucuda reddedilir. Görünen tek şey gerekçesiz bir
/// başarısızlıktır: `spendCoins` sunucunun `error` dizesini atıp yalnız
/// `false` döndürür.
///
/// Bu sınıf bu projede bir kez CANLIYA ÇIKTI: 2026-08-02'de neon çerçeve
/// istemcide satılıyor, sunucunun izin listesinde bulunmuyordu
/// (`shop_server_allowlist_contract_test`). O bekçi ürün KİMLİKLERİNİ
/// karşılaştırır; FİYATLARI karşılaştıran hiçbir şey yoktu.
///
/// ## Niçin sessiz kaldı
///
/// Joker fiyatları `WildcardType.coinCost` içinde, gerekçe dizeleri
/// `quiz_screen_ui` içinde satır satır yazılıydı; sunucu tarafı ise bir göç
/// dosyasında. Üç ayrı yer, hiçbir bağ. Seri dondurma ücreti daha da
/// dağınıktı: aynı `50` sayısı `home_screen` ve `quiz_result_screen` içinde
/// birer özel sabit olarak ve üçüncü kez RPC'de duruyordu (2026-08-17).
///
/// Ayrıca jokerin satın alma çağrısı `catchError` ile ateşlenip unutuluyor;
/// dönen `false` hiç okunmuyor. Yani sunucu reddettiğinde ekranda hiçbir iz
/// kalmaz — kusur ancak ekonomi bozulunca fark edilirdi. Bekçinin gerekli
/// olmasının asıl sebebi bu.
void main() {
  /// `spend_coins`i tanımlayan göçler arasında en yenisi. Dosya adları
  /// `YYYY-MM-DD_...` biçiminde olduğu için alfabetik sıra kronolojiktir —
  /// `shop_server_allowlist_contract_test` ile aynı seçim.
  File latestSpendCoinsMigration() {
    final matches =
        Directory('supabase')
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
      reason: 'spend_coins tanımlayan hiçbir göç bulunamadı.',
    );
    return matches.last;
  }

  /// RPC'nin `case p_reason when '...' then N` tablosunu okur.
  Map<String, int> serverPrices(File migration) {
    final source = migration.readAsStringSync();
    final start = source.indexOf('v_expected := case p_reason');
    expect(
      start,
      isNot(-1),
      reason:
          '${migration.path} içinde fiyat tablosu bulunamadı; RPC yeniden '
          'yazıldıysa bu bekçi de güncellenmeli.',
    );
    final end = source.indexOf('end;', start);
    final table = source.substring(start, end);

    final entry = RegExp(r"when\s+'([a-z_]+)'\s+then\s+(\d+)");
    return {
      for (final m in entry.allMatches(table)) m.group(1)!: int.parse(m.group(2)!),
    };
  }

  /// İstemcinin `spend_coins`e göndereceği her gerekçe ve tutar.
  ///
  /// Liste elle YAZILMAZ: jokerler enum üzerinden gezilir, yani yeni bir
  /// joker eklendiğinde bekçi onu kendiliğinden kapsar. Elle yazılsaydı yeni
  /// joker sessizce kapsam dışında kalırdı — kusurun ilk hâli tam olarak
  /// böyle bir "bir yerde var, öbüründe yok" durumuydu.
  final clientPrices = <String, int>{
    for (final type in WildcardType.values) type.spendReason: type.coinCost,
    CoinPrices.streakFreezeReason: CoinPrices.streakFreeze,
  };

  test('istemcinin gönderdiği her gerekçe sunucuda tanımlı', () {
    final server = serverPrices(latestSpendCoinsMigration());

    expect(
      server.length,
      greaterThanOrEqualTo(5),
      reason:
          'Sunucu tablosundan yalnız ${server.length} satır okunabildi; '
          'ayrıştırma bozulmuş olabilir ve bekçi boş kümede geçerdi.',
    );

    final unknown = clientPrices.keys.where((r) => !server.containsKey(r));
    expect(
      unknown,
      isEmpty,
      reason:
          'Bu gerekçeler sunucunun fiyat tablosunda yok; `spend_coins` '
          "null beklenen tutarla 'invalid price' döner ve satın alma "
          'gerekçesiz başarısız olur: ${unknown.toList()}',
    );
  });

  test('joker ve seri dondurma fiyatları iki tarafta da aynı', () {
    final server = serverPrices(latestSpendCoinsMigration());

    final mismatches = <String>[];
    clientPrices.forEach((reason, clientCost) {
      final serverCost = server[reason];
      if (serverCost == null || serverCost == clientCost) return;
      mismatches.add('$reason: istemci $clientCost, sunucu $serverCost');
    });

    expect(
      mismatches,
      isEmpty,
      reason:
          'Fiyat ayrıştı. Sunucu farklı tutarı reddeder ve kullanıcı yalnız '
          'gerekçesiz bir "satın alma başarısız" görür:\n'
          '${mismatches.join('\n')}',
    );
  });

  test('seri dondurma ücreti istemcide tek yerde tanımlı', () {
    // Aynı sayı üç yerde yazılıydı; ikisi ekranların içinde özel sabittiler.
    // Ekranlar artık ortak kaynağı okuyor ve bu kural onu kilitliyor.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('coin_prices.dart')) continue;
      final source = file.readAsStringSync();
      if (RegExp(r'_streakFreezeCost\s*=\s*\d').hasMatch(source)) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar seri dondurma ücretini kendi sayısıyla yazıyor; '
          '`CoinPrices.streakFreeze` kullanılmalı:\n${offenders.join('\n')}',
    );
  });

  test('joker gerekçeleri ekranlarda tekrar yazılmıyor', () {
    // Gerekçe dizesi fiyatın yanında (`WildcardType.spendReason`) durmalı;
    // ekranda ayrıca yazılırsa fiyat değişince gerekçe unutulur.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('wildcard.dart')) continue;
      final source = file.readAsStringSync();
      for (final type in WildcardType.values) {
        if (source.contains("'${type.spendReason}'")) {
          offenders.add('${file.path} → ${type.spendReason}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
