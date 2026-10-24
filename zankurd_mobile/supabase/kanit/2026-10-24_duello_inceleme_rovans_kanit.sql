-- Kanıt betiği: 2026-10-24_duello_inceleme_rovans.sql — `get_async_duel_review`.
-- Bulgular: 1 katılımcı bitmiş düelloyu görür (iki taraf da) · 2 yabancı
-- reddedilir · 3 süren düello reddedilir (açık, eşleşmiş) · 4 engelli çiftte
-- rakip kimliği/adı/cevapları gizli, kendi incelemem açık · 5 hükmen düello
-- (kaybeden cevapsız) · 6 rövanş uygunluğu (arkadaş / arkadaş değil) ·
-- 7 anon çalıştıramaz, authenticated çalıştırır · 8 kontrol: rövanş
-- `create_async_duel_challenge(null, arkadaş)` davetli kaydeder, engelli
-- arkadaşa 'Not a friend' (mevcut davranış; göçle değişmez).
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `durum`: SONRA-OK (gozlenen = beklenen_sonra), ONCE-DURUMU (gozlenen =
-- beklenen_once; göç henüz yok), BEKLENMEDIK (ikisi de değil). Fonksiyon
-- dinamik SQL ile çağrılır: göç yokken betik hata vermez, 'RPC yok' yazar.
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_duello_inceleme_rovans_kanit.sql
--
-- Hiçbir auth.users satırı eklenmez: gerçek profillerden açık/eşleşmiş
-- düellosu olmayan dördü seçilir (adı dolu); kimlik
-- set_config('request.jwt.claims') ile taklit edilir. Düello, cevap, arkadaş
-- ve engel satırlarını bu işlem kurar, rollback hepsini siler.
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid) on commit drop;
create temp table _d (k text, id uuid) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id
from (
  select pr.id
  from public.profiles pr
  where nullif(btrim(coalesce(pr.display_name, '')), '') is not null
    and not exists (
      select 1 from public.async_duels d
      where d.status in ('open', 'matched')
        and pr.id in (d.creator_id, d.opponent_id, d.invited_id)
    )
    and not exists (
      select 1 from public.blocked_users b
      where pr.id in (b.blocker_id, b.blocked_id)
    )
  order by pr.id
  limit 4
) p;

do $$
begin
  if (select count(*) from _p) < 4 then
    raise exception 'kanit: açık düellosu/engeli olmayan, adı dolu en az 4 profil gerekli';
  end if;
end $$;

create function pg_temp.uid(p_n int) returns uuid
language sql as $f$ select id from _p where n = p_n $f$;

-- Sorulu düello satırı; p_status 'completed' ise completed_at dolar.
create function pg_temp.duello(
  p_creator uuid, p_opp uuid, p_status text
) returns uuid
language plpgsql as $f$
declare v_q uuid[]; v_id uuid;
begin
  select array_agg(id) into v_q from (
    select id from public.questions where is_approved = true order by id limit 7
  ) q;
  insert into public.async_duels (
    question_ids, creator_id, opponent_id, status,
    matched_at, created_at, completed_at, expires_at
  ) values (
    v_q, p_creator, p_opp, p_status,
    case when p_opp is not null then now() - interval '2 hours' end,
    now() - interval '3 hours',
    case when p_status = 'completed' then now() - interval '1 hour' end,
    now() + interval '20 hours'
  ) returning id into v_id;
  return v_id;
end $f$;

-- p_n_cevap soruyu cevaplatır: ilk p_n_dogru doğru, kalanı TIMEOUT (yanlış).
create function pg_temp.cevapla(
  p_duel uuid, p_player uuid, p_n_cevap int, p_n_dogru int
) returns void
language plpgsql as $f$
declare i int; v_opt text;
begin
  for i in 0..p_n_cevap - 1 loop
    select q.correct_option into v_opt from public.questions q
    where q.id = (select question_ids[i + 1] from public.async_duels where id = p_duel);
    insert into public.async_duel_answers
      (duel_id, player_id, question_index, choice, is_correct, response_ms)
    values (p_duel, p_player, i,
            case when i < p_n_dogru then v_opt else 'TIMEOUT' end,
            i < p_n_dogru, 1000 + i * 100);
  end loop;
  if p_n_cevap >= 7 then
    insert into public.async_duel_results (duel_id, player_id, correct_count, total_ms)
    values (p_duel, p_player, p_n_dogru, 7000);
  end if;
end $f$;

-- Çağıran p_user iken get_async_duel_review(p_duel) özeti ya da hata metni.
create function pg_temp.gor(p_user uuid, p_duel uuid) returns text
language plpgsql as $f$
declare v jsonb;
begin
  if to_regprocedure('public.get_async_duel_review(uuid)') is null then
    return 'RPC yok';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
  begin
    execute 'select public.get_async_duel_review($1)' into v using p_duel;
  exception when others then
    return sqlerrm;
  end;
  return 'q=' || jsonb_array_length(v->'questions')
    || ',my=' || (select count(*) from jsonb_array_elements(v->'questions') e
                  where jsonb_typeof(e->'my') = 'object')
    || ',opp=' || (select count(*) from jsonb_array_elements(v->'questions') e
                   where jsonb_typeof(e->'opp') = 'object')
    || ',corr=' || (select count(*) from jsonb_array_elements(v->'questions') e
                    where e->>'correct_option' in ('A', 'B', 'C', 'D'))
    || ',opp_id=' || case when jsonb_typeof(v->'opponent_id') = 'string' then 'var' else 'null' end
    || ',name=' || case when jsonb_typeof(v->'opponent_name') = 'string' then 'var' else 'null' end
    || ',blocked=' || (v->>'opponent_blocked')
    || ',forfeit=' || (v->>'forfeit')
    || ',rematch=' || (v->>'can_rematch');
end $f$;

-- ------------------------------------------------------------ kurulum
-- Kullanıcılar: 1 yaratıcı, 2 rakip (1'in arkadaşı), 3 yabancı, 4 rakip
-- (arkadaş DEĞİL).
do $$
declare
  u1 uuid := pg_temp.uid(1); u2 uuid := pg_temp.uid(2); u4 uuid := pg_temp.uid(4);
  x uuid;
begin
  insert into public.friends (user_id, friend_id, friend_name)
  values (u1, u2, 'kanit-2'), (u2, u1, 'kanit-1');

  x := pg_temp.duello(u1, u2, 'completed');
  perform pg_temp.cevapla(x, u1, 7, 5);
  perform pg_temp.cevapla(x, u2, 7, 3);
  insert into _d values ('bitti', x);

  x := pg_temp.duello(u1, null, 'open');
  perform pg_temp.cevapla(x, u1, 7, 4);
  insert into _d values ('acik', x);

  x := pg_temp.duello(u1, u2, 'matched');
  perform pg_temp.cevapla(x, u1, 7, 4);
  perform pg_temp.cevapla(x, u2, 2, 2);
  insert into _d values ('esles', x);

  -- hükmen: yaratıcı bitirdi, rakip (2) hiç cevaplamadı.
  x := pg_temp.duello(u1, u2, 'expired');
  perform pg_temp.cevapla(x, u1, 7, 6);
  execute 'update public.async_duels set forfeit_loser_id = $2 where id = $1'
    using x, u2;
  insert into _d values ('hukmen', x);

  -- arkadaş olmayan rakiple bitmiş düello (1 ve 4).
  x := pg_temp.duello(u1, u4, 'completed');
  perform pg_temp.cevapla(x, u1, 7, 5);
  perform pg_temp.cevapla(x, u4, 7, 2);
  insert into _d values ('arkadassiz', x);
exception when others then
  insert into _kanit values (0, 'kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ 1..3
do $$
declare
  u1 uuid := pg_temp.uid(1); u2 uuid := pg_temp.uid(2); u3 uuid := pg_temp.uid(3);
  x_bitti uuid := (select id from _d where k = 'bitti');
  x_acik uuid := (select id from _d where k = 'acik');
  x_esles uuid := (select id from _d where k = 'esles');
begin
  insert into _kanit values (1, '(1a) yaratıcı bitmiş düelloyu görür',
    'RPC yok', 'q=7,my=7,opp=7,corr=7,opp_id=var,name=var,blocked=false,forfeit=false,rematch=true',
    pg_temp.gor(u1, x_bitti));
  insert into _kanit values (2, '(1b) rakip de aynı düelloyu görür',
    'RPC yok', 'q=7,my=7,opp=7,corr=7,opp_id=var,name=var,blocked=false,forfeit=false,rematch=true',
    pg_temp.gor(u2, x_bitti));
  insert into _kanit values (3, '(2) katılımcı olmayan reddedilir',
    'RPC yok', 'Not a duel player', pg_temp.gor(u3, x_bitti));
  insert into _kanit values (4, '(3a) açık (rakipsiz) düello reddedilir',
    'RPC yok', 'Duel not finished', pg_temp.gor(u1, x_acik));
  insert into _kanit values (5, '(3b) eşleşmiş, süren düello: rakip de reddedilir',
    'RPC yok', 'Duel not finished', pg_temp.gor(u2, x_esles));
  insert into _kanit values (6, '(3c) eşleşmiş, süren düello: yaratıcı da reddedilir',
    'RPC yok', 'Duel not finished', pg_temp.gor(u1, x_esles));
exception when others then
  insert into _kanit values (1, '(1..3)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ 5, 6
do $$
declare
  u1 uuid := pg_temp.uid(1); u2 uuid := pg_temp.uid(2); u4 uuid := pg_temp.uid(4);
  x_hukmen uuid := (select id from _d where k = 'hukmen');
  x_ark uuid := (select id from _d where k = 'arkadassiz');
begin
  insert into _kanit values (7, '(5) hükmen düello: kaybeden cevapsız',
    'RPC yok', 'q=7,my=7,opp=0,corr=7,opp_id=var,name=var,blocked=false,forfeit=true,rematch=true',
    pg_temp.gor(u1, x_hukmen));
  insert into _kanit values (8, '(5b) hükmen kaybeden kendi (boş) incelemesini açar',
    'RPC yok', 'q=7,my=0,opp=7,corr=7,opp_id=var,name=var,blocked=false,forfeit=true,rematch=true',
    pg_temp.gor(u2, x_hukmen));
  insert into _kanit values (9, '(6) arkadaş olmayan rakip: rövanş kapalı',
    'RPC yok', 'q=7,my=7,opp=7,corr=7,opp_id=var,name=var,blocked=false,forfeit=false,rematch=false',
    pg_temp.gor(u1, x_ark));
  insert into _kanit values (10, '(6b) arkadaş olmayan rakip kendi tarafından da kapalı',
    'RPC yok', 'q=7,my=7,opp=7,corr=7,opp_id=var,name=var,blocked=false,forfeit=false,rematch=false',
    pg_temp.gor(u4, x_ark));
exception when others then
  insert into _kanit values (7, '(5,6)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ 8a (kontrol)
-- Rövanş, engel EKLENMEDEN önce: arkadaşa meydan okuma davetliyi kaydeder.
do $$
declare
  u1 uuid := pg_temp.uid(1); u2 uuid := pg_temp.uid(2);
  v jsonb; r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u1)::text, true);
  begin
    v := public.create_async_duel_challenge(null, u2);
    r := case when exists (
      select 1 from public.async_duels
      where id = (v->>'duel_id')::uuid and invited_id = u2 and creator_id = u1
    ) then 'davetli kaydedildi' else 'davetli yok' end;
  exception when others then r := sqlerrm;
  end;
  insert into _kanit values (11, '(8a) kontrol: rövanş create_async_duel_challenge(arkadaş)',
    'davetli kaydedildi', 'davetli kaydedildi', r);
exception when others then
  insert into _kanit values (11, '(8a)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ 4 + 8b (engel)
-- 1, 2'yi engeller. İki yönde de rakip kimliği/adı/cevapları gizli, kendi
-- incelemem açık, rövanş kapalı. Mevcut kural: engelliye meydan okuma
-- 'Not a friend'.
do $$
declare
  u1 uuid := pg_temp.uid(1); u2 uuid := pg_temp.uid(2);
  x_bitti uuid := (select id from _d where k = 'bitti');
  r text;
begin
  insert into public.blocked_users (blocker_id, blocked_id) values (u1, u2);

  insert into _kanit values (12, '(4a) engelleyen: rakip kimliği/adı/cevapları gizli, kendi inceleme açık',
    'RPC yok', 'q=7,my=7,opp=0,corr=7,opp_id=null,name=null,blocked=true,forfeit=false,rematch=false',
    pg_temp.gor(u1, x_bitti));
  insert into _kanit values (13, '(4b) engellenen: aynı gizleme',
    'RPC yok', 'q=7,my=7,opp=0,corr=7,opp_id=null,name=null,blocked=true,forfeit=false,rematch=false',
    pg_temp.gor(u2, x_bitti));

  perform set_config('request.jwt.claims', json_build_object('sub', u1)::text, true);
  begin
    perform public.create_async_duel_challenge(null, u2);
    r := 'kabul edildi';
  exception when others then r := sqlerrm;
  end;
  insert into _kanit values (14, '(8b) kontrol: engelli arkadaşa meydan okuma',
    'Not a friend', 'Not a friend', r);
exception when others then
  insert into _kanit values (12, '(4)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ 7
insert into _kanit
select 15, '(7a) anon çalıştıramaz', 'RPC yok', 'false',
  case when to_regprocedure('public.get_async_duel_review(uuid)') is null
       then 'RPC yok'
       else has_function_privilege('anon', 'public.get_async_duel_review(uuid)', 'execute')::text end;
insert into _kanit
select 16, '(7b) authenticated çalıştırır', 'RPC yok', 'true',
  case when to_regprocedure('public.get_async_duel_review(uuid)') is null
       then 'RPC yok'
       else has_function_privilege('authenticated', 'public.get_async_duel_review(uuid)', 'execute')::text end;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
