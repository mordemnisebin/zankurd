/// Düello dürtme + profil maç geçmişi göçü (`2026-10-24_duello_durtme.sql`)
/// bekçisi.
///
/// ## Kusur
///
/// Dürtme bir bildirim üretir: sunucu kuralı gevşerse (12 saat sınırı yok,
/// katılımcı olmayan dürtebilir, rakip bitirmişken ya da engelli çiftte
/// gider) oyuncular birbirine bildirim yağdırır; profil geçmişi RPC'si de
/// başkasının maçlarını okuyabilirse gizlilik sızar.
///
/// ## Niçin sessiz kalırdı
///
/// Göç canlıda tek başına çalışır; bir `interval '12 hours'` unutulsa, engel
/// denetimi tek yönlü kalsa ya da `my_match_history` istemciye açılsa hiçbir
/// derleme/analiz/widget testi bunu görmez. Bu dosya göçü METİN olarak okuyup
/// her maddeyi sabitler (repo deseni: `duello_sirasi_sql_test.dart`).
///
/// ## Kural
///
/// * `nudge_async_duel`: SECURITY DEFINER, katılımcı + turu bitirmiş +
///   rakip bitirmemiş + açık/süresi dolmamış + iki yönlü engel yok +
///   düello+gönderici başına 12 saatte 1; `async_duel_turn` push'u
///   `from_user_id` ile ve "KU · TR" metinle.
/// * `list_my_async_duels` canlı gövdeyi korur, yalnız `my_nudged_at` ekler.
/// * `list_my_recent_matches` / `get_my_records` yalnız `auth.uid()`
///   verisini okur; iç yardımcı `my_match_history` istemciye KAPALI.
/// * Her yeni RPC anon'a kapalı, authenticated'a açık; dürtme tablosu RLS'li.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/2026-10-24_duello_durtme.sql').readAsStringSync();
  final proof = File(
    'supabase/kanit/2026-10-24_duello_durtme_kanit.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();

  /// Yorum satırları atılmış metin: açıklayıcı yorumlar kod iddialarını
  /// bozmasın.
  final code = sql
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n');
  final lower = code.toLowerCase();

  String body(String name) {
    final marker = 'create or replace function public.$name(';
    final start = lower.indexOf(marker);
    if (start < 0) throw StateError('$name tanımlı değil');
    final next = lower.indexOf(
      'create or replace function public.',
      start + marker.length,
    );
    return code.substring(start, next == -1 ? code.length : next);
  }

  test('tek işlemde: begin … commit', () {
    expect(lower.trimLeft(), startsWith('begin;'));
    expect(lower.trimRight(), endsWith('commit;'));
  });

  group('nudge_async_duel', () {
    final fn = body('nudge_async_duel');
    final low = fn.toLowerCase();

    test('SECURITY DEFINER ve sabit search_path', () {
      expect(low, contains('security definer'));
      expect(low, contains("set search_path to 'public', 'pg_temp'"));
    });

    test('kimliksiz çağrı ve katılımcı olmayan reddedilir', () {
      expect(fn, contains("raise exception 'Not authenticated'"));
      expect(fn, contains("raise exception 'Not a duel player'"));
      expect(low, contains('for update'));
    });

    test('yalnız açık/eşleşmiş ve süresi dolmamış düello', () {
      expect(low, contains("status not in ('open', 'matched')"));
      expect(low, contains('expires_at <= v_now'));
      expect(fn, contains("raise exception 'Duel closed'"));
    });

    test('çağıran turunu bitirmeli, rakip bitirmemeli', () {
      expect(fn, contains("raise exception 'Finish your turn first'"));
      expect(fn, contains("raise exception 'Opponent already finished'"));
      expect(fn, contains("raise exception 'No opponent to nudge'"));
      // Hedef: yaratıcıysam rakip (yoksa davetli), değilsem yaratıcı.
      expect(low, contains('coalesce(v_duel.opponent_id, v_duel.invited_id)'));
    });

    test('engel iki yönde denetlenir', () {
      expect(low, contains('b.blocker_id = v_uid and b.blocked_id = v_target'));
      expect(low, contains('b.blocker_id = v_target and b.blocked_id = v_uid'));
      expect(fn, contains("raise exception 'Blocked'"));
    });

    test('düello+gönderici başına 12 saatte 1 (kilitli satır, upsert)', () {
      expect(low, contains("interval '12 hours'"));
      expect(fn, contains("raise exception 'Nudge cooldown'"));
      expect(low, contains('from public.async_duel_nudges n'));
      expect(
        low,
        contains(
          'insert into public.async_duel_nudges (duel_id, sender_id, recipient_id',
        ),
      );
    });

    test('gönderici→alıcı başına 12 saatte en çok 3 (düellolar arası)', () {
      expect(low, contains('n.recipient_id = v_target'));
      expect(low, contains('if v_pair >= 3 then'));
      expect(fn, contains("raise exception 'Nudge limit'"));
      expect(low, contains('pg_advisory_xact_lock'));
    });

    test('push: async_duel_turn, from_user_id, iki dilli KU · TR', () {
      expect(low, contains('insert into public.push_outbox'));
      expect(low, contains('(to_user_id, kind, title, body, from_user_id)'));
      expect(fn, contains("'async_duel_turn'"));
      expect(fn, contains('Dora te ye: '));
      expect(fn, contains(' · Sıra sende: '));
      // Gönderen kimliği son değer: engel denetimi tetikleyicide çalışır.
      expect(RegExp(r'v_uid\s*\n\s*\);').hasMatch(fn), isTrue);
    });

    test('anon kapalı, authenticated açık', () {
      expect(
        lower,
        contains(
          'revoke all on function public.nudge_async_duel(uuid) from public, anon;',
        ),
      );
      expect(
        lower,
        contains(
          'grant execute on function public.nudge_async_duel(uuid) to authenticated;',
        ),
      );
    });
  });

  group('async_duel_nudges tablosu', () {
    test('RLS açık, istemciye kapalı, düello silinince gider', () {
      expect(
        lower,
        contains('create table if not exists public.async_duel_nudges'),
      );
      expect(lower, contains('recipient_id uuid not null'));
      expect(lower, contains('(sender_id, recipient_id, nudged_at desc)'));
      expect(
        lower,
        contains(
          'alter table public.async_duel_nudges enable row level security;',
        ),
      );
      expect(
        lower,
        contains(
          'revoke all on table public.async_duel_nudges from public, anon, authenticated;',
        ),
      );
      expect(lower, contains('on delete cascade'));
    });
  });

  group('list_my_async_duels (canlı gövde + my_nudged_at)', () {
    final fn = body('list_my_async_duels');

    test('yeni anahtar ve birleşim eklendi', () {
      expect(fn, contains("'my_nudged_at', nud.last_nudged_at"));
      expect(fn, contains('from public.async_duel_nudges n'));
      expect(fn, contains(') nud on true'));
      expect(fn, contains('n.sender_id = v_uid'));
    });

    test('canlı gövdedeki hiçbir şey düşürülmedi', () {
      for (final needle in [
        "'duel_id', d.id",
        "'forfeit', (d.forfeit_loser_id is not null)",
        "'expires_at', d.expires_at",
        "'incoming_challenge'",
        "'invited_name'",
        "'opponent_id', opponent_profile.id",
        "interval '30 days'",
        "raise exception 'Not authenticated'",
      ]) {
        expect(fn, contains(needle), reason: '$needle kayıp');
      }
    });
  });

  group('profil maç geçmişi + rekorlar', () {
    test('my_match_history istemciye KAPALI', () {
      expect(
        lower,
        contains(
          'revoke all on function public.my_match_history(uuid, integer)\n  from public, anon, authenticated;',
        ),
      );
      expect(
        lower,
        isNot(contains('grant execute on function public.my_match_history')),
      );
    });

    test('iki RPC yalnız çağıranın verisini okur', () {
      final recent = body('list_my_recent_matches');
      expect(recent, contains('auth.uid()'));
      expect(recent, contains("raise exception 'Not authenticated'"));
      expect(recent, contains('my_match_history(v_uid, v_limit)'));
      expect(recent, contains('least(coalesce(p_limit, 10), 50)'));
      final records = body('get_my_records');
      expect(records, contains('auth.uid()'));
      expect(records, contains('my_duel_tally(v_uid)'));
      // Rekorlar tüm geçmişi satır satır üretmez.
      expect(records, isNot(contains('from public.my_match_history')));
      // Parametre olarak kullanıcı kimliği KABUL ETMEZ.
      expect(recent, isNot(contains('p_uid')));
      expect(records, isNot(contains('p_uid')));
    });

    test('maç kaynakları: bitmiş sırayla düello + bitmiş canlı oda', () {
      final h = body('my_match_history');
      expect(h, contains("d.status = 'completed'"));
      expect(h, contains('d.forfeit_loser_id is not null'));
      expect(h, contains("r.status = 'finished'"));
      expect(h, contains("r.ended_reason in ('completed', 'forfeit')"));
      expect(h, contains("'room_1v1'"));
    });

    test('her kaynak kendi sorgusunda sıralanıp limitlenir', () {
      final h = body('my_match_history');
      expect(
        RegExp(
          r'order by coalesce\(d\.completed_at, d\.expires_at\) desc\s+limit v_limit',
        ).hasMatch(h),
        isTrue,
      );
      expect(
        RegExp(
          r'order by coalesce\(r\.finished_at, r\.created_at\) desc\s+limit v_limit',
        ).hasMatch(h),
        isTrue,
      );
    });

    test('kalabalık odada hükmen herkese win vermez; rekora girmez', () {
      final h = body('my_match_history');
      expect(
        h,
        contains(
          'r.max_players = 2\n               and r.ended_reason = \'forfeit\'',
        ),
      );
      final tally = body('my_duel_tally');
      expect(tally, contains('and r.max_players = 2'));
    });

    test('en uzun doğru serisi: boşluk-ada, son 100 oda, anlık seri değil', () {
      final records = body('get_my_records');
      expect(
        records,
        contains('partition by pa.room_id order by rq.question_index'),
      );
      expect(records, contains('limit 100'));
      expect(records, isNot(contains('max(rp.streak)')));
    });

    test('anon kapalı, authenticated açık', () {
      for (final f in ['list_my_recent_matches(integer)', 'get_my_records()']) {
        expect(
          lower,
          contains('revoke all on function public.$f'),
          reason: '$f revoke',
        );
        expect(
          lower,
          contains('grant execute on function public.$f'),
          reason: '$f grant',
        );
      }
    });
  });

  test('doğrulama bloğu: ACL tutmazsa göç geri alınır', () {
    expect(lower, contains(r'do $verify$'));
    expect(lower, contains("has_function_privilege('anon'"));
    expect(
      lower,
      contains(
        "has_function_privilege('authenticated', 'public.my_match_history(uuid, integer)'",
      ),
    );
  });

  group('kanıt betiği', () {
    test('tek işlem, sonda rollback, auth.users yazmaz', () {
      expect(proof.trimRight(), endsWith('rollback;'));
      expect(proof, contains('\nbegin;'));
      expect(proof.toLowerCase(), isNot(contains('insert into auth.users')));
      expect(proof, contains('set_config('));
    });

    test('beş zorunlu senaryo satırı var', () {
      for (final needle in [
        '(a) izinli dürtme',
        '(b) 12 saat içinde ikinci dürtme',
        '(d) katılımcı olmayan',
        '(e) engelli çiftte dürtme',
        '(f) rakibi bitirmiş düelloda dürtme',
        '(l2) aynı alıcıya farklı düellodan 4. dürtme',
        '(m) 8 doğru + 1 yanlış + 2 doğru',
        '(n) kalabalık oda hükmen',
      ]) {
        expect(proof, contains(needle));
      }
      expect(proof, contains('bulgu | beklenen_once'));
      expect(proof, contains("'SONRA-OK'"));
      expect(proof, contains("'ONCE-DURUMU'"));
    });
  });

  test('applied.md satırı "bekliyor"', () {
    final line = applied
        .split('\n')
        .firstWhere((l) => l.contains('2026-10-24_duello_durtme.sql'));
    expect(line, contains('bekliyor'));
  });
}
