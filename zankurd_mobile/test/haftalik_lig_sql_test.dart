/// `2026-11-05_haftalik_lig.sql` bekçisi: Duolingo tarzı haftalık lig.
///
/// ## Kusur (kurul bulgusu)
///
/// Tek global sıralama yeni oyuncuyu bin puanlık liderlerin altında bırakıp
/// bırakma isteği doğuruyordu. Lig: aynı kademeden en çok 30 oyunculu haftalık
/// küme; ilk 5 çıkar, son 5 düşer.
///
/// ## Niçin sessiz kalırdı
///
/// Küme/kapanış mantığı SQL'dedir ve yanlış olsa hata vermez: küme 31'e
/// taşar, kapanış iki kez çalışıp oyuncuyu iki kademe düşürür, Bronz'un altına
/// inilir, engellenen oyuncu listede görünür, `anon` RPC çağırır ya da eski
/// `weekly_league` (07-10) nesneleri ezilir. Canlı DB'ye bağlanılmaz (PGlite
/// bu makinede kurulu değil); bu dosya göçü ve geri almayı metin olarak okuyup
/// kuralları sabitler.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-05_haftalik_lig.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-05_haftalik_lig_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();

  String strip(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
  final code = strip(raw);
  final geri = strip(geriRaw);

  String body(String name) {
    final start = code.indexOf('function public.$name(');
    expect(start, greaterThanOrEqualTo(0), reason: '$name tanımı yok');
    final end = code.indexOf(
      r'$function$;',
      code.indexOf(r'$function$', start) + 1,
    );
    expect(end, greaterThan(start), reason: '$name gövdesi kapanmıyor');
    return code.substring(start, end);
  }

  test('işlem: küçük harfli begin/commit, idempotent tablo/indeks', () {
    final lines = code.split('\n').map((l) => l.trim()).toList();
    expect(lines.where((l) => l == 'begin;').length, 1);
    expect(lines.where((l) => l == 'commit;').length, 1);
    expect(code, isNot(contains('\nBEGIN')));
    expect(
      RegExp(r'create table (?!if not exists)').hasMatch(code),
      isFalse,
      reason: 'tablolar idempotent olmalı',
    );
    expect(code, isNot(contains('create index public.')));
    expect(
      RegExp(r'create (unique )?index (?!if not exists)').hasMatch(code),
      isFalse,
      reason: 'indeksler idempotent olmalı',
    );
    expect(code, isNot(contains('drop table')));
  });

  test('eski weekly_league nesnelerine dokunmaz', () {
    for (final old in [
      'league_weeks',
      'league_memberships',
      'finalize_weekly_league',
      'get_my_league_state',
    ]) {
      expect(code, isNot(contains(old)), reason: old);
    }
    expect(RegExp(r'(?<!weekly_)league_week_start\(').hasMatch(code), isFalse);
  });

  test(
    'eski finalize-weekly-league işi kaldırılır, ödül verilmez, geri alma kurar',
    () {
      expect(
        code,
        contains("select cron.unschedule('finalize-weekly-league')"),
      );
      for (final reward in [
        'coin_transactions',
        'user_badges',
        'grant_coins',
      ]) {
        expect(
          code,
          isNot(contains(reward)),
          reason: 'yeni kapanış ödül vermez',
        );
      }
      expect(
        geri,
        contains("cron.schedule('finalize-weekly-league', '5 0 * * 1'"),
      );
      // İstemci eski lig çıktısını okumaz.
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final t = f
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(t.contains('get_my_league_state'), isFalse, reason: f.path);
        expect(t.contains('league_memberships'), isFalse, reason: f.path);
      }
    },
  );

  test('yeni tablolar: RLS açık, istemciye doğrudan yetki yok', () {
    for (final t in ['cohorts', 'players', 'members', 'closed']) {
      expect(
        code,
        contains(
          'alter table public.weekly_league_$t enable row level security;',
        ),
      );
      expect(
        code,
        contains(
          'revoke all on public.weekly_league_$t from public, anon, authenticated;',
        ),
      );
    }
    expect(code, isNot(contains('create policy')));
  });

  test('kademe 0..4 ve küme en çok 30', () {
    expect(code, contains('check (tier between 0 and 4)'));
    expect(code, contains('member_count between 0 and 30'));
    expect(body('weekly_league_assign'), contains('member_count < 30'));
  });

  test('küme ataması: kademe+hafta kilidi, satır kilidi, çift atama yok', () {
    final b = body('weekly_league_assign');
    expect(b, contains('pg_advisory_xact_lock'));
    expect(b, contains("'league-cohort:'"));
    expect(b, contains('for update'));
    // Kilitten önce ve sonra mevcut üyelik yeniden okunur.
    expect(
      RegExp('from public.weekly_league_members m').allMatches(b).length,
      greaterThanOrEqualTo(2),
    );
    expect(b, contains('member_count = member_count + 1'));
  });

  test('küme araması için indeksler var', () {
    expect(code, contains('weekly_league_cohorts_open_idx'));
    expect(code, contains('where member_count < 30'));
    expect(code, contains('weekly_league_members_cohort_idx'));
    expect(code, contains('weekly_league_members_player_idx'));
  });

  test('puan kaynağı player_score_daily; oda tablosu taranmaz', () {
    expect(body('weekly_league_score'), contains('public.player_score_daily'));
    expect(code, isNot(contains('public.room_players')));
    expect(code, isNot(contains('public.rooms')));
    expect(body('weekly_league_week_start'), contains("'europe/istanbul'"));
    expect(body('weekly_league_week_start'), contains("date_trunc('week'"));
  });

  test('bölge: >= 4 kişide en çok 5, çakışmaz', () {
    final b = body('weekly_league_zone_size');
    expect(b, contains('p_size < 4 then 0'));
    expect(b, contains('least(5, (p_size / 3)::integer)'));
  });

  test(
    'kapanış: idempotent, süren hafta kapatılamaz, Bronz altına inilmez',
    () {
      final b = body('weekly_league_rollover');
      expect(b, contains('insert into public.weekly_league_closed'));
      expect(b, contains('on conflict (week_start) do nothing'));
      expect(b, contains('if not found then'));
      expect(b, contains('return 0;'));
      expect(b, contains('v_week >= public.weekly_league_week_start()'));
      expect(b, contains('pg_advisory_xact_lock'));
      expect(b, contains('s.tier < 4 and s.score > 0'));
      expect(b, contains('when s.tier > 0'));
      expect(b, contains("'promoted' then d.tier + 1"));
      expect(b, contains("'demoted' then d.tier - 1"));
      expect(b, contains('m.outcome is null'));
    },
  );

  test(
    'get_my_league: yalnız authenticated, search_path sabit, engel süzgeci',
    () {
      final b = body('get_my_league');
      expect(code, contains(r'security definer'));
      expect(code, contains("set search_path to 'public', 'pg_temp'"));
      expect(b, contains('auth.uid()'));
      expect(b, contains('public.blocked_users'));
      expect(b, contains('b.blocker_id = v_uid'));
      expect(b, contains('weekly_league_score(v_uid, v_week) > 0'));
      expect(b, contains('perform public.weekly_league_rollover(v_week - 7)'));
      expect(b, contains("'last_result'"));
      expect(
        code,
        contains(
          'revoke all on function public.get_my_league() from public, anon;',
        ),
      );
      expect(
        code,
        contains(
          'grant execute on function public.get_my_league() to authenticated;',
        ),
      );
      expect(
        code,
        contains(
          'grant execute on function public.ack_my_league_result() to authenticated;',
        ),
      );
    },
  );

  test('iç işlevler ve kapanış istemciye açık değil', () {
    for (final sig in [
      'weekly_league_week_start(timestamptz)',
      'weekly_league_zone_size(bigint)',
      'weekly_league_score(uuid, date)',
      'weekly_league_assign(uuid, date)',
      'weekly_league_rollover(date)',
    ]) {
      expect(
        code,
        contains(
          'revoke all on function public.$sig\n  from public, anon, authenticated;',
        ),
        reason: sig,
      );
      expect(code, isNot(contains('grant execute on function public.$sig')));
    }
  });

  test('her SECURITY DEFINER işlevin search_path\'i sabit', () {
    final defs = RegExp(
      r'security definer\nset search_path to',
    ).allMatches(code).length;
    expect(defs, RegExp('security definer').allMatches(code).length);
  });

  test('pg_cron: pazartesi 00:05 İstanbul = pazar 21:05 UTC, idempotent', () {
    expect(code, contains("select cron.unschedule('weekly-league-rollover')"));
    expect(code, contains("'5 21 * * 0'"));
    expect(code, contains(r'$$select public.weekly_league_rollover()$$'));
  });

  test('geri alma: cron, işlevler ve yalnız yeni tablolar', () {
    expect(geri, contains("cron.unschedule('weekly-league-rollover')"));
    for (final f in [
      'ack_my_league_result()',
      'get_my_league()',
      'weekly_league_rollover(date)',
      'weekly_league_assign(uuid, date)',
      'weekly_league_score(uuid, date)',
      'weekly_league_zone_size(bigint)',
      'weekly_league_week_start(timestamptz)',
    ]) {
      expect(geri, contains('drop function if exists public.$f;'));
    }
    for (final t in ['closed', 'members', 'players', 'cohorts']) {
      expect(geri, contains('drop table if exists public.weekly_league_$t;'));
    }
    expect(geri, isNot(contains('league_memberships')));
  });

  test('applied.md: ✅ satırı var', () {
    final row = applied
        .split('\n')
        .firstWhere((l) => l.startsWith('| 2026-11-05_haftalik_lig.sql'));
    expect(row, contains('✅'));
    expect(row, contains('geri_al/2026-11-05_haftalik_lig_geri.sql'));
  });
}
