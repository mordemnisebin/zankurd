/// Sırayla düello (async 1v1) — Supabase göç sözleşmesi bekçisi.
///
/// ## Kusur
///
/// Küçük kullanıcı kitlesinde canlı eşleştirme (`join_matchmaking`) çoğu
/// zaman rakipsiz kalıyor: oyuncu ya botla oynuyor ya da hiç oynayamıyor.
/// `supabase/2026-09-28_async_duels.sql`, rakibin aynı anda çevrimiçi
/// olmasını gerektirmeyen bir 1v1 açıyor — ama bu, `questions.correct_option`
/// gibi daha önce hiç istemciye açılmamış bir alanı yeni bir yüzeyden
/// (yeni RPC'ler, yeni tablolar) bir daha sızdırma riski taşıyan bir göç.
///
/// ## Niçin sessiz kalırdı
///
/// Migration dosyası tek başına "derlenmiyor" diye değil, RLS'nin üç
/// tablodan birinde unutulması, bir RPC'nin `search_path` almadan
/// yayınlanması ya da soru JSON'una doğru cevabın yanlışlıkla eklenmesi
/// gibi SESSİZCE geçen sızıntılarla bozulur — bunların hiçbiri
/// `flutter analyze` ya da normal widget testleriyle yakalanmaz. Repo
/// deseni (`test/xp_idempotency_acl_contract_test.dart`,
/// `test/award_xp_server_authority_contract_test.dart`) göç dosyasını
/// canlıya uygulamadan METİN olarak okuyup sözleşmenin her maddesini tek
/// tek denetlemektir; bu dosya düello sözleşmesini (RPC imzaları, JSON
/// anahtarları, hata metinleri — Dart tarafı `lib/src/models/async_duel.dart`)
/// aynı şekilde denetler.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tables = ['async_duels', 'async_duel_answers', 'async_duel_results'];

const _clientFunctions = [
  'start_async_duel',
  'answer_async_duel',
  'list_my_async_duels',
  'mark_async_duel_seen',
  'claim_async_duel_xp',
];

void main() {
  final sql = File('supabase/2026-09-28_async_duels.sql').readAsStringSync();

  /// Bir fonksiyonun `create or replace function public.<name>(`
  /// satırından bir SONRAKİ `create or replace function` satırına (ya da
  /// dosya sonuna) kadarki bölümünü döndürür — hata metinleri ve
  /// JSON alanları gibi bir fonksiyona ÖZGÜ iddiaları, dosyanın başka
  /// yerinde geçen aynı kelimelerle karıştırmadan denetlemek için.
  String functionBody(String name) {
    final marker = 'create or replace function public.$name(';
    final start = sql.indexOf(marker);
    expect(start, greaterThanOrEqualTo(0), reason: "$name tanımlı değil");
    final next = sql.indexOf(
      'create or replace function public.',
      start + marker.length,
    );
    return sql.substring(start, next == -1 ? sql.length : next);
  }

  group('üç tabloda RLS açık ve istemci yetkisi tamamen kapalı', () {
    for (final table in _tables) {
      test(table, () {
        expect(
          sql,
          contains('alter table public.$table enable row level security'),
        );
        expect(
          sql,
          contains(
            'revoke all on table public.$table from public, anon, authenticated',
          ),
        );
      });
    }
  });

  group('her RPC security definer + search_path=public taşıyor', () {
    for (final fn in [..._clientFunctions, 'expire_async_duels']) {
      test(fn, () {
        final body = functionBody(fn);
        expect(body, contains('language plpgsql'));
        expect(body, contains('security definer'));
        expect(body, contains('set search_path = public'));
        // 2026-09-06_award_xp_server_authority_contract_test.dart'taki
        // regresyonun aynısı: yanlışlıkla STABLE/IMMUTABLE işaretlenmiş bir
        // yazma fonksiyonu istemciye eski veri döndürebilir.
        expect(body, isNot(RegExp(r'\bstable\b', caseSensitive: false)));
        expect(body, isNot(RegExp(r'\bimmutable\b', caseSensitive: false)));
      });
    }
  });

  group('client RPC\'leri authenticated\'e açık, anon/public\'e kapalı', () {
    test('start_async_duel(text)', () {
      expect(
        sql,
        contains(
          'revoke all on function public.start_async_duel(text) from public, anon',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.start_async_duel(text) to authenticated',
        ),
      );
    });

    test('answer_async_duel(uuid, integer, text, integer)', () {
      expect(
        sql,
        contains(
          'revoke all on function public.answer_async_duel(uuid, integer, text, integer)\n'
          '  from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.answer_async_duel(uuid, integer, text, integer)\n'
          '  to authenticated;',
        ),
      );
    });

    test('list_my_async_duels()', () {
      expect(
        sql,
        contains(
          'revoke all on function public.list_my_async_duels() from public, anon',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.list_my_async_duels() to authenticated',
        ),
      );
    });

    test('mark_async_duel_seen(uuid)', () {
      expect(
        sql,
        contains(
          'revoke all on function public.mark_async_duel_seen(uuid) from public, anon',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.mark_async_duel_seen(uuid) to authenticated',
        ),
      );
    });

    test('claim_async_duel_xp(uuid)', () {
      expect(
        sql,
        contains(
          'revoke all on function public.claim_async_duel_xp(uuid) from public, anon',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.claim_async_duel_xp(uuid) to authenticated',
        ),
      );
    });
  });

  test('expire_async_duels istemciye (authenticated dahil) hiç açılmamış', () {
    expect(
      sql,
      contains(
        'revoke all on function public.expire_async_duels()\n'
        '  from public, anon, authenticated;',
      ),
      reason: 'authenticated de dahil edilmeli, yoksa cron dışı çağrı mümkün',
    );
    expect(
      sql,
      contains(
        'grant execute on function public.expire_async_duels() to service_role',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant execute on function public.expire_async_duels() to authenticated',
        ),
      ),
    );
  });

  test('start_async_duel döndürdüğü soru nesnesinde correct_option YOK', () {
    final body = functionBody('start_async_duel');

    final jsonStart = body.indexOf(
      "jsonb_build_object(\n      'index', ord.idx - 1,",
    );
    expect(
      jsonStart,
      greaterThanOrEqualTo(0),
      reason: 'soru JSON bloğu bulunamadı — dosya yeniden şekillendi mi?',
    );
    final jsonEnd = body.indexOf('from unnest(v_question_ids)', jsonStart);
    expect(jsonEnd, greaterThan(jsonStart));

    final questionJson = body.substring(jsonStart, jsonEnd);
    expect(questionJson, isNot(contains('correct_option')));
    // Yanlış bloğu yakalamadığımızı doğrula: gerçek alanlar orada olmalı.
    expect(questionJson, contains("'option_a'"));
    expect(questionJson, contains("'option_d'"));
    expect(questionJson, contains("'difficulty'"));
  });

  test(
    'start_async_duel: Not authenticated + 5 açık düello + 7 soru sabiti',
    () {
      final body = functionBody('start_async_duel');
      expect(body, contains("raise exception 'Not authenticated'"));
      expect(body, contains('v_open_count >= 5'));
      expect(body, contains("raise exception 'Too many open duels'"));
      expect(body, contains('limit 7'));
      expect(body, contains('v_question_count < 7'));
      expect(body, contains("raise exception 'No questions'"));
    },
  );

  test(
    'answer_async_duel doğruluğu correct_option ile SUNUCUDA hesaplıyor',
    () {
      final body = functionBody('answer_async_duel');
      // İstemcinin gönderdiği bir "is_correct" alanı yok; tek kaynak
      // questions.correct_option'ın sunucu tarafından okunmasıdır.
      expect(body, contains('q.correct_option into v_correct_option'));
      expect(
        body,
        contains(
          'v_is_correct := coalesce(v_correct_option = p_choice, false)',
        ),
      );
    },
  );

  test('answer_async_duel hata metinleri sözleşmeyle birebir aynı', () {
    final body = functionBody('answer_async_duel');
    for (final message in [
      'Not authenticated',
      'Duel not found',
      'Not a duel player',
      'Duel expired',
      'Already answered',
      'Invalid choice',
      'Invalid index',
    ]) {
      expect(
        body,
        contains("raise exception '$message'"),
        reason: "'$message' hatası eksik ya da metni değişmiş",
      );
    }
  });

  test('answer_async_duel: ilk cevap kilidi unique_violation üzerinden', () {
    final body = functionBody('answer_async_duel');
    expect(body, contains('when unique_violation then'));
    expect(body, contains("raise exception 'Already answered'"));
  });

  test('answer_async_duel: response_ms 0..120000 kırpılır, reddedilmez', () {
    final body = functionBody('answer_async_duel');
    expect(
      body,
      contains(
        'v_response_ms := greatest(0, least(coalesce(p_response_ms, 0), 120000))',
      ),
    );
  });

  test(
    'claim_async_duel_xp: idempotent, 20/doğru + 30/galibiyet, award_xp_delta ile',
    () {
      final body = functionBody('claim_async_duel_xp');
      expect(body, contains('xp_awarded'));
      expect(body, contains("raise exception 'Duel not finished'"));
      expect(body, contains('correct_count * 20'));
      expect(body, contains('v_delta + 30'));
      expect(body, contains('public.award_xp_delta(v_delta)'));
    },
  );

  test(
    'expire_async_duels: hem open hem matched, süresi geçmiş olanları kapatır',
    () {
      final body = functionBody('expire_async_duels');
      expect(body, contains("status in ('open', 'matched')"));
      expect(body, contains('expires_at <= now()'));
    },
  );

  group('inceleme düzeltmeleri (ana ajan, 2026-09-27)', () {
    test('süre dolunca gönderilen TIMEOUT kabul edilir ve yanlış sayılır', () {
      expect(
        sql,
        contains("check (choice in ('A', 'B', 'C', 'D', 'TIMEOUT'))"),
      );
      final body = functionBody('answer_async_duel');
      expect(body, contains("not in ('A', 'B', 'C', 'D', 'TIMEOUT')"));
      // Doğruluk yine yalnız correct_option karşılaştırmasıyla: TIMEOUT
      // hiçbir şıkla eşleşmediği için her zaman false.
      expect(body, contains('coalesce(v_correct_option = p_choice, false)'));
    });

    test('rakip eşleşince kendi 48 saatini alır', () {
      final body = functionBody('start_async_duel');
      expect(
        body,
        contains(
          "expires_at = greatest(expires_at, now() + interval '48 hours')",
        ),
      );
      expect(body, contains('returning expires_at into v_expires_at'));
    });

    test('dosya kalıcı olmayan bir çalışma klasörüne atıf yapmaz', () {
      expect(sql, isNot(contains('scratchpad')));
    });

    test('yalnız açanı turunu bitirmiş düellolar eşleşir', () {
      final body = functionBody('start_async_duel');
      expect(body, contains('from public.async_duel_results r'));
      expect(body, contains('r.player_id = d.creator_id'));
    });
  });
}
