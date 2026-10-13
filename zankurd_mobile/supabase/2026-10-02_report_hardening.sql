-- 2026-10-02: bildirim (rapor) yolları sertleştirilir (güvenlik denetimi L3).
--
-- KUSURLAR:
--   1. `message_reports.reason`, `question_reports.reason`,
--      `profile_reports.reason` sınırsız `text`. Soru bildirme penceresinde
--      karakter sınırı yok ve `question_reports`a istemci doğrudan INSERT
--      ediyor; tek bir istek MB'larca metin yazabilir (depolama şişirme,
--      moderasyon arayüzünü kilitleme).
--   2. `report_room_message(p_message_id, p_reason)` bildireni mesajın ODASININ
--      üyesi mi diye bakmıyordu: UUID'yi bilen (ya da sızdıran) herkes başka
--      odanın mesajını bildirebilirdi. Üstelik `message_reports` tablosunda
--      `{public}` rolüne açık doğrudan INSERT politikası vardı
--      (`message_reports_insert_own`), yani RPC'deki her kontrol tabloya
--      doğrudan yazılarak atlanabilirdi.
--
-- DÜZELTME:
--   * Üç tabloda `check (char_length(reason) <= 500)` + `BEFORE INSERT/UPDATE`
--     kırpma tetikleyicisi (`left(reason, 500)`). Tetikleyici, uzun metinli
--     ESKİ istemcinin insert'ünü reddetmek yerine kırpar (kullanıcı hata
--     görmez); CHECK, tetikleyici bir gün düşse bile üst sınırı korur.
--   * `report_room_message`: bildiren, mesajın odasında `room_players` üyesi
--     olmalı; değilse 'Message not found' (mesajın varlığı sızdırılmaz).
--     Gerekçe metni de 500'e kırpılır. İmza ve dönüş (`void`) AYNI.
--   * `message_reports_insert_own` politikası kaldırılır; INSERT hakkı
--     `2026-10-02_grants_hardening.sql` ile zaten alınır. Tek yol RPC'dir.
--     (İstemci `message_reports`a doğrudan yazmıyor: lib/ ve 468ea4a4
--     tarandı, yalnız `report_room_message` RPC'si.)
--
-- ARTA KALAN RİSK: `report_question(text)` her çağrıda `questions.report_count`
-- artırır ve 5'te soruyu `needsReview`a düşürür; kullanıcı başına tekilleştirme
-- yok. Bu düzeltme kapsamı dışında bırakıldı (ayrı bulgu).
--
-- GERİ ALMA: üç `drop trigger` + `drop constraint`, `report_room_message`ın
-- önceki gövdesi (baseline) ve `create policy message_reports_insert_own on
-- public.message_reports for insert with check (reporter_id = auth.uid())`.

begin;

create or replace function public.truncate_report_reason()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.reason := left(new.reason, 500);
  return new;
end;
$$;

-- Trigger fonksiyonu RPC olarak çağrılamamalı.
revoke all on function public.truncate_report_reason() from public, anon, authenticated;

drop trigger if exists message_reports_truncate_reason on public.message_reports;
create trigger message_reports_truncate_reason
  before insert or update of reason on public.message_reports
  for each row execute function public.truncate_report_reason();

drop trigger if exists question_reports_truncate_reason on public.question_reports;
create trigger question_reports_truncate_reason
  before insert or update of reason on public.question_reports
  for each row execute function public.truncate_report_reason();

drop trigger if exists profile_reports_truncate_reason on public.profile_reports;
create trigger profile_reports_truncate_reason
  before insert or update of reason on public.profile_reports
  for each row execute function public.truncate_report_reason();

do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'message_reports_reason_len'
                   and conrelid = 'public.message_reports'::regclass) then
    alter table public.message_reports
      add constraint message_reports_reason_len check (char_length(reason) <= 500);
  end if;
  if not exists (select 1 from pg_constraint
                 where conname = 'question_reports_reason_len'
                   and conrelid = 'public.question_reports'::regclass) then
    alter table public.question_reports
      add constraint question_reports_reason_len check (char_length(reason) <= 500);
  end if;
  if not exists (select 1 from pg_constraint
                 where conname = 'profile_reports_reason_len'
                   and conrelid = 'public.profile_reports'::regclass) then
    alter table public.profile_reports
      add constraint profile_reports_reason_len check (char_length(reason) <= 500);
  end if;
end $$;

create or replace function public.report_room_message(
  p_message_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select m.room_id into v_room_id
  from public.room_messages m
  where m.id = p_message_id;

  -- Bildiren, mesajın odasının üyesi olmalı. Mesaj yoksa da aynı hata:
  -- başka odadaki bir mesajın var olup olmadığı sızmaz.
  if v_room_id is null
     or not exists (
       select 1
       from public.room_players rp
       where rp.room_id = v_room_id
         and rp.player_id = v_uid
     ) then
    raise exception 'Message not found';
  end if;

  insert into public.message_reports (message_id, reporter_id, reason)
  values (
    p_message_id,
    v_uid,
    left(coalesce(nullif(btrim(p_reason), ''), 'other'), 500)
  )
  on conflict (message_id, reporter_id) do nothing;
end;
$$;

revoke all on function public.report_room_message(uuid, text) from public, anon;
grant execute on function public.report_room_message(uuid, text) to authenticated;

drop policy if exists message_reports_insert_own on public.message_reports;

do $$
begin
  if exists (select 1 from pg_policies
             where schemaname = 'public' and tablename = 'message_reports'
               and policyname = 'message_reports_insert_own') then
    raise exception 'message_reports doğrudan insert politikası duruyor';
  end if;
  if (select count(*) from pg_trigger
      where not tgisinternal
        and tgname in ('message_reports_truncate_reason',
                       'question_reports_truncate_reason',
                       'profile_reports_truncate_reason')) <> 3 then
    raise exception 'kırpma tetikleyicileri eksik';
  end if;
  if (select count(*) from pg_constraint
      where conname in ('message_reports_reason_len',
                        'question_reports_reason_len',
                        'profile_reports_reason_len')) <> 3 then
    raise exception 'reason uzunluk kısıtları eksik';
  end if;
  if pg_get_functiondef('public.report_room_message(uuid,text)'::regprocedure)
       not like '%room_players%' then
    raise exception 'report_room_message oda üyeliğini denetlemiyor';
  end if;
  if has_function_privilege('anon', 'public.report_room_message(uuid,text)', 'execute') then
    raise exception 'report_room_message anon''a açık';
  end if;
  if not has_function_privilege('authenticated', 'public.report_room_message(uuid,text)', 'execute') then
    raise exception 'report_room_message authenticated''a kapalı';
  end if;
end $$;

commit;
