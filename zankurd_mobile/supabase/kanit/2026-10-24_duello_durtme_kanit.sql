-- Kanıt betiği: 2026-10-24_duello_durtme.sql, bulgular a..k:
-- a izinli dürtme 1 push · b 12 saat içinde ikinci dürtme reddi · c reddedilen
-- dürtme ikinci push yazmadı · d katılımcı olmayan reddi · e engelli çift
-- reddi · f rakibi bitirmiş düello reddi · g kendi turunu bitirmemiş reddi ·
-- h 12 saat geçince yeniden dürtme · i list_my_async_duels `my_nudged_at` ·
-- j list_my_recent_matches kazanılan düelloyu verir · k get_my_records
-- galibiyeti sayar · l aynı alıcıya FARKLI düellolardan 4. dürtme reddi ·
-- m en uzun doğru serisi (8 doğru + 1 yanlış + 2 doğru -> 8) · n kalabalık
-- odada hükmen: terk eden dışındakilere otomatik 'win' yok (puan sırası).
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `durum`: SONRA-OK (gozlenen = beklenen_sonra), ONCE-DURUMU (gozlenen =
-- beklenen_once; göç henüz yok), BEKLENMEDIK (ikisi de değil). RPC henüz
-- yoksa gözlem 'RPC yok' yazar (HATA değil); başka bir adım hata verirse
-- satırda 'HATA: ...' görünür (diğer adımlar sürer).
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_duello_durtme_kanit.sql
--
-- Hiçbir auth.users satırı eklenmez: gerçek profillerden açık/eşleşmiş
-- düellosu olmayan beşi seçilir; kimlik set_config('request.jwt.claims')
-- ile taklit edilir. Düello, sonuç, engel ve dürtme satırlarını bu işlem
-- kurar, rollback hepsini siler. Push sayımı yalnız bu işlemde yazılan,
-- from_user_id'si seçilen profil olan satırları sayar.
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
    select 1 from public.async_duels d
    where d.status in ('open', 'matched')
      and pr.id in (d.creator_id, d.opponent_id, d.invited_id)
  )
  order by pr.id
  limit 5
) p;

do $$
begin
  if (select count(*) from _p) < 5 then
    raise exception 'kanit: açık düellosu olmayan en az 5 profil gerekli';
  end if;
end $$;

create function pg_temp.uid(p_n int) returns uuid
language sql as $f$ select id from _p where n = p_n $f$;

-- Sorulu düello satırı kurar; kimlik döner.
create function pg_temp.duello(
  p_creator uuid, p_opp uuid, p_status text
) returns uuid
language plpgsql as $f$
declare v_q uuid[]; v_id uuid;
begin
  select array_agg(id) into v_q from (
    select id from public.questions where is_approved = true limit 7
  ) q;
  insert into public.async_duels (
    question_ids, creator_id, opponent_id, status, matched_at,
    created_at, expires_at
  ) values (
    v_q, p_creator, p_opp, p_status,
    case when p_opp is not null then now() - interval '1 hour' else null end,
    now() - interval '1 hour', now() + interval '23 hours'
  ) returning id into v_id;
  return v_id;
end $f$;

create function pg_temp.bitir(p_duel uuid, p_player uuid, p_dogru int)
returns void
language sql as $f$
  insert into public.async_duel_results (duel_id, player_id, correct_count, total_ms)
  values (p_duel, p_player, p_dogru, 60000)
$f$;

-- Kimliği taklit edip dürter; 'ok', hata iletisi ya da 'RPC yok' döner.
create function pg_temp.durt(p_duel uuid, p_user uuid) returns text
language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user)::text, true);
  begin
    execute 'select public.nudge_async_duel($1)' using p_duel;
    return 'ok';
  exception
    when undefined_function then return 'RPC yok';
    when others then return sqlerrm;
  end;
end $f$;

create function pg_temp.push_sayisi(p_gonderen uuid) returns int
language sql as $f$
  select count(*)::int from public.push_outbox
  where from_user_id = p_gonderen and kind = 'async_duel_turn'
$f$;

-- Kullanıcılar: 1 = yaratıcı (bitirdi), 2 = rakip (bitirmedi),
-- 3 = katılımcı olmayan, 4 = engelli çiftin ikinci tarafı, 5 = bitirmiş rakip.
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2);
  c uuid := pg_temp.uid(3); d uuid := pg_temp.uid(4);
  e uuid := pg_temp.uid(5);
  x uuid; x2 uuid; x3 uuid; x4 uuid; r text; v0 text; v1 text;
begin
  -- (a)/(b)/(c)/(h): A bitirdi, B bitirmedi.
  x := pg_temp.duello(a, b, 'matched');
  perform pg_temp.bitir(x, a, 5);

  r := pg_temp.durt(x, a);
  insert into _kanit values (1, '(a) izinli dürtme sonucu', 'RPC yok', 'ok', r);
  insert into _kanit values (2, '(a) dürtme sonrası push sayısı (gönderen A)',
    '0', '1', pg_temp.push_sayisi(a)::text);

  r := pg_temp.durt(x, a);
  insert into _kanit values (3, '(b) 12 saat içinde ikinci dürtme',
    'RPC yok', 'Nudge cooldown', r);
  insert into _kanit values (4, '(c) reddedilen dürtme push yazmadı',
    '0', '1', pg_temp.push_sayisi(a)::text);

  -- (d) katılımcı olmayan C.
  r := pg_temp.durt(x, c);
  insert into _kanit values (5, '(d) katılımcı olmayan dürtmesi',
    'RPC yok', 'Not a duel player', r);

  -- (g) rakip B kendi turunu bitirmeden dürtemez (A bitirmiş olsa da).
  r := pg_temp.durt(x, b);
  insert into _kanit values (6, '(g) turunu bitirmemiş oyuncunun dürtmesi',
    'RPC yok', 'Finish your turn first', r);

  -- (e) engelli çift: D, A'yı engelledi; A bitirdi, D girmiş ama bitirmedi.
  x2 := pg_temp.duello(a, d, 'matched');
  perform pg_temp.bitir(x2, a, 4);
  insert into public.blocked_users (blocker_id, blocked_id) values (d, a);
  r := pg_temp.durt(x2, a);
  insert into _kanit values (7, '(e) engelli çiftte dürtme',
    'RPC yok', 'Blocked', r);

  -- (f) rakip E zaten bitirmiş.
  x3 := pg_temp.duello(a, e, 'matched');
  perform pg_temp.bitir(x3, a, 3);
  perform pg_temp.bitir(x3, e, 2);
  r := pg_temp.durt(x3, a);
  insert into _kanit values (8, '(f) rakibi bitirmiş düelloda dürtme',
    'RPC yok', 'Opponent already finished', r);

  -- (h) 12 saat geçince yeniden dürtülebilir (tablo yoksa dürtme zaten 'RPC yok').
  if to_regclass('public.async_duel_nudges') is not null then
    execute 'update public.async_duel_nudges set nudged_at = nudged_at - interval ''13 hours'' where duel_id = $1 and sender_id = $2'
      using x, a;
  end if;
  r := pg_temp.durt(x, a);
  insert into _kanit values (9, '(h) 12 saat sonra yeniden dürtme',
    'RPC yok', 'ok', r);
  insert into _kanit values (10, '(h) yeniden dürtme sonrası push sayısı',
    '0', '2', pg_temp.push_sayisi(a)::text);

  -- (i) list_my_async_duels `my_nudged_at` döndürür (A'nın satırı).
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', a)::text, true);
    select (coalesce(jsonb_typeof(j->'my_nudged_at'), 'yok') = 'string')::text
    into r
    from public.list_my_async_duels() j
    where (j->>'duel_id')::uuid = x;
  exception when others then r := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (11, '(i) list_my_async_duels my_nudged_at dolu',
    'false', 'true', coalesce(r, 'satır yok'));

  -- (j)/(k) tamamlanmış düello: A kazandı (6-2). Rekor farkı ölçülür (A'nın
  -- canlıdaki eski galibiyetleri sonucu bozmasın).
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', a)::text, true);
    execute 'select (public.get_my_records()->>''duel_wins'')' into v0;
  exception
    when undefined_function then v0 := 'RPC yok';
    when others then v0 := 'HATA: ' || sqlerrm;
  end;
  x4 := pg_temp.duello(a, e, 'completed');
  perform pg_temp.bitir(x4, a, 6);
  perform pg_temp.bitir(x4, e, 2);
  update public.async_duels set completed_at = now() where id = x4;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', a)::text, true);
    execute $q$
      select j->>'result'
      from public.list_my_recent_matches(10) j
      where (j->>'id')::uuid = $1
    $q$ into r using x4;
  exception
    when undefined_function then r := 'RPC yok';
    when others then r := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (12, '(j) son maçlarda kazanılan düello',
    'RPC yok', 'win', coalesce(r, 'satır yok'));

  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', a)::text, true);
    execute 'select (public.get_my_records()->>''duel_wins'')' into v1;
  exception
    when undefined_function then v1 := 'RPC yok';
    when others then v1 := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (13, '(k) get_my_records duel_wins artışı',
    'RPC yok', '1',
    case when v1 ~ '^[0-9]+$' and v0 ~ '^[0-9]+$'
         then (v1::int - v0::int)::text else v1 end);
exception when others then
  insert into _kanit values (99, '(genel)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (l)
-- Aynı gönderici (C) -> aynı alıcı (D), dört FARKLI düello: 12 saatte en çok 3.
do $$
declare
  c uuid := pg_temp.uid(3); d uuid := pg_temp.uid(4);
  x uuid; r text; i int; ok_n int := 0; r4 text;
begin
  for i in 1..4 loop
    x := pg_temp.duello(c, d, 'matched');
    perform pg_temp.bitir(x, c, 4);
    r := pg_temp.durt(x, c);
    if i <= 3 and r = 'ok' then ok_n := ok_n + 1; end if;
    if i = 4 then r4 := r; end if;
  end loop;
  insert into _kanit values (14, '(l1) farklı düellolardan ilk 3 dürtme geçti',
    'RPC yok', '3', case when r4 = 'RPC yok' then 'RPC yok' else ok_n::text end);
  insert into _kanit values (15, '(l2) aynı alıcıya farklı düellodan 4. dürtme',
    'RPC yok', 'Nudge limit', r4);
exception when others then
  insert into _kanit values (14, '(l)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- Odalar için yardımcılar: oyuncu başına tek satır, cevap sırası dizgesi
-- ('1'=doğru, '0'=yanlış) soru sırasıyla player_answers'a yazılır.
create function pg_temp.oda(
  p_max int, p_reason text, p_forfeited_by uuid
) returns uuid
language plpgsql as $f$
declare v_id uuid;
begin
  insert into public.rooms (
    code, host_id, status, max_players, ended_reason, forfeited_by,
    finished_at, question_count, is_custom
  ) values (
    'K' || substr(md5(random()::text), 1, 7), pg_temp.uid(1), 'finished',
    p_max, p_reason, p_forfeited_by, now(), 11, p_max > 2
  ) returning id into v_id;
  return v_id;
end $f$;

-- ---------------------------------------------------------------- (m)
-- 8 doğru + 1 yanlış + 2 doğru: anlık seri (room_players.streak) 2'de biter,
-- rekor 8 olmalı.
do $$
declare
  a uuid; e uuid := pg_temp.uid(5);
  room uuid; qs uuid[]; flags text := '11111111011'; i int; v text;
begin
  -- Canlı odalarında hiç kaydı olmayan bir profil: eski serileri sonucu bozmaz.
  select pr.id into a from public.profiles pr
  where pr.id not in (select id from _p)
    and not exists (select 1 from public.room_players rp where rp.player_id = pr.id)
  order by pr.id limit 1;
  if a is null then
    insert into _kanit values (16, '(m) en uzun doğru serisi', 'RPC yok', '8',
      'oda geçmişsiz profil yok');
    return;
  end if;
  select array_agg(id) into qs from (
    select id from public.questions where is_approved = true limit 11
  ) q;
  room := pg_temp.oda(2, 'completed', null);
  insert into public.room_players (room_id, player_id, score, streak)
  values (room, a, 100, 2), (room, e, 50, 0);
  for i in 1..11 loop
    insert into public.room_questions (room_id, question_id, question_index)
    values (room, qs[i], i - 1);
  end loop;
  -- Cevap ekleme tetikleyicisi canlı oda akışını denetler; bu işlemde kapatılır.
  execute 'alter table public.player_answers disable trigger player_answers_current_question_trg';
  for i in 1..11 loop
    insert into public.player_answers (room_id, question_id, player_id, selected_option, is_correct, response_ms)
    values (room, qs[i], a, 'A', substr(flags, i, 1) = '1', 3000);
  end loop;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
    execute $q$ select public.get_my_records()->>'best_quiz_streak' $q$ into v;
  exception
    when undefined_function then v := 'RPC yok';
    when others then v := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (16, '(m) 8 doğru + 1 yanlış + 2 doğru -> en uzun doğru serisi',
    'RPC yok', '8', coalesce(v, 'null'));
exception when others then
  insert into _kanit values (16, '(m)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (n)
-- 4 kişilik odada C terk etti; A (10 puan) ikinci değil: eski mantık 'win'
-- verirdi, yenisi puan sırasına göre 'loss'.
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2); c uuid := pg_temp.uid(3);
  room uuid; v text;
begin
  room := pg_temp.oda(4, 'forfeit', c);
  insert into public.room_players (room_id, player_id, score, streak)
  values (room, a, 10, 0), (room, b, 20, 0), (room, c, 5, 0);
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
    execute $q$
      select j->>'result' from public.list_my_recent_matches(50) j
      where (j->>'id')::uuid = $1
    $q$ into v using room;
  exception
    when undefined_function then v := 'RPC yok';
    when others then v := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (17, '(n) kalabalık oda hükmen: terk eden dışındaki ikinci oyuncunun sonucu',
    'RPC yok', 'loss', coalesce(v, 'satır yok'));
exception when others then
  insert into _kanit values (17, '(n)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
