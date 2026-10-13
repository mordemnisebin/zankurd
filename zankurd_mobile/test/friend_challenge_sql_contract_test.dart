/// Arkadaşa meydan okuma (`supabase/2026-10-13_friend_challenge.sql`) —
/// sunucu sözleşmesi bekçisi.
///
/// ## Kusur
///
/// Sırayla düello yalnız RASTGELE rakiple eşleşiyordu; `async_duels.
/// invited_id` sütunu hiçbir RPC tarafından doldurulmuyordu. Birbirini
/// tanıyan insanlar arasındaki yarış (ürünün rakipsiz yüzü ve tek büyüme/
/// dönüş döngüsü) bu yüzden yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// Bu göç Docker'sız yazıldı: yerelde `db reset` koşmadı. Bir RPC'nin
/// anon'a açık kalması, rastgele eşleşmenin bağlantı düellosunu çalması,
/// başkasının kodunun listede sızması, engelin ifşa edilmesi ya da davetli
/// olmayanın arkadaş meydan okumasını kabul etmesi hiçbir derleme/analiz
/// hatası vermez; yalnız canlıda, bir insanın başına gelir. Bu dosya göçü
/// canlıya uygulamadan METİN olarak okuyup her maddeyi tek tek denetler
/// (repo deseni: `async_duel_sql_contract_test.dart`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/join_deep_link.dart';

void main() {
  final sql = File(
    'supabase/2026-10-13_friend_challenge.sql',
  ).readAsStringSync();
  final blocking = File(
    'supabase/2026-10-02_blocking_enforcement.sql',
  ).readAsStringSync();
  final original = File(
    'supabase/2026-09-28_async_duels.sql',
  ).readAsStringSync();

  /// `create or replace function public.<name>(` satırından bir sonraki
  /// `create or replace function` satırına (ya da dosya sonuna) kadar.
  /// Büyük/küçük harf duyarsız (start_async_duel `CREATE OR REPLACE` ile
  /// başlar).
  String bodyOf(String source, String name) {
    final lower = source.toLowerCase();
    final marker = 'create or replace function public.$name(';
    final start = lower.indexOf(marker);
    if (start < 0) throw StateError('$name tanımlı değil');
    final next = lower.indexOf(
      'create or replace function public.',
      start + marker.length,
    );
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('şema', () {
    test('challenge_code nullable, UNIQUE ve biçim kısıtlı', () {
      expect(sql, contains('add column if not exists challenge_code text;'));
      expect(
        sql,
        contains(
          'create unique index if not exists async_duels_challenge_code_key',
        ),
      );
      expect(sql, contains(r"challenge_code ~ '^D[2-9A-HJKMNP-Z]{8}$'"));
      // Nullable: "not null" yok.
      expect(sql, isNot(contains('challenge_code text not null')));
    });

    test('kod üreticisi onaylı alfabeyi ve D önekini kullanır', () {
      expect(sql, contains("'23456789ABCDEFGHJKMNPQRSTUVWXYZ'"));
      expect(sql, contains("v_code text := 'D';"));
      // 31 karakterlik alfabe: 8 + 8 + 4 + 11.
      expect(sql, contains('% 31'));
      // Belirsiz karakterler alfabede yok.
      final alphabet = RegExp(
        r"v_alphabet constant text := '([^']+)'",
      ).firstMatch(sql)!.group(1)!;
      expect(alphabet.length, 31);
      for (final c in ['0', '1', 'O', 'I', 'L']) {
        expect(alphabet.contains(c), isFalse, reason: '$c belirsiz');
      }
      // Rastgelelik kaynağı CSPRNG, random() değil.
      final gen = bodyOf(sql, 'generate_async_duel_challenge_code');
      expect(gen, contains('gen_random_uuid()'));
      expect(gen, isNot(contains('random()')));
    });

    test('SQL kod biçimi ile Dart ayrıştırıcısı aynı regex', () {
      // Aynı dize iki yerde de durmalı; biri değişirse bu test düşer.
      expect(sql, contains(r'^D[2-9A-HJKMNP-Z]{8}$'));
      expect(JoinDeepLink.isChallengeCode('DK7M2Q9XA'), isTrue);
      expect(JoinDeepLink.isChallengeCode('DK7M2Q9X0'), isFalse);
    });

    test('iç yardımcılar istemciye kapalı', () {
      expect(
        sql,
        contains(
          'revoke all on function public.generate_async_duel_challenge_code()\n'
          '  from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on function public.async_duel_questions_payload(uuid[])\n'
          '  from public, anon, authenticated;',
        ),
      );
    });
  });

  group('create_async_duel_challenge', () {
    final body = bodyOf(sql, 'create_async_duel_challenge');

    test('imza ve yetkiler', () {
      expect(body, contains('p_category text default null'));
      expect(body, contains('p_friend_id uuid default null'));
      expect(body, contains('language plpgsql'));
      expect(body, contains('security definer'));
      expect(body, contains('set search_path = public'));
      expect(
        sql,
        contains(
          'revoke all on function public.create_async_duel_challenge(text, uuid)\n'
          '  from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.create_async_duel_challenge(text, uuid)\n'
          '  to authenticated;',
        ),
      );
    });

    test('kimlik zorunlu', () {
      expect(body, contains('v_uid uuid := auth.uid();'));
      expect(body, contains("raise exception 'Not authenticated'"));
    });

    test('ASLA bekleyen rastgele düelloya eşleşmez', () {
      // Eşleşme aramasındaki iki işaret yok: `for update skip locked` ve
      // `status = 'matched'` güncellemesi.
      expect(body, isNot(contains('skip locked')));
      expect(body, isNot(contains("set opponent_id")));
      expect(body, isNot(contains("'matched'")));
      expect(body, contains('insert into public.async_duels'));
    });

    test('açık düello sınırı start_async_duel ile aynı kilit ve sayı', () {
      expect(
        body,
        contains(
          "pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0))",
        ),
      );
      expect(body, contains('v_open_count >= 5'));
      expect(body, contains("raise exception 'Too many open duels'"));
      expect(body, contains("status = 'open'"));
    });

    test('soru seçimi start_async_duel ile aynı süzgeç', () {
      final start = bodyOf(blocking, 'start_async_duel');
      for (final fragment in [
        'q.is_approved = true',
        'c.is_active = true',
        "btrim(coalesce(q.prompt, '')) <> ''",
        "coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'",
        "q.correct_option in ('A', 'B', 'C', 'D')",
        "q.question_type = 'true_false'",
        "q.correct_option in ('A', 'B')",
        'limit 7',
      ]) {
        expect(start, contains(fragment), reason: 'start: $fragment');
        expect(body, contains(fragment), reason: 'create: $fragment');
      }
      expect(body, contains("raise exception 'No questions'"));
    });

    test(
      'arkadaş: kabul edilmiş, engelsiz, kendisi değil; engel ifşa edilmez',
      () {
        expect(body, contains('p_friend_id = v_uid'));
        expect(body, contains('from public.friends f'));
        expect(
          body,
          contains('f.user_id = v_uid and f.friend_id = p_friend_id'),
        );
        expect(body, contains('from public.blocked_users b'));
        // İki yön.
        expect(
          body,
          contains('b.blocker_id = v_uid and b.blocked_id = p_friend_id'),
        );
        expect(
          body,
          contains('b.blocker_id = p_friend_id and b.blocked_id = v_uid'),
        );
        // Tek ve ortak hata metni.
        expect(
          RegExp("raise exception 'Not a friend'").allMatches(body).length,
          1,
        );
      },
    );

    test(
      'invited_id ve challenge_code yazılır; kod UNIQUE çakışmasında yeniden denenir',
      () {
        expect(
          body,
          contains(
            'category_id, question_ids, creator_id, invited_id, challenge_code, status',
          ),
        );
        expect(
          body,
          contains('v_category_id, v_question_ids, v_uid, p_friend_id, v_code'),
        );
        expect(body, contains('generate_async_duel_challenge_code()'));
        expect(body, contains('when unique_violation'));
      },
    );

    test('yanıt start_async_duel şeklini korur + yeni alanlar', () {
      for (final key in [
        "'duel_id'",
        "'role', 'creator'",
        "'opponent_name'",
        "'expires_at'",
        "'questions'",
        "'challenge_code', v_code",
        "'invited_name'",
      ]) {
        expect(body, contains(key));
      }
      // Doğru şık sızmaz.
      expect(body, isNot(contains("'correct_option'")));
      final payload = bodyOf(sql, 'async_duel_questions_payload');
      expect(payload, isNot(contains('correct_option')));
      for (final key in [
        "'index'",
        "'category_name'",
        "'prompt'",
        "'option_a'",
        "'option_d'",
        "'question_type'",
        "'image_url'",
        "'difficulty'",
      ]) {
        expect(payload, contains(key));
      }
    });
  });

  group('accept_async_duel_challenge', () {
    final body = bodyOf(sql, 'accept_async_duel_challenge');

    test('imza ve yetkiler: yalnız authenticated (misafir dahil), anon yok', () {
      expect(body, contains('security definer'));
      expect(body, contains('set search_path = public'));
      expect(
        sql,
        contains(
          'revoke all on function public.accept_async_duel_challenge(text)\n'
          '  from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.accept_async_duel_challenge(text)\n'
          '  to authenticated;',
        ),
      );
      expect(body, contains("raise exception 'Not authenticated'"));
    });

    test('kod büyütülüp kırpılır, boş kod bulunamadı sayılır', () {
      expect(body, contains("upper(btrim(coalesce(p_code, '')))"));
      expect(body, contains("if v_code = '' then"));
    });

    test('satır kilidi altında okunur (iki kişi aynı bağlantıyı açarsa)', () {
      expect(body, contains('where challenge_code = v_code'));
      expect(body, contains('for update;'));
    });

    test('her hata yolu tanımlı ve beklenen sırada', () {
      final order = [
        "'Challenge not found'", // boş kod / bilinmeyen kod
        "'Own challenge'",
        "'Challenge expired'", // aynı kişi, süresi dolmuş
        "'Challenge already taken'",
        "'Challenge not for you'",
        "'Challenge not ready'",
      ];
      var last = -1;
      for (final text in order) {
        final at = body.indexOf('raise exception $text');
        expect(at, greaterThanOrEqualTo(0), reason: '$text yok');
        expect(at, greaterThan(last), reason: '$text yanlış sırada');
        last = at;
      }
    });

    test('yaratıcı kendi bağlantısını kabul edemez', () {
      expect(body, contains('v_duel.creator_id = v_uid'));
    });

    test('engel iki yönde, ifşa edilmeden "bulunamadı"', () {
      expect(
        body,
        contains('b.blocker_id = v_uid and b.blocked_id = v_duel.creator_id'),
      );
      expect(
        body,
        contains('b.blocker_id = v_duel.creator_id and b.blocked_id = v_uid'),
      );
      final blockAt = body.indexOf('from public.blocked_users b');
      final raiseAt = body.indexOf(
        "raise exception 'Challenge not found'",
        blockAt,
      );
      final nextRaiseAny = body.indexOf('raise exception', blockAt);
      expect(raiseAt, nextRaiseAny, reason: 'engel yolu başka hata fırlatıyor');
    });

    test(
      'arkadaş meydan okuması yalnız davetliye, bağlantı meydan okuması herkese',
      () {
        expect(
          body,
          contains(
            'v_duel.invited_id is not null and v_duel.invited_id <> v_uid',
          ),
        );
      },
    );

    test('aynı kişi için idempotent: yeniden açınca durumunu döndürür', () {
      expect(body, contains('if v_duel.opponent_id = v_uid then'));
      expect(body, contains("'answered', v_answered"));
      expect(body, contains("'finished', v_finished"));
      // Başkası almışsa ayrı hata.
      expect(body, contains('if v_duel.opponent_id is not null then'));
    });

    test('süresi dolmuş / açık olmayan düello kabul edilmez', () {
      expect(
        body,
        contains("v_duel.status <> 'open' or v_duel.expires_at <= now()"),
      );
    });

    test('yaratıcı turunu bitirmediyse kabul edilmez', () {
      expect(body, contains('from public.async_duel_results r'));
      expect(body, contains('r.player_id = v_duel.creator_id'));
    });

    test('kabul: rakip + matched + 48 saat, start_async_duel gibi', () {
      expect(body, contains('set opponent_id = v_uid'));
      expect(body, contains("status = 'matched'"));
      expect(body, contains('matched_at = now()'));
      expect(
        body,
        contains(
          "expires_at = greatest(expires_at, now() + interval '48 hours')",
        ),
      );
    });

    test('yanıt: rol opponent, soru JSON, doğru şık yok', () {
      expect(body, contains("'role', 'opponent'"));
      expect(
        body,
        contains('async_duel_questions_payload(v_duel.question_ids)'),
      );
      expect(body, isNot(contains('correct_option')));
    });
  });

  group('start_async_duel', () {
    final body = bodyOf(sql, 'start_async_duel');
    final previous = bodyOf(blocking, 'start_async_duel');

    test('rastgele eşleşme challenge_code\'lu düelloları atlar', () {
      expect(body, contains('and d.challenge_code is null'));
      expect(previous, isNot(contains('challenge_code')));
    });

    test('önceki (SON) gövdenin birebir kopyası + yalnız o satır', () {
      // Eklenen yorum+satır çıkarılınca eski gövde elde edilmeli.
      final stripped = body.replaceFirst(
        '    -- Bağlantı/arkadaş meydan okumaları (2026-10-13_friend_challenge.sql)\n'
            '    -- rastgele eşleşmeye ASLA girmez.\n'
            '    and d.challenge_code is null\n',
        '',
      );
      // Bölüm ayracı yorumları (dosya içi başlık) gövdeye dahil değildir;
      // fonksiyon bitişine kadar karşılaştır.
      String upToEnd(String s) {
        final end = s.indexOf(r'$function$;', s.indexOf(r'AS $function$') + 1);
        return s.substring(0, end + r'$function$;'.length);
      }

      expect(upToEnd(stripped), upToEnd(previous));
    });

    test('engel, davetli ve gizli-cevap süzgeçleri korunur', () {
      expect(body, contains('d.invited_id is null'));
      expect(body, contains('from public.blocked_users b'));
      expect(body, contains('d.expires_at > now()'));
      expect(body, contains('for update skip locked'));
      expect(body, contains("raise exception 'Too many open duels'"));
      expect(body, isNot(contains("'correct_option'")));
    });

    test('ACL korunur', () {
      expect(
        sql,
        contains(
          'revoke all on function public.start_async_duel(text) from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.start_async_duel(text) to authenticated;',
        ),
      );
    });
  });

  group('list_my_async_duels', () {
    final body = bodyOf(sql, 'list_my_async_duels');
    final previous = bodyOf(original, 'list_my_async_duels');

    test('mevcut yanıt alanları aynen durur (yalnız ekleme)', () {
      for (final key in [
        "'duel_id', d.id",
        "'status', d.status",
        "'role', case when d.creator_id = v_uid then 'creator' else 'opponent' end",
        "'opponent_name', opponent_profile.display_name",
        "'category_name', cat.name",
        "'my_correct', mine.correct_count",
        "'created_at', d.created_at",
        "'completed_at', d.completed_at",
        "'seen', (mine.duel_id is null or mine.seen_at is not null)",
      ]) {
        expect(previous, contains(key), reason: 'eski gövde: $key');
        expect(body, contains(key), reason: 'yeni gövde: $key');
      }
    });

    test('yeni alanlar: challenge_code, incoming_challenge, invited_name', () {
      expect(body, contains("'challenge_code', case"));
      expect(body, contains("'incoming_challenge'"));
      expect(body, contains("'invited_name'"));
    });

    test('kod yalnız yaratıcıya ya da davetliye döner, başkasına asla', () {
      final codeBlock = body.substring(
        body.indexOf("'challenge_code', case"),
        body.indexOf("'incoming_challenge'"),
      );
      expect(codeBlock, contains('d.creator_id = v_uid'));
      expect(
        codeBlock,
        contains('d.invited_id = v_uid and d.opponent_id is null'),
      );
      expect(codeBlock, contains('else null'));
    });

    test('gelen meydan okuma: kabul edilmemiş, açık, süresi dolmamış, '
        'yaratıcı bitirmiş, engelsiz', () {
      final incoming = body.substring(
        body.indexOf('-- Bana gelen meydan okuma'),
      );
      expect(incoming, contains('d.invited_id = v_uid'));
      expect(incoming, contains('d.opponent_id is null'));
      expect(incoming, contains("d.status = 'open'"));
      expect(incoming, contains('d.expires_at > now()'));
      expect(incoming, contains('r.player_id = d.creator_id'));
      expect(incoming, contains('from public.blocked_users b'));
    });

    test('30 gün penceresi ve sıralama korunur; ACL aynı', () {
      expect(body, contains("d.created_at >= now() - interval '30 days'"));
      expect(body, contains('order by d.created_at desc'));
      expect(
        sql,
        contains(
          'revoke all on function public.list_my_async_duels() from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.list_my_async_duels() to authenticated;',
        ),
      );
    });
  });

  group('expire_async_duels', () {
    test('göçte yeniden yazılmaz; mevcut gövde kabul edilmemiş açık '
        'meydan okumaları zaten kapsar', () {
      expect(sql, isNot(contains('function public.expire_async_duels')));
      final expire = bodyOf(original, 'expire_async_duels');
      expect(expire, contains("where status in ('open', 'matched')"));
      expect(expire, contains('and expires_at <= now()'));
      // Doğrulama bloğu canlıda aynısını denetler.
      expect(
        sql,
        contains(
          "pg_get_functiondef('public.expire_async_duels()'::regprocedure)",
        ),
      );
    });
  });

  group('göç disiplini', () {
    test('başlık bölümleri ve begin/commit', () {
      for (final heading in [
        'NİÇİN:',
        'NE YAPAR:',
        'TEKRAR:',
        'GERİ ALMA:',
        'Uygulama:',
      ]) {
        expect(sql, contains(heading));
      }
      expect(sql, contains('\nbegin;\n'));
      expect(sql.trimRight(), endsWith('commit;'));
    });

    test('doğrulama bloğu hata fırlatır', () {
      final verify = sql.substring(sql.lastIndexOf('do \$\$'));
      expect(verify, contains('raise exception'));
      for (final marker in [
        'challenge_code sütunu yok',
        'UNIQUE indeksi yok',
        "anon''a açık",
        'istemciye açık',
        'meydan okumaları atlamıyor',
      ]) {
        expect(verify, contains(marker));
      }
    });

    test(
      'davet bildirimi yeniden yazılmaz (push_delivery tetikleyicisi yeter)',
      () {
        expect(
          sql,
          isNot(contains('enqueue_async_duel_invite_push()\nreturns')),
        );
        expect(sql, isNot(contains('insert into public.push_outbox')));
      },
    );

    test('canlı veritabanına doğrudan dokunan hiçbir şey yok', () {
      expect(sql, isNot(contains('drop table')));
      expect(sql, isNot(contains('truncate')));
    });
  });
}
