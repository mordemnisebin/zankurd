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
    const maximumMissingSourceReferences = 1199;
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
