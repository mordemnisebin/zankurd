-- ============================================================
-- Matchmaking kurulumu + duzeltmeleri (2026-07-03)
--
-- matchmaking.sql hic canliya uygulanmamisti; ustune uc hatasi vardi:
-- 1. Oda host'u BEKLEYEN oyuncuydu ama start_room_game'i ESLESEN
--    (ikinci) oyuncu cagiriyor -> "Only the host can start" ile tum
--    islem geri aliniyordu. Simdi host = cagiran oyuncu.
-- 2. Oda kodu yalnizca 900 kombinasyondu; 32^4 alfabeli kod +
--    unique cakismasinda yeniden deneme geldi.
-- 3. Ayni bekleyen oyuncunun iki kisiye birden eslesmesine karsi
--    "for update skip locked" kilidi geldi; 2 dakikadan eski hayalet
--    kuyruk kayitlari da temizleniyor.
-- Ek: matchmaking_queue realtime yayinina eklendi (istemci stream'i
-- room_id atamasini bununla goruyor).
-- ============================================================

create table if not exists public.matchmaking_queue (
  player_id uuid primary key references public.profiles(id) on delete cascade,
  category_name text not null,
  joined_at timestamp with time zone default now() not null,
  room_id uuid references public.rooms(id) on delete set null
);

alter table public.matchmaking_queue enable row level security;

drop policy if exists "Allow read own matchmaking queue entry"
  on public.matchmaking_queue;
create policy "Allow read own matchmaking queue entry"
  on public.matchmaking_queue for select
  to authenticated
  using (player_id = auth.uid());

drop policy if exists "Allow insert own matchmaking queue entry"
  on public.matchmaking_queue;
create policy "Allow insert own matchmaking queue entry"
  on public.matchmaking_queue for insert
  to authenticated
  with check (player_id = auth.uid());

drop policy if exists "Allow delete own matchmaking queue entry"
  on public.matchmaking_queue;
create policy "Allow delete own matchmaking queue entry"
  on public.matchmaking_queue for delete
  to authenticated
  using (player_id = auth.uid());

-- Istemci kuyruk satirini stream ile dinler; tablo realtime yayininda olmali.
do $$
begin
  alter publication supabase_realtime add table public.matchmaking_queue;
exception
  when duplicate_object then null;
end;
$$;

create or replace function public.join_matchmaking(
  p_category_name text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_opponent uuid;
  v_room_id uuid;
  v_room_code text;
  v_category_id uuid;
  v_opponent_name text;
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt integer;
  v_i integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select id into v_category_id
  from public.categories
  where upper(name) = upper(p_category_name)
  limit 1;

  if v_category_id is null then
    select id into v_category_id
    from public.categories
    where slug = 'ziman'
    limit 1;
  end if;

  -- Eski kaydini ve 2 dakikadan eski hayalet kayitlari temizle.
  delete from public.matchmaking_queue where player_id = v_player_id;
  delete from public.matchmaking_queue
  where room_id is null
    and joined_at < now() - interval '2 minutes';

  -- Ayni kategoride bekleyen en eski oyuncu; kilitle ki iki es zamanli
  -- cagri ayni bekleyeni kapmasin.
  select player_id into v_opponent
  from public.matchmaking_queue
  where category_name = p_category_name
    and player_id <> v_player_id
    and room_id is null
  order by joined_at asc
  limit 1
  for update skip locked;

  if v_opponent is not null then
    -- Oda host'u CAGIRAN oyuncudur: start_room_game host kontrolu
    -- ayni cagri icinde auth.uid() = cagiran ile calisir.
    v_attempt := 0;
    loop
      v_attempt := v_attempt + 1;
      v_room_code := 'ZK-';
      for v_i in 1..4 loop
        v_room_code := v_room_code
          || substr(v_alphabet, 1 + floor(random() * 32)::int, 1);
      end loop;
      begin
        insert into public.rooms (
          code, host_id, category_id, question_count,
          seconds_per_question, status
        )
        values (v_room_code, v_player_id, v_category_id, 10, 15, 'lobby')
        returning id into v_room_id;
        exit;
      exception
        when unique_violation then
          if v_attempt >= 5 then
            raise;
          end if;
      end;
    end loop;

    insert into public.room_players (room_id, player_id, is_ready)
    values
      (v_room_id, v_opponent, true),
      (v_room_id, v_player_id, true);

    -- Bekleyen oyuncunun stream'i bu guncelleme ile odayi ogrenir.
    update public.matchmaking_queue
    set room_id = v_room_id
    where player_id = v_opponent;

    -- Sorulari doldurur ve odayi aktif eder (host = cagiran).
    perform public.start_room_game(v_room_id);

    select display_name into v_opponent_name
    from public.profiles
    where id = v_opponent;

    return json_build_object(
      'status', 'matched',
      'room_id', v_room_id,
      'code', v_room_code,
      'opponent_name', coalesce(v_opponent_name, 'Hevrik')
    );
  else
    insert into public.matchmaking_queue (player_id, category_name, room_id)
    values (v_player_id, p_category_name, null);

    return json_build_object('status', 'waiting');
  end if;
end;
$$;

revoke all on function public.join_matchmaking(text) from public;
grant execute on function public.join_matchmaking(text) to authenticated;
