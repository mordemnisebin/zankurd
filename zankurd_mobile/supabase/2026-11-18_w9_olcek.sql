-- 2.1.2 W9: temizlik işlerinin ÖLÇEĞİ (ChatGPT Pro alan 9 #15, #16, #17).
-- Geri alma: geri_al/2026-11-18_w9_olcek_geri.sql
-- İndeksler (CONCURRENTLY, transaction dışı): 2026-11-18_w9_olcek_indeks_concurrently.sql
--
-- NİÇİN
--  #15 verified_solo_selections: 3 günden eski biletler yalnız AYNI kullanıcı
--      `prepare_verified_solo_questions` çağırınca siliniyordu. Uygulamayı bırakan
--      kullanıcının biletleri (question_ids uuid[]) süresiz birikirdi. Genel süpürme
--      eklenir (aynı eşik: 3 gün; kullanılmış/kullanılmamış fark etmez, işlev de
--      ikisini birden siliyor).
--  #16 push_outbox_retention ve rate_limit_events_sweep günde BİR kez çalışıyor ve
--      her çalışmada en çok 40 x 5000 = 200.000 satır siliyordu; günlük üretim
--      bunu aşarsa kuyruk her gün büyür. Gövdelere DOKUNULMAZ: yalnız zamanlama
--      günlükten 4 saatlikse (günde 6 koşu = 1,2 milyon satır) çıkar.
--  #17 idempotent-ops-temizlik: günde bir koşu, en çok 20.000 satır. 3 saatlik
--      zamanlama (günde 8 koşu = 160.000 satır). Komut metnine DOKUNULMAZ.
--
-- NE DEĞİŞMEZ: hiçbir MEVCUT işlev gövdesi değişmez (bu yüzden tam gövde md5
-- ön koşulu yok); yalnız bir YENİ işlev ve 3 cron zamanlaması (cron.alter_job:
-- komut aynen kalır). Eski zamanlamalar `olcek_tur3_yedek` 'w9:cron:<ad>' satırına
-- yedeklenir. Beklenmeyen ön durumda göç durur.
--
-- BİLİNÇLİ ATLANANLAR (bu göçte değil; gerekçe applied.md): #4 lig kapanışı,
-- #5 sıralama board CTE, #11 jeton bakiyesi (yalnız indeks).
begin;

set local lock_timeout = '10s';

create extension if not exists pg_cron with schema pg_catalog;

do $once$
begin
  if to_regclass('public.verified_solo_selections') is null
     or to_regclass('public.olcek_tur3_yedek') is null
     or to_regprocedure('public.push_outbox_retention(integer,integer)') is null
     or to_regprocedure('public.rate_limit_events_sweep(integer)') is null then
    raise exception 'w9: beklenen canlı nesneler eksik (verified_solo_selections / olcek_tur3_yedek / süpürme işlevleri)';
  end if;
end
$once$;

-- 1. #15 genel süpürme işlevi (YENİ) -----------------------------------------------
create or replace function public.verified_solo_selections_sweep(p_batch integer default 5000)
returns bigint
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_total bigint := 0;
  v_n bigint;
  v_i integer := 0;
begin
  loop
    delete from public.verified_solo_selections s
    where s.ctid in (
      select d.ctid from public.verified_solo_selections d
      where d.created_at < clock_timestamp() - interval '3 days'
      limit greatest(p_batch, 100)
      for update skip locked
    );
    get diagnostics v_n = row_count;
    v_total := v_total + v_n;
    v_i := v_i + 1;
    exit when v_n = 0 or v_i >= 40;
  end loop;
  return v_total;
end;
$function$;
revoke all on function public.verified_solo_selections_sweep(integer)
  from public, anon, authenticated;

-- 2. Zamanlama --------------------------------------------------------------------
-- (job adı, beklenen ESKİ zamanlama, YENİ zamanlama). Komut metni aynen kalır.
create temp table w9_isler (
  ad text primary key, eski text not null, yeni text not null
) on commit drop;
insert into w9_isler values
  ('push-outbox-retention',    '20 0 * * *', '20 */4 * * *'),
  ('rate-limit-events-sweep',  '25 0 * * *', '25 */4 * * *'),
  ('idempotent-ops-temizlik',  '47 3 * * *', '47 */3 * * *');

do $zaman$
declare
  r record;
  j record;
begin
  for r in select * from w9_isler loop
    select * into j from cron.job where jobname = r.ad;
    if not found then
      raise exception 'w9: cron işi yok: % (önceki göç uygulanmamış)', r.ad;
    end if;
    if j.schedule = r.yeni then
      continue; -- zaten uygulanmış (idempotent)
    end if;
    if j.schedule <> r.eski then
      raise exception 'w9: % zamanlaması beklenen eski değer değil (% <> %); yeniden incele', r.ad, j.schedule, r.eski;
    end if;
    insert into public.olcek_tur3_yedek (ad, tanim)
    values ('w9:cron:' || r.ad, j.schedule || E'\n' || j.command)
    on conflict (ad) do nothing;
    perform cron.alter_job(j.jobid, schedule := r.yeni);
  end loop;
end
$zaman$;

-- Yeni süpürme işi: 6 saatte bir (xx:35). Yoksa kurulur.
do $yeni_is$
begin
  if not exists (select 1 from cron.job where jobname = 'verified-solo-selections-sweep') then
    perform cron.schedule('verified-solo-selections-sweep', '35 */6 * * *',
      'select public.verified_solo_selections_sweep(5000)');
  end if;
end
$yeni_is$;

-- 3. Son denetim --------------------------------------------------------------------
do $son$
declare
  r record;
begin
  for r in select * from w9_isler loop
    if (select schedule from cron.job where jobname = r.ad) is distinct from r.yeni then
      raise exception 'w9: % zamanlaması yeni değere ulaşmadı', r.ad;
    end if;
  end loop;
  if not exists (select 1 from cron.job where jobname = 'verified-solo-selections-sweep') then
    raise exception 'w9: verified-solo-selections-sweep işi kurulmadı';
  end if;
  if has_function_privilege('anon', 'public.verified_solo_selections_sweep(integer)', 'execute')
     or has_function_privilege('authenticated', 'public.verified_solo_selections_sweep(integer)', 'execute')
     or has_function_privilege('public', 'public.verified_solo_selections_sweep(integer)', 'execute') then
    raise exception 'w9: süpürme işlevi istemci rollerine açık';
  end if;
end
$son$;

commit;
