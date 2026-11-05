-- Seri dondurma satın alımında SUNUCU üst sınırı (2.1.2 veri güvenliği).
-- Geri alma: geri_al/2026-11-16_seri_dondurma_ust_sinir_geri.sql
--
-- NİÇİN (ChatGPT Pro 2.1.2 alan 3 #4):
--  Üst sınır (en çok 2 jeton) yalnız istemcide denetleniyordu. İki cihaz aynı
--  anda, her biri kendi yerelinde "2'den az" görüp 50'şer jeton ödeyince iki
--  ücret kesiliyor, bulut defter birleşimi bakiyeyi 2'ye kıstırınca bir hak
--  sessizce eriyordu (iki ücret / tek hak).
--
-- NE EKLER (YALNIZ YENİ nesne; `spend_streak_freeze(text)` gövdesine DOKUNMAZ,
-- bozulma anı teklifi ve eski istemciler onu kullanmaya devam eder):
--   public.spend_streak_freeze_capped(p_idempotency_key text)
--   Aynı advisory kilit altında (hesap başına): anahtar daha önce
--   tahsil edildiyse aynı sonucu döner (already_charged); değilse hesabın
--   bulut anlık görüntüsündeki jeton bakiyesini + o anlık görüntüden SONRA
--   kesilmiş ama henüz eşitlenmemiş mağaza alımlarını sayar; toplam 2'ye
--   ulaştıysa ÜCRET KESMEDEN {success:false, error:'freeze_full'} döner.
--   Bakiye yetersizse 'insufficient balance'.
--
-- SINIR (bilinçli): "eşitlenmemiş alım" = anlık görüntünün `updated_at`ından
-- sonra kesilmiş anahtarlı mağaza alımları. Bir alımın hakkı teslim edilip
-- anlık görüntüye YAZILMADAN başka bir cihaz anlık görüntüyü kaydederse o alım
-- bir sonraki kayda dek eksik sayılabilir (iki cihaz aynı anda sınırın
-- altında kalıp yine çift alabilir: pencere "kayıt-teslim" arasıdır, saniyeler).
-- Ters yönde (alım iki kez sayılırsa) sonuç yanlış RED'dir: ücret kesilmez,
-- istemci eşitleyip yeniden dener; asla fazladan ücret değildir.
--
-- İstemci: anahtarı `shop_freeze_` ile başlayan alımlar bu işlevi çağırır;
-- işlev yoksa (PGRST202) eski işleve düşer (build 45 ve öncesi etkilenmez).
begin;

set local lock_timeout = '10s';

do $once$
begin
  if to_regprocedure('public.spend_streak_freeze(text)') is null
     or to_regclass('public.coin_transactions') is null
     or to_regclass('public.player_progress') is null then
    raise exception 'seri_ust_sinir: beklenen canlı nesneler eksik';
  end if;
  if to_regprocedure('public.spend_streak_freeze_capped(text)') is not null then
    raise exception 'seri_ust_sinir: yaratılacak işlev zaten var; göç durdu';
  end if;
end
$once$;

create temp table seri_mevcut (md5 text not null) on commit drop;
insert into seri_mevcut
select md5(pg_get_functiondef(to_regprocedure('public.spend_streak_freeze(text)')));

create function public.spend_streak_freeze_capped(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_cost constant integer := 50;
  v_cap constant integer := 2;
  v_key text;
  v_reason text;
  v_existing integer;
  v_balance integer;
  v_snapshot jsonb;
  v_saved_at timestamptz;
  v_streak jsonb;
  v_held integer := 0;
  v_unsynced integer;
  v_device record;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  v_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  if v_key is null or length(v_key) > 200 then
    return jsonb_build_object('success', false, 'error', 'invalid key');
  end if;
  v_reason := 'streak_freeze:' || v_key;

  -- `spend_streak_freeze` ile AYNI kilit: iki işlev birbirini de sıraya sokar.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  select coin_tx.amount into v_existing
  from public.coin_transactions coin_tx
  where coin_tx.player_id = v_uid and coin_tx.reason = v_reason
  limit 1;
  if found then
    select coalesce(sum(amount), 0)::integer into v_balance
    from public.coin_transactions where player_id = v_uid;
    return jsonb_build_object(
      'success', true, 'already_charged', true,
      'amount', abs(v_existing), 'balance', v_balance);
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  select pp.snapshot, pp.updated_at into v_snapshot, v_saved_at
  from public.player_progress pp where pp.player_id = v_uid;

  v_streak := case when jsonb_typeof(v_snapshot -> 'streak') = 'object'
                   then v_snapshot -> 'streak' else null end;
  if v_streak is not null then
    if jsonb_typeof(v_streak -> 'freezeBase') = 'number' then
      -- Defter modu: taban + kazanılan - harcanan (istemcideki balanceOf).
      v_held := greatest(0, (v_streak ->> 'freezeBase')::numeric::integer);
      if jsonb_typeof(v_streak -> 'freezeLedger') = 'object' then
        for v_device in
          select value from jsonb_each(v_streak -> 'freezeLedger')
        loop
          if jsonb_typeof(v_device.value) = 'array'
             and jsonb_array_length(v_device.value) >= 2 then
            v_held := v_held
              + coalesce((v_device.value ->> 0)::numeric::integer, 0)
              - coalesce((v_device.value ->> 1)::numeric::integer, 0);
          end if;
        end loop;
      end if;
    elsif jsonb_typeof(v_streak -> 'freeze') = 'number' then
      v_held := (v_streak ->> 'freeze')::numeric::integer;
    end if;
  end if;
  v_held := greatest(0, least(v_cap, v_held));

  -- Anlık görüntüden SONRA kesilmiş mağaza alımları (hakları henüz bulutta yok).
  select count(*)::integer into v_unsynced
  from public.coin_transactions ct
  where ct.player_id = v_uid
    and ct.reason like 'streak_freeze:shop\_freeze\_%'
    and ct.created_at > coalesce(v_saved_at, '-infinity'::timestamptz);

  if v_held + v_unsynced >= v_cap then
    return jsonb_build_object(
      'success', false, 'error', 'freeze_full',
      'held', v_held, 'unsynced', v_unsynced);
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions where player_id = v_uid;
  if v_balance < v_cost then
    return jsonb_build_object(
      'success', false, 'error', 'insufficient balance', 'balance', v_balance);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_cost, v_reason);

  return jsonb_build_object(
    'success', true, 'already_charged', false,
    'amount', v_cost, 'balance', v_balance - v_cost);
end;
$$;

revoke all on function public.spend_streak_freeze_capped(text) from public, anon;
grant execute on function public.spend_streak_freeze_capped(text) to authenticated;

do $son$
begin
  if exists (select 1 from seri_mevcut m
             where m.md5 <> md5(pg_get_functiondef(
               to_regprocedure('public.spend_streak_freeze(text)')))) then
    raise exception 'seri_ust_sinir: mevcut spend_streak_freeze gövdesi değişti';
  end if;
  if has_function_privilege('anon', 'public.spend_streak_freeze_capped(text)', 'execute')
     or has_function_privilege('public', 'public.spend_streak_freeze_capped(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.spend_streak_freeze_capped(text)', 'execute') then
    raise exception 'seri_ust_sinir: işlev yetkileri beklenen değil';
  end if;
  if not exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.spend_streak_freeze_capped(text)')
      and p.prosecdef and p.proconfig @> array['search_path=public']) then
    raise exception 'seri_ust_sinir: definer/search_path beklenen değil';
  end if;
end
$son$;

commit;
