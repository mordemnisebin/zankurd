/// `supabase/2026-10-15_ilerleme_esitleme.sql` sunucu sözleşmesi bekçisi.
///
/// ## Kusurlar
///
/// 1. Kayıtlı kullanıcı seri/rozet/seviye/tekrar geçmişini çıkışta, telefon
///    değişiminde ve yeniden kurulumda kaybediyordu (hepsi yalnız cihazda).
/// 2. `claim_solo_reward` tekil değildi: kuyruktaki yeniden gönderim, yanıtı
///    kaybolan ilk çağrının üstüne ikinci kez jeton yazıyordu.
/// 3. Günlük tavanlar UTC gününe göre sayılıyordu (Türkiye'de 03:00).
///
/// ## Niçin sessizdi
///
/// Göç Docker'sız yazıldı, yerelde `db reset` koşmadı. Bir tablonun
/// istemciye açık kalması, bir RPC'nin anon'a verilmesi, iki imza arasında
/// PostgREST belirsizliği ya da hesap silmenin yeni tabloyu bırakması hiçbir
/// derleme/analiz hatası vermez; yalnız canlıda, bir insanın başına gelir.
/// Bu dosya göçü uygulamadan METİN olarak okuyup her maddeyi denetler
/// (repo deseni: `friend_challenge_sql_contract_test.dart`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/2026-10-15_ilerleme_esitleme.sql',
  ).readAsStringSync();
  final lower = sql.toLowerCase();

  /// `create or replace function public.<name>(` başından bir sonraki
  /// `create or replace function` satırına kadar; [args] verilirse o imza.
  String bodyOf(String name, {String? firstParam}) {
    final marker = 'create or replace function public.$name(';
    var from = 0;
    while (true) {
      final start = lower.indexOf(marker, from);
      if (start < 0) throw StateError('$name tanımlı değil');
      final next = lower.indexOf(
        'create or replace function public.',
        start + marker.length,
      );
      final verification = lower.indexOf('-- 5) doğrulama');
      final end = next != -1
          ? next
          : (verification == -1 ? sql.length : verification);
      // Satır yorumları kod sayılmaz (yorum "current_date" diyebilir).
      final body = sql
          .substring(start, end)
          .split('\n')
          .map((line) => line.trimLeft().startsWith('--') ? '' : line)
          .join('\n');
      if (firstParam == null || body.toLowerCase().contains(firstParam)) {
        return body;
      }
      from = start + marker.length;
    }
  }

  test('tek işlemde ve Türkçe NİÇİN başlığıyla', () {
    expect(sql, contains('NİÇİN'));
    expect(sql, contains('GERİ ALMA'));
    expect(RegExp(r'^begin;', multiLine: true).hasMatch(sql), isTrue);
    expect(sql.trimRight().endsWith('commit;'), isTrue);
    expect(sql, contains('Uygulama: supabase db query --linked -f'));
  });

  group('player_progress', () {
    test('tablo: profiles cascade, jsonb, 256 KB sınırı, RLS, yetki yok', () {
      expect(
        sql,
        contains('create table if not exists public.player_progress'),
      );
      expect(
        sql,
        contains(
          'player_id uuid primary key references public.profiles (id) on '
          'delete cascade',
        ),
      );
      expect(sql, contains('snapshot jsonb not null'));
      expect(sql, contains('updated_at timestamptz not null default now()'));
      expect(sql, contains('octet_length(snapshot::text) <= 262144'));
      expect(
        sql,
        contains(
          'alter table public.player_progress enable row level security;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.player_progress from public, anon, '
          'authenticated;',
        ),
      );
      // Politika yok: istemci tabloya doğrudan erişemez.
      expect(lower.contains('create policy'), isFalse);
      expect(
        lower.contains('grant select on table public.player_progress'),
        isFalse,
      );
    });

    test(
      'get_my_progress: auth.uid() şart, definer, search_path, anon kapalı',
      () {
        final body = bodyOf('get_my_progress');
        expect(body, contains('security definer'));
        expect(body, contains('set search_path = public'));
        expect(body, contains('auth.uid()'));
        expect(body, contains("raise exception 'Not authenticated'"));
        expect(body, contains('where player_id = v_uid'));
        expect(
          sql,
          contains(
            'revoke all on function public.get_my_progress() from public, anon;',
          ),
        );
        expect(
          sql,
          contains(
            'grant execute on function public.get_my_progress() to authenticated;',
          ),
        );
      },
    );

    test('save_my_progress: kimlik, nesne, 256 KB, profil, upsert', () {
      final body = bodyOf('save_my_progress');
      expect(body, contains('security definer'));
      expect(body, contains('set search_path = public'));
      expect(body, contains("raise exception 'Not authenticated'"));
      expect(body, contains("jsonb_typeof(p_snapshot) <> 'object'"));
      expect(body, contains('octet_length(p_snapshot::text) > 262144'));
      expect(body, contains("raise exception 'Snapshot too large'"));
      expect(body, contains("raise exception 'Profile missing'"));
      expect(body, contains('on conflict (player_id) do update'));
      // Oyuncu kimliği ASLA istemciden gelmez.
      expect(body.contains('p_player_id'), isFalse);
      expect(
        sql,
        contains(
          'revoke all on function public.save_my_progress(jsonb) from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.save_my_progress(jsonb) to authenticated;',
        ),
      );
    });

    test('hesap silme zinciri doğrulama bloğunda denetlenir', () {
      expect(sql, contains("confrelid = 'auth.users'::regclass"));
      expect(sql, contains("confdeltype = 'c'"));
      expect(
        sql,
        contains("'public.player_progress', 'public.solo_reward_claims'"),
      );
    });
  });

  group('claim_solo_reward tekilliği', () {
    test(
      'tablo: (player_id, client_round_id) birincil anahtar, cascade, kapalı',
      () {
        expect(
          sql,
          contains('create table if not exists public.solo_reward_claims'),
        );
        expect(
          sql,
          contains(
            'player_id uuid not null references public.profiles (id) on delete '
            'cascade',
          ),
        );
        expect(sql, contains('client_round_id uuid not null'));
        expect(sql, contains('primary key (player_id, client_round_id)'));
        expect(
          sql,
          contains(
            'revoke all on table public.solo_reward_claims from public, anon, '
            'authenticated;',
          ),
        );
      },
    );

    test('yeni imza: kimlik zorunlu (varsayılan YOK), ikinci çağrı ödemez', () {
      final body = bodyOf('claim_solo_reward', firstParam: 'p_client_round_id');
      // Varsayılan değer PostgREST'te iki imza arasında PGRST203 doğururdu.
      expect(
        body.toLowerCase().contains('p_client_round_id uuid default'),
        isFalse,
      );
      expect(body, contains('p_client_round_id uuid'));
      expect(body, contains('from public.solo_reward_claims c'));
      expect(
        body,
        contains("v_prior || jsonb_build_object('already_claimed', true)"),
      );
      // İkinci çağrı dönüşü, ödeme (coin_transactions insert) öncesindedir.
      expect(
        body.indexOf("'already_claimed', true"),
        lessThan(body.indexOf('insert into public.coin_transactions')),
      );
      // Eşzamanlı iki talep profil kilidiyle sıraya girer.
      expect(
        body.indexOf('for update'),
        lessThan(body.indexOf('from public.solo_reward_claims c')),
      );
      expect(
        body,
        contains('on conflict (player_id, client_round_id) do nothing'),
      );
      expect(body, contains("reason = 'solo_round'"));
      expect(body, contains('v_daily_cap constant integer := 45'));
      expect(body, contains('v_max_questions constant integer := 50'));
      expect(body, contains('security definer'));
      expect(body, contains('set search_path = public'));
    });

    test('eski 3 argümanlı imza yayındaki iOS için durur ve yeniye devreder', () {
      final body = sql.substring(
        lower.indexOf(
          'create or replace function public.claim_solo_reward(\n  p_correct_count integer,\n  p_total_questions integer,\n  p_best_streak integer\n)',
        ),
      );
      expect(body, contains('null::uuid'));
      expect(
        sql,
        contains(
          'grant execute on function public.claim_solo_reward(integer, integer, integer)\n  to authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.claim_solo_reward(integer, integer, integer, uuid)\n  to authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on function public.claim_solo_reward(integer, integer, integer, uuid)\n  from public, anon;',
        ),
      );
    });
  });

  group('tek "bugün" (Europe/Istanbul)', () {
    test('app_today istemciye kapalı, İstanbul gününü verir', () {
      final body = bodyOf('app_today');
      expect(body, contains("(now() at time zone 'Europe/Istanbul')::date"));
      expect(
        sql,
        contains(
          'revoke all on function public.app_today() from public, anon, authenticated;',
        ),
      );
    });

    test('beş fonksiyon app_today kullanır, current_date kalmaz', () {
      final names = {
        'claim_solo_reward': 'p_client_round_id',
        'award_spin_coins': null,
        'can_spin_today': null,
        'claim_daily_spin': null,
        'claim_quiz_reward': null,
      };
      names.forEach((name, firstParam) {
        final body = bodyOf(name, firstParam: firstParam);
        expect(
          body.toLowerCase().contains('current_date'),
          isFalse,
          reason: '$name hâlâ current_date kullanıyor',
        );
        expect(body, contains('app_today()'), reason: name);
      });
    });

    test(
      'solo günün sınırları İstanbul gününe göre (UTC oturum dilimi değil)',
      () {
        final body = bodyOf(
          'claim_solo_reward',
          firstParam: 'p_client_round_id',
        );
        expect(body, contains("at time zone 'Europe/Istanbul'"));
        expect(body, contains('created_at >= v_day_start'));
        expect(body, contains('created_at < v_day_end'));
        expect(body.contains('v_today::timestamptz'), isFalse);
      },
    );

    test('canlı gövdelerin güvenlik özellikleri korunur', () {
      // Oda ödülü: oyuncu kilidi + advisory lock + günlük tavan 300.
      final quiz = bodyOf('claim_quiz_reward');
      expect(quiz, contains('pg_advisory_xact_lock'));
      expect(quiz, contains('v_daily_cap constant integer := 300'));
      expect(quiz, contains("'quiz_complete:room='"));
      expect(quiz, contains('SECURITY DEFINER'));
      // Çark: günde bir kez (spin_date benzersizliği).
      final spin = bodyOf('award_spin_coins');
      expect(spin, contains('on conflict (user_id, spin_date) do nothing'));
      final daily = bodyOf('claim_daily_spin');
      expect(daily, contains('on conflict (user_id, spin_date) do nothing'));
    });

    test('kapsam dışı bırakılanlar başlıkta listelenir', () {
      for (final name in [
        'award_xp_delta',
        'sync_mission_completion',
        'get_today_contest',
        'save_tournament_progress',
        'finalize_weekly_league',
      ]) {
        expect(sql, contains(name), reason: name);
      }
    });
  });

  test('doğrulama bloğu kusurlu göçü geri alır', () {
    for (final guard in [
      'RLS kapalı',
      'istemciye açık',
      "ON DELETE CASCADE değil",
      "anon''a açık",
      'tekillik mantığı eksik',
      'hâlâ current_date kullanıyor',
      'İstanbul gününe uymuyor',
    ]) {
      expect(sql, contains(guard), reason: guard);
    }
  });

  test('applied.md satırı ⏳ ve göçü anlatır', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    final row = applied
        .split('\n')
        .firstWhere(
          (l) => l.startsWith('| 2026-10-15_ilerleme_esitleme.sql |'),
        );
    expect(row, contains('⏳'));
    expect(row, contains('player_progress'));
    expect(row, contains('claim_solo_reward'));
    expect(row, contains('app_today'));
  });
}
