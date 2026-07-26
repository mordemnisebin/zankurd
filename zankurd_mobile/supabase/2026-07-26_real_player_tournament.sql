-- Gerçek oyuncular arasında turnuva.
--
-- Bugüne dek turnuva tümüyle istemci tarafında bir bot benzetimiydi:
-- `joinTournament`, `loadTournamentBracket` ve `submitTournamentMatch`
-- Supabase deposunda bile sahte depoya yönleniyordu. Ekran "16 oyuncu
-- (bot)" yazıyordu; oyuncular hiçbir zaman karşılaşmıyordu.
--
-- Tasarım kararı — **eşzamansız eşleşme**. Küçük bir oyuncu kitlesinde
-- sekiz kişinin aynı anda çevrimiçi olmasını beklemek turnuvanın hiç
-- başlamaması demektir. Bunun yerine her maçın bir süresi vardır: iki
-- oyuncu da kendi uygun olduğu anda aynı soru setini oynar, ikisi de
-- gönderdiğinde sunucu kazananı belirler. Süre dolduğunda oynamış olan
-- turu geçer (hükmen).
--
-- Yetki tümüyle sunucudadır: eşleştirmeyi, kazananı ve ilerlemeyi istemci
-- değil bu fonksiyonlar belirler. İstemci yalnız kendi skorunu bildirir ve
-- skor da tek sefer kabul edilir.
--
-- UYGULAMADAN ÖNCE: staging projesinde doğrulanmalı. Bu dosya canlıya
-- uygulanmadan turnuva ekranı eski (bot) davranışına düşer — istemci
-- fonksiyon yokluğunu (42883) sessizce yakalar.

-- ── Şema ────────────────────────────────────────────────────────────────

create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  -- Hedef kontenjan. Dolunca turnuva hemen başlar.
  --
  -- Başlangıç için 4 seçildi: az oyuncuyla bir kupa iki turda biter ve
  -- turnuva gerçekten *tamamlanır*. Kitle büyüyünce bu değeri yükseltmek
  -- yeter; kod hiçbir yerde dört sayısına bağlı değil.
  size int not null default 4,
  -- Kontenjan dolmasa da turnuva başlayabilir: `fill_hours` dolduğunda
  -- en az `min_size` oyuncuyla başlar. Bu olmasaydı tek bir eksik oyuncu
  -- turnuvayı süresiz bekletirdi — "gerçek oyuncular" sözünün en sık
  -- kırıldığı yer budur.
  min_size int not null default 2,
  fill_hours int not null default 24,
  status text not null default 'open',   -- open | running | finished
  round_hours int not null default 24,   -- bir turun süresi
  opened_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  champion_id uuid references auth.users(id) on delete set null
);

create table if not exists public.tournament_entries (
  tournament_id uuid not null references public.tournaments(id)
    on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  joined_at timestamptz not null default now(),
  primary key (tournament_id, player_id)
);

create table if not exists public.tournament_matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id)
    on delete cascade,
  round int not null,
  slot int not null,
  player_one uuid references auth.users(id) on delete set null,
  player_two uuid references auth.users(id) on delete set null,
  score_one int,
  score_two int,
  submitted_one timestamptz,
  submitted_two timestamptz,
  winner_id uuid references auth.users(id) on delete set null,
  status text not null default 'pending',  -- pending | completed
  deadline timestamptz,
  unique (tournament_id, round, slot)
);

create index if not exists tournament_matches_player_idx
  on public.tournament_matches (tournament_id, player_one, player_two);

alter table public.tournaments enable row level security;
alter table public.tournament_entries enable row level security;
alter table public.tournament_matches enable row level security;

-- Okuma herkese açık (bracket görünür olmalı); yazma yalnız fonksiyonlar
-- üzerinden. Doğrudan insert/update politikası **bilerek yok**: skor ve
-- ilerleme istemciden yazılamaz.
drop policy if exists tournaments_read on public.tournaments;
create policy tournaments_read on public.tournaments
  for select using (true);

drop policy if exists tournament_entries_read on public.tournament_entries;
create policy tournament_entries_read on public.tournament_entries
  for select using (true);

drop policy if exists tournament_matches_read on public.tournament_matches;
create policy tournament_matches_read on public.tournament_matches
  for select using (true);

-- ── Katılım ─────────────────────────────────────────────────────────────

create or replace function public.join_tournament()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_name text;
  v_tournament public.tournaments;
  v_count int;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select coalesce(display_name, 'Lîstikvan') into v_name
    from public.profiles where id = v_user;

  -- Zaten bir turnuvada mı? Katılım tekrarlanabilir olmalı: ekranı yeniden
  -- açmak ikinci bir kayıt oluşturmamalı.
  select t.* into v_tournament
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_user
     and t.status in ('open', 'running')
   order by t.opened_at desc
   limit 1;

  if found then
    return jsonb_build_object('tournament_id', v_tournament.id,
                              'status', v_tournament.status);
  end if;

  -- Açık turnuva yoksa aç.
  select * into v_tournament
    from public.tournaments
   where status = 'open'
   order by opened_at asc
   limit 1
   for update;

  if not found then
    insert into public.tournaments default values
    returning * into v_tournament;
  end if;

  insert into public.tournament_entries (tournament_id, player_id, display_name)
  values (v_tournament.id, v_user, coalesce(v_name, 'Lîstikvan'))
  on conflict do nothing;

  select count(*) into v_count
    from public.tournament_entries
   where tournament_id = v_tournament.id;

  -- Kontenjan dolduğunda turnuva başlar ve ilk tur eşleşmeleri kurulur.
  if v_count >= v_tournament.size then
    perform public.start_tournament(v_tournament.id);
    select * into v_tournament from public.tournaments
     where id = v_tournament.id;
  end if;

  return jsonb_build_object('tournament_id', v_tournament.id,
                            'status', v_tournament.status);
end;
$$;

-- ── Başlatma ve eşleştirme ──────────────────────────────────────────────

create or replace function public.start_tournament(p_tournament_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tournament public.tournaments;
  v_players uuid[];
  v_i int;
  v_slot int := 0;
begin
  select * into v_tournament from public.tournaments
   where id = p_tournament_id for update;
  if not found or v_tournament.status <> 'open' then
    return;
  end if;

  -- Katılım sırasına göre eşleştirilir: ilk gelen ilk sıraya. Rastgele
  -- eşleştirme de mümkündü ama katılım sırası hem yeniden üretilebilir
  -- hem de açıklanabilir.
  select array_agg(player_id order by joined_at)
    into v_players
    from public.tournament_entries
   where tournament_id = p_tournament_id;

  v_i := 1;
  while v_i <= array_length(v_players, 1) loop
    insert into public.tournament_matches (
      tournament_id, round, slot, player_one, player_two, deadline
    ) values (
      p_tournament_id, 1, v_slot,
      v_players[v_i],
      v_players[v_i + 1],  -- tek sayıda oyuncuda null: hükmen geçer
      now() + make_interval(hours => v_tournament.round_hours)
    );
    v_slot := v_slot + 1;
    v_i := v_i + 2;
  end loop;

  -- Rakipsiz kalan oyuncu beklemeden ilerler.
  update public.tournament_matches
     set status = 'completed', winner_id = player_one
   where tournament_id = p_tournament_id
     and round = 1
     and player_two is null;

  update public.tournaments
     set status = 'running', started_at = now()
   where id = p_tournament_id;
end;
$$;

-- Süresi dolan açık turnuvalar, eldeki oyuncularla başlar.
create or replace function public.start_due_tournaments()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  for v_id in
    select t.id
      from public.tournaments t
     where t.status = 'open'
       and t.opened_at + make_interval(hours => t.fill_hours) < now()
       and (select count(*) from public.tournament_entries e
             where e.tournament_id = t.id) >= t.min_size
  loop
    perform public.start_tournament(v_id);
  end loop;
end;
$$;

-- ── Skor bildirimi ve ilerleme ──────────────────────────────────────────

create or replace function public.submit_tournament_match(
  p_match_id uuid,
  p_score int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_match public.tournament_matches;
  v_winner uuid;
  v_score int := greatest(coalesce(p_score, 0), 0);
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select * into v_match from public.tournament_matches
   where id = p_match_id for update;
  if not found then
    raise exception 'Match not found';
  end if;
  if v_user not in (coalesce(v_match.player_one, '00000000-0000-0000-0000-000000000000'::uuid),
                    coalesce(v_match.player_two, '00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'Player is not in this match';
  end if;
  if v_match.status = 'completed' then
    return jsonb_build_object('status', 'completed',
                              'winner_id', v_match.winner_id);
  end if;

  -- Skor tek sefer kabul edilir: ikinci gönderim sessizce yok sayılır,
  -- yoksa oyuncu turu tekrar oynayıp skorunu yükseltebilirdi.
  if v_user = v_match.player_one and v_match.submitted_one is null then
    update public.tournament_matches
       set score_one = v_score, submitted_one = now()
     where id = p_match_id;
  elsif v_user = v_match.player_two and v_match.submitted_two is null then
    update public.tournament_matches
       set score_two = v_score, submitted_two = now()
     where id = p_match_id;
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;

  if v_match.submitted_one is not null and v_match.submitted_two is not null
  then
    -- Eşitlikte daha erken bitiren geçer: aynı skoru önce tamamlamak
    -- ölçülebilir bir üstünlüktür ve yazı-tura atmaktan yeğdir.
    if coalesce(v_match.score_one, 0) > coalesce(v_match.score_two, 0) then
      v_winner := v_match.player_one;
    elsif coalesce(v_match.score_two, 0) > coalesce(v_match.score_one, 0) then
      v_winner := v_match.player_two;
    elsif v_match.submitted_one <= v_match.submitted_two then
      v_winner := v_match.player_one;
    else
      v_winner := v_match.player_two;
    end if;

    update public.tournament_matches
       set status = 'completed', winner_id = v_winner
     where id = p_match_id;

    perform public.advance_tournament(v_match.tournament_id);
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;
  return jsonb_build_object('status', v_match.status,
                            'winner_id', v_match.winner_id);
end;
$$;

-- Süresi dolmuş maçlarda oynamış olan geçer (hükmen); ikisi de
-- oynamadıysa maç kimseye yazılmaz ve üst tur boş kalır.
create or replace function public.resolve_expired_tournament_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.tournament_matches
     set status = 'completed',
         winner_id = case
           when submitted_one is not null and submitted_two is null
             then player_one
           when submitted_two is not null and submitted_one is null
             then player_two
           else null
         end
   where status <> 'completed'
     and deadline is not null
     and deadline < now();
end;
$$;

create or replace function public.advance_tournament(p_tournament_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round int;
  v_pending int;
  v_winners uuid[];
  v_i int;
  v_slot int := 0;
  v_hours int;
begin
  select round_hours into v_hours from public.tournaments
   where id = p_tournament_id;

  select max(round) into v_round from public.tournament_matches
   where tournament_id = p_tournament_id;
  if v_round is null then return; end if;

  select count(*) into v_pending from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and status <> 'completed';
  if v_pending > 0 then return; end if;

  select array_agg(winner_id order by slot) into v_winners
    from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and winner_id is not null;

  if v_winners is null or array_length(v_winners, 1) <= 1 then
    update public.tournaments
       set status = 'finished',
           finished_at = now(),
           champion_id = case
             when v_winners is null then null else v_winners[1] end
     where id = p_tournament_id;
    return;
  end if;

  v_i := 1;
  while v_i <= array_length(v_winners, 1) loop
    insert into public.tournament_matches (
      tournament_id, round, slot, player_one, player_two, deadline
    ) values (
      p_tournament_id, v_round + 1, v_slot,
      v_winners[v_i], v_winners[v_i + 1],
      now() + make_interval(hours => coalesce(v_hours, 24))
    );
    v_slot := v_slot + 1;
    v_i := v_i + 2;
  end loop;

  update public.tournament_matches
     set status = 'completed', winner_id = player_one
   where tournament_id = p_tournament_id
     and round = v_round + 1
     and player_two is null;
end;
$$;

-- ── Bracket okuma ───────────────────────────────────────────────────────

create or replace function public.get_tournament_bracket()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_tournament public.tournaments;
  v_rounds jsonb;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  -- Ekran her açıldığında zamanı gelmiş işler yürütülür: süresi dolan
  -- maçlar hükmen kapanır, dolmayı bekleyen turnuvalar eldeki oyuncularla
  -- başlar. Ayrı bir zamanlayıcı gerekmez.
  perform public.resolve_expired_tournament_matches();
  perform public.start_due_tournaments();

  select t.* into v_tournament
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_user
   order by t.opened_at desc
   limit 1;

  if not found then
    return null;
  end if;

  select jsonb_agg(r order by r_round)
    into v_rounds
    from (
      select m.round as r_round,
             jsonb_build_object(
               'round', m.round,
               'matches', jsonb_agg(
                 jsonb_build_object(
                   'id', m.id,
                   'playerOneId', coalesce(m.player_one::text, ''),
                   'playerOneName', coalesce(e1.display_name, '—'),
                   'playerTwoId', coalesce(m.player_two::text, ''),
                   'playerTwoName', coalesce(e2.display_name, '—'),
                   'playerOneScore', coalesce(m.score_one, 0),
                   'playerTwoScore', coalesce(m.score_two, 0),
                   'status', m.status,
                   'winnerId', coalesce(m.winner_id::text, ''),
                   'deadline', m.deadline
                 ) order by m.slot
               )
             ) as r
        from public.tournament_matches m
        left join public.tournament_entries e1
               on e1.tournament_id = m.tournament_id
              and e1.player_id = m.player_one
        left join public.tournament_entries e2
               on e2.tournament_id = m.tournament_id
              and e2.player_id = m.player_two
       where m.tournament_id = v_tournament.id
       group by m.round
    ) rounds;

  return jsonb_build_object(
    'tournamentId', v_tournament.id,
    'userId', v_user,
    'status', case
      when v_tournament.status = 'finished'
           and v_tournament.champion_id = v_user then 'won'
      when v_tournament.status = 'finished' then 'eliminated'
      else 'active' end,
    'createdAt', v_tournament.opened_at,
    'completedAt', v_tournament.finished_at,
    'rounds', coalesce(v_rounds, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.start_tournament(uuid) from public, anon,
  authenticated;
revoke all on function public.advance_tournament(uuid) from public, anon,
  authenticated;
revoke all on function public.start_due_tournaments() from public, anon,
  authenticated;
grant execute on function public.join_tournament() to authenticated;
grant execute on function public.submit_tournament_match(uuid, int)
  to authenticated;
grant execute on function public.get_tournament_bracket() to authenticated;
grant execute on function public.resolve_expired_tournament_matches()
  to authenticated;
