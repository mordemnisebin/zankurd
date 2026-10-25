-- 2026-10-25: seri onarımında kırılma gününe bir gün saat dilimi toleransı.
--
-- NİÇİN: istemci (lib/src/data/streak_store.dart, repairOffer) kırılma gününü
-- cihazın YEREL takvimiyle "dün" olarak yollar; sunucu bugünü
-- Europe/Istanbul ile hesaplar ve `v_break < v_today - 1` ise
-- 'break day out of range' döner. İstanbul'un batısındaki oyuncuda (Almanya:
-- kışın 2, yazın 1 saat geride) yerel gece yarısından önceki saatlerde
-- İstanbul günü dönmüş olur; yerel "dün" = İstanbul "evvelsi gün" olduğundan
-- ücretli onarım haksız yere reddedilir. Alt sınır `v_today - 2` tüm saat
-- dilimlerini kapsar (UTC-12'de yerel tarih İstanbul'dan en çok 1 gün geride;
-- doğuda yerel "dün" en çok İstanbul bugünü olur, üst sınır yeterli).
--
-- NASIL: gövde CANLI tanımdan (pg_get_functiondef, 2026-10-25) türetildi;
-- yalnız tarih alt sınırı değişti. Ayda bir hak (month_key), aynı kırılma
-- gününün tekrarı ('already_repaired'), bakiye/kilit denetimleri aynen.
-- İmza aynı; CREATE OR REPLACE mevcut yetkileri korur.
--
-- Test: begin … rollback içinde derlenir; gövdede yeni sınırın bulunduğu
-- doğrulanır. Fonksiyon kullanıcı bağlamı (auth.uid) istediği için çağrılmaz.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-25_seri_onarimi_gun_toleransi.sql

begin;

CREATE OR REPLACE FUNCTION public.spend_streak_repair(p_month text, p_break_day text, p_premium boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_cost constant integer := 100;
  -- Ay ve gün SUNUCU saatiyle (Europe/Istanbul) belirlenir; p_month ve
  -- p_premium yok sayılır (imza uyumu için duruyor).
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_month text := to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM');
  v_break date;
  v_reason text;
  v_existing public.streak_repairs%rowtype;
  v_balance integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  v_reason := 'streak_repair:' || v_month;

  -- Aynı kullanıcının eşzamanlı iki denemesi sıraya girer.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Aynı kırılma günü için önceki onarım, AY FARK ETMEKSİZİN önce aranır:
  -- 31 Ekim'de yapılan onarım 1 Kasım'da tekrar çağrılırsa ay anahtarı
  -- değiştiği için aşağıdaki aylık arama onu bulamaz ve 100 zêr yeniden
  -- kesilirdi (2026-10-24 ikinci tur dış inceleme, iki model uyuştu).
  select * into v_existing
  from public.streak_repairs
  where player_id = v_uid
    and break_day::text = btrim(coalesce(p_break_day, ''))
  order by created_at desc nulls last
  limit 1;
  if found then
    select coalesce(sum(amount), 0)::integer into v_balance
    from public.coin_transactions where player_id = v_uid;
    return jsonb_build_object(
      'success', true, 'already_repaired', true,
      'paid', v_existing.paid, 'balance', v_balance);
  end if;

  -- Mevcut kayıt tarih denetimlerinden ÖNCE: aynı parametreyle geç tekrar
  -- (gece yarısı geçmiş olsa da) ücret kesmeden 'already_repaired' döner.
  select * into v_existing
  from public.streak_repairs
  where player_id = v_uid and month_key = v_month;
  if found then
    select coalesce(sum(amount), 0)::integer into v_balance
    from public.coin_transactions where player_id = v_uid;
    if v_existing.break_day::text = btrim(coalesce(p_break_day, '')) then
      return jsonb_build_object(
        'success', true, 'already_repaired', true,
        'paid', v_existing.paid, 'balance', v_balance);
    end if;
    return jsonb_build_object(
      'success', false, 'error', 'monthly_limit', 'balance', v_balance);
  end if;

  begin
    v_break := to_date(coalesce(p_break_day, ''), 'YYYY-MM-DD');
  exception when others then
    return jsonb_build_object('success', false, 'error', 'invalid break day');
  end;
  -- Kırılan (kaçırılan) gün dün ya da bugün: "son 24 saatte kırıldı" kuralı.
  -- Alt sınırda bir gün tolerans: istemci kırılma gününü cihazın yerel
  -- takvimiyle yollar; İstanbul'un batısındaki oyuncu (ör. Almanya'da yerel
  -- 22:00-24:00) İstanbul'da gün dönmüşken bir gün geride kalır (2026-10-25).
  if v_break < v_today - 2 or v_break > v_today then
    return jsonb_build_object('success', false, 'error', 'break day out of range');
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions where player_id = v_uid;

  if v_balance < v_cost then
    return jsonb_build_object(
      'success', false, 'error', 'insufficient balance', 'balance', v_balance);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_cost, v_reason);
  insert into public.streak_repairs (player_id, month_key, break_day, paid)
  values (v_uid, v_month, v_break, true);

  return jsonb_build_object(
    'success', true, 'already_repaired', false, 'paid', true,
    'amount', v_cost, 'balance', v_balance - v_cost);
end;
$function$;

commit;
