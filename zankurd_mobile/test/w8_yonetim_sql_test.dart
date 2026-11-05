/// `2026-11-16_w8_yonetim.sql` bekçisi (2.1.2 W8): GPT-6 Pro denetiminin yönetim
/// bölümü SQL bulguları (alan 8 + alan 9 #6/#18).
///
/// ## Kusurlar
///
/// * Oyuncu kendi önerisini `status='approved'` ekleyebilir, `created_at`'ı
///   geçmişe çekip 24 saatlik 10 öneri sınırını aşabilirdi (RLS yalnız
///   `user_id = auth.uid()` ister).
/// * Geçersiz öneri cevap anahtarı onayda sessizce 'D' olurdu; yinelenen şıklı
///   öneri/düzeltme onaylanırdı; düzeltmede eski içerik günlüğe yazılmazdı.
/// * Sonuçlandırılmış profil şikâyeti yeniden gönderilince açılmaz, bildirim
///   gitmezdi.
/// * Bitmemiş dönemin (geri alınamaz) ödülü verilebilir, geçmiş dönem
///   seçilemez, aynı dönemde aynı derece iki kişiye verilebilir, durmuş cron
///   geçmiş dönemleri telafi etmez, kişi hatası iz bırakmazdı.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: kayıtlar "başarıyla" yazılır, yalnız moderasyon sırası,
/// sayaçlar ve jeton ekonomisi sapar. Davranış `tool/test_w8_yonetim_local.mjs`
/// ile PGlite'ta kanıtlanır (her kusur göçten ÖNCE gösterilir); bu dosya metni
/// ve istemci uyumunu sabitler. Canlı DB'ye bağlanılmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-16_w8_yonetim.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-16_w8_yonetim_geri.sql',
  ).readAsStringSync();
  final indeksRaw = File(
    'supabase/2026-11-16_w8_yonetim_indeks_concurrently.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) =>
      s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
  final code = strip(raw);
  final geri = strip(geriRaw);

  test('tek işlem, küçük harfli begin/commit; geri alma da; applied ⏳/✅', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-16_w8_yonetim.sql | '));
    expect(code, isNot(contains('lock table')));
    // CONCURRENTLY dosyası işlem dışı, ayrı.
    expect(indeksRaw, contains('create index concurrently if not exists'));
    expect(strip(indeksRaw), isNot(contains('begin;')));
    expect(code, isNot(contains('concurrently')));
  });

  test('tam gövde md5 ön koşulu, yedek + yama zinciri, son güvenlik', () {
    expect(
      RegExp(r"'[0-9a-f]{32}', '[0-9a-f]{32}'").allMatches(code).length,
      11,
    );
    expect(code, isNot(contains('__N')));
    expect(code, contains("'w8:' || p_imza"));
    expect(code, contains('bu sürümün nihai gövdesi'));
    expect(code, contains('p.prosecdef'));
    expect(code, contains('p.proowner = r.sahip'));
    expect(code, contains('p.proacl::text is not distinct from r.acl'));
    expect(code, contains("has_function_privilege('anon'"));
    expect(geri, contains('for update;'));
    expect(geri, contains('yedek satırı yok; hiçbir işlev geri alınmadı'));
    expect(geri, contains('canlı gövdesi göçten sonra değişmiş'));
    expect(geri, contains('execute r.eski'));
    expect(geri, isNot(contains('ad like')));
    for (final m in RegExp(
      r"'public\.[a-z_0-9]+\([^)]*\)', '([0-9a-f]{32})', '([0-9a-f]{32})'",
    ).allMatches(code)) {
      expect(applied, contains(m.group(1)!), reason: 'applied.md taban md5');
      expect(
        applied,
        contains(m.group(2)!),
        reason: 'applied.md beklenen nihai md5',
      );
    }
  });

  test(
    '#10/#11: oyuncu tarafı yalnız pending + sunucu saati; hız sınırından önce',
    () {
      expect(code, contains("new.status := 'pending'"));
      expect(code, contains('new.created_at := now()'));
      expect(code, contains('new.reviewed_by := null'));
      expect(code, contains('if auth.uid() is null then'));
      expect(
        code,
        contains('create trigger suggested_questions_00_force_defaults'),
      );
      // Ad sıralaması: 00_ < rate_limit (aynı olayda ada göre çalışır).
      expect(
        'suggested_questions_00_force_defaults'.compareTo(
          'suggested_questions_rate_limit',
        ),
        lessThan(0),
      );
    },
  );

  test('#9/#8/#18: cevap anahtarı, farklı şıklar, eski içerik günlükte', () {
    expect(
      code,
      contains(
        "check (status <> 'pending' or upper(btrim(correct_option)) in ('A', 'B', 'C', 'D')) not valid",
      ),
    );
    expect(code, isNot(contains('else 3 end')));
    expect(
      RegExp(
        r'count\(distinct lower\(btrim\(o\)\)\) from unnest\((v_opts|p_options)\) o\) <> 4',
      ).allMatches(code).length,
      2,
    );
    expect(code, contains("'before', jsonb_build_object("));
    expect(code, contains("'original', jsonb_build_object("));
  });

  test('#12: şikâyet yeniden açılır ve yalnız kapalıyken bildirim gider', () {
    expect(code, contains('before update on public.profile_reports'));
    expect(code, contains('new.handled_at := null'));
    expect(
      code,
      contains('when (old.handled_at is not null and new.handled_at is null)'),
    );
  });

  test(
    '#4/#5/#14/#17: dönem tamamlanmış, geçmiş seçimi, neden, derece tekilliği',
    () {
      expect(code, contains("raise exception 'period_not_finished'"));
      expect(code, contains("'prev_key'"));
      expect(code, contains("'next_key'"));
      expect(code, contains("'reason', 'rank_already_rewarded'"));
      expect(code, contains("'reason', 'already_rewarded'"));
      expect(
        code,
        contains(
          'create unique index if not exists admin_reward_grants_rank_uidx',
        ),
      );
      expect(code, contains('on conflict do nothing'));
      expect(code, contains('pg_advisory_xact_lock'));
    },
  );

  test('#15/#16: hata kayıtlı, telafi ilerleme işaretiyle', () {
    expect(code, contains("'reward_auto_error'"));
    expect(code, contains('raise warning'));
    expect(code, contains("'auto_reward_done_daily'"));
    expect(code, contains("'auto_reward_done_weekly'"));
    expect(code, contains('limit 45'));
    expect(code, contains('limit 12'));
    // Eski sessiz yutma kalmadı.
    expect(
      RegExp(r'exception when others then\s+null;').hasMatch(code),
      isFalse,
    );
  });

  test('alan9: solo sayacı 64 parça, new_today indeks dostu', () {
    expect(code, contains('floor(random() * 64)::smallint'));
    expect(code, contains('check (shard between 0 and 63)'));
    expect(
      code,
      contains(
        "(public.app_today()::timestamp at time zone 'Europe/Istanbul')",
      ),
    );
    expect(code, isNot(contains('(created_at at time zone')));
  });

  test('geri alma: yeni nesneleri siler, veri nesneleri kalır', () {
    for (final s in [
      'drop trigger if exists suggested_questions_00_force_defaults',
      'drop trigger if exists trg_w8_profile_report_reopen on',
      'drop trigger if exists trg_w8_profile_report_reopen_push',
      'drop function if exists public.w8_force_suggestion_defaults()',
      'drop function if exists public.w8_reopen_profile_report()',
      'drop function if exists public.admin_list_audit_page(integer, bigint)',
      'drop function if exists public._admin_reward_last_key(text)',
      'drop index if exists public.admin_reward_grants_rank_uidx',
    ]) {
      expect(geri, contains(s));
    }
  });

  test('eski istemci sözleşmesi: yönetici imzaları değişmez, drop yok', () {
    expect(code, isNot(contains('drop function')));
    expect(code, isNot(contains('alter function')));
    // Yalnız YENİ işlev adları create function ile tanımlanır; değişenler tam gövde
    // `pg_temp.w8_degistir` içinde `create or replace` (aynı imza) ile gelir.
    expect(
      RegExp(
        r'create or replace function public\.(w8_[a-z_]+|_admin_reward_last_key|admin_list_audit_page)',
      ).allMatches(code).map((m) => m.group(1)).toSet(),
      {
        '_admin_reward_last_key',
        'w8_force_suggestion_defaults',
        'w8_reopen_profile_report',
        'admin_list_audit_page',
      },
    );
  });

  test('11-12/13 başlıkları artık "canlıda" der (#1)', () {
    for (final f in [
      'supabase/2026-11-12_yonetim_paneli.sql',
      'supabase/2026-11-13_yonetim_moderasyon.sql',
      'supabase/2026-11-13_yonetim_otomatik_odul_cron.sql',
    ]) {
      final first = File(f).readAsLinesSync().first;
      expect(first, contains('CANLIDA'), reason: f);
      expect(first, isNot(contains('CANLIYA UYGULANMADI')), reason: f);
    }
  });
}
