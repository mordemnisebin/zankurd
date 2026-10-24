// 2026-10-24 "günün yarışması sonucu" göçünün bekçisi.
//
// ## Kusur
//
// Günün turu sunucuda hiç sonuç bırakmıyordu; sıralama için yeni tablo ve iki
// RPC yazıldı. Kurallar SQL'de yaşadığı için istemci testleri onları göremez.
//
// ## Niçin sessiz kalırdı
//
// Bir GRANT unutulursa ya da tablo istemciye açık kalırsa hiçbir şey
// kırılmaz: sıralama çalışır, ama herkes başkasının sonucunu yazabilir ya da
// bütün satırları (kullanıcı kimlikleriyle) okuyabilir. Güvenlik kusuru
// işlevsel olarak görünmezdir.
//
// ## Kural
//
// Tablo istemciye kapalı; iki RPC security definer + sabit search_path, anon
// kapalı, authenticated açık; pano yalnız herkese açık gösterim alanlarını
// (ad, doğru/toplam, süre) döndürür, kullanıcı kimliği DÖNDÜRMEZ; gün sınırı
// istemci geri sayımıyla aynı İstanbul gününden (`app_today`) gelir.
// Canlı doğrulama: `supabase/kanit/2026-10-24_gunun_yarismasi_sonuc_kanit.sql`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/contest.dart';

void main() {
  final sql = File(
    'supabase/2026-10-24_gunun_yarismasi_sonuc.sql',
  ).readAsStringSync();
  final code = sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  // Biçimlendirme (satır sonu/boşluk) değişse de kural aynı kalsın.
  final flat = code.replaceAll(RegExp(r'\s+'), ' ');

  test('tek işlemde; yıkıcı komut yok', () {
    expect(code, contains('\nbegin;\n'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(code, isNot(contains('drop ')));
  });

  test('tablo istemciye kapalı: RLS açık, hiçbir rolde yetki yok', () {
    expect(
      code,
      contains(
        'alter table public.daily_event_results enable row level security;',
      ),
    );
    expect(
      code,
      contains(
        'revoke all on table public.daily_event_results '
        'from public, anon, authenticated;',
      ),
    );
    expect(code, isNot(contains('create policy')));
  });

  test('gün başına oyuncu başına tek satır; değer aralıkları kısıtlı', () {
    expect(code, contains('primary key (day, user_id)'));
    expect(code, contains('total_count between 1 and 20'));
    expect(code, contains('correct_count between 0 and total_count'));
    expect(code, contains('seconds between 0 and 3600'));
    expect(code, contains('on conflict (day, user_id) do nothing'));
  });

  test('iki RPC security definer + sabit search_path, anon kapalı', () {
    for (final fn in [
      'submit_daily_event_result(integer, integer, integer)',
      'get_daily_event_board()',
    ]) {
      expect(
        flat,
        contains('revoke all on function public.$fn from public, anon;'),
        reason: '$fn anon/public çalıştıramamalı',
      );
      expect(
        flat,
        contains('grant execute on function public.$fn to authenticated;'),
      );
    }
    expect(
      RegExp(r'security definer').allMatches(code).length,
      2,
      reason: 'iki fonksiyon, ikisi de definer',
    );
    expect(
      RegExp(r"set search_path to 'public', 'pg_temp'").allMatches(code).length,
      2,
    );
  });

  test(
    'kimlik şart; yazma auth.uid() ile, parametreyle kullanıcı verilmez',
    () {
      expect(code, contains('v_uid uuid := auth.uid();'));
      expect(code, contains('if v_uid is null'));
      expect(
        code,
        isNot(contains('p_user')),
        reason: 'başkası adına sonuç yazılamaz',
      );
    },
  );

  test(
    'pano kullanıcı kimliği döndürmez; engelliler süzülür; gün İstanbul',
    () {
      final board = code.substring(
        code.indexOf('create or replace function public.get_daily_event_board'),
      );
      final built = board.substring(board.indexOf('jsonb_build_object'));
      expect(built, isNot(contains("'user_id'")));
      expect(built, isNot(contains("'id'")));
      expect(board, contains('public.blocked_users'));
      expect(board, contains('b.blocker_id = auth.uid()'));
      expect(board, contains('public.app_today()'));
      expect(
        board,
        contains('order by r.correct_count desc, r.seconds asc'),
        reason: 'doğru çok -> süre az',
      );
    },
  );

  test('istemci geri sayımı sunucu gün sınırıyla aynı: İstanbul 00:00', () {
    // `app_today()` = (now() at time zone 'Europe/Istanbul')::date
    // (2026-10-15_ilerleme_esitleme.sql). Türkiye UTC+3 sabit.
    final ledger = File(
      'supabase/2026-10-15_ilerleme_esitleme.sql',
    ).readAsStringSync();
    expect(ledger, contains("at time zone 'Europe/Istanbul'"));
    expect(
      nextContestResetAt(DateTime.utc(2026, 7, 1, 10)),
      DateTime.utc(2026, 7, 1, 21),
      reason: 'yaz saati yok: Temmuz da 21:00 UTC',
    );
    expect(
      nextContestResetAt(DateTime.utc(2026, 1, 1, 10)),
      DateTime.utc(2026, 1, 1, 21),
    );
  });

  test('kanıt betiği geri alır ve göç öncesi/sonrası biçimindedir', () {
    final proof = File(
      'supabase/kanit/2026-10-24_gunun_yarismasi_sonuc_kanit.sql',
    ).readAsStringSync();
    expect(proof, contains('begin;'));
    expect(proof.trimRight(), endsWith('rollback;'));
    expect(proof, contains('beklenen_once'));
    expect(proof, contains('beklenen_sonra'));
    expect(proof, contains("'SONRA-OK'"));
  });

  test('applied.md göçü ⏳ olarak kaydeder (uygulanınca ✅)', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(
      applied,
      contains('| 2026-10-24_gunun_yarismasi_sonuc.sql | '),
      reason: 'uygulanan göçler defterde olmalı',
    );
  });
}
