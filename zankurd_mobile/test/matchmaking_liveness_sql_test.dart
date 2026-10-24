import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 1v1 canlılık göçü (`2026-10-15_matchmaking_canlilik.sql`) metin bekçisi.
///
/// ## Kusur
///
/// Bekleyen oyuncunun kuyruk satırında canlılık sinyali yoktu: uygulamayı
/// kapatan ya da iptali başarısız olan oyuncu 40 sn boyunca "eşleştirilebilir"
/// kalıyor, eşleşen taraf hayaletle maça girip 2 dakika (maç öncesi hazır
/// süresi) boş ekrana bakıyordu. Canlıda terk edilen 6 1v1 odasının 6'sında
/// bir oyuncu hiç hazır olmamıştı.
///
/// ## Neden sessizdi
///
/// Sunucu davranışı yerelde çalıştırılamıyor (Docker yok); bir sonraki "temiz"
/// yeniden yazım 12 sn kuralını, eski istemci (NULL) dalını ya da 45 sn
/// süresini sessizce düşürebilirdi. Bu test göçün sözleşmesini metin olarak
/// sabitler.
void main() {
  final sql = File(
    'supabase/2026-10-15_matchmaking_canlilik.sql',
  ).readAsStringSync();

  test('touch_matchmaking yalnız authenticated için açılır', () {
    expect(sql, contains('function public.touch_matchmaking()'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
    expect(
      sql,
      contains(
        'revoke all on function public.touch_matchmaking() from public, anon;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.touch_matchmaking() to authenticated;',
      ),
    );
  });

  test('bekleyen rakip 12 sn kalp atışı kuralıyla, eski istemci 40 sn ile', () {
    expect(sql, contains("interval '12 seconds'"));
    expect(sql, contains('mq.last_seen_at is null'));
    expect(sql, contains("interval '40 seconds'"));
    expect(sql, contains('add column if not exists last_seen_at timestamptz'));
  });

  test('maç öncesi istemci-hazır süresi 45 sn; 2 dakika kalmaz', () {
    expect(sql, contains("interval '45 seconds'"));
    expect(
      sql.contains("interval '2 minutes'"),
      isFalse,
      reason: 'start_room_game / mark_room_client_ready eski süreye dönmüş',
    );
  });

  test('göç idempotent ve tek işlemde', () {
    expect(sql, contains('begin;'));
    expect(sql.trimRight(), endsWith('commit;'));
  });
}
