// 2026-10-16 "son boşluklar" göçünün (beş sessiz sunucu kusuru) bekçisi.
//
// Kurallar SQL'de yaşadığı için istemci testleri bunları göremez; bu dosya
// göçün metnine bakar. Her grup, kusurun ne olduğunu ve niçin sessiz
// kaldığını anlatır. Canlı doğrulama (geri alınan işlemde duman testi) ana
// ajanda; burada yalnız dosyanın amaçlanan davranışı koruduğu ölçülür.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';

void main() {
  final sql = File('supabase/2026-10-16_son_bosluklar.sql').readAsStringSync();

  /// `create or replace function public.<name>(` ... `$function$;` bloğu.
  String body(String name) {
    // toLowerCase() Türkçe büyük İ'de uzunluğu değiştirir; büyük/küçük harf
    // duyarsız eşleşme için RegExp kullanılır.
    final match = RegExp(
      'create or replace function public\\.$name\\(',
      caseSensitive: false,
    ).firstMatch(sql);
    if (match == null) throw StateError('$name göçte tanımlı olmalı');
    final start = match.start;
    final open = sql.indexOf(r'$function$', start) + r'$function$'.length;
    final close = sql.indexOf(r'$function$', open);
    return sql.substring(start, close + r'$function$'.length);
  }

  test('tek işlemde, idempotent create or replace', () {
    expect(sql, contains('\nbegin;\n'));
    expect(sql.trimRight(), endsWith('commit;'));
    final code = sql
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n');
    expect(code, isNot(contains('drop function')));
    expect(code, isNot(contains('drop table')));
  });

  test('applied.md satırı var ve henüz uygulanmadı olarak işaretli', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(applied, contains('| 2026-10-16_son_bosluklar.sql |'));
  });

  group('1) get_my_favorite_questions', () {
    final fn = body('get_my_favorite_questions');

    test('çağıranın favorisi + onaylı soru; cevap ve açıklama sızmaz', () {
      expect(fn, contains('security definer'));
      expect(fn, contains('set search_path = public'));
      expect(fn, contains('auth.uid() is null'));
      expect(fn, contains('f.player_id = auth.uid()'));
      // favorite_questions.question_id metindir.
      expect(fn, contains('f.question_id = q.id::text'));
      expect(fn, contains('q.is_approved = true'));
      expect(fn, isNot(contains('correct_option')));
      expect(fn, isNot(contains('explanation')));
      expect(fn, isNot(contains('source_url')));
    });

    test('tek çağrıda en çok 200 kimlik', () {
      expect(fn, contains('cardinality(p_ids) > 200'));
    });

    test('anon çağıramaz, authenticated çağırır', () {
      expect(
        sql,
        contains(
          'revoke all on function public.get_my_favorite_questions(uuid[]) '
          'from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.get_my_favorite_questions(uuid[]) '
          'to authenticated, service_role;',
        ),
      );
    });
  });

  group('2) ayrılan oyuncu sonucu görür', () {
    test('kalabalık dalında left_at şartı yok; tamlık şartı ve 1v1 kalır', () {
      final fn = body('get_room_result_payload');
      expect(fn, isNot(contains('mine.left_at is null')));
      expect(fn, contains('public.crowd_room_result_complete(r.id)'));
      // Eski dal aynen: tam iki oyuncu, hepsi açıklanmış, skorlar tutarlı.
      expect(fn, contains('not (r.is_custom and r.max_players > 2)'));
      expect(fn, contains('having count(*) = 2'));
      expect(fn, contains('having count(*) = r.question_count * 2'));
      // Makbuz verildiyse bekleyen sonuç olarak yeniden sunulmaz.
      expect(fn, contains('from public.room_result_receipts receipt'));
      // Hiç cevabı olmayan ayrılan: istemci answers için liste ister.
      expect(fn, contains("'answers', coalesce(v_answers, '[]'::jsonb)"));
    });

    test('get_my_room_result / pending bu fonksiyona yaslanır, değişmez', () {
      expect(sql, isNot(contains('function public.get_my_room_result')));
      expect(
        sql,
        isNot(contains('function public.get_my_pending_room_result')),
      );
    });

    test('acknowledge_room_result ayrılanı da kabul eder', () {
      final fn = body('acknowledge_room_result');
      expect(fn, contains('or (r.is_custom and r.max_players > 2)\n'));
      expect(fn, isNot(contains('r.max_players > 2 and rp.left_at is null')));
      // Tamlık yine denetlenir; idempotent makbuz yolu yerinde.
      expect(fn, contains('public.crowd_room_result_complete(p_room_id)'));
      expect(fn, contains('on conflict (room_id, player_id) do nothing'));
    });
  });

  group('3) yarım rastgele düello', () {
    final fn = body('start_async_duel');

    test(
      'kilitten sonra, eşleşme aramasından ÖNCE yarım düelloyu döndürür',
      () {
        final lock = fn.indexOf('pg_advisory_xact_lock');
        final resume = fn.indexOf("d.status = 'matched'");
        final match = fn.indexOf("d.status = 'open'");
        expect(lock, isNonNegative);
        expect(resume, greaterThan(lock));
        expect(match, greaterThan(resume));
      },
    );

    test('yalnız rakip olarak eşleşilen, sonucu olmayan, rastgele düello', () {
      expect(fn, contains('d.opponent_id = v_uid'));
      expect(fn, contains('d.invited_id is null'));
      expect(fn, contains('d.challenge_code is null'));
      expect(fn, contains('d.expires_at > now()'));
      expect(fn, contains('from public.async_duel_results r'));
    });

    test('yanıt kendi şekli + answered/finished; soru payload ortak', () {
      for (final key in [
        "'duel_id', v_duel.id",
        "'role', 'opponent'",
        "'opponent_name', v_opponent_name",
        "'expires_at', v_duel.expires_at",
        "'questions', public.async_duel_questions_payload(v_duel.question_ids)",
        "'answered', v_answered",
        "'finished', false",
      ]) {
        expect(fn, contains(key));
      }
    });

    test('canlı gövdeden korunanlar: engel, gizli kategori, 5 açık düello', () {
      expect(fn, contains('public.blocked_users b'));
      expect(fn, contains('Too many open duels'));
      expect(fn, contains('for update skip locked'));
      expect(fn, contains('d.challenge_code is null'));
    });

    test('istemci bu yanıtı zaten okur: kaldığı sorudan devam eder', () {
      final start = AsyncDuelStart.fromJson({
        'duel_id': 'd1',
        'role': 'opponent',
        'opponent_name': 'Rojda',
        'expires_at': '2026-10-17T10:00:00Z',
        'questions': <Map<String, dynamic>>[
          for (var i = 0; i < 7; i++)
            {
              'index': i,
              'id': 'q$i',
              'category_name': 'Ziman',
              'prompt': 'Soru $i?',
              'option_a': 'A',
              'option_b': 'B',
              'option_c': 'C',
              'option_d': 'D',
              'question_type': 'multiple_choice',
              'image_url': null,
              'difficulty': 2,
            },
        ],
        'answered': 3,
        'finished': false,
      });
      expect(start.answeredCount, 3);
      expect(start.alreadyFinished, isFalse);
      expect(start.questions, hasLength(7));
      expect(start.questions.first.hasHiddenAnswer, isTrue);
    });
  });

  group('4) UTC gün -> app_today()', () {
    const functions = [
      'award_xp_delta',
      'sync_mission_completion',
      'get_today_contest',
      'save_tournament_progress',
      'league_week_start',
      'finalize_weekly_league',
    ];

    test('altı fonksiyonda current_date ve UTC günü kalmadı', () {
      for (final name in functions) {
        final fn = body(name);
        expect(
          fn.toLowerCase(),
          isNot(contains('current_date')),
          reason: '$name hâlâ UTC günü kullanıyor',
        );
        expect(fn, isNot(contains("'UTC'")), reason: name);
      }
    });

    test('günlük anahtarlar app_today() ile yazılır', () {
      final xp = body('award_xp_delta');
      expect('public.app_today()'.allMatches(xp).length, 3);
      expect(
        body('sync_mission_completion'),
        contains('v_today := public.app_today();'),
      );
      expect(
        body('save_tournament_progress'),
        contains('v_today DATE := public.app_today();'),
      );
      final contest = body('get_today_contest');
      expect('public.app_today()'.allMatches(contest).length, 3);
      expect(contest, contains('on conflict (day_key) do nothing'));
    });

    test(
      'lig haftası İstanbul pazartesi 00:00; cron saatinden önce kapanır',
      () {
        expect(
          body('league_week_start'),
          contains(
            "date_trunc('week', ts at time zone 'Europe/Istanbul')::date",
          ),
        );
        final fin = body('finalize_weekly_league');
        expect(
          fin,
          contains(
            "v_from timestamptz := (v_week::timestamp at time zone "
            "'Europe/Istanbul')",
          ),
        );
        expect(
          fin,
          contains(
            "v_to   timestamptz := ((v_week + 7)::timestamp at time zone "
            "'Europe/Istanbul')",
          ),
        );
        // Anahtar ve kademe mantığı dokunulmadan kalır.
        expect(fin, contains('public.league_tier_for_rank'));
        expect(fin, contains("week_start = (v_week - 7)"));
      },
    );
  });

  group('5) sıralama günlük puan tavanı', () {
    for (final name in ['get_leaderboard', 'get_my_leaderboard_rank']) {
      test('$name: (oyuncu, İstanbul günü) başına 5000 ile kesilir', () {
        final fn = body(name);
        expect(fn, contains('least(coalesce(sum(rp.score), 0), 5000)'));
        expect(
          fn,
          contains("(r.finished_at at time zone 'Europe/Istanbul')::date"),
        );
        // Süzgeçler değişmedi.
        expect(
          fn,
          contains("coalesce(r.ended_reason, 'completed') = 'completed'"),
        );
        expect(fn, contains('public.blocked_users b'));
        expect(fn, contains('b.blocker_id = auth.uid()'));
        // Oda sayısı tavanlanmaz: tüm odalar sayılır.
        expect(fn, contains('count(distinct rp.room_id)'));
        // Bugün eklenen eşitlik sırası korunur.
        expect(fn, contains('player_id asc'));
      });
    }

    test('sıra: puan, seri, oda sayısı, kimlik (iki fonksiyonda aynı)', () {
      final list = body('get_leaderboard');
      final rank = body('get_my_leaderboard_rank');
      expect(list, contains('pd.player_id asc'));
      expect(rank, contains('b.player_id asc'));
      expect(rank, contains('row_number() over ('));
    });
  });
}
