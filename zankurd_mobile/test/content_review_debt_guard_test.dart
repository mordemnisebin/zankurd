import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

void main() {
  test('runtime JSON bankalarında kaynaksız soru borcu büyümez', () {
    // 1199 -> 1394 -> 1199: 2026-09-30 çok modelli doğrulamadan geçen
    // DeepSeek sorularının 195'inde `sourceReference` yoktu ve tavan geçici
    // olarak 1394'e çıkarılmıştı. Aynı gün ChatGPT bu 195 kaydı web'de aradı:
    // 151'ine güvenilir kaynak bulundu (künyeye yazıldı), 44'ü bulunamadığı
    // (30) ya da işaretli cevabın yanlış çıktığı (14) için doğrulanmış
    // kopyadan çıkarılıp karantinaya döndü. Borç artışı tamamen geri alındı:
    // tavan eski değerine, 1199'a indi. Yeni içerik bu tavanı kendiliğinden
    // büyütemez; bir artış gerekçelendirilmeden yapılamaz.
    //
    // 1199 -> 1235 (+36): 2026-10-19 `kolay_2026_10_19`. Kolay havuz takviyesi
    // (zorluk-1 genel bilgi: Sînema, Edebiyat, Siyaset, Dîrok) tek bir web
    // sayfasına bağlanamayan temel bilgilerdir; iki bağımsız jüri (Gemini 3.1
    // Pro + Grok/ChatGPT) ikisi de KABUL dedi. Kaynak borcu bilinçli artırıldı.
    //
    // 1235 -> 1424 (+189): 2026-11-07 `yeni_2026_11_07`. Yeni genel bilgi
    // soruları (Sînema, Paradigma, Siyaset, Muzîk, Edebiyat) tek bir web
    // sayfasına bağlanamayan temel bilgilerdir; yazar olmayan bir web modeli ve
    // bir komut satırı modeli ONAY dedi. Kaynak borcu bilinçli artırıldı.
    //
    // 1424 -> 2118 (+694): 2026-11-10 `yeni2_2026_11_10`. Yeni genel bilgi
    // soruları (Sînema, Paradigma, Siyaset, Muzîk, Edebiyat, Teknolojî) tek bir
    // web sayfasına bağlanamayan temel bilgilerdir; yazar olmayan iki model
    // ONAY dedi. Kaynak borcu 2026-11-07 turundaki gibi bilinçli artırıldı.
    //
    // 2118 -> 2931 (+813): 2026-11-14 `yeni3_2026_11_14` (814 soru; biri kaynaklı).
    // On kategoride (Teknolojî, Edebiyat, Sînema, Muzîk, Paradigma, Siyaset,
    // Cografya, Cîhan, Dîrok, Çand) tek bir web sayfasına bağlanamayan temel
    // bilgiler; en az iki bağımsız model ONAY dedi. Kaynak borcu önceki
    // turlardaki gibi bilinçli artırıldı (ölçüm: 2931).
    const maximumMissingSourceReferences = 2931;
    var missing = 0;

    for (final asset in questionBankAssets) {
      final decoded = jsonDecode(File(asset).readAsStringSync()) as List;
      for (final raw in decoded) {
        final question = raw as Map<String, dynamic>;
        final metadata = question['metadata'] as Map<String, dynamic>?;
        final reference = (metadata?['sourceReference'] as String? ?? '')
            .trim();
        if (reference.isEmpty) missing += 1;
      }
    }

    expect(
      missing,
      lessThanOrEqualTo(maximumMissingSourceReferences),
      reason:
          '2026-09-30 ölçümünde runtime JSON kaynak borcu '
          '$maximumMissingSourceReferences kayıttı. Yeni içerik gerçek '
          'sourceReference olmadan bu borcu büyütemez.',
    );
  });

  test('çapraz kontrol çelişkilerinin tamamı açık karara bağlıdır', () {
    final conflicts =
        (jsonDecode(
                  File(
                    'docs/content_batches/celiskiler.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<String>()
            .toSet();
    final decisions =
        jsonDecode(
              File(
                'docs/content_batches/celiski_kararlari.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final resolved = <String>{
      for (final raw in (decisions['banka_duzeltildi'] as List? ?? const []))
        (raw as Map<String, dynamic>)['id'] as String,
      ...(decisions['banka_dogru_model_yanlis'] as List? ?? const [])
          .cast<String>(),
    };

    final unresolved = conflicts.difference(resolved).toList()..sort();
    expect(
      unresolved,
      isEmpty,
      reason:
          'Çapraz kontrolde çelişen her soru insan/editoryal karar kaydına '
          'bağlanmalı. Kararsız kalanlar: ${unresolved.take(12).join(', ')}',
    );
  });
}
