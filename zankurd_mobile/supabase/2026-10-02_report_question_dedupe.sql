-- 2026-10-02: soru bildirimi kullanıcı başına BİR kez sayılır; sayaç gerçekten
-- çalışır hale gelir; blocked_users.blocked_id indeksi eklenir.
--
-- KUSURLAR (canlı veritabanında salt okunur sorgularla 2026-10-02 doğrulandı):
--   1. `report_question(text)` her çağrıda `questions.report_count` artırır ve
--      5'te soruyu `needsReview`a düşürür. Bildirenin kim olduğuna hiç
--      bakmaz: aynı kullanıcı aynı soruyu 5 kez bildirip soruyu kendi başına
--      oynanabilir havuzdan düşürebilirdi. `question_reports`ta
--      (reporter_id, question_id) için tekillik de yok.
--   2. (Asıl bulgu, ilkini gölgeliyordu.) Canlı gövde
--      `where id = p_question_id` karşılaştırır: `questions.id` UUID,
--      parametre `text`. PL/pgSQL parametre tipini korur, yani her çağrı
--      "operator does not exist: uuid = text" ile HATA verir. İstemci hatayı
--      yutar (`_recordError ... 'report_question RPC failed'`), bildirim
--      `question_reports`a yine yazılır. Sonuç: sayaç HİÇ çalışmadı
--      (`report_count > 0` olan soru: 0; tabloda 3 gerçek bildirim var).
--      Üstelik yerel banka kimlikleri (`ziman_x_0035`) UUID değildir; onlar
--      için sunucuda soru zaten yoktur, ama bildirim yine de gelir.
--   3. `blocked_users` birincil anahtarı (blocker_id, blocked_id); engelleyen
--      tarafı sorgular hızlıdır, "beni kim engelledi" (`where blocked_id = $1`;
--      `2026-10-02_blocking_enforcement.sql` süzgeçleri) tam tablo taraması.
--
-- NİÇİN SESSİZ KALDI: RPC'nin hatası istemcide yutuluyor, kullanıcı bir şey
-- görmüyor; bildirim tablosu dolduğu için "bildirimler çalışıyor" görünüyordu.
-- Tekrar bildirme saldırısı da gerçek bir sayaç olmadığından hiç ölçülmedi.
--
-- DÜZELTME:
--   * `question_reports` üstünde UNIQUE (reporter_id, question_id). Mevcut
--     yinelenenler önce silinir (en eski satır kalır; bugün 0 yineleme var).
--     reporter_id NULL (hesabı silinmiş) satırlar birbirinden ayrı sayılır.
--   * BEFORE INSERT tetikleyicisi: aynı kullanıcının aynı soruyu ikinci
--     bildirimi HATA vermeden sessizce atlanır (`return null`). Eski mağaza
--     sürümü doğrudan insert yapıyor; unique ihlali o istemcide bildirimi
--     hatalı gösterirdi. Tetikleyici `counted_at`ı da sıfırlar (istemci kendi
--     satırını "sayıldı" diye işaretleyip sayımı atlatamasın). UNIQUE indeks
--     yarış durumunda son güvencedir.
--   * `question_reports.counted_at`: bildirimin sayaca eklendiği an. RPC bu
--     işareti `null -> now()` yapabilirse sayar, yapamazsa (zaten sayılmış ya
--     da bildirim satırı yok) hiçbir şey yapmadan DÖNER: idempotent, çift
--     sayım yok, imza ve dönüş (`void`) aynı.
--   * `report_question`: UUID olmayan kimlikte sessizce döner; `id = uuid`
--     karşılaştırması artık tip uyumlu. Aksi her şey (SECURITY DEFINER,
--     search_path, eşik 5, `rejected` korunur) canlı gövdeyle aynı.
--   * Geriye dönük sayım: bugüne dek hiç sayılmamış (`counted_at is null`)
--     UUID kimlikli bildirimler bir kez sayılır, sonra hepsi işaretlenir.
--   * `blocked_users_blocked_id_idx`.
--
-- GERİ ALMA:
--   drop trigger question_reports_before_insert on public.question_reports;
--   drop function public.question_reports_before_insert();
--   drop index public.question_reports_reporter_question_uidx;
--   drop index public.blocked_users_blocked_id_idx;
--   alter table public.question_reports drop column counted_at;
--   ve `report_question`ı eski gövdesiyle yeniden yaz (pg_get_functiondef,
--   2026-10-02: `update ... where id = p_question_id returning report_count,
--   review_status`; `if v_count >= 5 and v_status is distinct from 'rejected'
--   then review_status = 'needsReview'`). Geriye dönük sayımla artan
--   `questions.report_count` değerleri geri alınmaz (bugün 0 satır etkilenir).
--
-- UYGULAMA: supabase db query --linked -f supabase/2026-10-02_report_question_dedupe.sql

begin;

-- 1) Mevcut yinelenenleri güvenle ele: aynı (reporter_id, question_id)
--    için EN ESKİ satır kalır, fazlası silinir. Bugün 0 satır.
delete from public.question_reports r
using (
  select id,
         row_number() over (
           partition by reporter_id, question_id
           order by created_at, id
         ) as rn
  from public.question_reports
  where reporter_id is not null
) d
where r.id = d.id
  and d.rn > 1;

-- 2) Sayılma işareti. Eski satırlar `null` başlar.
alter table public.question_reports
  add column if not exists counted_at timestamptz;

-- 3) Geriye dönük sayım: sayaç hiç çalışmadığı için bugüne dek sayılmamış,
--    UUID kimlikli bildirimler bir kez eklenir (UUID olmayanlar sunucuda
--    soru değildir; yalnız işaretlenir).
create temp table _legacy_report_counts on commit drop as
select case
         when lower(question_id) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           then lower(question_id)::uuid
       end as qid,
       count(*)::integer as n
from public.question_reports
where counted_at is null
group by 1;

update public.questions q
   set report_count = coalesce(q.report_count, 0) + l.n
  from _legacy_report_counts l
 where l.qid is not null
   and q.id = l.qid;

update public.questions q
   set review_status = 'needsReview'
  from _legacy_report_counts l
 where l.qid is not null
   and q.id = l.qid
   and q.report_count >= 5
   and q.review_status is distinct from 'rejected';

update public.question_reports
   set counted_at = created_at
 where counted_at is null;

-- 4) Tekillik: kullanıcı başına soru başına tek bildirim.
create unique index if not exists question_reports_reporter_question_uidx
  on public.question_reports (reporter_id, question_id);

-- 5) İkinci bildirim hata vermeden atlanır; istemci `counted_at` yazamaz.
--    SECURITY DEFINER: çağıran (authenticated) bu tabloda SELECT politikası
--    olmadığı için kendi satırını göremez.
create or replace function public.question_reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.counted_at := null;
  if new.reporter_id is not null
     and exists (
       select 1
       from public.question_reports r
       where r.reporter_id = new.reporter_id
         and r.question_id = new.question_id
     ) then
    return null;
  end if;
  return new;
end;
$$;

-- Tetikleyici fonksiyonu RPC olarak çağrılamamalı.
revoke all on function public.question_reports_before_insert() from public, anon, authenticated;

drop trigger if exists question_reports_before_insert on public.question_reports;
create trigger question_reports_before_insert
  before insert on public.question_reports
  for each row execute function public.question_reports_before_insert();

-- 6) Idempotent sayaç. İmza ve dönüş aynı.
create or replace function public.report_question(p_question_id text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_qid uuid;
  v_marked integer;
  v_count integer;
  v_status text;
begin
  if v_uid is null or p_question_id is null then
    return;
  end if;

  -- Yerel banka kimlikleri (ziman_x_0035) UUID değildir; sunucuda soru yok.
  if lower(p_question_id) !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return;
  end if;
  v_qid := lower(p_question_id)::uuid;

  -- Bu kullanıcının bu soruya bildirimi varsa ve henüz sayılmamışsa işaretle.
  -- İşaretleyemezsek (zaten sayılmış ya da bildirim satırı yok) SAYMA.
  update public.question_reports
     set counted_at = now()
   where reporter_id = v_uid
     and question_id = p_question_id
     and counted_at is null;
  get diagnostics v_marked = row_count;
  if v_marked = 0 then
    return;
  end if;

  update public.questions
     set report_count = coalesce(report_count, 0) + 1
   where id = v_qid
  returning report_count, review_status into v_count, v_status;

  if v_count >= 5 and (v_status is distinct from 'rejected') then
    update public.questions
       set review_status = 'needsReview'
     where id = v_qid;
  end if;
end;
$function$;

revoke all on function public.report_question(text) from public, anon;
grant execute on function public.report_question(text) to authenticated;

-- 7) Engelleyeni sorgulayan süzgeçler için.
create index if not exists blocked_users_blocked_id_idx
  on public.blocked_users (blocked_id);

-- 8) Doğrulama: biri tutmazsa bütün göç geri alınır.
do $$
begin
  if not exists (
    select 1 from pg_index i
    join pg_class c on c.oid = i.indexrelid
    where c.relname = 'question_reports_reporter_question_uidx'
      and i.indisunique
      and i.indrelid = 'public.question_reports'::regclass
  ) then
    raise exception 'question_reports tekillik indeksi eksik';
  end if;
  if exists (
    select 1 from public.question_reports
    where reporter_id is not null
    group by reporter_id, question_id
    having count(*) > 1
  ) then
    raise exception 'question_reports hâlâ yinelenen bildirim içeriyor';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'question_reports'
      and column_name = 'counted_at'
  ) then
    raise exception 'question_reports.counted_at yok';
  end if;
  if exists (select 1 from public.question_reports where counted_at is null) then
    raise exception 'sayılmamış eski bildirim kaldı';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgname = 'question_reports_before_insert'
      and tgrelid = 'public.question_reports'::regclass
      and not tgisinternal
  ) then
    raise exception 'question_reports_before_insert tetikleyicisi yok';
  end if;
  if pg_get_functiondef('public.report_question(text)'::regprocedure)
       not like '%counted_at%' then
    raise exception 'report_question idempotent değil';
  end if;
  if not (select prosecdef from pg_proc
          where oid = 'public.report_question(text)'::regprocedure) then
    raise exception 'report_question SECURITY DEFINER değil';
  end if;
  if (select pg_get_function_result(oid) from pg_proc
      where oid = 'public.report_question(text)'::regprocedure) <> 'void' then
    raise exception 'report_question dönüş tipi değişti';
  end if;
  if has_function_privilege('anon', 'public.report_question(text)', 'execute') then
    raise exception 'report_question anon''a açık';
  end if;
  if not has_function_privilege('authenticated', 'public.report_question(text)', 'execute') then
    raise exception 'report_question authenticated''a kapalı';
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and tablename = 'blocked_users'
      and indexname = 'blocked_users_blocked_id_idx'
  ) then
    raise exception 'blocked_users_blocked_id_idx yok';
  end if;
end $$;

commit;
