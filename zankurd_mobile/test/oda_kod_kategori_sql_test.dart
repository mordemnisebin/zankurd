import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-10-18 göçünün (6 rakamlı kod, çoklu kategori, kolay soru ağırlığı)
/// sözleşmesi. Canlıya karşı koşmaz; göç dosyasının kritik kararlarını
/// sessizce geri alınmaktan korur.
///
/// Neden: göç canlı `pg_get_functiondef` çıktısından türetildi ve birçok
/// fonksiyonu birden değiştirir. Eski göç dosyasından yeniden kopyalayan biri
/// (a) küresel `rooms_code_key`i geri getirebilir (1 milyonluk uzayda biten
/// odanın kodu yeni oda açmayı engellerdi), (b) eski 5 parametreli
/// `create_online_room` imzasını düşürüp mağazadaki sürümleri kırabilir,
/// (c) düz `random()` seçimine dönüp soruları yeniden zorlaştırabilir.
void main() {
  final sql = File(
    'supabase/2026-10-18_oda_kod_kategori.sql',
  ).readAsStringSync();

  // Ajan v2 gövdesini kabuk kaçışıyla `AS \$` yazmıştı; Postgres ters
  // bölüyü tanımaz, göç canlıda sözdizimi hatasıyla düşerdi. Yerelde
  // Postgres olmadığı için hiçbir test bunu görmemişti (2026-10-18).
  test('dolar tırnakları kaçışlı yazılmamış', () {
    expect(sql.contains(r'\$'), isFalse);
  });

  test('kod 6 rakam; benzersizlik yalnız açık odalar arasında', () {
    expect(sql, contains("lpad(floor(random() * 100000)"));
    expect(sql, contains('rooms_open_upper_code_uidx'));
    expect(sql, contains("where status in ('lobby', 'active', 'reveal')"));
    expect(sql, contains('drop constraint if exists rooms_code_key'));
    // Oda kurma (v2) artık 'ZK-' üretmez; hızlı eşleşme odasının kodunu
    // kimse yazmadığından join_matchmaking bilerek dokunulmadı.
    // Eski 5 parametreli RPC eski 'ZK-' kodunu üretmeye devam eder (mağaza
    // sürümleri yalnız onu kabul eder); yeni kod yalnız v2 yoluyla gelir.
    final impl = sql.substring(
      sql.indexOf('FUNCTION public.create_online_room_impl'),
      sql.indexOf('FUNCTION public.create_online_room_v2'),
    );
    expect(impl, contains('if p_legacy_code then'));
    expect(impl, contains("v_room_code := 'ZK-' || upper("));
    expect(sql, contains('p_entry_fee, p_max_players, false'));
    expect(sql, contains('    p_max_players,\n    true\n  );'));
  });

  test(
    'katılım yalnız lobby odayı çözer, en yeniyi seçer, eski kodu korur',
    () {
      final join = sql.substring(sql.indexOf('join_room_by_code(p_code text)'));
      expect(join, contains("r.status = 'lobby'"));
      expect(join, contains('upper(r.code) = upper(btrim(p_code))'));
      expect(join, contains('order by r.created_at desc, r.id desc'));
      // Engel bloğu ve profil kilidi korunur (2026-10-17 geri alınmıştı).
      expect(join, contains('blocked_users'));
      expect(join, contains('for update'));
    },
  );

  test('eski 5 parametreli imza durur; çoklu kategori yeni adla gelir', () {
    expect(
      sql,
      contains(
        'public.create_online_room(p_category_name text, '
        'p_seconds_per_question integer',
      ),
    );
    expect(
      sql,
      contains('public.create_online_room_v2(p_category_names text[]'),
    );
    expect(sql, contains('add column if not exists category_ids uuid[]'));
    expect(sql, contains("v_category_name := 'Tevlihev'"));
  });

  test('zorluk ağırlığı oda, hızlı eşleşme ve düello seçiminde kullanılır', () {
    expect(sql, contains('weighted_question_pick'));
    expect(sql, contains('round(p_count * 0.6)'));
    expect(sql, contains('round(p_count * 0.1)'));
    final start = sql.substring(
      sql.indexOf('FUNCTION public.start_room_game'),
      sql.indexOf('FUNCTION public.create_async_duel_challenge'),
    );
    expect(start, contains('public.weighted_question_pick('));
    expect(start, contains('recent_seen'), reason: 'görülmüş kaçınma korunur');
    expect(start, isNot(contains('random() as random_order')));
    expect(start, contains('v_room.category_ids'));
  });

  test('göç dosyası uygulandı olarak işaretlenmeden bekçisiz kalmaz', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(applied, contains('2026-10-18_oda_kod_kategori.sql'));
  });
}
