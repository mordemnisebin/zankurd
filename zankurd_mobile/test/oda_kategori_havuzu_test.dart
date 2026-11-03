// Bilim odasında hareket öğretisi sorusu çıkmasın.
//
// 2026-11-03 turu: "Bilim" kategorili özel odada "Abdullah Öcalan ... -îzm"
// (curated_paradigma_0004) çıktı. Oda havuzu doğruydu (start_room_game yalnız
// odanın kategorisinden çeker; "Bilim" = iç kimlik Paradigma). Kusur veriydi:
// 2026-10-01 yerel eşitlemesi, 2026-09-30'da ayıklanan türden sekiz soruyu
// sunucuda yeniden onaylı yaptı ve yerel paket de onları emekli etmemişti.
// Sessizdi, çünkü iki ayıklama dalgası yalnız o günkü kimlikleri kapsıyordu.
// Bu bekçi: yerel emekli listesi ile sunucu göçü aynı sekiz soruyu kapsar,
// oyun akışı onları sunmaz, oda havuzu kategori süzgecini korur.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

void main() {
  const ids = [
    'curated_paradigma_0001',
    'curated_paradigma_0002',
    'curated_paradigma_0003',
    'curated_paradigma_0004',
    'curated_paradigma_0005',
    'curated_paradigma_0006',
    'curated_paradigma_0007',
    'curated_paradigma_0010',
  ];

  test('yerel paket sekiz soruyu oynatmaz', () {
    final all = QuestionBankLoader.instance.allQuestions;
    for (final id in ids) {
      expect(isQuestionRetired(id), isTrue, reason: id);
      final q = all.firstWhere((q) => q.id == id);
      expect(const QuestionContentPolicy().isPlayable(q), isFalse, reason: id);
    }
  });

  test('sunucu göçü aynı sekiz soruyu kapatır; yalnız veri, atomik', () {
    final sql = File(
      'supabase/2026-11-04_oda_kategori_havuzu.sql',
    ).readAsStringSync();
    final rollback = File(
      'supabase/geri_al/2026-11-04_oda_kategori_havuzu_geri.sql',
    ).readAsStringSync();
    final sync = File(
      'supabase/2026-10-01_local_parity_sync_paradigma.sql',
    ).readAsStringSync();
    expect(sql, contains('\nbegin;\n'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(sql, contains('set is_approved = false'));
    expect(sql, isNot(contains('create or replace function')));
    expect(rollback, contains('set is_approved = true'));
    for (final id in ids) {
      final uuid = RegExp(
        "\\('([0-9a-f-]{36})'[^\\n]*-- yerel: $id\\b",
      ).firstMatch(sync)?.group(1);
      expect(uuid, isNotNull, reason: '$id eşitleme dosyasında yok');
      expect(sql, contains(uuid!), reason: id);
      expect(rollback, contains(uuid), reason: id);
    }
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('| 2026-11-04_oda_kategori_havuzu.sql | ⏳ |'),
    );
  });

  test('oda soru havuzu yalnız odanın kategorisinden çeker', () {
    final src = File(
      'supabase/2026-10-18_oda_kod_kategori.sql',
    ).readAsStringSync();
    final start = src.indexOf('FUNCTION public.start_room_game');
    final body = src.substring(start, src.indexOf(r'$function$;', start));
    expect(body, contains('q.category_id = any(v_room.category_ids)'));
    expect(body, contains('q.category_id = v_room.category_id'));
  });
}
