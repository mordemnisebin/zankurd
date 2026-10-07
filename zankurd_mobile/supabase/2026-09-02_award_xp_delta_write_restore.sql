-- 2026-09-02: award_xp_delta yazımını geri getirir.
--
-- 2026-07-29_client_reward_authority_fix fonksiyonu STABLE yaptı ve
-- p_delta'yı yok sayarak mevcut xp'yi döndürdü. İstemci awardXp çağırıyordu
-- ama sıralama/lig boş kaldı (2026-08-12: 21 profilde xp=0).
--
-- Bu göç 2026-07-25 yazım kapısını geri yükler: delta ekler, çağrı başına
-- 2000 / gün 20000 tavan, istemci profiles.xp yazamaz (mevcut trigger).
-- Idempotent: create or replace.

create or replace function public.award_xp_delta(p_delta integer)
returns integer
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_delta integer;
  v_row public.profiles%rowtype;
  v_today_total integer;
  v_allowed integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_row from public.profiles where id = v_uid for update;
  if not found then
    raise exception 'Profile not found';
  end if;

  v_delta := greatest(0, coalesce(p_delta, 0));
  if v_delta = 0 then
    return coalesce(v_row.xp, 0);
  end if;

  v_delta := least(v_delta, 2000);

  if v_row.xp_daily_date is distinct from current_date then
    v_today_total := 0;
  else
    v_today_total := coalesce(v_row.xp_daily_total, 0);
  end if;

  v_allowed := greatest(0, 20000 - v_today_total);
  v_delta := least(v_delta, v_allowed);

  if v_delta = 0 then
    update public.profiles
    set xp_daily_date = current_date,
        xp_daily_total = v_today_total,
        updated_at = now()
    where id = v_uid;
    return coalesce(v_row.xp, 0);
  end if;

  update public.profiles
  set xp = coalesce(xp, 0) + v_delta,
      xp_daily_total = v_today_total + v_delta,
      xp_daily_date = current_date,
      updated_at = now()
  where id = v_uid
  returning xp into v_today_total;

  return coalesce(v_today_total, 0);
end;
$$;

revoke all on function public.award_xp_delta(integer) from public, anon;
grant execute on function public.award_xp_delta(integer) to authenticated;
grant execute on function public.award_xp_delta(integer) to service_role;
