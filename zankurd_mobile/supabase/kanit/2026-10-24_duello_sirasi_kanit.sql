-- Kanıt betiği: 2026-10-24_duello_sirasi.sql (+ _cron.sql), bulgular a..i.
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `durum`: SONRA-OK (gozlenen = beklenen_sonra), ONCE-DURUMU (gozlenen =
-- beklenen_once; göç henüz yok), BEKLENMEDIK (ikisi de değil). Bir adım hata
-- verirse satırda 'HATA: ...' görünür (diğer adımlar sürer; hatalı adım kendi
-- savepoint'inde geri alınır). Yeni sütun yoksa ilgili gözlem 'kolon yok'
-- yazar, hata vermez (dinamik SQL).
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_duello_sirasi_kanit.sql
--
-- Hiçbir auth.users satırı eklenmez: gerçek profillerden açık/eşleşmiş
-- düellosu olmayan altısı seçilir; kimlik set_config('request.jwt.claims')
-- ile taklit edilir. Düello, sonuç ve cevap satırlarını bu işlem kurar,
-- rollback hepsini siler.
-- UYARI: expire_async_duels() işlem içinde BÜTÜN canlı süresi geçmiş
-- düellolara da dokunur (ve onlar için push_outbox satırı yazar); hepsi
-- rollback ile geri alınır. Betik birkaç saniyede biter. Push sayımı yalnız
-- bu işlemde (created_at >= now()) ve yalnız seçilen altı profil için yapılır.
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid) on commit drop;
create temp table _f (k text, id uuid) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id
from (
  select pr.id
  from public.profiles pr
  where not exists (
    select 1 from public.async_duels d
    where d.status in ('open', 'matched')
      and pr.id in (d.creator_id, d.opponent_id, d.invited_id)
  )
  order by pr.id
  limit 6
) p;

do $$
begin
  if (select count(*) from _p) < 6 then
    raise exception 'kanit: açık düellosu olmayan en az 6 profil gerekli';
  end if;
end $$;

-- Yeni sütun yoksa 'kolon yok' (HATA değil).
create function pg_temp.kaybeden(p_duel uuid) returns text
language plpgsql as $f$
declare v text;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'async_duels'
      and column_name = 'forfeit_loser_id'
  ) then
    return 'kolon yok';
  end if;
  execute 'select coalesce(forfeit_loser_id::text, ''null'') from public.async_duels where id = $1'
    into v using p_duel;
  return v;
end $f$;

-- Kullanıcı numarası -> 'a'/'b'... etiketi için kısa yol.
create function pg_temp.uid(p_n int) returns uuid
language sql as $f$ select id from _p where n = p_n $f$;

-- Sorulu düello satırı kurar; kimlik döner.
create function pg_temp.duello(
  p_creator uuid, p_opp uuid, p_invited uuid, p_status text,
  p_created interval, p_expires interval, p_code text default null
) returns uuid
language plpgsql as $f$
declare v_q uuid[]; v_id uuid;
begin
  select array_agg(id) into v_q from (
    select id from public.questions where is_approved = true limit 7
  ) q;
  insert into public.async_duels (
    question_ids, creator_id, opponent_id, invited_id, status,
    matched_at, created_at, expires_at, challenge_code
  ) values (
    v_q, p_creator, p_opp, p_invited, p_status,
    case when p_opp is not null then now() - p_created else null end,
    now() - p_created, now() + p_expires, p_code
  ) returning id into v_id;
  return v_id;
end $f$;

create function pg_temp.bitir(p_duel uuid, p_player uuid) returns void
language sql as $f$
  insert into public.async_duel_results (duel_id, player_id, correct_count, total_ms)
  values (p_duel, p_player, 5, 60000)
$f$;

-- ---------------------------------------------------------------- (a)
-- Yeni düello (create_async_duel_challenge, kullanıcı 5): pencere 24 saat.
do $$
declare
  u uuid := pg_temp.uid(5);
  v jsonb; v_h numeric;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  v := public.create_async_duel_challenge(null, null);
  select round(extract(epoch from (expires_at - created_at)) / 3600, 2)
  into v_h from public.async_duels where id = (v->>'duel_id')::uuid;
  insert into _kanit values (1, '(a) yeni düello expires_at - created_at (saat)',
    '48.00', '24.00', v_h::text);
exception when others then
  insert into _kanit values (1, '(a)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- kurulum
-- Kullanıcılar: 1 = yaratıcı, 2 = girmiş rakip (bitirmedi), 3 = kabul
-- etmemiş davetli, 4 = hatırlatılacak rakip, 5/6 = (a)/(g).
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2);
  c uuid := pg_temp.uid(3); d uuid := pg_temp.uid(4);
  x uuid;
begin
  -- (b)/(f): eşleşmiş, yaratıcı bitirdi, rakip bitirmedi, süre geçti.
  x := pg_temp.duello(a, b, null, 'matched', interval '25 hours', interval '-1 minute');
  perform pg_temp.bitir(x, a);
  insert into _f values ('forfeit', x);
  -- (c): kabul edilmemiş arkadaş daveti, süre geçti.
  x := pg_temp.duello(a, null, c, 'open', interval '25 hours', interval '-1 minute', 'DKANTXPA2');
  perform pg_temp.bitir(x, a);
  insert into _f values ('davet', x);
  -- (d): rakipsiz rastgele düello, süre geçti.
  x := pg_temp.duello(a, null, null, 'open', interval '25 hours', interval '-1 minute');
  perform pg_temp.bitir(x, a);
  insert into _f values ('rakipsiz', x);
  -- (e): 3 saat kaldı, rakip (4) bitirmedi.
  x := pg_temp.duello(a, d, null, 'matched', interval '21 hours', interval '3 hours');
  perform pg_temp.bitir(x, a);
  insert into _f values ('hatirlat', x);
exception when others then
  insert into _kanit values (0, 'kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- expire #1
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2);
  c uuid := pg_temp.uid(3); d uuid := pg_temp.uid(4);
  v_forfeit uuid := (select id from _f where k = 'forfeit');
  v_davet uuid := (select id from _f where k = 'davet');
  v_rakipsiz uuid := (select id from _f where k = 'rakipsiz');
  v_hat uuid := (select id from _f where k = 'hatirlat');
  v_row jsonb; v_n int; s text;
begin
  perform public.expire_async_duels();

  -- (b) kaybeden = bitirmeyen rakip; kazanan için outcome win.
  s := pg_temp.kaybeden(v_forfeit);
  insert into _kanit values (2, '(b1) forfeit_loser_id = bitirmeyen rakip',
    'kolon yok', 'bitirmeyen',
    case when s = b::text then 'bitirmeyen' else s end);

  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  select r into v_row from public.list_my_async_duels() r
  where r->>'duel_id' = v_forfeit::text;
  insert into _kanit values (3, '(b2) kazanan (bitiren) için list outcome',
    'null', 'win', coalesce(v_row->>'outcome', 'null'));

  -- (c) kabul edilmemiş davet: hükmen yok, düz expired.
  insert into _kanit values (4, '(c) kabul edilmemiş davet: durum / kaybeden',
    'expired/kolon yok', 'expired/null',
    (select status from public.async_duels where id = v_davet)
      || '/' || pg_temp.kaybeden(v_davet));

  -- (d) rakipsiz rastgele düello: düz expired.
  insert into _kanit values (5, '(d) rakipsiz rastgele düello: durum / kaybeden',
    'expired/kolon yok', 'expired/null',
    (select status from public.async_duels where id = v_rakipsiz)
      || '/' || pg_temp.kaybeden(v_rakipsiz));

  -- (e1) ≤4 sa kala bitirmemiş rakibe (4) async_duel_turn.
  select count(*) into v_n from public.push_outbox
  where to_user_id = d and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (6, '(e1) hatırlatma satırı (kullanıcı 4, ilk expire)',
    '0', '1', v_n::text);
  -- Bitirmiş yaratıcıya hatırlatma gitmez (kontrol).
  select count(*) into v_n from public.push_outbox
  where to_user_id = a and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (7, '(e0) bitirmiş yaratıcıya hatırlatma yok (kontrol)',
    '0', '0', v_n::text);

  -- (f) hükmen sonuç iki tarafa async_duel_result.
  select count(*) into v_n from public.push_outbox
  where to_user_id = a and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (8, '(f1) kazanana async_duel_result', '0', '1', v_n::text);
  select count(*) into v_n from public.push_outbox
  where to_user_id = b and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (9, '(f2) kaybedene async_duel_result', '0', '1', v_n::text);
  -- Davetliye (3) hükmen bildirimi gitmez (kontrol).
  select count(*) into v_n from public.push_outbox
  where to_user_id = c and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (10, '(f0) kabul etmemiş davetliye sonuç bildirimi yok (kontrol)',
    '0', '0', v_n::text);

  -- (h) liste alanları.
  insert into _kanit values (11, '(h) list_my_async_duels expires_at / forfeit anahtarları',
    'expires_at=yok,forfeit=yok', 'expires_at=var,forfeit=var',
    'expires_at=' || case when v_row ? 'expires_at' then 'var' else 'yok' end
      || ',forfeit=' || case when v_row ? 'forfeit' then 'var' else 'yok' end);
exception when others then
  insert into _kanit values (2, '(b..h)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- expire #2
do $$
declare
  d uuid := pg_temp.uid(4); v_n int;
begin
  perform public.expire_async_duels();
  select count(*) into v_n from public.push_outbox
  where to_user_id = d and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (12, '(e2) ikinci expire sonrası hatırlatma YİNELENMEZ (toplam)',
    '0', '1', v_n::text);
exception when others then
  insert into _kanit values (12, '(e2)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (g)
-- Devam adaleti: rakip (6) 4 saat önce eşleşti, ilk soruyu 3 saat önce
-- cevapladı; şimdi devam edip ikinciyi cevaplar. Eski: ölçülen süre 20 sn
-- tavanı; yeni: dönüş anından ölçülür (küçük).
do $$
declare
  a uuid := pg_temp.uid(1); u uuid := pg_temp.uid(6);
  x uuid; v_ms int;
begin
  x := pg_temp.duello(a, u, null, 'matched', interval '4 hours', interval '20 hours');
  perform pg_temp.bitir(x, a);
  insert into public.async_duel_answers (duel_id, player_id, question_index,
                                         choice, is_correct, response_ms, answered_at)
  values (x, u, 0, 'A', false, 5000, now() - interval '3 hours');
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  perform public.resume_my_async_duel(x);
  perform public.answer_async_duel(x, 1, 'A', 0);
  select response_ms into v_ms from public.async_duel_answers
  where duel_id = x and player_id = u and question_index = 1;
  insert into _kanit values (13, '(g) 3 sa sonra devam: sonraki cevabın ölçülen süresi',
    'tavan(20000)', 'kucuk',
    case when v_ms >= 20000 then 'tavan(20000)' else 'kucuk' end);
exception when others then
  insert into _kanit values (13, '(g)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (i)
insert into _kanit
select 14, '(i) expire-async-duels cron takvimi', '37 * * * *', '*/10 * * * *',
       coalesce((select schedule from cron.job where jobname = 'expire-async-duels'),
                'iş yok');

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
