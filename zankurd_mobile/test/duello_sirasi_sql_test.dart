/// Sırayla düello 2026-10-24 göçü (`2026-10-24_duello_sirasi*.sql`) bekçisi.
///
/// ## Kusur
///
/// Düello penceresi 48 saatti: rakibi bekleyen oyuncu iki gün boyunca
/// bir sonuç göremiyor, turunu bitirip rakibin kaçtığı düellolar "Rakip
/// çıkmadı" ile kapanıp bitiren oyuncuya hiçbir şey kazandırmıyordu (rakip
/// KAYBETMİYORDU, yani oynamamanın bedeli yoktu). Sırası gelen oyuncuya süre
/// dolmadan haber veren bir bildirim de yoktu; saatler sonra dönen oyuncunun
/// sıradaki sorusu son cevaptan ölçüldüğü için hep 20 saniye (tavan) yazılıp
/// eşitlik bozucuda haksız yere kaybediyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Göç dosyası canlıda tek başına çalışmaz sınanır: bir `interval '48 hours'`
/// unutulsa, `expire_async_duels` kaybedeni işaretlese de kazanana XP
/// vermese, hatırlatma tekrar tekrar gitse ya da `list_my_async_duels`
/// `expires_at`ı döndürmese hiçbir derleme/analiz/widget testi bunu
/// yakalamaz — istemci yalnızca sessizce kalan süre göstermez ya da hükmen
/// sonucu "bitmedi" okur. Bu dosya göçü METİN olarak okuyup her maddeyi
/// sabitler (repo deseni: `async_duel_sql_contract_test.dart`).
///
/// ## Kural
///
/// 24 saat her yerde (yaratma, eşleşme, kabul); hükmen: turunu bitiren kazanır
/// ve normal galibiyetin +30 XP'sini alır; hatırlatma düello+oyuncu başına
/// tek; cron 10 dakikada bir; liste `expires_at` + `forfeit` döndürür.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/2026-10-24_duello_sirasi.sql').readAsStringSync();
  final cron = File(
    'supabase/2026-10-24_duello_sirasi_cron.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();

  /// Yorum satırları atılmış metin: "48 saat" gibi ifadeleri açıklayan
  /// yorumlar kod iddialarını bozmasın.
  final code = sql
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n');

  /// `create or replace function public.<name>(` ile bir SONRAKİ
  /// `create or replace function` (ya da dosya sonu) arası, büyük/küçük
  /// harf duyarsız (canlı gövdeler `CREATE OR REPLACE` ile gelir).
  String body(String name) {
    final lower = code.toLowerCase();
    final marker = 'create or replace function public.$name(';
    final start = lower.indexOf(marker);
    expect(start, greaterThanOrEqualTo(0), reason: '$name tanımlı değil');
    final next = lower.indexOf(
      'create or replace function public.',
      start + marker.length,
    );
    return code.substring(start, next == -1 ? code.length : next);
  }

  group('24 saat pencere', () {
    test('sütun varsayılanı 24 saat (yaratma yolu)', () {
      expect(
        code,
        contains(
          'alter column expires_at set default (now() + interval \'24 hours\')',
        ),
      );
    });

    test('yeni gövdelerde 48 saat KALMADI', () {
      // Doğrulama bloğu eski değeri ARAR (kalmadığını sınar); o bölüm hariç.
      final bodies = code.substring(0, code.indexOf(r'do $verify$'));
      expect(bodies, isNot(contains("interval '48")));
      expect(bodies, isNot(contains('48 hours')));
    });

    test('rastgele eşleşme ve arkadaş kabulü rakibe 24 saat verir', () {
      for (final fn in ['start_async_duel', 'accept_async_duel_challenge']) {
        expect(
          body(fn),
          contains(
            "expires_at = greatest(expires_at, now() + interval '24 hours')",
          ),
          reason: fn,
        );
      }
    });

    test('katılan oyuncu hatırlatma hakkını yeniden kazanır', () {
      for (final fn in ['start_async_duel', 'accept_async_duel_challenge']) {
        expect(
          body(fn),
          contains(
            'reminder_sent_for = array_remove(reminder_sent_for, v_uid)',
          ),
          reason: fn,
        );
      }
    });

    test('doğrulama bloğu 24 saati ve eski 48 saatin kalmadığını sınar', () {
      expect(code, contains("like '%24:00:00%'"));
      expect(code, contains("like '%48 hours%'"));
    });
  });

  group('hükmen (expire_async_duels)', () {
    String fn() => body('expire_async_duels');

    test('süresi geçmiş open/matched düelloyu kapatır, kaybedeni yazar', () {
      final b = fn();
      expect(b, contains("d.status in ('open', 'matched')"));
      expect(b, contains('d.expires_at <= now()'));
      expect(b, contains("set status = 'expired'"));
      expect(b, contains('forfeit_loser_id = decided.loser_id'));
    });

    test('satır kilidi: iki cron koşusu aynı düelloyu çifte işlemez', () {
      expect(fn(), contains('for update of d'));
    });

    test(
      'kural: bitiren kazanır, öteki taraf (rakip ya da davetli) kaybeder',
      () {
        final b = fn();
        // Öteki taraf = rakip, yoksa davet edilen arkadaş.
        expect(b, contains('coalesce(d.opponent_id, d.invited_id)'));
        expect(
          b,
          contains(
            'when due.creator_done\n'
            '             and due.other_id is not null\n'
            '             and not due.other_done then due.other_id',
          ),
        );
        expect(
          b,
          contains(
            'when not due.creator_done\n'
            '             and due.other_done then due.creator_id',
          ),
        );
        // Rakipsiz düello ve kimsenin bitirmediği düello kayıpsız kalır.
        expect(b, contains('else null'));
      },
    );

    test('hükmen sonuç iki oyuncuya async_duel_result bildirimi kuyruklar', () {
      final b = fn();
      expect(b, contains("'async_duel_result'"));
      expect(b, contains('c.loser_id is not null'));
      expect(b, contains('p.uid is not null'));
      // Bildirim metni iki dilli "KU · TR".
      expect(b, contains('tu xweber serketî · '));
      expect(b, contains('düelloyu hükmen kazandın'));
      expect(b, contains('te winda kir · '));
      expect(b, contains('düelloyu hükmen kaybettin'));
    });

    test('hatırlatma: ≤ 4 saat kala, turunu bitirmemiş oyuncuya, TEK kez', () {
      final b = fn();
      expect(b, contains("'async_duel_turn'"));
      expect(b, contains("d.expires_at <= now() + interval '4 hours'"));
      expect(b, contains('d.expires_at > now()'));
      // Dedupe: gönderilmiş oyuncu tekrar aday olmaz ve işaretlenir.
      expect(b, contains('not (p.uid = any (d.reminder_sent_for))'));
      expect(b, contains('reminder_sent_for = d.reminder_sent_for || m.uids'));
      // Turunu bitiren hatırlatılmaz.
      expect(
        b,
        contains(
          'select 1 from public.async_duel_results r\n'
          '        where r.duel_id = d.id and r.player_id = p.uid',
        ),
      );
      // Davetli/rakip için yaratıcı turunu bitirmiş olmalı; engel iki yönde.
      expect(b, contains('p.is_creator'));
      expect(b, contains('public.blocked_users b'));
      // Metin iki dilli.
      expect(b, contains("'Dora te ye: '"));
      expect(b, contains("' saet mane · Sıra sende: '"));
      expect(b, contains("' saat kaldı'"));
    });

    test('yalnız service_role çalıştırabilir', () {
      expect(
        code,
        contains(
          'revoke all on function public.expire_async_duels()\n'
          '  from public, anon, authenticated;',
        ),
      );
      expect(
        code,
        contains(
          'grant execute on function public.expire_async_duels() to service_role',
        ),
      );
    });
  });

  group('hükmen XP ve liste', () {
    test('claim_async_duel_xp: hükmen kazanan +30 bonus alır', () {
      final b = body('claim_async_duel_xp');
      expect(b, contains('v_duel.forfeit_loser_id is not null'));
      expect(b, contains('v_duel.forfeit_loser_id <> v_uid'));
      expect(b, contains('v_delta := v_delta + 30;'));
      // Normal karşılaştırma dalı elsif olarak durur (hükmenle çifte bonus yok).
      expect(b, contains('elsif v_opponent_id is not null then'));
    });

    test('list_my_async_duels: expires_at, forfeit ve hükmen outcome', () {
      final b = body('list_my_async_duels');
      expect(b, contains("'expires_at', d.expires_at"));
      expect(b, contains("'forfeit', (d.forfeit_loser_id is not null)"));
      expect(
        b,
        contains(
          "when d.forfeit_loser_id is not null then\n"
          "        case when d.forfeit_loser_id = v_uid then 'loss' else 'win' end",
        ),
      );
      // Hükmen outcome normal karşılaştırmanın ÖNÜNDE.
      expect(
        b.indexOf('d.forfeit_loser_id is not null then'),
        lessThan(b.indexOf('mine.duel_id is not null and theirs.duel_id')),
      );
      // Daveti hiç açmayan hükmen kaybeden de listede görür.
      expect(b, contains('or d.forfeit_loser_id = v_uid'));
      // Kaybeden, bitiren rakibin skorunu görür.
      expect(b, contains('or d.forfeit_loser_id = v_uid then theirs'));
    });

    test('hükmen yeni durum değeri eklemez: status check değişmez', () {
      expect(code, isNot(contains('async_duels_status_check')));
      expect(code, isNot(contains("'forfeited'")));
    });

    test('sütunlar idempotent eklenir', () {
      for (final c in [
        'forfeit_loser_id uuid',
        "reminder_sent_for uuid[] not null default '{}'",
        'creator_resumed_at timestamptz',
        'opponent_resumed_at timestamptz',
      ]) {
        expect(code, contains('add column if not exists $c'), reason: c);
      }
    });
  });

  group('devam adaleti', () {
    test('answer_async_duel süreyi dönüş anından ölçer', () {
      final b = body('answer_async_duel');
      expect(b, contains('v_duel.creator_resumed_at'));
      expect(b, contains('v_duel.opponent_resumed_at'));
      expect(b, contains('v_baseline := greatest('));
      expect(b, contains('v_resumed_at\n  );'));
      // 20 sn tavanı ve sunucu ölçümü korunur.
      expect(b, contains('v_max_ms constant integer := 20000'));
    });

    test('resume / start / accept devam işaretini yazar', () {
      for (final fn in [
        'resume_my_async_duel',
        'start_async_duel',
        'accept_async_duel_challenge',
      ]) {
        expect(
          body(fn),
          contains('perform public.async_duel_touch_resume(v_duel.id, v_uid)'),
          reason: fn,
        );
      }
    });

    test(
      'işaret yalnız 2 dakikadan eski etkinlikte yazılır, istemciye kapalı',
      () {
        final b = body('async_duel_touch_resume');
        expect(b, contains("interval '2 minutes'"));
        expect(b, contains('for update'));
        expect(
          code,
          contains(
            'revoke all on function public.async_duel_touch_resume(uuid, uuid)\n'
            '  from public, anon, authenticated;',
          ),
        );
      },
    );
  });

  group('her gövde security definer + search_path', () {
    for (final fn in [
      'start_async_duel',
      'accept_async_duel_challenge',
      'answer_async_duel',
      'resume_my_async_duel',
      'claim_async_duel_xp',
      'list_my_async_duels',
      'expire_async_duels',
      'async_duel_touch_resume',
    ]) {
      test(fn, () {
        final b = body(fn).toLowerCase();
        expect(b, contains('security definer'));
        expect(b, contains('search_path'));
        expect(b, isNot(RegExp(r'\bstable\b')));
      });
    }
  });

  group('dosya biçimi', () {
    test('tek işlem: begin ... commit', () {
      expect(code.trimLeft(), startsWith('begin;'));
      expect(code.trimRight(), endsWith('commit;'));
    });

    test('yerel olmayan klasöre atıf yok', () {
      expect(sql, isNot(contains('scratchpad')));
      expect(sql, isNot(contains('/tmp/')));
    });
  });

  group('cron: 10 dakikada bir', () {
    test('idempotent unschedule + schedule, saatlik zamanlama yok', () {
      expect(cron, contains("cron.unschedule('expire-async-duels')"));
      expect(cron, contains("'expire-async-duels'"));
      expect(cron, contains("'*/10 * * * *'"));
      expect(cron, contains(r'$$select public.expire_async_duels()$$'));
      expect(cron, isNot(contains("'37 * * * *'")));
      expect(cron.trimLeft().startsWith('--'), isTrue);
      expect(cron, contains('begin;'));
      expect(cron, contains('commit;'));
    });
  });

  group('uygulama manifesti', () {
    test('iki göç applied.md\'de "bekliyor" olarak kayıtlı', () {
      for (final f in [
        '2026-10-24_duello_sirasi.sql',
        '2026-10-24_duello_sirasi_cron.sql',
      ]) {
        final row = applied
            .split('\n')
            .firstWhere((l) => l.startsWith('| $f '), orElse: () => '');
        expect(row, isNotEmpty, reason: '$f satırı yok');
        expect(row, contains('bekliyor'), reason: f);
      }
    });
  });
}
