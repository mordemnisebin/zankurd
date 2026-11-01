-- 2026-11-01 paylaşım ödülü: çarktan AYRI sunucu işlevi.
--
-- Kusur: "günün ilk paylaşımı +25 jeton" istemcide `award_spin_coins`i
-- çağırıyordu. Bu, çarkın günlük hakkını yakıyor (sonra çark "bugün zaten
-- çevirdin" diyordu) ya da çark kullanılmışsa `claim_extra_spin` ile SATIN
-- ALINMIŞ ekstra çevirmeyi tüketiyordu; ödeme 10–100 arası gün-tabanlıydı,
-- bildirim hep "+25" yazıyordu.
--
-- Çözüm: `claim_share_reward()` — yalnız auth.uid() (misafir dahil), İstanbul
-- gününde (`app_today()`) bir kez, sabit 25 jeton, idempotent. Kayıt
-- `share_reward_claims(player_id, claim_date)` birincil anahtarı ile tekil;
-- jeton `coin_transactions`a (reason 'share_reward') yazılır — bakiye
-- çark/ödül işlevleriyle aynı defterden okunur.
--
-- Yetki: SECURITY DEFINER, search_path sabit; anon/public execute YOK.
-- Tablo istemciye kapalı (RLS açık, politika yok).
-- İstemci: işlev yoksa (PGRST202/42883) ödül verilmez, çark yakılmaz.
-- Geri alma: geri_al/2026-11-01_paylasim_odulu_geri.sql
begin;

create table if not exists public.share_reward_claims (
  player_id uuid not null references public.profiles (id) on delete cascade,
  claim_date date not null,
  created_at timestamptz not null default now(),
  primary key (player_id, claim_date)
);

alter table public.share_reward_claims enable row level security;
alter table public.share_reward_claims force row level security;
revoke all on table public.share_reward_claims from public, anon, authenticated;

create or replace function public.claim_share_reward()
 returns table(success boolean, reward_amount integer, message text)
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_today date := public.app_today();
  v_claim_date date;
  c_reward constant integer := 25;
begin
  if v_uid is null then
    return query select false, 0, 'Authenticated user required'::text;
    return;
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return query select false, 0, 'Profile missing'::text;
    return;
  end if;

  insert into public.share_reward_claims (player_id, claim_date)
  values (v_uid, v_today)
  on conflict (player_id, claim_date) do nothing
  returning claim_date into v_claim_date;

  if v_claim_date is null then
    return query select false, 0, 'Already claimed today'::text;
    return;
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, c_reward, 'share_reward');

  return query select true, c_reward, 'Share reward granted'::text;
end;
$function$;

revoke all on function public.claim_share_reward() from public, anon;
grant execute on function public.claim_share_reward() to authenticated;

commit;
