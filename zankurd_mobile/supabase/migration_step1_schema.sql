-- ============================================================
-- ZanKurd Supabase Migration — STEP 1 of 2
-- Schema + Policies + Functions + Leaderboard view
-- Run FIRST in SQL Editor
-- ============================================================

create extension if not exists "pgcrypto";

create type room_status as enum ('lobby', 'active', 'reveal', 'finished', 'cancelled');
create type match_mode as enum ('practice', 'private_room', 'random_match', 'daily', 'tournament');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_color text not null default '#177a56',
  coins integer not null default 0 check (coins >= 0),
  rating integer not null default 1000,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id),
  language_code text not null default 'ku-kmr',
  prompt text not null,
  option_a text not null,
  option_b text not null,
  option_c text not null,
  option_d text not null,
  correct_option text not null check (correct_option in ('A', 'B', 'C', 'D')),
  explanation text,
  question_type text not null default 'multiple_choice'
    check (question_type in ('multiple_choice', 'true_false', 'visual')),
  image_url text,
  source_url text,
  difficulty integer not null default 2 check (difficulty between 1 and 5),
  is_approved boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  host_id uuid not null references public.profiles(id),
  status room_status not null default 'lobby',
  mode match_mode not null default 'private_room',
  category_id uuid references public.categories(id),
  question_count integer not null default 10 check (question_count between 3 and 30),
  seconds_per_question integer not null default 15 check (seconds_per_question between 5 and 60),
  current_question_index integer not null default 0,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.room_players (
  room_id uuid not null references public.rooms(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  score integer not null default 0,
  streak integer not null default 0,
  is_ready boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (room_id, player_id)
);

create table public.room_questions (
  room_id uuid not null references public.rooms(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  question_index integer not null,
  started_at timestamptz,
  revealed_at timestamptz,
  primary key (room_id, question_index),
  unique (room_id, question_id)
);

create table public.player_answers (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  player_id uuid not null references public.profiles(id) on delete cascade,
  selected_option text not null check (selected_option in ('A', 'B', 'C', 'D')),
  is_correct boolean not null default false,
  response_ms integer not null check (response_ms >= 0),
  points_awarded integer not null default 0,
  created_at timestamptz not null default now(),
  unique (room_id, question_id, player_id)
);

create table public.question_reports (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  reporter_id uuid references public.profiles(id) on delete set null,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table public.favorite_questions (
  player_id uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (player_id, question_id)
);

create table public.coin_transactions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  amount integer not null,
  reason text not null,
  play_purchase_token text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.questions enable row level security;
alter table public.rooms enable row level security;
alter table public.room_players enable row level security;
alter table public.room_questions enable row level security;
alter table public.player_answers enable row level security;
alter table public.question_reports enable row level security;
alter table public.favorite_questions enable row level security;
alter table public.coin_transactions enable row level security;

create policy "Profiles are readable by signed-in users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users update their own profile"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "Approved questions are readable"
  on public.questions for select
  to authenticated
  using (is_approved = true);

create policy "Categories are readable"
  on public.categories for select
  to authenticated
  using (is_active = true);

create policy "Room participants can read rooms"
  on public.rooms for select
  to authenticated
  using (
    host_id = auth.uid()
    or exists (
      select 1 from public.room_players
      where room_players.room_id = rooms.id
      and room_players.player_id = auth.uid()
    )
  );

create policy "Signed-in users create rooms"
  on public.rooms for insert
  to authenticated
  with check (host_id = auth.uid());

create policy "Players can join as themselves"
  on public.room_players for insert
  to authenticated
  with check (player_id = auth.uid());

create policy "Players read room membership"
  on public.room_players for select
  to authenticated
  using (
    player_id = auth.uid()
    or exists (
      select 1 from public.room_players own_membership
      where own_membership.room_id = room_players.room_id
      and own_membership.player_id = auth.uid()
    )
  );

create policy "Players submit their own answers"
  on public.player_answers for insert
  to authenticated
  with check (player_id = auth.uid());

create policy "Players read their own answers"
  on public.player_answers for select
  to authenticated
  using (player_id = auth.uid());

create policy "Users report questions"
  on public.question_reports for insert
  to authenticated
  with check (reporter_id = auth.uid());

create policy "Users manage favorites"
  on public.favorite_questions for all
  to authenticated
  using (player_id = auth.uid())
  with check (player_id = auth.uid());

-- Leaderboard view (safe to re-run after any data migrations)
create or replace view public.leaderboard_entries as
select
  row_number() over (order by coalesce(sum(rp.score), 0) desc, coalesce(max(rp.streak), 0) desc)::integer as rank,
  rp.player_id,
  coalesce(p.display_name, 'Oyuncu') as display_name,
  coalesce(sum(rp.score), 0)::integer as total_score,
  coalesce(max(rp.streak), 0)::integer as best_streak,
  count(distinct rp.room_id)::integer as rooms_played
from public.room_players rp
left join public.profiles p on p.id = rp.player_id
group by rp.player_id, p.display_name;

grant select on public.leaderboard_entries to anon, authenticated;


-- ── Additional RLS policies ──────────────────────────
drop policy if exists "Users insert their own profile" on public.profiles;
drop policy if exists "Players update their own room membership" on public.room_players;

create policy "Users insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "Players update their own room membership"
  on public.room_players for update
  to authenticated
  using (player_id = auth.uid())
  with check (player_id = auth.uid());

drop policy if exists "Anon can read active categories" on public.categories;
drop policy if exists "Anon can read approved questions" on public.questions;

create policy "Anon can read active categories"
  on public.categories for select
  to anon
  using (is_active = true);

create policy "Anon can read approved questions"
  on public.questions for select
  to anon
  using (is_approved = true);


-- ── Server-side functions ────────────────────────────
create or replace function public.submit_answer(
  p_room_id uuid,
  p_question_id uuid,
  p_selected_option text,
  p_response_ms integer default 2000
) returns json language plpgsql security definer as $$
declare
  v_player_id uuid;
  v_is_correct boolean;
  v_correct_option text;
  v_points integer := 0;
  v_current_streak integer;
  v_current_score integer;
  v_existing_answer record;
begin
  -- Authenticate
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Get correct option
  select correct_option into v_correct_option
  from public.questions
  where id = p_question_id;

  if v_correct_option is null then
    raise exception 'Question not found';
  end if;

  -- Check correctness
  v_is_correct := (p_selected_option = v_correct_option);

  -- Get current player score/streak from room
  select score, streak into v_current_score, v_current_streak
  from public.room_players
  where room_id = p_room_id and player_id = v_player_id;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select is_correct, points_awarded into v_existing_answer
  from public.player_answers
  where room_id = p_room_id
    and question_id = p_question_id
    and player_id = v_player_id;

  if found then
    return json_build_object(
      'is_correct', v_existing_answer.is_correct,
      'points', 0,
      'new_score', v_current_score,
      'new_streak', v_current_streak,
      'correct_option', v_correct_option,
      'already_answered', true
    );
  end if;

  -- Calculate points and streak
  if v_is_correct then
    v_current_streak := v_current_streak + 1;
    -- Base 100 points + combo points (max 50 based on streak)
    v_points := 100 + (case when v_current_streak * 10 > 50 then 50 else v_current_streak * 10 end);
    v_current_score := v_current_score + v_points;
  else
    v_current_streak := 0;
    v_points := 0;
  end if;

  -- Insert answer record before score update, so duplicate submits cannot add points twice.
  insert into public.player_answers (
    room_id, question_id, player_id, selected_option, is_correct, response_ms, points_awarded
  ) values (
    p_room_id, p_question_id, v_player_id, p_selected_option, v_is_correct, p_response_ms, v_points
  );

  -- Update player's score and streak in the room
  update public.room_players
  set
    score = v_current_score,
    streak = v_current_streak
  where room_id = p_room_id and player_id = v_player_id;

  -- Return the result
  return json_build_object(
    'is_correct', v_is_correct,
    'points', v_points,
    'new_score', v_current_score,
    'new_streak', v_current_streak,
    'correct_option', v_correct_option,
    'already_answered', false
  );
end;
$$;

create or replace function public.start_room_game(
  p_room_id uuid
) returns json language plpgsql security definer as $$
declare
  v_player_id uuid;
  v_room public.rooms%rowtype;
  v_question_count integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id;

  if not found then
    raise exception 'Room not found';
  end if;

  if v_room.host_id <> v_player_id then
    raise exception 'Only the host can start this room';
  end if;

  if not exists (
    select 1
    from public.room_questions
    where room_id = p_room_id
  ) then
    insert into public.room_questions (
      room_id,
      question_id,
      question_index,
      started_at
    )
    select
      p_room_id,
      picked.id,
      row_number() over (order by picked.random_order)::integer - 1,
      case
        when row_number() over (order by picked.random_order) = 1 then now()
        else null
      end
    from (
      select q.id, random() as random_order
      from public.questions q
      where q.is_approved = true
        and (v_room.category_id is null or q.category_id = v_room.category_id)
      order by random_order
      limit v_room.question_count
    ) picked;
  end if;

  select count(*)::integer into v_question_count
  from public.room_questions
  where room_id = p_room_id;

  if v_question_count = 0 then
    raise exception 'No approved questions available for this room';
  end if;

  update public.rooms
  set
    status = 'active',
    current_question_index = 0,
    started_at = coalesce(started_at, now())
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$$;

create or replace function public.finish_room_game(
  p_room_id uuid
) returns json language plpgsql security definer as $$
declare
  v_player_id uuid;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.room_players
    where room_id = p_room_id
      and player_id = v_player_id
  ) then
    raise exception 'Player is not in the room';
  end if;

  update public.rooms
  set
    status = 'finished',
    finished_at = coalesce(finished_at, now())
  where id = p_room_id;

  return json_build_object('status', 'finished');
end;
$$;

drop policy if exists "Room participants can read room questions" on public.room_questions;

create policy "Room participants can read room questions"
  on public.room_questions for select
  to authenticated
  using (
    exists (
      select 1
      from public.room_players
      where room_players.room_id = room_questions.room_id
        and room_players.player_id = auth.uid()
    )
    or exists (
      select 1
      from public.rooms
      where rooms.id = room_questions.room_id
        and rooms.host_id = auth.uid()
    )
  );

grant execute on function public.start_room_game(uuid) to authenticated;
grant execute on function public.finish_room_game(uuid) to authenticated;


-- ── Leaderboard view ─────────────────────────────────
drop view if exists public.leaderboard_entries;

create view public.leaderboard_entries as
select
  row_number() over (order by coalesce(sum(rp.score), 0) desc, coalesce(max(rp.streak), 0) desc)::integer as rank,
  rp.player_id,
  coalesce(p.display_name, 'Oyuncu') as display_name,
  coalesce(sum(rp.score), 0)::integer as total_score,
  coalesce(max(rp.streak), 0)::integer as best_streak,
  count(distinct rp.room_id)::integer as rooms_played
from public.room_players rp
left join public.profiles p on p.id = rp.player_id
group by rp.player_id, p.display_name
order by total_score desc, best_streak desc, rooms_played desc;

grant select on public.leaderboard_entries to anon, authenticated;


-- ── Question bank: add columns + seed categories ─────
alter table public.questions
  add column if not exists question_type text not null default 'multiple_choice';

alter table public.questions
  add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'questions_question_type_check'
  ) then
    alter table public.questions
      add constraint questions_question_type_check
      check (question_type in ('multiple_choice', 'true_false', 'visual'));
  end if;
end;
$$;

insert into public.categories (name, slug, is_active)
values
  ('Ziman', 'ziman', true),
  ('Çand', 'cand', true),
  ('Dîrok', 'dirok', true),
  ('Edebiyat', 'edebiyat', true),
  ('Cografya', 'cografya', true),
  ('Muzîk', 'muzik', true)
on conflict (name) do update set is_active = excluded.is_active;

delete from public.questions
where source_url = 'zankurd_seed_rich_v2';
