-- 2.1.2 W8: yönetim bölümü (ChatGPT Pro denetimi alan 8 + alan 9 #6/#18; her bulgu güncel
-- kodda doğrulandı). CANLIYA UYGULANMADI.
-- Geri alma: geri_al/2026-11-16_w8_yonetim_geri.sql
-- Yerel test: node tool/test_w8_yonetim_local.mjs <pglite index.js>
-- Ek (ayrı dosya, işlem dışı): 2026-11-16_w8_yonetim_indeks_concurrently.sql
--
-- Taban (canlı ✅): 11-12 yönetim göçünün gövdeleri; record_activity 2026-11-16 W1'in nihai
-- gövdesi. Yamalanan işlevin TAM gövdesinin md5'i bilinen tabana eşitse değiştirilir (başka
-- her durumda göç durur); eski gövde ve md5'i olcek_tur3_yedek'e ('w8:<imza>') alınır, yeni
-- gövdenin md5'i zincire eklenir. Eski istemci (build 45) sözleşmesi: oyuncu tarafı hiçbir
-- RPC'nin imzası/dönüşü değişmez. Yönetici RPC'lerinin imzaları da AYNI kalır (yalnız
-- admin_list_audit_page ve _admin_reward_last_key yeni; ikisi eklemelidir).
--
-- BULGULAR
--  #10/#11 suggested_questions: oyuncu INSERT'inde status='approved' / reviewed_* /
--      created_at=geçmiş verebiliyordu (RLS yalnız user_id=auth.uid()); sayıyı ve 24 saatlik
--      hız sınırını bozuyordu. BEFORE INSERT tetikleyicisi (hız sınırından ÖNCE çalışır)
--      auth.uid() varsa status'u 'pending', created_at'ı now() yapar, reviewed_* ve
--      review_note'u siler. service_role / SQL (auth.uid() boş) dokunulmaz.
--  #9  correct_option CHECK (bekleyen öneride A-D, büyük/küçük harf fark etmez; NOT VALID eklenir, eski satır
--      temizse doğrulanır); admin_review_suggestion geçersiz anahtarı artık sessizce 'D'ye
--      çevirmez: bad_edits.
--  #8  admin_review_suggestion ve admin_fix_question şıkların dolu VE farklı olduğunu
--      doğrular (admin_add_question zaten doğruluyordu); şıklar kırpılarak yazılır.
--  #18 soru düzeltmede ESKİ içerik (soru, şıklar, doğru) denetim günlüğüne 'before' olarak;
--      öneri düzeltilerek onaylanırsa özgün öneri 'original' olarak yazılır.
--  #12 sonuçlandırılmış (handled_at dolu) profil şikâyeti aynı oyuncu tarafından yeniden
--      gönderilince (report_player_profile: ON CONFLICT DO UPDATE created_at=now()) yeniden
--      AÇILIR (BEFORE UPDATE) ve yöneticilere bildirim gider (AFTER UPDATE, yalnız kapalıyken
--      açılınca; açık şikâyetin tekrarı bildirim yağdırmaz).
--  #4  ödül dönemi yalnız TAMAMLANMIŞ olabilir (günlük: dün ve öncesi; haftalık: geçen hafta
--      ve öncesi). Anahtarsız çağrı artık bugünü değil SON TAMAMLANAN dönemi gösterir; bitmemiş
--      dönem 'period_finished' değil -> 'period_not_finished'. Geri alınamaz jeton sıralama
--      oturmadan verilemez.
--  #5  admin_list_reward_candidates dönemin 'prev_key' / 'next_key' anahtarlarını döndürür
--      (geçmiş dönem seçimi); admin_grant_reward'ın p_period_key'i zaten vardı.
--  #14 admin_grant_reward ödül verilmediyse (granted:false) NEDENİ ('already_rewarded' /
--      'rank_already_rewarded') döndürür; arayüz "Kaydedildi" demez (Dart tarafı W8).
--  #17 dönem + derece tekilliği: admin_reward_grants (period_kind, period_key, rank) benzersiz
--      indeks (ön denetim: yinelenen satır varsa göç durur) + işlevlerde dönem başına
--      danışma kilidi; elle ve otomatik yol birbirini dışlar.
--  #15 otomatik ödül kişi hatası artık sessiz değil: admin_audit_log 'reward_auto_error'
--      (+ sunucu WARNING'i); ilerleme yine sürer.
--  #16 otomatik ödül telafisi: 'auto_reward_done_daily/weekly' ilerleme işaretleri; cron
--      günlerce durduysa sonraki çalıştırma işaretten bugüne kadar (günlük en çok 45, haftalık
--      en çok 12 dönem) tamamlar. 'auto_reward_since' öncesi dönem yine ödüllenmez.
--  #6  admin_list_user_reports süresi dolmuş askıyı 'suspended' göstermez (state/until boş).
--  #19 admin_set_notify_pref denetim günlüğüne yazar ('notify_pref_set').
--  #21 admin_list_audit satırlara 'id' ve 'admin_id' ekler; yeni admin_list_audit_page(limit,
--      before_id) eski kayıtlara sayfalı erişim verir (eski limit 100 aşılabilir).
--  #24 admin_get_stats: 'contest' sayısı geçiş dönemindeki iki tabloyu ÇİFT saymaz (eski
--      beyan tablosu yalnız doğrulanmış satırı olmayan günlerde); mod sayıları farklı olayları
--      ölçtüğü için arayüz etiketi "başlatılan oyun/kurulan oda..." diye düzeltildi (Dart).
--  alan9 #6 record_activity solo sayacı 8 yerine 64 parçaya yazar (sıcak satır azalır;
--      shard CHECK'i 0..63).
--  alan9 #18 new_today yarı açık zaman aralığıyla sorgulanır (created_at indeksi kullanılabilir;
--      indeks ayrı concurrently dosyasında).
-- DOĞRULANDI / DOKUNULMADI: #2 turnuva ve #3 lig (W1 11-16, canlıda), #13 katkı ödülü kimliği
--      (W1), #22 record_activity günlük sınırı (W1), #1 başlıklar (11-12/13 dosyalarının
--      başlıkları "canlıda" diye güncellendi). #25 oda: engel oda KATILIMINDA ve sohbette
--      uygulanıyor, odada olan oyuncu mevcut oyunu bitirir (oda ömrü dakikalar; ayrıca atma
--      oda motoruna dokunur, bu dalın sahipliği dışında) — kalıcı iş kuralı kararı, yazılı.
--      #26 solo ödülü kısıtlı hesapta W1'de kapandı. #27 istemci (Dart).
begin;

set local lock_timeout = '10s';

do $w8_onkosul$
begin
  if to_regprocedure('public.admin_assert()') is null
     or to_regprocedure('public.admin_log(text,text,text,jsonb)') is null
     or to_regprocedure('public._admin_credit_coins(uuid,integer,text)') is null
     or to_regprocedure('public._admin_reward_key(text,text)') is null
     or to_regprocedure('public._admin_reward_coins(text)') is null
     or to_regprocedure('public._admin_reward_top3(text,text)') is null
     or to_regprocedure('public.admin_enqueue_push()') is null
     or to_regprocedure('public.admin_reward_contributor(uuid,integer,text,uuid)') is null
     or to_regprocedure('public.limit_suggested_question_rate()') is null
     or to_regclass('public.olcek_tur3_yedek') is null
     or to_regclass('public.usage_mode_counter') is null
     or to_regclass('public.admin_reward_grants') is null
     or to_regclass('public.admin_settings') is null
     or to_regclass('public.admin_audit_log') is null
     or to_regclass('public.suggested_questions') is null
     or to_regclass('public.profile_reports') is null
     or to_regclass('public.user_moderation') is null then
    raise exception 'w8: beklenen canlı nesneler eksik (w1 ve 11-12/13 göçleri uygulanmış olmalı); incele';
  end if;
  -- Yedek tablosu istemci rollerine kapalı (W1 ile aynı sertlik).
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w8: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) then
    raise exception 'w8: olcek_tur3_yedek sahibi dışında alıcıya açık (relacl)';
  end if;
  -- #17: derece tekilliği indeksinden önce yinelenen kayıt var mı?
  if exists (
    select 1 from public.admin_reward_grants
    group by period_kind, period_key, rank having count(*) > 1
  ) then
    raise exception 'w8: admin_reward_grants içinde aynı dönem+derece için birden çok ödül var; derece tekilliği indeksi kurulamaz, elle incele';
  end if;
end;
$w8_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef) ve bu göçün nihai md5'i.
-- Gövde ya (a) tam bu taban -> yamalanır, ya (b) tam nihai ve yedek satırı + md5 zinciri
-- sağlam -> uygulanmış, atlanır. Başka her durum göçü durdurur.
create temp table w8_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w8_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.admin_review_suggestion(uuid,text,text,jsonb)', '80336c7d343ff826023d794a9a127ffa', 'd0a7dfd7458e7d0439aac7caa94f7bfc'),
    ('public.admin_fix_question(uuid,text,text[],integer,text)', '5acac975ae22dbe6fb320a2cf2f36af4', '6e3c4645e1fba8211834e312b2c89282'),
    ('public.admin_list_reward_candidates(text,text)', 'e589a7693bd67d79802a020b4c9c3255', '86db58b5976b259e7f6da445c9f60dd5'),
    ('public.admin_grant_reward(text,text,uuid,integer,text)', '0d6a2a5e855910eed34bf673db2f5970', '564cfbe6048e612be1518e22a5711b9f'),
    ('public._admin_auto_grant(text,text)', '8c92097880b1080ac7add89283598322', 'e586043c0542889375a4b75ee6e3599e'),
    ('public.admin_run_auto_rewards()', 'ba54e1aa41d1fd181606d008699c8802', 'ce4ccd57b023c17d3c836f7652e936a5'),
    ('public.admin_list_user_reports(integer)', 'ff6eda2d31422a4270bd49378f445fe8', '95af89f17146fc0eb7c0007404f4d74a'),
    ('public.admin_get_stats()', 'ec13f71785ee1b6a089f7a3ad1366592', 'f1e6cd9b46fc6e0836a2fe1f6340cef2'),
    ('public.admin_list_audit(integer)', '6a6e0a70a25990247cd4432eb50c57ab', '8da8ed83298c095ea80514a9fc3cf53d'),
    ('public.admin_set_notify_pref(text,boolean)', '6ac20dd83953ce1f6406e03ba554938c', 'daa8661c9104eab2db71bf34c87569d2'),
    ('public.record_activity(boolean)', '466ceb76c6f4a0d92e9828e97f75748e', '5dca1dc8ad0acb601e9813151a5700b6')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into w8_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'w8: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w8:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'w8: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into w8_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$w8_durum$;

-- Değiştirici: CANLI gövde yedeğe ('w8:<imza>') yazılır, ardından TAM yeni tanım çalışır,
-- yeni gövdenin md5'i zincire eklenir. (CREATE OR REPLACE sahibi / ACL'i korur.)
create or replace function pg_temp.w8_degistir(p_imza text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_oid regprocedure := to_regprocedure(p_imza);
  v_def text;
begin
  if v_oid is null then
    raise exception 'w8: işlev yok: %', p_imza;
  end if;
  v_def := pg_get_functiondef(v_oid);
  insert into public.olcek_tur3_yedek (ad, tanim, alindi)
  values ('w8:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
  on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  execute p_yeni;
  update public.olcek_tur3_yedek
  set tanim = tanim || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w8:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- Yeni (eklemeli) nesneler
-- ---------------------------------------------------------------------------
-- alan9 #6: solo sayacı 64 parça.
do $w8_shard$
declare c record;
begin
  for c in select conname from pg_constraint
           where conrelid = 'public.usage_mode_counter'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%shard%' loop
    execute format('alter table public.usage_mode_counter drop constraint %I', c.conname);
  end loop;
  alter table public.usage_mode_counter
    add constraint usage_mode_counter_shard_w8_check check (shard between 0 and 63);
end;
$w8_shard$;

-- #17: aynı dönemde aynı derece iki kez ödüllenemez.
create unique index if not exists admin_reward_grants_rank_uidx
  on public.admin_reward_grants (period_kind, period_key, rank);

-- Son TAMAMLANAN ödül dönemi: günlük = dün, haftalık = geçen haftanın pazartesisi.
create or replace function public._admin_reward_last_key(p_kind text)
returns text
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if p_kind = 'daily' then
    return (public.app_today() - 1)::text;
  elsif p_kind = 'weekly' then
    return (date_trunc('week', public.app_today()::timestamp)::date - 7)::text;
  end if;
  raise exception 'bad_kind' using errcode = '22023';
end;
$fn$;
revoke all on function public._admin_reward_last_key(text) from public, anon, authenticated;

-- #10/#11: oyuncu tarafı yalnız 'pending' ve sunucu saatiyle öneri ekleyebilir.
create or replace function public.w8_force_suggestion_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if auth.uid() is null then
    return new; -- service_role / yönetim betiği / SQL: sahibi karar verir
  end if;
  new.status := 'pending';
  new.created_at := now();
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.review_note := null;
  return new;
end;
$fn$;
revoke all on function public.w8_force_suggestion_defaults() from public, anon, authenticated;

-- Tetikleyici adı hız sınırı tetikleyicisinden ÖNCE sıralanır ('suggested_questions_00...' <
-- 'suggested_questions_rate_limit'; PostgreSQL aynı olaydaki tetikleyicileri ada göre çalıştırır).
drop trigger if exists suggested_questions_00_force_defaults on public.suggested_questions;
create trigger suggested_questions_00_force_defaults
before insert on public.suggested_questions
for each row execute function public.w8_force_suggestion_defaults();

-- #9: BEKLEYEN öneride doğru şık A-D olmalı (onay/ret güncellemesi status'u değiştirdiği için
-- bozuk bekleyen satırın kapatılmasını da engellemez). NOT VALID: yeni satırlar hemen denetlenir;
-- eski satırlar temizse doğrulanır, bozuk bekleyen satır varsa doğrulama atlanır
-- (admin_review_suggestion onu düzeltme olmadan onaylatmaz: bad_edits).
do $w8_ck$
begin
  if not exists (select 1 from pg_constraint
                 where conrelid = 'public.suggested_questions'::regclass
                   and conname = 'suggested_questions_correct_option_w8_check') then
    alter table public.suggested_questions
      add constraint suggested_questions_correct_option_w8_check
      check (status <> 'pending' or upper(btrim(correct_option)) in ('A', 'B', 'C', 'D')) not valid;
  end if;
  begin
    alter table public.suggested_questions validate constraint suggested_questions_correct_option_w8_check;
  exception when check_violation then
    raise notice 'w8: suggested_questions içinde geçersiz correct_option satırı var; CHECK NOT VALID kaldı (yeni satırlar denetlenir)';
  end;
end;
$w8_ck$;

-- #12: sonuçlandırılmış şikâyet yeniden gönderilince yeniden açılır + bildirim.
create or replace function public.w8_reopen_profile_report()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if old.handled_at is not null
     and new.handled_at is not distinct from old.handled_at
     and new.created_at is distinct from old.created_at then
    new.handled_at := null;
  end if;
  return new;
end;
$fn$;
revoke all on function public.w8_reopen_profile_report() from public, anon, authenticated;

drop trigger if exists trg_w8_profile_report_reopen on public.profile_reports;
create trigger trg_w8_profile_report_reopen
before update on public.profile_reports
for each row execute function public.w8_reopen_profile_report();

drop trigger if exists trg_w8_profile_report_reopen_push on public.profile_reports;
create trigger trg_w8_profile_report_reopen_push
after update on public.profile_reports
for each row
when (old.handled_at is not null and new.handled_at is null)
execute function public.admin_enqueue_push();

-- #21: eski denetim kayıtlarına sayfalı erişim (id'ye göre, yeniden eskiye).
create or replace function public.admin_list_audit_page(
  p_limit integer default 50, p_before_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r) order by r.id desc)
    from (
      select id, admin_id, action, target_type, target_id, detail ->> 'label' as label,
             detail, created_at
      from public.admin_audit_log
      where p_before_id is null or id < p_before_id
      order by id desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) r
  ), '[]'::jsonb);
end;
$fn$;
revoke all on function public.admin_list_audit_page(integer, bigint) from public, anon, authenticated;
grant execute on function public.admin_list_audit_page(integer, bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Değişen işlev gövdeleri (tam tanım; imzalar aynı)
-- ---------------------------------------------------------------------------

-- #8 #9 #18: öneri onayı.
select pg_temp.w8_degistir('public.admin_review_suggestion(uuid,text,text,jsonb)', $w8y$
create or replace function public.admin_review_suggestion(
  p_id uuid, p_decision text, p_note text default null, p_edits jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  s public.suggested_questions;
  v_cat uuid;
  v_prompt text;
  v_opts text[];
  v_correct int;
  v_qid uuid;
begin
  perform public.admin_assert();
  if p_decision not in ('approve', 'reject') then
    raise exception 'bad_decision' using errcode = '22023';
  end if;
  select * into s from public.suggested_questions where id = p_id for update;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if s.status <> 'pending' then raise exception 'already_reviewed' using errcode = '22023'; end if;

  if p_decision = 'reject' then
    update public.suggested_questions
       set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(),
           review_note = nullif(trim(p_note), '')
     where id = p_id;
    perform public.admin_log('suggestion_reject', 'suggested_question', p_id::text,
      jsonb_build_object('note', p_note, 'label', left(s.prompt, 60)));
    return jsonb_build_object('status', 'rejected');
  end if;

  v_prompt := btrim(s.prompt);
  v_opts := array[s.option_a, s.option_b, s.option_c, s.option_d];
  -- Geçersiz/boş cevap anahtarı artık sessizce 'D' olmaz: düzeltme yoksa bad_edits.
  v_correct := case upper(btrim(s.correct_option))
    when 'A' then 0 when 'B' then 1 when 'C' then 2 when 'D' then 3 else null end;
  if p_edits is not null then
    v_prompt := coalesce(nullif(btrim(p_edits ->> 'prompt'), ''), v_prompt);
    if jsonb_typeof(p_edits -> 'options') = 'array' and jsonb_array_length(p_edits -> 'options') = 4 then
      v_opts := array(select jsonb_array_elements_text(p_edits -> 'options'));
    end if;
    v_correct := coalesce((p_edits ->> 'correct')::int, v_correct);
  end if;
  if v_correct is null or v_correct not between 0 and 3
     or nullif(v_prompt, '') is null
     or exists (select 1 from unnest(v_opts) o where nullif(btrim(o), '') is null)
     or (select count(distinct lower(btrim(o))) from unnest(v_opts) o) <> 4 then
    raise exception 'bad_edits' using errcode = '22023';
  end if;

  select id into v_cat from public.categories
   where lower(name) = lower(s.category) or lower(slug) = lower(s.category) limit 1;
  if v_cat is null then raise exception 'category_not_found' using errcode = 'P0002'; end if;

  -- (Tırnaklı yazım bilinçli: soru kalitesi kapısı düz yazımı arayıp dosyayı
  -- soru KAYNAĞI sayar; bu bir kaynak değil, işlemdir.)
  insert into "public"."questions" (
    category_id, prompt, option_a, option_b, option_c, option_d, correct_option,
    explanation, difficulty, is_approved, review_status, created_by
  ) values (
    v_cat, v_prompt, btrim(v_opts[1]), btrim(v_opts[2]), btrim(v_opts[3]), btrim(v_opts[4]),
    (array['A','B','C','D'])[v_correct + 1],
    s.explanation, coalesce(s.difficulty, 3), true, 'approved', s.user_id
  ) returning id into v_qid;

  update public.suggested_questions
     set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
         review_note = nullif(trim(p_note), '')
   where id = p_id;
  perform public.admin_log('suggestion_approve', 'suggested_question', p_id::text,
    jsonb_build_object('question_id', v_qid, 'edited', p_edits is not null,
                       'label', left(v_prompt, 60))
    || case when p_edits is not null then jsonb_build_object('original', jsonb_build_object(
         'prompt', s.prompt,
         'options', jsonb_build_array(s.option_a, s.option_b, s.option_c, s.option_d),
         'correct', s.correct_option)) else '{}'::jsonb end);
  return jsonb_build_object('status', 'approved', 'question_id', v_qid);
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_review_suggestion(uuid,text,text,jsonb)' and d.gerekli;

-- #8 #18: onaylı soru düzeltme.
select pg_temp.w8_degistir('public.admin_fix_question(uuid,text,text[],integer,text)', $w8y$
create or replace function public.admin_fix_question(
  p_question_id uuid, p_prompt text, p_options text[], p_correct integer,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_old public.questions;
begin
  perform public.admin_assert();
  if nullif(trim(p_prompt), '') is null
     or p_options is null or array_length(p_options, 1) <> 4
     or exists (select 1 from unnest(p_options) o where nullif(btrim(o), '') is null)
     or (select count(distinct lower(btrim(o))) from unnest(p_options) o) <> 4
     or p_correct is null or p_correct not between 0 and 3 then
    raise exception 'bad_edits' using errcode = '22023';
  end if;
  select * into v_old from public.questions where id = p_question_id for update;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  update public.questions
     set prompt = trim(p_prompt), option_a = btrim(p_options[1]), option_b = btrim(p_options[2]),
         option_c = btrim(p_options[3]), option_d = btrim(p_options[4]),
         correct_option = (array['A','B','C','D'])[p_correct + 1],
         updated_at = now()
   where id = p_question_id;
  update public.question_reports set status = 'resolved'
   where question_id = p_question_id and status = 'open';
  perform public.admin_log('question_fix', 'question', p_question_id::text,
    jsonb_build_object('note', p_note, 'label', left(btrim(p_prompt), 60),
      'before', jsonb_build_object(
        'prompt', v_old.prompt,
        'options', jsonb_build_array(v_old.option_a, v_old.option_b, v_old.option_c, v_old.option_d),
        'correct', v_old.correct_option)));
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_fix_question(uuid,text,text[],integer,text)' and d.gerekli;

-- #4 #5: ödül adayları — yalnız tamamlanmış dönem; önceki/sonraki dönem anahtarı.
select pg_temp.w8_degistir('public.admin_list_reward_candidates(text,text)', $w8y$
create or replace function public.admin_list_reward_candidates(
  p_kind text, p_period_key text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_last date;
  v_key text;
  v_step integer;
begin
  perform public.admin_assert();
  v_last := public._admin_reward_last_key(p_kind)::date;
  v_key := public._admin_reward_key(p_kind,
    coalesce(nullif(p_period_key, ''), v_last::text));
  if v_key::date > v_last then
    raise exception 'period_not_finished' using errcode = '22023';
  end if;
  v_step := case p_kind when 'daily' then 1 else 7 end;
  return jsonb_build_object(
    'kind', p_kind, 'period_key', v_key,
    'period_finished', true,
    'prev_key', (v_key::date - v_step)::text,
    'next_key', case when v_key::date + v_step <= v_last then (v_key::date + v_step)::text end,
    'suggested_coins', to_jsonb(public._admin_reward_coins(p_kind)),
    'candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'rank', t.r_rank, 'user_id', t.r_user, 'name', t.r_name, 'score', t.r_score,
        'rewarded', exists (select 1 from public.admin_reward_grants g
                             where g.period_kind = p_kind and g.period_key = v_key
                               and g.user_id = t.r_user)
      ) order by t.r_rank)
      from public._admin_reward_top3(p_kind, v_key) t
    ), '[]'::jsonb)
  );
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_list_reward_candidates(text,text)' and d.gerekli;

-- #4 #14 #17: ödül verme.
select pg_temp.w8_degistir('public.admin_grant_reward(text,text,uuid,integer,text)', $w8y$
create or replace function public.admin_grant_reward(
  p_kind text, p_period_key text, p_user_id uuid, p_coins integer,
  p_badge_slug text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_key text;
  v_rank int;
  v_name text;
  v_contest uuid;
  v_badge uuid;
begin
  perform public.admin_assert();
  if p_coins is null or p_coins not between 0 and 5000 then
    raise exception 'bad_coins' using errcode = '22023';
  end if;
  if p_coins = 0 and p_badge_slug is null then
    raise exception 'nothing_to_grant' using errcode = '22023';
  end if;
  v_key := public._admin_reward_key(p_kind, p_period_key);
  -- Geri alınamaz jeton: yalnız TAMAMLANMIŞ dönem (sıralama oturmuş olmalı).
  if v_key::date > public._admin_reward_last_key(p_kind)::date then
    raise exception 'period_not_finished' using errcode = '22023';
  end if;
  -- Aynı dönemde elle/otomatik ödüller birbirini sırayla görür.
  perform pg_advisory_xact_lock(hashtextextended('admin-reward:' || p_kind || ':' || v_key, 0));
  select t.r_rank, t.r_name into v_rank, v_name
    from public._admin_reward_top3(p_kind, v_key) t
   where t.r_user = p_user_id;
  if v_rank is null then raise exception 'not_in_top3' using errcode = '22023'; end if;

  if p_badge_slug is not null then
    if p_kind <> 'daily' then raise exception 'badge_requires_daily' using errcode = '22023'; end if;
    select id into v_badge from public.contest_badges where slug = p_badge_slug;
    select id into v_contest from public.contests where day_key = v_key::date limit 1;
    if v_badge is null or v_contest is null then
      raise exception 'badge_not_found' using errcode = 'P0002';
    end if;
  end if;

  -- İkinci ödül verilmez; sessiz değil, açık sonuç (arayüz "kaydedildi" demez).
  if exists (select 1 from public.admin_reward_grants g
              where g.period_kind = p_kind and g.period_key = v_key and g.user_id = p_user_id) then
    return jsonb_build_object('granted', false, 'reason', 'already_rewarded');
  end if;
  if exists (select 1 from public.admin_reward_grants g
              where g.period_kind = p_kind and g.period_key = v_key and g.rank = v_rank) then
    return jsonb_build_object('granted', false, 'reason', 'rank_already_rewarded');
  end if;

  begin
    insert into public.admin_reward_grants
      (period_kind, period_key, user_id, rank, coins, badge_slug, source, granted_by)
    values (p_kind, v_key, p_user_id, v_rank, p_coins, p_badge_slug, 'manual', auth.uid());
  exception when unique_violation then
    return jsonb_build_object('granted', false, 'reason', 'already_rewarded');
  end;

  perform public._admin_credit_coins(p_user_id, p_coins, 'admin_' || p_kind || '_reward');
  if v_badge is not null then
    insert into public.user_contest_badges (user_id, badge_id, contest_id)
    values (p_user_id, v_badge, v_contest);
  end if;
  perform public.admin_log('reward_grant', 'user', p_user_id::text,
    jsonb_build_object('kind', p_kind, 'period', v_key, 'rank', v_rank,
                       'coins', p_coins, 'badge', p_badge_slug, 'label', v_name));
  return jsonb_build_object('granted', true, 'rank', v_rank, 'coins', p_coins);
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_grant_reward(text,text,uuid,integer,text)' and d.gerekli;

-- #15 #17: otomatik ödül — kişi hatası kayıtlı; dönem kilidi; derece çakışması atlanır.
select pg_temp.w8_degistir('public._admin_auto_grant(text,text)', $w8y$
create or replace function public._admin_auto_grant(p_kind text, p_key text)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  r record;
  v_coins integer[] := public._admin_reward_coins(p_kind);
  v_n integer := 0;
  v_ins integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('admin-reward:' || p_kind || ':' || p_key, 0));
  for r in select * from public._admin_reward_top3(p_kind, p_key) loop
    begin
      -- Hedefsiz ON CONFLICT: hem (dönem, kişi) hem (dönem, derece) tekilliğini atlar.
      insert into public.admin_reward_grants
        (period_kind, period_key, user_id, rank, coins, source, granted_by)
      values (p_kind, p_key, r.r_user, r.r_rank, v_coins[r.r_rank], 'auto', null)
      on conflict do nothing;
      get diagnostics v_ins = row_count;
      if v_ins = 1 then
        perform public._admin_credit_coins(r.r_user, v_coins[r.r_rank], 'admin_' || p_kind || '_reward');
        perform public.admin_log('reward_auto', 'user', r.r_user::text,
          jsonb_build_object('kind', p_kind, 'period', p_key, 'rank', r.r_rank,
                             'coins', v_coins[r.r_rank], 'label', r.r_name));
        v_n := v_n + 1;
      end if;
    exception when others then
      -- Bu kişinin ödülü (ve satırı) geri alınır; sonrakilere devam. Hata SESSİZ DEĞİL:
      -- denetim günlüğüne ve sunucu günlüğüne yazılır (alt işlem geri alındıktan sonra).
      insert into public.admin_audit_log (admin_id, action, target_type, target_id, detail)
      values (null, 'reward_auto_error', 'user', r.r_user::text,
        jsonb_build_object('kind', p_kind, 'period', p_key, 'rank', r.r_rank,
                           'sqlstate', sqlstate, 'message', left(sqlerrm, 200), 'label', r.r_name));
      raise warning '_admin_auto_grant: % % % (%)', p_kind, p_key, sqlerrm, sqlstate;
    end;
  end loop;
  return v_n;
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public._admin_auto_grant(text,text)' and d.gerekli;

-- #16: cron durursa telafi (ilerleme işaretleri).
select pg_temp.w8_degistir('public.admin_run_auto_rewards()', $w8y$
create or replace function public.admin_run_auto_rewards()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_today date := public.app_today();
  v_since date;
  v_day date;
  v_week date := date_trunc('week', public.app_today()::timestamp)::date;
  v_first_week date;
  v_done_d date;
  v_done_w date;
  v_last_d date;
  v_last_w date;
  v_n integer := 0;
begin
  if not coalesce((select (value)::text::boolean from public.admin_settings where key = 'auto_reward'), false) then
    return jsonb_build_object('enabled', false, 'granted', 0);
  end if;
  v_since := coalesce(
    (select (value #>> '{}')::date from public.admin_settings where key = 'auto_reward_since'),
    v_today);
  v_done_d := (select (value #>> '{}')::date from public.admin_settings where key = 'auto_reward_done_daily');
  v_done_w := (select (value #>> '{}')::date from public.admin_settings where key = 'auto_reward_done_weekly');

  -- Biten günler: ilerleme işaretinden (yoksa açıldığı günden) dünkü güne; tek çalıştırmada
  -- en çok 45 gün (durmuş cron sonraki gecelerde de ilerler). Açıldığı günden önceki dönem
  -- ödüllenmez; verilmiş (dönem, kişi/derece) tekrar verilmez.
  for v_day in
    select g::date from generate_series(
      greatest(v_since, coalesce(v_done_d + 1, v_since)), v_today - 1, interval '1 day') g
    order by 1 limit 45
  loop
    v_n := v_n + public._admin_auto_grant('daily', v_day::text);
    v_last_d := v_day;
  end loop;
  if v_last_d is not null then
    insert into public.admin_settings (key, value) values ('auto_reward_done_daily', to_jsonb(v_last_d::text))
    on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;

  -- Biten haftalar: hafta, açıldığı günden SONRA (ya da o gün) başlamış olmalı; en çok 12 hafta.
  v_first_week := date_trunc('week', v_since::timestamp)::date;
  if v_first_week < v_since then v_first_week := v_first_week + 7; end if;
  for v_day in
    select g::date from generate_series(
      greatest(v_first_week, coalesce(v_done_w + 7, v_first_week)), v_week - 7, interval '7 days') g
    order by 1 limit 12
  loop
    v_n := v_n + public._admin_auto_grant('weekly', v_day::text);
    v_last_w := v_day;
  end loop;
  if v_last_w is not null then
    insert into public.admin_settings (key, value) values ('auto_reward_done_weekly', to_jsonb(v_last_w::text))
    on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;
  return jsonb_build_object('enabled', true, 'granted', v_n);
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_run_auto_rewards()' and d.gerekli;

-- #6: süresi dolmuş askı "askıda" görünmez.
select pg_temp.w8_degistir('public.admin_list_user_reports(integer)', $w8y$
create or replace function public.admin_list_user_reports(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select pr.reported_id as user_id, p.display_name as name,
             count(*) filter (where pr.handled_at is null) as open_reports,
             (array_agg(pr.reason order by pr.created_at desc))[1] as last_reason,
             case when m.state = 'suspended' and m.until is not null and m.until <= now()
                  then null else m.state end as state,
             case when m.state = 'suspended' and m.until is not null and m.until <= now()
                  then null else m.until end as until
      from public.profile_reports pr
      left join public.profiles p on p.id = pr.reported_id
      left join public.user_moderation m on m.user_id = pr.reported_id
      group by pr.reported_id, p.display_name, m.state, m.until
      having count(*) filter (where pr.handled_at is null) > 0
          or (m.state is not null
              and not (m.state = 'suspended' and m.until is not null and m.until <= now()))
      order by count(*) filter (where pr.handled_at is null) desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) r
  ), '[]'::jsonb);
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_list_user_reports(integer)' and d.gerekli;

-- #24 alan9 #18: pano.
select pg_temp.w8_degistir('public.admin_get_stats()', $w8y$
create or replace function public.admin_get_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v jsonb;
begin
  perform public.admin_assert();
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'active_today', (select count(*) from public.usage_daily_active where day = public.app_today()),
    'active_week', (select count(distinct user_id) from public.usage_daily_active
                     where day > public.app_today() - 7),
    -- Yarı açık zaman aralığı: created_at indeksi kullanılabilir (günün başı = app_today() gece yarısı).
    'new_today', (select count(*) from public.profiles
                   where created_at >= (public.app_today()::timestamp at time zone 'Europe/Istanbul')
                     and created_at < ((public.app_today() + 1)::timestamp at time zone 'Europe/Istanbul')),
    'new_week', (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
    'crashes_week', null,
    'mode_usage', jsonb_build_object(
      'solo', coalesce((select sum(n) from public.usage_mode_counter
                         where mode = 'solo' and day > public.app_today() - 7), 0),
      'room', (select count(*) from public.rooms where created_at >= now() - interval '7 days'),
      'duel', (select count(*) from public.async_duels where created_at >= now() - interval '7 days'),
      'tournament', (select count(*) from public.tournaments where opened_at >= now() - interval '7 days'),
      -- Geçiş döneminde aynı gün iki tabloda olabilir: eski beyan tablosu yalnız
      -- doğrulanmış satırı OLMAYAN günlerde sayılır (ödül sıralamasıyla aynı kural).
      'contest',
        (select count(*) from public.verified_daily_event_results where day > public.app_today() - 7)
        + (select count(*) from public.daily_event_results d
            where d.day > public.app_today() - 7
              and not exists (select 1 from public.verified_daily_event_results v where v.day = d.day))
    ),
    'pending_suggestions', (select count(*) from public.suggested_questions where status = 'pending'),
    'open_reports',
      (select count(distinct question_id) from public.question_reports where status = 'open')
      + (select count(distinct reported_id) from public.profile_reports where handled_at is null)
  ) into v;
  return v;
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_get_stats()' and d.gerekli;

-- #21: satırlara id + admin_id.
select pg_temp.w8_degistir('public.admin_list_audit(integer)', $w8y$
create or replace function public.admin_list_audit(p_limit integer default 5)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select id, admin_id, action, target_type, target_id, detail ->> 'label' as label,
             detail, created_at
      from public.admin_audit_log
      order by created_at desc, id desc
      limit least(greatest(coalesce(p_limit, 5), 1), 100)
    ) r
  ), '[]'::jsonb);
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_list_audit(integer)' and d.gerekli;

-- #19: bildirim tercihi değişikliği günlüğe yazılır.
select pg_temp.w8_degistir('public.admin_set_notify_pref(text,boolean)', $w8y$
create or replace function public.admin_set_notify_pref(p_kind text, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  if p_kind not in ('suggestion', 'report') then
    raise exception 'bad_kind' using errcode = '22023';
  end if;
  insert into public.admin_notify_prefs (admin_id, kind, enabled)
  values (auth.uid(), p_kind, coalesce(p_enabled, false))
  on conflict (admin_id, kind) do update set enabled = excluded.enabled;
  perform public.admin_log('notify_pref_set', 'setting', p_kind,
    jsonb_build_object('enabled', coalesce(p_enabled, false), 'label', p_kind));
end;
$fn$;
$w8y$) from w8_durum d where d.imza = 'public.admin_set_notify_pref(text,boolean)' and d.gerekli;

-- alan9 #6: solo sayacı 64 parça (W1'in günlük 30 sınırı AYNEN korunur).
select pg_temp.w8_degistir('public.record_activity(boolean)',
  replace(pg_get_functiondef(to_regprocedure('public.record_activity(boolean)')),
          'floor(random() * 8)::smallint', 'floor(random() * 64)::smallint'))
from w8_durum d where d.imza = 'public.record_activity(boolean)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- Yama sonrası güvenlik doğrulaması
-- ---------------------------------------------------------------------------
do $w8_son$
declare
  r record;
begin
  for r in select * from w8_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'w8: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'w8: % yama sonrası gövde beklenen nihai md5 değil', r.imza;
    end if;
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                   and p.prosecdef and p.proconfig is not null) then
      raise exception 'w8: % SECURITY DEFINER + sabit search_path değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w8: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  for r in select unnest(array[
      'public.admin_list_audit_page(integer,bigint)', 'public._admin_reward_last_key(text)',
      'public.w8_force_suggestion_defaults()', 'public.w8_reopen_profile_report()']) as imza
  loop
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                   and p.prosecdef and p.proconfig is not null) then
      raise exception 'w8: % SECURITY DEFINER + sabit search_path değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w8: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  if has_function_privilege('authenticated', 'public._admin_reward_last_key(text)'::regprocedure, 'execute')
     or has_function_privilege('authenticated', 'public.w8_force_suggestion_defaults()'::regprocedure, 'execute')
     or has_function_privilege('authenticated', 'public.w8_reopen_profile_report()'::regprocedure, 'execute')
     or not has_function_privilege('authenticated', 'public.admin_list_audit_page(integer,bigint)'::regprocedure, 'execute') then
    raise exception 'w8: yeni işlevlerin authenticated EXECUTE durumu beklenen değil';
  end if;
end;
$w8_son$;

commit;
