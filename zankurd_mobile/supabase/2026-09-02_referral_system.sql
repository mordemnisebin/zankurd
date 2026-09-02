-- 2026-09-02: Referans (Arkadaş Davet) Sistemi
--
-- Oyuncular kendi benzersiz `player_tag` (ZK-XXXX) kodlarıyla arkadaşlarını davet edebilir.
-- Davet edilen oyuncu kodu girdiğinde her iki tarafa da 100 coin ödül verilir.
-- Güvenlik: Kendi kodunu girme engellenir, bir kullanıcı en fazla bir kez referans kodu kullanabilir.

-- 1. profiles tablosuna referred_by sütunu ekle (idempotent)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'referred_by'
  ) then
    alter table public.profiles
      add column referred_by uuid references public.profiles(id) on delete set null;
  end if;
end $$;

-- 2. Referans kodu uygulama RPC'si
create or replace function public.redeem_referral_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_clean_code text;
  v_referrer record;
  v_caller record;
  v_reward_amount constant integer := 100;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'unauthenticated';
  end if;

  v_clean_code := upper(trim(p_code));
  if v_clean_code = '' then
    raise exception 'invalid_code';
  end if;

  -- Çağıranın profilini oku
  select id, referred_by, player_tag, coins
  into v_caller
  from public.profiles
  where id = v_user_id
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;

  -- Daha önce kod kullanılmış mı?
  if v_caller.referred_by is not null then
    return jsonb_build_object(
      'success', false,
      'error', 'already_redeemed',
      'message', 'Referral code already used'
    );
  end if;

  -- Davet eden oyuncuyu bul (ZK- önekiyle veya öneksiz esnek eşleşme)
  select id, display_name, player_tag
  into v_referrer
  from public.profiles
  where player_tag = v_clean_code
     or player_tag = 'ZK-' || v_clean_code
     or replace(player_tag, 'ZK-', '') = v_clean_code
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'code_not_found',
      'message', 'Invalid referral code'
    );
  end if;

  -- Kendi kodunu girmesini engelle
  if v_referrer.id = v_user_id then
    return jsonb_build_object(
      'success', false,
      'error', 'own_code',
      'message', 'Cannot use own code'
    );
  end if;

  -- Referansı kaydet
  update public.profiles
  set referred_by = v_referrer.id,
      coins = coins + v_reward_amount,
      updated_at = now()
  where id = v_user_id;

  -- Davet edene de ödül ver
  update public.profiles
  set coins = coins + v_reward_amount,
      updated_at = now()
  where id = v_referrer.id;

  -- Muhasebe hareketleri (coin_transactions)
  insert into public.coin_transactions (user_id, amount, reason, created_at)
  values
    (v_user_id, v_reward_amount, 'referral_welcome', now()),
    (v_referrer.id, v_reward_amount, 'referral_invite', now());

  return jsonb_build_object(
    'success', true,
    'coins_awarded', v_reward_amount,
    'referrer_name', coalesce(v_referrer.display_name, 'Heval')
  );
end;
$$;

-- 3. İzinler: Yalnızca oturum açmış kullanıcılar (authenticated) çağırabilir
revoke all on function public.redeem_referral_code(text) from public;
revoke all on function public.redeem_referral_code(text) from anon;
grant execute on function public.redeem_referral_code(text) to authenticated;
