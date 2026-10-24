/// Düello incelemesi + rövanş göçü (`2026-10-24_duello_inceleme_rovans.sql`)
/// bekçisi.
///
/// ## Kusur
///
/// `get_async_duel_review` istemciye kapalı üç tabloyu (düello, cevaplar,
/// sorular) yeni bir SELECT yoluyla açar. Sunucu kuralı gevşerse (süren
/// düelloda cevap dönmesi, katılımcı olmayanın okuyabilmesi, engelli çiftte
/// rakibin adı/cevapları) oyuncu rakibin cevabından ya da doğru şıktan kopya
/// çeker, yabancı birinin düellosunu okur ya da engellediği kişinin kimliğini
/// görür.
///
/// ## Niçin sessiz kalırdı
///
/// Göç canlıda tek başına çalışır; bir `status` süzgeci unutulsa ya da engel
/// denetimi tek yönlü kalsa hiçbir derleme/analiz/widget testi bunu görmez.
/// Bu dosya göçü METİN olarak okuyup her kapıyı sabitler (repo deseni:
/// `duello_durtme_sql_test.dart`).
///
/// ## Kural
///
/// * Üç kapı: katılımcı ('Not a duel player'), bitmiş ('Duel not finished'),
///   engel (kimlik + ad + cevaplar gizli, kendi inceleme açık).
/// * `can_rematch` = rakip var + engel yok + kabul edilmiş arkadaş
///   (`create_async_duel_challenge` ile aynı koşul).
/// * SECURITY DEFINER, sabit search_path, anon kapalı, authenticated açık.
/// * Kanıt betiği tek işlemde rollback ile biter ve dört ana bulguyu üretir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/2026-10-24_duello_inceleme_rovans.sql',
  ).readAsStringSync();
  final proof = File(
    'supabase/kanit/2026-10-24_duello_inceleme_rovans_kanit.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();

  /// Yorum satırları atılmış metin: açıklayıcı yorumlar kod iddialarını
  /// bozmasın.
  final code = sql
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n');
  final lower = code.toLowerCase();

  test('tek işlemde: begin … commit', () {
    expect(lower.trimLeft(), startsWith('begin;'));
    expect(lower.trimRight(), endsWith('commit;'));
  });

  test('üç fonksiyon: yardımcı, rövanş davetı, inceleme', () {
    final creates = RegExp(
      r'create or replace function ([a-z_.]+)\(',
    ).allMatches(lower).map((m) => m.group(1)).toList();
    expect(creates, [
      'public.async_duel_recent_pair',
      'public.create_async_duel_challenge',
      'public.get_async_duel_review',
    ]);
  });

  /// Bir fonksiyonun gövdesi (sonraki `create or replace`e kadar).
  String bodyOf(String name) {
    final start = lower.indexOf('create or replace function public.$name(');
    final next = lower.indexOf(
      'create or replace function public.',
      start + 10,
    );
    return lower.substring(start, next == -1 ? lower.length : next);
  }

  group('async_duel_recent_pair', () {
    final fn = bodyOf('async_duel_recent_pair');
    test('bitmiş, rakipli, iki yönlü, son 7 gün; istemciye kapalı', () {
      expect(fn, contains("d.status in ('completed', 'expired')"));
      expect(fn, contains('d.opponent_id is not null'));
      expect(fn, contains('d.creator_id = p_a and d.opponent_id = p_b'));
      expect(fn, contains('d.creator_id = p_b and d.opponent_id = p_a'));
      expect(fn, contains("interval '7 days'"));
      expect(fn, contains("set search_path to 'public', 'pg_temp'"));
      expect(
        lower,
        contains(
          'revoke all on function public.async_duel_recent_pair(uuid, uuid)\n'
          '  from public, anon, authenticated;',
        ),
      );
    });
  });

  group('create_async_duel_challenge (rövanş istisnası)', () {
    final fn = bodyOf('create_async_duel_challenge');
    test('canlı gövde korunur: sınırlar, soru seçimi, dönüş', () {
      expect(
        fn,
        contains(
          "raise exception 'not authenticated'"
              .replaceFirst('not authenticated', 'Not authenticated')
              .toLowerCase(),
        ),
      );
      expect(fn, contains('v_open_count >= 5'));
      expect(fn, contains("raise exception 'too many open duels'"));
      expect(fn, contains('public.weighted_question_pick'));
      expect(
        fn,
        contains("'invited_id', case when v_invited_name is not null"),
      );
      expect(fn, contains("set search_path to 'public', 'pg_temp'"));
    });

    test('engel iki yönde HER ZAMAN reddeder, istisnadan önce', () {
      final block = fn.indexOf(
        'b.blocker_id = v_uid and b.blocked_id = p_friend_id',
      );
      final exception = fn.indexOf(
        'async_duel_recent_pair(v_uid, p_friend_id)',
      );
      expect(block, greaterThan(0));
      expect(exception, greaterThan(block));
      expect(
        fn,
        contains('b.blocker_id = p_friend_id and b.blocked_id = v_uid'),
      );
    });

    test('arkadaş değilse yalnız son 7 günde birlikte oynadıysa geçer', () {
      expect(
        fn,
        contains(
          'if not public.async_duel_recent_pair(v_uid, p_friend_id) then',
        ),
      );
      expect(fn, contains("raise exception 'not a friend'"));
      expect(fn, contains('v_non_friend := true'));
    });

    test('arkadaş olmayana günde en çok 3 davet, kilitten sonra', () {
      final lock = fn.indexOf('pg_advisory_xact_lock');
      final limit = fn.indexOf("raise exception 'too many invites'");
      final open = fn.indexOf('v_open_count >= 5');
      expect(limit, greaterThan(lock));
      expect(limit, lessThan(open));
      expect(fn, contains("d.created_at > now() - interval '24 hours'"));
      expect(fn, contains('if v_non_friend then'));
      expect(fn, contains('v_recent_invites >= 3'));
    });

    test('yetkiler: anon kapalı, authenticated açık', () {
      expect(
        lower,
        contains(
          'revoke all on function public.create_async_duel_challenge(text, uuid)\n'
          '  from public, anon;',
        ),
      );
      expect(
        lower,
        contains(
          'grant execute on function public.create_async_duel_challenge(text, uuid)\n'
          '  to authenticated;',
        ),
      );
    });
  });

  group('get_async_duel_review', () {
    test('SECURITY DEFINER, sabit search_path, schema nitelikli', () {
      expect(lower, contains('security definer'));
      expect(lower, contains("set search_path to 'public', 'pg_temp'"));
      expect(lower, contains('public.async_duels'));
      expect(lower, contains('public.async_duel_answers'));
      expect(lower, contains('public.questions'));
      // Niteliksiz tablo okuması yok.
      expect(
        RegExp(r'\bfrom (async_duels|questions|profiles)\b').hasMatch(lower),
        isFalse,
      );
    });

    test('kimliksiz ve olmayan düello reddedilir', () {
      expect(code, contains("raise exception 'Not authenticated'"));
      expect(code, contains("raise exception 'Duel not found'"));
      expect(lower, contains('v_uid uuid := auth.uid()'));
    });

    test('kapı 1: yalnız yaratıcı ya da eşleşmiş rakip', () {
      expect(code, contains("raise exception 'Not a duel player'"));
      expect(lower, contains('v_uid is distinct from v_duel.creator_id'));
      expect(lower, contains('v_uid is distinct from v_duel.opponent_id'));
    });

    test('kapı 2: yalnız bitmiş düello (süren düelloda hiçbir cevap yok)', () {
      expect(code, contains("raise exception 'Duel not finished'"));
      expect(lower, contains("v_duel.status not in ('completed', 'expired')"));
      // Süzgeç, cevapları toplayan sorgudan ÖNCE gelir.
      expect(
        lower.indexOf("raise exception 'duel not finished'"),
        lessThan(lower.indexOf('async_duel_answers')),
      );
    });

    test('kapı 3: iki yönlü engel; rakip kimliği/adı/cevapları gizli', () {
      expect(
        lower,
        contains('b.blocker_id = v_uid and b.blocked_id = v_other'),
      );
      expect(
        lower,
        contains('b.blocker_id = v_other and b.blocked_id = v_uid'),
      );
      // Rakip cevapları yalnız engelsizse (v_show_other) eşleşir.
      expect(lower, contains('theirs.player_id = v_show_other'));
      expect(lower, contains("'opponent_id', v_show_other"));
      expect(lower, contains("'opponent_blocked', v_blocked"));
      // Engelde ad hiç okunmaz: select, `if not v_blocked` içindedir.
      final fnr = bodyOf('get_async_duel_review');
      final block = fnr.indexOf('if not v_blocked then');
      final nameRead = fnr.indexOf('select p.display_name');
      expect(block, greaterThan(0));
      expect(nameRead, greaterThan(block));
    });

    test('rövanş uygunluğu: rakip var + engel yok + (arkadaş ya da 7 gün)', () {
      expect(lower, contains('from public.friends f'));
      expect(lower, contains('f.user_id = v_uid and f.friend_id = v_other'));
      expect(
        lower,
        contains(
          "'can_rematch', (v_show_other is not null and (v_friend or v_recent))",
        ),
      );
    });

    test('doğru şık yalnız bitmiş düelloda döner (kapılardan sonra)', () {
      expect(lower, contains("'correct_option', q.correct_option"));
      expect(
        lower.indexOf("'correct_option'"),
        greaterThan(lower.indexOf("raise exception 'duel not finished'")),
      );
    });

    test('yanıt: 7 soru sıralı, benim ve rakibin cevabı ayrı', () {
      expect(lower, contains('unnest(v_duel.question_ids) with ordinality'));
      expect(lower, contains('order by o.idx'));
      expect(lower, contains('mine.player_id = v_uid'));
      expect(lower, contains("'my', case"));
      expect(lower, contains("'opp', case"));
      expect(lower, contains("'choice', mine.choice"));
      expect(lower, contains("'ms', mine.response_ms"));
    });

    test('anon kapalı, authenticated açık', () {
      expect(
        lower,
        contains(
          'revoke all on function public.get_async_duel_review(uuid)\n'
          '  from public, anon;',
        ),
      );
      expect(
        lower,
        contains(
          'grant execute on function public.get_async_duel_review(uuid)\n'
          '  to authenticated;',
        ),
      );
    });
  });

  group('kanıt betiği', () {
    test('tek işlem, rollback ile biter, auth.users satırı eklemez', () {
      final low = proof.toLowerCase();
      expect(low, contains('\nbegin;'));
      expect(low.trimRight(), endsWith('rollback;'));
      expect(low, isNot(contains('insert into auth.users')));
      expect(low, isNot(contains('\ncommit;')));
    });

    test('dinamik SQL: göçten önce çalışır (RPC yok)', () {
      expect(
        proof,
        contains("to_regprocedure('public.get_async_duel_review(uuid)')"),
      );
      expect(
        proof,
        contains("execute 'select public.get_async_duel_review(\$1)'"),
      );
      expect(proof, contains("'RPC yok'"));
    });

    test('çıktı sütunları ve durumlar', () {
      expect(proof, contains('bulgu | beklenen_once'));
      expect(proof, contains("'SONRA-OK'"));
      expect(proof, contains("'ONCE-DURUMU'"));
      expect(proof, contains("'BEKLENMEDIK'"));
      expect(proof, contains("set_config('request.jwt.claims'"));
    });

    test('dört ana bulgu ve kontrol satırları var', () {
      expect(proof, contains('(1a) yaratıcı bitmiş düelloyu görür'));
      expect(proof, contains('(2) katılımcı olmayan reddedilir'));
      expect(proof, contains("'Not a duel player'"));
      expect(proof, contains("'Duel not finished'"));
      expect(proof, contains('(4a) engelleyen'));
      expect(proof, contains('opp_id=null,name=null,blocked=true'));
      expect(proof, contains('(7a) anon çalıştıramaz'));
      expect(proof, contains('(8b) kontrol: engelli arkadaşa meydan okuma'));
      expect(proof, contains('(8c) arkadaş olmayan, hiç oynamadığımız'));
      expect(proof, contains("'Not a friend', 'davetli kaydedildi'"));
      expect(proof, contains("'Not a friend', 'Too many invites'"));
      expect(proof, contains('(8g) engelli, birlikte oynanmış'));
      expect(proof, contains('(8f) 7 günden eski'));
    });
  });

  test('applied.md satırı bekliyor olarak işli', () {
    final line = applied
        .split('\n')
        .firstWhere((l) => l.contains('2026-10-24_duello_inceleme_rovans.sql'));
    expect(line, contains('bekliyor'));
    expect(line, isNot(contains('✅')));
  });
}
