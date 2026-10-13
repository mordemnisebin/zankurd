-- 2026-09-06: davet ödülü yalnız doğrulanmış (misafir olmayan) hesap.
--
-- Anonim oturumla kod basıp çift 100 jeton farmi kapanır. Göç,
-- 2026-09-02 redeem_referral_code gövdesini koruyup kapıyı ekler.
-- Idempotent: create or replace.

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

  -- Misafir (anonymous identity) veya kimliği olmayan oturum ödül alamaz.
  -- `auth.users.is_anonymous` sürümden sürüme yok; identities yeter.
  if not exists (
       select 1
       from auth.identities i
       where i.user_id = v_user_id
         and i.provider is distinct from 'anonymous'
     )
  then
    return jsonb_build_object(
      'success', false,
      'error', 'not_verified',
      'message', 'Referral requires a verified account'
    );
  end if;

  v_clean_code := upper(trim(p_code));
  if v_clean_code = '' then
    raise exception 'invalid_code';
  end if;

  select id, referred_by, player_tag
  into v_caller
  from public.profiles
  where id = v_user_id
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;

  if v_caller.referred_by is not null then
    return jsonb_build_object(
      'success', false,
      'error', 'already_redeemed',
      'message', 'Referral code already used'
    );
  end if;

  select id, display_name, player_tag
  into v_referrer
  from public.profiles
  where player_tag = v_clean_code
     or player_tag = 'ZK-' || v_clean_code
     or replace(player_tag, 'ZK-', '') = v_clean_code
  limit 1
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'code_not_found',
      'message', 'Invalid referral code'
    );
  end if;

  if v_referrer.id = v_user_id then
    return jsonb_build_object(
      'success', false,
      'error', 'own_code',
      'message', 'Cannot use own code'
    );
  end if;

  update public.profiles
  set referred_by = v_referrer.id,
      updated_at = now()
  where id = v_user_id;

  insert into public.coin_transactions (player_id, amount, reason)
  values
    (v_user_id, v_reward_amount, 'referral_welcome'),
    (v_referrer.id, v_reward_amount, 'referral_invite');

  return jsonb_build_object(
    'success', true,
    'coins_awarded', v_reward_amount,
    'referrer_name', coalesce(v_referrer.display_name, 'Heval')
  );
end;
$$;

revoke all on function public.redeem_referral_code(text) from public;
revoke all on function public.redeem_referral_code(text) from anon;
grant execute on function public.redeem_referral_code(text) to authenticated;
