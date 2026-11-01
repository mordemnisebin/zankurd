-- 2026-11-01 soru önerisi hız sınırı.
--
-- Kusur: `suggested_questions` INSERT politikası `TO authenticated`; anonim
-- misafir oturumları da bu role girer ve satır sayısı sınırsızdı: bir
-- istemci döngüyle moderasyon kuyruğunu taşırabilirdi.
--
-- Çözüm: BEFORE INSERT tetikleyici — kullanıcı başına son 24 saatte en çok
-- 10 öneri. Aşılırsa 'suggestion_rate_limited' (SQLSTATE ZK429) fırlatır.
-- `auth.uid()` yoksa (service_role / moderasyon betiği) sınır uygulanmaz.
-- İstemci hatayı genel hata iletisiyle gösterir.
-- Geri alma: geri_al/2026-11-01_oneri_siniri_geri.sql
begin;

create or replace function public.limit_suggested_question_rate()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_recent integer;
begin
  if auth.uid() is null then
    return new;
  end if;

  select count(*)::integer into v_recent
  from (
    select 1
    from public.suggested_questions s
    where s.user_id = new.user_id
      and s.created_at > now() - interval '24 hours'
    limit 10
  ) recent;

  if v_recent >= 10 then
    raise exception 'suggestion_rate_limited' using errcode = 'ZK429';
  end if;
  return new;
end;
$function$;

revoke all on function public.limit_suggested_question_rate()
  from public, anon, authenticated;

drop trigger if exists suggested_questions_rate_limit
  on public.suggested_questions;
create trigger suggested_questions_rate_limit
before insert on public.suggested_questions
for each row
execute function public.limit_suggested_question_rate();

commit;
