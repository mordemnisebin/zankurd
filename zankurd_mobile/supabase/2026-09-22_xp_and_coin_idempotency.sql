-- 2026-09-22 — Solo XP ve coin harcamasını idempotent yapar.
--
-- UYGULANMADI
--
-- Bu dosya production'a, staging'e veya local'e UYGULANMAMIŞTIR.
-- İstemci fonksiyonu bulamazsa (42883 / PGRST202) eski çağrıyı bir kez
-- yapar ve onu kuyruğa koymaz. Fonksiyon varken aynı anahtarla yeniden
-- deneme ikinci kez yazmaz.

begin;

create table if not exists public.xp_award_keys (
  user_id uuid not null references auth.users (id) on delete cascade,
  idempotency_key text not null,
  delta integer not null,
  total_after integer not null,
  created_at timestamptz not null default now(),
  primary key (user_id, idempotency_key)
);

create table if not exists public.idempotent_spends (
  player_id uuid not null references auth.users (id) on delete cascade,
  idempotency_key text not null,
  amount integer not null,
  reason text not null,
  created_at timestamptz not null default now(),
  primary key (player_id, idempotency_key)
);

alter table public.xp_award_keys enable row level security;
alter table public.idempotent_spends enable row level security;

-- Bu tablolar security-definer RPC'lerin iç kayıt defteridir. İstemci
-- doğrudan okuyamaz/yazamaz; policy bilerek tanımlanmamıştır.
revoke all on table public.xp_award_keys from public, anon, authenticated;
revoke all on table public.idempotent_spends from public, anon, authenticated;
grant all on table public.xp_award_keys to service_role;
grant all on table public.idempotent_spends to service_role;

create or replace function public.award_xp_delta_once(
  p_delta integer,
  p_idempotency_key text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_key text;
  v_total integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  v_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  if v_key is null or length(v_key) > 200 then
    raise exception 'invalid key';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':xp:' || v_key, 0));

  select total_after
    into v_total
    from public.xp_award_keys
   where user_id = v_uid
     and idempotency_key = v_key;
  if found then
    return v_total;
  end if;

  v_total := public.award_xp_delta(p_delta);
  insert into public.xp_award_keys (user_id, idempotency_key, delta, total_after)
  values (v_uid, v_key, greatest(p_delta, 0), coalesce(v_total, 0));
  return coalesce(v_total, 0);
end;
$$;

create or replace function public.spend_coins_once(
  p_amount integer,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_key text;
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;
  v_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  if v_key is null or length(v_key) > 200 then
    return jsonb_build_object('success', false, 'error', 'invalid key');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':coin:' || v_key, 0));

  if exists (
    select 1
      from public.idempotent_spends
     where player_id = v_uid
       and idempotency_key = v_key
  ) then
    return jsonb_build_object('success', true, 'idempotent', true);
  end if;

  v_result := public.spend_coins(p_amount, p_reason);
  if coalesce((v_result->>'success')::boolean, false) then
    insert into public.idempotent_spends (player_id, idempotency_key, amount, reason)
    values (v_uid, v_key, p_amount, p_reason);
  end if;
  return v_result || jsonb_build_object('idempotent', true);
end;
$$;

-- Solo/client delta artık rekabetçi XP yazamaz. Bu fonksiyon geçmiş istemci
-- uyumluluğu için tanımlı kalır ama yalnız servis rolü çalıştırabilir.
revoke all on function public.award_xp_delta(integer) from public, anon, authenticated;
grant execute on function public.award_xp_delta(integer) to service_role;
revoke all on function public.award_xp_delta_once(integer, text) from public, anon, authenticated;
grant execute on function public.award_xp_delta_once(integer, text) to service_role;
revoke all on function public.spend_coins_once(integer, text, text) from public, anon;
grant execute on function public.spend_coins_once(integer, text, text) to authenticated;

commit;
