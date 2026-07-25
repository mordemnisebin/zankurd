-- XP yetkisi sunucuya taşınır (2026-07-25 denetim bulgusu #2)
--
-- Sorun:
--   1) İstemci `profiles.xp` kolonuna MUTLAK değer yazıyordu
--      (`update profiles set xp = <istemci degeri>`). RLS kendi satırına
--      yazmaya izin verdiği için, JWT'si olan biri REST çağrısını döngüye
--      alarak her istekte +2000 XP kazanabiliyordu.
--   2) Aynı clamp, çevrimdışı 2000'den fazla XP biriktiren DÜRÜST
--      kullanıcının XP'sini sessizce kırpıyordu; istemci hata almadığı
--      için kuyruktan siliyor ve fark kalıcı olarak kayboluyordu.
--   3) Mutlak değer yazımı, iki cihazdan çevrimdışı oynayan kullanıcıda
--      son yazanın diğerini ezmesine yol açıyordu.
--
-- Çözüm:
--   - `profiles.xp` istemciden HİÇBİR ŞEKİLDE yazılamaz (trigger).
--   - Tek yazım yolu `award_xp_delta(p_delta)` security definer RPC'sidir.
--   - RPC delta ekler (mutlak yazmaz) → cihazlar arası ezme biter.
--   - Çağrı başına ve GÜN başına üst sınır uygulanır → döngüyle şişirme
--     ekonomik olarak anlamsız hale gelir.
--   - RPC yeni toplamı döner; istemci kırpılıp kırpılmadığını görebilir.
--
-- Idempotent: tekrar çalıştırmak güvenlidir.

-- 1) Günlük XP sayacı için kolonlar.
alter table public.profiles
  add column if not exists xp_daily_total integer not null default 0,
  add column if not exists xp_daily_date date;

-- 2) Trigger: istemci artık xp/coins/rating kolonlarının HİÇBİRİNE
--    dokunamaz. (Önceki sürüm xp için +2000 clamp'e izin veriyordu.)
create or replace function public.profiles_client_write_guard()
returns trigger
language plpgsql
as $$
begin
  -- security definer fonksiyonlar (postgres olarak calisir) serbesttir;
  -- yalnizca dogrudan REST/istemci guncellemeleri kisitlanir.
  if current_user in ('authenticated', 'anon') then
    -- XP yalnizca award_xp_delta() RPC'si uzerinden yazilir.
    new.xp := old.xp;
    new.xp_daily_total := old.xp_daily_total;
    new.xp_daily_date := old.xp_daily_date;
    -- Coin bakiyesi ve rating hicbir zaman istemciden yazilmaz.
    new.coins := old.coins;
    new.rating := old.rating;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_client_write_guard_trg on public.profiles;
create trigger profiles_client_write_guard_trg
  before update on public.profiles
  for each row
  execute function public.profiles_client_write_guard();

-- 3) Tek XP yazım kapısı.
--
-- p_delta: kazanılan XP farkı (negatif ve 0 yok sayılır).
-- Döner: kullanıcının güncel toplam XP'si.
create or replace function public.award_xp_delta(p_delta integer)
returns integer
language plpgsql
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

  -- Tek çağrı tavanı: en uzun quiz bile bunu aşmaz.
  v_delta := least(v_delta, 2000);

  -- Günlük tavan (UTC gün sınırı). Gün değiştiyse sayaç sıfırlanır.
  if v_row.xp_daily_date is distinct from current_date then
    v_today_total := 0;
  else
    v_today_total := coalesce(v_row.xp_daily_total, 0);
  end if;

  v_allowed := greatest(0, 20000 - v_today_total);
  v_delta := least(v_delta, v_allowed);

  if v_delta = 0 then
    -- Günlük tavan dolu; XP değişmez ama sayaç tarihi güncellenir.
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
