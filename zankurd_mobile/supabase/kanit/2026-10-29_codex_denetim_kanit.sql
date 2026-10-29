-- Kanıt betiği: 2026-10-29_codex_denetim_duzeltmeleri.sql (R1 iade, R2 katılım, R3 soru).
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `gozlenen` ilk çalıştırmada beklenen_once, ikincide beklenen_sonra ile
-- eşleşmelidir (durum: ONCE-DURUMU / SONRA-OK / BEKLENMEDIK). Bir adım hata
-- verirse satırda 'HATA: ...' görünür (diğer adımlar sürer).
--
--   supabase db query --linked -f supabase/kanit/2026-10-29_codex_denetim_kanit.sql
--
-- Canlı odası olmayan üç gerçek profil seçilir (ev sahibi, iade misafiri,
-- bakiye misafiri). Oda, üyelik ve jeton satırlarını bu işlem kurar,
-- rollback hepsini siler. Jeton bakiyesi coin_transactions toplamıdır.
--
-- R1 (hata #3): ücretli lobiye gir→çık→tekrar gir→çık. Net bakiye değişimi
--     ÖNCE -10 (ikinci iade çakışıp atlanır), SONRA 0.
-- R2 (hata #10): son jetonuyla katılan oyuncunun tekrar katılması. ÖNCE
--     'Insufficient coins' istisnası, SONRA mevcut odayı döndürür.
-- R3 (içerik #10): hat_0094 (Mitanni başkenti) ÖNCE onaylı, SONRA değil.
--     'yok' görünürse hat_0094 sunucuya hiç senkronlanmamış demektir
--     (durum BEKLENMEDIK ama zararsız: kapatılacak bir şey yok).
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id
from (
  select pr.id
  from public.profiles pr
  where not exists (
    select 1
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where rp.player_id = pr.id and r.status in ('lobby', 'active')
  )
  order by pr.id
  limit 3
) p;

do $$
begin
  if (select count(*) from _p) < 3 then
    raise exception 'kanit: canlı odası olmayan en az 3 profil gerekli';
  end if;
end $$;

create temp table _r (ad text primary key, id uuid, code text) on commit drop;

-- Ücretli (10 jeton) özel lobi; ev sahibi p1.
do $$
declare
  h uuid := (select id from _p where n = 1);
  v uuid;
  v_code text := 'K' || upper(substr(md5(random()::text), 1, 5));
begin
  insert into public.rooms (code, host_id, status, entry_fee, is_custom, max_players)
  values (v_code, h, 'lobby', 10, true, 4)
  returning id into v;
  insert into public.room_players (room_id, player_id) values (v, h);
  insert into _r values ('ucretli', v, v_code);
exception when others then
  insert into _kanit values (1, 'R kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- R1
do $$
declare
  g uuid := (select id from _p where n = 2);
  v_room uuid := (select id from _r where ad = 'ucretli');
  v_code text := (select code from _r where ad = 'ucretli');
  b0 integer; b1 integer;
begin
  -- Yeterli bakiye: 100 jeton tohumu.
  insert into public.coin_transactions (player_id, amount, reason)
  values (g, 100, 'kanit_tohum');
  select coalesce(sum(amount), 0)::integer into b0
  from public.coin_transactions where player_id = g;
  perform set_config('request.jwt.claims', json_build_object('sub', g)::text, true);
  perform public.join_room_by_code(v_code);
  perform public.leave_room(v_room);
  -- Aynı lobiye ikinci giriş ve çıkış (joined_at farklı olsun diye bekle).
  perform pg_sleep(0.01);
  perform public.join_room_by_code(v_code);
  -- Tek işlemde now() sabit: ikinci katılımın zamanını gerçek saatle ayır
  -- (canlıda her RPC ayrı işlem, joined_at zaten farklı olur).
  update public.room_players set joined_at = clock_timestamp()
   where room_id = v_room and player_id = g;
  perform public.leave_room(v_room);
  select coalesce(sum(amount), 0)::integer into b1
  from public.coin_transactions where player_id = g;
  insert into _kanit values (2, 'R1 gir-çık-gir-çık net bakiye değişimi',
    '-10', '0', (b1 - b0)::text);
exception when others then
  insert into _kanit values (2, 'R1', '-10', '0', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- R2
do $$
declare
  g uuid := (select id from _p where n = 3);
  v_code text := (select code from _r where ad = 'ucretli');
  v_room uuid := (select id from _r where ad = 'ucretli');
  c integer; v_res text; v_json json;
begin
  perform set_config('request.jwt.claims', '{}', true);
  select coalesce(sum(amount), 0)::integer into c
  from public.coin_transactions where player_id = g;
  -- Bakiyeyi TAM 10 jetona getir (yalnız bu işlemde).
  insert into public.coin_transactions (player_id, amount, reason)
  values (g, 10 - c, 'kanit_tohum');
  perform set_config('request.jwt.claims', json_build_object('sub', g)::text, true);
  perform public.join_room_by_code(v_code);       -- bakiye 0'a iner
  begin
    v_json := public.join_room_by_code(v_code);   -- yanıtı kaybolan katılımın tekrarı
    v_res := case when (v_json ->> 'room_id')::uuid = v_room
                  then 'mevcut_oda_doner' else 'yanlis_oda' end;
  exception when others then
    v_res := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (3, 'R2 son jetonla katılanın tekrar katılması',
    'HATA: Insufficient coins for room entry fee', 'mevcut_oda_doner', v_res);
exception when others then
  insert into _kanit values (3, 'R2', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- R3
insert into _kanit
select 4, 'R3 hat_0094 (Mitanni başkenti) onaylı mı', 'true', 'false',
       coalesce(
         (select q.is_approved::text from public.questions q
          where q.id = 'c593666a-a8fe-5f3d-a011-c038192c6237'),
         'yok');

-- ------------------------------------------------- yetki
insert into _kanit
select 10, 'Y1 authenticated refund_room_entry_fee çalıştırabilir mi', 'false', 'false',
       has_function_privilege('authenticated', 'public.refund_room_entry_fee(uuid, uuid)', 'execute')::text;
insert into _kanit
select 11, 'Y2 anon join_room_by_code çalıştırabilir mi', 'false', 'false',
       has_function_privilege('anon', 'public.join_room_by_code(text)', 'execute')::text;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
