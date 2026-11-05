/// `2026-11-18_w6_soru_secimi.sql` bekçisi (2.1.2 W6): oda soru seçiminde
/// "görülmüş" kümesi ve doğrulanmış solo seçimin rastgele aday kümesi.
///
/// ## Kusurlar
///
/// * `start_room_game`: `recent_seen` kümesinin ikinci kolu oda başlarken
///   önceden yazılan HER `room_questions` satırını görülmüş sayıyordu;
///   sunulmayan sorular oyuncuyu gereksiz dışlıyordu (alan 6 #2).
/// * `prepare_verified_solo_questions`: her çağrıda bütün uygun havuz
///   `random()` ile sıralanıyordu (alan 9 #1).
///
/// ## Niçin sessiz kalırdı
///
/// İkisi de doğru sonuç verir: dışlama yalnız taze soru azalınca fark edilir,
/// sıralama yalnız yük altında maliyet. Davranış
/// `tool/test_w6_soru_secimi_local.mjs` ile PGlite'ta kanıtlanır (kusur göçten
/// ÖNCE gösterilir); bu dosya metni sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-18_w6_soru_secimi.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-18_w6_soru_secimi_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) =>
      s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
  final code = strip(raw);

  test('tek işlem, küçük harfli begin/commit (kuru çalıştırma tuzağı); ⏳', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(strip(geriRaw).trimLeft(), startsWith('begin;'));
    expect(strip(geriRaw).trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-18_w6_soru_secimi.sql | ⏳'));
    // Yeni nesne yok.
    expect(code, isNot(contains('create table if not exists')));
    expect(code, contains('add column if not exists server_only'));
    expect(code, contains('and q.server_only = false'));
    expect(code, isNot(contains('cron.schedule')));
    expect(code, isNot(contains('create index')));
  });

  test('tam gövde md5 ön koşulu + yedek zinciri + geri alma', () {
    expect(
      raw,
      contains('918cef7cf52cde1d9dd3994ef2383c0e'),
    ); // start_room_game
    expect(raw, contains('a20a15d07f5ad79871fa5fa4a4b889bb')); // prepare_...
    expect(raw, contains("'w6:' || p_imza"));
    expect(raw, contains('yama-md5'));
    expect(geriRaw, contains("'w6:' || v_imza"));
    expect(geriRaw, contains('md5 zinciri'));
    // applied.md satırı nihai md5'leri de taşır.
    expect(applied, contains('19ed6e01a674cbc526bd3f9129c03400'));
    expect(applied, contains('ea49c4455504e3ea44bea08c8f821bd6'));
  });

  test('yalnız sunulan sorular görülmüş; solo seçim kimlik eşiğinden', () {
    expect(
      code,
      contains(
        'where (seen_rq.started_at is not null or seen_rq.revealed_at is not null)',
      ),
    );
    expect(code, contains('gen_random_uuid()'));
    expect(code, contains('limit p_limit * 5'));
    // Eski tam havuz sıralaması yeni gövdede kalmamalı (yalnız küçük kümede).
    expect(code, contains('from (select id from tail_part union all'));
  });
}
