-- 2026-10-16: KALABALIK ODA — giriş ücreti İADE yardımcıları (+ ödül TODO'su).
--
-- NİÇİN: Özel odada giriş ücreti, odaya girerken coin_transactions'a 'room_entry_fee'
-- olarak düşer. host_left / stale_timeout / opponent_not_ready / forfeit ile biten
-- odalarda bu ücret ne ödül ne iade oluyordu (gerçek para kaybı hatası; hızlı
-- eşleşme odalarında ücret 0 olduğundan orada etkisizdi). Bu dosya iade
-- yardımcılarını ekler; `2026-10-16_kalabalik_oda.sql` onları leave_room,
-- cleanup_stale_rooms, mark_room_client_ready ve delete_my_account'tan çağırır.
-- BU DOSYA ÖNCE UYGULANIR (yalnız yeni fonksiyon + indeks ekler; mevcut hiçbir
-- fonksiyonu değiştirmez, tek başına zararsızdır).
--
-- TODO (BU DOSYADA YAPILMADI — başka dal claim_quiz_reward'un günlük tavanını
-- değiştiriyor, çakışmasın diye ayrı iş): claim_quiz_reward kalabalık odada
-- ödül havuzunu bölüşmeli. Gerekli değişiklik:
--   1. Odayı okurken is_custom ve max_players da seçilsin;
--      v_crowd := is_custom and max_players > 2.
--   2. Kalabalık odada çağıran oyuncunun room_players.left_at'i dolu ise
--      (ayrılan/düşen) havuzdan pay almaz: bahis payı 0 (taban ödül kuralı
--      aynen; zaten tüm soruları cevaplamadığı için 'answers_incomplete' döner).
--   3. Ücretli kalabalık odada (entry_fee > 0) havuz = entry_fee * (odada
--      room_players satırı sayısı; ayrılan/düşenlerin ücreti de havuza dahil).
--      Sıralama yalnız AKTİF (left_at is null) oyuncular arasında skora göre,
--      eşitlikte aynı rank (rank() window, 1,1,3 ...). Pay payı konumlara:
--      1. %50, 2. %30, 3. %20 (konum 4+ = 0). Aynı rank'taki k oyuncu, kapladığı
--      konumların paylarının toplamını eşit böler (aşağı yuvarla). Tüm
--      ödenenlerin toplamı ile havuz arasındaki KALAN (yuvarlama + dolmayan
--      konumlar) rank-1 grubundaki en küçük player_id'ye gider; böylece toplam
--      ödeme tam havuza eşit olur. Her oyuncu kendi talebinde yalnız kendi
--      payını hesaplar (tüm adımlar oda durumundan deterministik).
--   4. 2 kişilik oda (is_custom=false ya da max_players = 2): BUGÜNKÜ kural
--      aynen (kazanan entry_fee*2, berabere entry_fee iade, eşitlikte yok).
--   5. Bahis payı günlük tavana (v_daily_cap) SAYILMAZ (bugünkü gibi yalnız
--      taban ödül sayılır) ve aynı 'quiz_complete:room=<id>' işlemine yazılır.
--   6. Erken biten kalabalık oda (current_question_index < soru sayısı) zaten
--      'room_progress_incomplete' döner: havuz dağıtılmaz; kalanların ücretini
--      leave_room (crowd_room_member_leave) refund_room_entry_fees ile iade eder.
--
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-10-16_kalabalik_oda_odul.sql`

begin;

-- Sütun ana dosyada da eklenir; iade yardımcısı left_at'e baktığı için bu dosya
-- tek başına uygulansa da fonksiyon çalışsın diye burada da idempotent eklenir.
alter table public.room_players
  add column if not exists left_at timestamptz;

-- Aynı oyuncu aynı odanın ücretini iki kez geri alamasın (yarış durumuna karşı
-- ikinci savunma; birincisi yardımcıdaki ON CONFLICT DO NOTHING).
create unique index if not exists coin_transactions_room_refund_uidx
  on public.coin_transactions (player_id, reason)
  where reason like 'room_entry_refund:%';

-- Tek oyuncunun giriş ücretini iade eder. Dönüş: iade edilen jeton (0 = ücret
-- yok / oyuncu odada değil / daha önce iade edilmiş). İÇ YARDIMCI: istemciye açık
-- değil; çağıran oda kilidini tutar.
create or replace function public.refund_room_entry_fee(
  p_room_id uuid,
  p_player_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_fee integer;
  v_reason text;
  v_inserted integer;
begin
  select coalesce(r.entry_fee, 0) into v_fee
  from public.rooms r
  where r.id = p_room_id;

  if not found or v_fee <= 0 then
    return 0;
  end if;

  -- Yalnız ücreti gerçekten ödemiş olan üye (ücret girişte düşer).
  if not exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = p_player_id
  ) then
    return 0;
  end if;

  v_reason := 'room_entry_refund:room=' || p_room_id::text
    || ':player=' || p_player_id::text;

  insert into public.coin_transactions (player_id, amount, reason)
  values (p_player_id, v_fee, v_reason)
  on conflict (player_id, reason) where reason like 'room_entry_refund:%'
  do nothing;

  get diagnostics v_inserted = row_count;

  return case when v_inserted > 0 then v_fee else 0 end;
end;
$function$;

-- Odadaki üyelerin giriş ücretini iade eder.
--   p_except       : bu oyuncu hariç (ör. oyunu terk eden: kaybeder).
--   p_include_left : false (varsayılan) = oyundan ayrılan/düşen (left_at dolu)
--                    oyuncular iade almaz; true = herkes (oyun hiç başlamadı).
-- Dönüş: toplam iade edilen jeton. İÇ YARDIMCI: istemciye açık değil.
create or replace function public.refund_room_entry_fees(
  p_room_id uuid,
  p_except uuid default null,
  p_include_left boolean default false
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_member record;
  v_total integer := 0;
begin
  for v_member in
    select rp.player_id
    from public.room_players rp
    where rp.room_id = p_room_id
      and (p_except is null or rp.player_id <> p_except)
      and (p_include_left or rp.left_at is null)
    order by rp.player_id
  loop
    v_total := v_total + public.refund_room_entry_fee(p_room_id, v_member.player_id);
  end loop;

  return v_total;
end;
$function$;

revoke all on function public.refund_room_entry_fee(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.refund_room_entry_fee(uuid, uuid)
  to service_role;
revoke all on function public.refund_room_entry_fees(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.refund_room_entry_fees(uuid, uuid, boolean)
  to service_role;

commit;
