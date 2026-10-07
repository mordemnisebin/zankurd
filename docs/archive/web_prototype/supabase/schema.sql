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
