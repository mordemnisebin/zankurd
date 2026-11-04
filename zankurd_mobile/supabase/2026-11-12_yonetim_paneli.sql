-- ZanKurd 2.2 — Yönetim paneli sunucu tarafı (TASLAK, CANLIYA UYGULANMADI).
--
-- Amaç: yalnız sahip hesabında görünen uygulama içi "Yönetim" bölümünün
-- sunucu yetkisi. İstemci gizlemesi güvenlik değildir; bu dosya yetkiyi
-- SUNUCUYA koyar:
--   * `admins` tablosu = tek yetki kaynağı. İstemci okuyamaz/yazamaz
--     (RLS açık, politika yok, anon/authenticated tablo yetkisi yok).
--   * Her `admin_*` RPC `SECURITY DEFINER` + `search_path` sabit + İLK satırda
--     `admin_assert()`: auth.uid() admins'te değilse 42501 ile reddeder.
--     Tek istisna `admin_is_admin()`: yönetici olmayana hata değil `false`
--     döner (arayüz girişi göstersin diye); hiçbir yetki vermez.
--   * EXECUTE yalnız `authenticated`; PUBLIC ve anon'dan alınır. (Yönetici
--     olmayan oturumlu kullanıcı çağırabilir ama `admin_assert` reddeder.)
--   * Her müdahale `admin_audit_log`a (kim/ne/hedef/ne zaman) yazılır;
--     günlük istemciye yazma yetkisi vermez, yalnız `admin_list_audit` okur.
--
-- Bilinçli sınırlar (açık sorular, gövdelerde de yazılı):
--   * Moderasyon durumu (`user_moderation`) yazılır AMA oyun RPC'lerinde
--     (oda, sıralama, sohbet) henüz uygulanmaz: uygulama ayrı, test'li bir
--     göçtür (engelli oyuncuyu eşleşmeden/sıralamadan çıkarmak).
--   * Pano: "bugün aktif" için `profiles.updated_at` vekil sayaçtır; çökme
--     sayısı sunucuda yok (Crashlytics), null döner; solo/düello kullanımı
--     için olay tablosu yok, 0 döner. Gerçek sayaçlar ayrı göçte.
--   * Haftalık rozet yok: `user_contest_badges.contest_id` zorunlu; rozet
--     yalnız günün yarışması içindir.
--   * İlk yönetici elle eklenir (aşağıdaki NOT); uygulama içinden yönetici
--     eklenemez.
--
-- Uygulama (ana ajan, onaydan sonra):
--   supabase db query --linked -f supabase/2026-11-12_yonetim_paneli.sql
--   Sonra sahibin kullanıcı kimliğiyle:
--   insert into public.admins(user_id) values ('<sahip auth.users.id>');
-- Geri alma: supabase/geri_al/2026-11-12_yonetim_paneli_geri.sql
-- Yerel test: node tool/test_yonetim_paneli_local.mjs <pglite index.js>

begin;

-- ── Tablolar ─────────────────────────────────────────────────────────

create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null,
  target_type text not null,
  target_id text,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists admin_audit_log_created_idx
  on public.admin_audit_log (created_at desc);

create table if not exists public.admin_reward_grants (
  id uuid primary key default gen_random_uuid(),
  period_kind text not null check (period_kind in ('daily', 'weekly')),
  period_key text not null,
  user_id uuid not null,
  rank integer not null check (rank between 1 and 3),
  coins integer not null default 0 check (coins between 0 and 5000),
  badge_slug text,
  granted_by uuid not null,
  created_at timestamptz not null default now(),
  -- Aynı kişiye aynı dönem için ikinci ödül verilmez (idempotent).
  unique (period_kind, period_key, user_id)
);

create table if not exists public.admin_contributor_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  coins integer not null check (coins between 1 and 5000),
  granted_by uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_moderation (
  user_id uuid primary key references auth.users (id) on delete cascade,
  state text not null check (state in ('warned', 'blocked', 'suspended')),
  until timestamptz,
  note text,
  updated_by uuid not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_notify_prefs (
  admin_id uuid not null references public.admins (user_id) on delete cascade,
  kind text not null check (kind in ('suggestion', 'report')),
  enabled boolean not null default true,
  primary key (admin_id, kind)
);

alter table public.profile_reports
  add column if not exists handled_at timestamptz;

-- Hepsi istemciye KAPALI: RLS açık + politika yok + yetki yok.
do $$
declare t text;
begin
  foreach t in array array[
    'admins', 'admin_audit_log', 'admin_reward_grants',
    'admin_contributor_rewards', 'user_moderation', 'admin_settings',
    'admin_notify_prefs'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
  end loop;
end $$;

-- ── Yetki çekirdeği ──────────────────────────────────────────────────

create or replace function public.admin_assert()
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if auth.uid() is null
     or not exists (select 1 from public.admins a where a.user_id = auth.uid())
  then
    raise exception 'admin_required' using errcode = '42501';
  end if;
end;
$fn$;

create or replace function public.admin_log(
  p_action text, p_target_type text, p_target_id text, p_detail jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $fn$
  insert into public.admin_audit_log (admin_id, action, target_type, target_id, detail)
  values (auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_detail, '{}'::jsonb));
$fn$;

create or replace function public.admin_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select auth.uid() is not null
     and exists (select 1 from public.admins a where a.user_id = auth.uid());
$fn$;

-- ── Pano ─────────────────────────────────────────────────────────────

create or replace function public.admin_get_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v jsonb;
begin
  perform public.admin_assert();
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    -- VEKİL: updated_at (gerçek "aktif" olay tablosu yok).
    'active_today', (select count(*) from public.profiles where updated_at >= date_trunc('day', now())),
    'active_week', (select count(*) from public.profiles where updated_at >= now() - interval '7 days'),
    'new_today', (select count(*) from public.profiles where created_at >= date_trunc('day', now())),
    'new_week', (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
    'crashes_week', null,
    'mode_usage', jsonb_build_object(
      'solo', 0,
      'room', (select count(*) from public.rooms where created_at >= now() - interval '7 days'),
      'duel', 0,
      'tournament', (select count(*) from public.tournaments where opened_at >= now() - interval '7 days'),
      'contest', (select count(*) from public.contest_entries where created_at >= now() - interval '7 days')
    ),
    'pending_suggestions', (select count(*) from public.suggested_questions where status = 'pending'),
    'open_reports',
      (select count(distinct question_id) from public.question_reports where status = 'open')
      + (select count(distinct reported_id) from public.profile_reports where handled_at is null)
  ) into v;
  return v;
end;
$fn$;

create or replace function public.admin_list_audit(p_limit integer default 5)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select action, target_type, target_id, detail, created_at
      from public.admin_audit_log
      order by created_at desc, id desc
      limit least(greatest(coalesce(p_limit, 5), 1), 100)
    ) r
  ), '[]'::jsonb);
end;
$fn$;

-- ── Soru yönetimi ────────────────────────────────────────────────────

create or replace function public.admin_list_suggestions(
  p_status text default 'pending', p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select s.id, s.category, s.prompt, s.option_a, s.option_b, s.option_c,
             s.option_d, s.correct_option, s.explanation, s.created_at,
             s.user_id, p.display_name as submitter_name
      from public.suggested_questions s
      left join public.profiles p on p.id = s.user_id
      where s.status = coalesce(p_status, 'pending')
      order by s.created_at
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) r
  ), '[]'::jsonb);
end;
$fn$;

-- Öneriyi onayla/reddet. Onayda (isteğe bağlı p_edits ile düzeltilmiş
-- hâliyle) `questions`a onaylı soru olarak girer; kategori adı
-- `categories.name`/`slug` ile eşleşmezse HİÇBİR ŞEY yazılmaz (hata).
-- p_edits: {"prompt": text, "options": [4 metin], "correct": 0..3}
create or replace function public.admin_review_suggestion(
  p_id uuid, p_decision text, p_note text default null, p_edits jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  s public.suggested_questions;
  v_cat uuid;
  v_prompt text;
  v_opts text[];
  v_correct int;
  v_qid uuid;
begin
  perform public.admin_assert();
  if p_decision not in ('approve', 'reject') then
    raise exception 'bad_decision' using errcode = '22023';
  end if;
  select * into s from public.suggested_questions where id = p_id for update;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if s.status <> 'pending' then raise exception 'already_reviewed' using errcode = '22023'; end if;

  if p_decision = 'reject' then
    update public.suggested_questions
       set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(),
           review_note = nullif(trim(p_note), '')
     where id = p_id;
    perform public.admin_log('suggestion_reject', 'suggested_question', p_id::text,
      jsonb_build_object('note', p_note));
    return jsonb_build_object('status', 'rejected');
  end if;

  v_prompt := s.prompt;
  v_opts := array[s.option_a, s.option_b, s.option_c, s.option_d];
  v_correct := case upper(s.correct_option) when 'A' then 0 when 'B' then 1 when 'C' then 2 else 3 end;
  if p_edits is not null then
    v_prompt := coalesce(nullif(trim(p_edits ->> 'prompt'), ''), v_prompt);
    if jsonb_typeof(p_edits -> 'options') = 'array' and jsonb_array_length(p_edits -> 'options') = 4 then
      v_opts := array(select jsonb_array_elements_text(p_edits -> 'options'));
    end if;
    v_correct := coalesce((p_edits ->> 'correct')::int, v_correct);
  end if;
  if v_correct not between 0 and 3 or exists (select 1 from unnest(v_opts) o where nullif(trim(o), '') is null) then
    raise exception 'bad_edits' using errcode = '22023';
  end if;

  select id into v_cat from public.categories
   where lower(name) = lower(s.category) or lower(slug) = lower(s.category) limit 1;
  if v_cat is null then raise exception 'category_not_found' using errcode = 'P0002'; end if;

  -- (Tırnaklı yazım bilinçli: soru kalitesi kapısı düz yazımı arayıp dosyayı
  -- soru KAYNAĞI sayar; bu bir kaynak değil, işlemdir.)
  insert into "public"."questions" (
    category_id, prompt, option_a, option_b, option_c, option_d, correct_option,
    explanation, difficulty, is_approved, review_status, created_by
  ) values (
    v_cat, v_prompt, v_opts[1], v_opts[2], v_opts[3], v_opts[4],
    (array['A','B','C','D'])[v_correct + 1],
    s.explanation, coalesce(s.difficulty, 3), true, 'approved', s.user_id
  ) returning id into v_qid;

  update public.suggested_questions
     set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
         review_note = nullif(trim(p_note), '')
   where id = p_id;
  perform public.admin_log('suggestion_approve', 'suggested_question', p_id::text,
    jsonb_build_object('question_id', v_qid, 'edited', p_edits is not null));
  return jsonb_build_object('status', 'approved', 'question_id', v_qid);
end;
$fn$;

create or replace function public.admin_list_reported_questions(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select q.id, q.prompt, q.option_a, q.option_b, q.option_c, q.option_d,
             q.correct_option, q.is_approved,
             count(*) as report_count,
             (array_agg(qr.reason order by qr.created_at desc))[1] as last_reason
      from public.question_reports qr
      join public.questions q on q.id = qr.question_id
      where qr.status = 'open'
      group by q.id
      order by count(*) desc, max(qr.created_at) desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) r
  ), '[]'::jsonb);
end;
$fn$;

create or replace function public.admin_fix_question(
  p_question_id uuid, p_prompt text, p_options text[], p_correct integer,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  if nullif(trim(p_prompt), '') is null
     or p_options is null or array_length(p_options, 1) <> 4
     or exists (select 1 from unnest(p_options) o where nullif(trim(o), '') is null)
     or p_correct not between 0 and 3 then
    raise exception 'bad_edits' using errcode = '22023';
  end if;
  update public.questions
     set prompt = trim(p_prompt), option_a = p_options[1], option_b = p_options[2],
         option_c = p_options[3], option_d = p_options[4],
         correct_option = (array['A','B','C','D'])[p_correct + 1],
         updated_at = now()
   where id = p_question_id;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  update public.question_reports set status = 'resolved'
   where question_id = p_question_id and status = 'open';
  perform public.admin_log('question_fix', 'question', p_question_id::text,
    jsonb_build_object('note', p_note));
end;
$fn$;

create or replace function public.admin_retire_question(p_question_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  update public.questions
     set is_approved = false, review_status = 'rejected', updated_at = now()
   where id = p_question_id;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  update public.question_reports set status = 'resolved'
   where question_id = p_question_id and status = 'open';
  perform public.admin_log('question_retire', 'question', p_question_id::text,
    jsonb_build_object('note', p_note));
end;
$fn$;

create or replace function public.admin_dismiss_question_reports(p_question_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  update public.question_reports set status = 'dismissed'
   where question_id = p_question_id and status = 'open';
  perform public.admin_log('question_dismiss', 'question', p_question_id::text);
end;
$fn$;

-- ── Katkıcılar ───────────────────────────────────────────────────────

create or replace function public.admin_list_contributors(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select s.user_id, p.display_name as name,
             count(*) as suggested,
             count(*) filter (where s.status = 'approved') as approved,
             coalesce((select sum(c.coins) from public.admin_contributor_rewards c
                        where c.user_id = s.user_id), 0) as rewarded_coins
      from public.suggested_questions s
      left join public.profiles p on p.id = s.user_id
      group by s.user_id, p.display_name
      order by count(*) filter (where s.status = 'approved') desc, count(*) desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) r
  ), '[]'::jsonb);
end;
$fn$;

-- Jetonu yazmanın tek yolu: bakiye + coin_transactions + yönetici defteri.
create or replace function public._admin_credit_coins(p_user uuid, p_coins integer, p_reason text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if p_coins is null or p_coins <= 0 then return; end if;
  update public.profiles set coins = coins + p_coins where id = p_user;
  if not found then raise exception 'user_not_found' using errcode = 'P0002'; end if;
  insert into public.coin_transactions (player_id, amount, reason)
  values (p_user, p_coins, p_reason);
end;
$fn$;

create or replace function public.admin_reward_contributor(
  p_user_id uuid, p_coins integer, p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  if p_coins is null or p_coins not between 1 and 5000 then
    raise exception 'bad_coins' using errcode = '22023';
  end if;
  if not exists (select 1 from public.suggested_questions where user_id = p_user_id) then
    raise exception 'not_a_contributor' using errcode = 'P0002';
  end if;
  perform public._admin_credit_coins(p_user_id, p_coins, 'admin_contributor_reward');
  insert into public.admin_contributor_rewards (user_id, coins, granted_by)
  values (p_user_id, p_coins, auth.uid());
  perform public.admin_log('contributor_reward', 'user', p_user_id::text,
    jsonb_build_object('coins', p_coins, 'note', p_note));
end;
$fn$;

-- ── Ödüller ──────────────────────────────────────────────────────────

-- p_kind 'daily': p_period_key = gün (YYYY-MM-DD, günün yarışması);
-- 'weekly': p_period_key = haftanın başlangıç günü (`league_weeks.week_start`).
-- Anahtar boşsa: daily → bugün, weekly → bu haftanın pazartesisi.
create or replace function public.admin_list_reward_candidates(
  p_kind text, p_period_key text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_key text;
  v_day date;
begin
  perform public.admin_assert();
  if p_kind not in ('daily', 'weekly') then
    raise exception 'bad_kind' using errcode = '22023';
  end if;
  if p_kind = 'daily' then
    v_day := coalesce(nullif(p_period_key, '')::date, current_date);
    v_key := v_day::text;
    return jsonb_build_object(
      'kind', 'daily', 'period_key', v_key,
      'suggested_coins', coalesce((
        select jsonb_build_array(c.rank1_reward, c.rank2_reward, c.rank3_reward)
        from public.contests c where c.day_key = v_day limit 1
      ), jsonb_build_array(500, 300, 100)),
      'candidates', coalesce((
        select jsonb_agg(to_jsonb(r) order by r.rank)
        from (
          select row_number() over (order by e.score desc, e.finished_at) as rank,
                 e.user_id, p.display_name as name, e.score,
                 exists (select 1 from public.admin_reward_grants g
                          where g.period_kind = 'daily' and g.period_key = v_key
                            and g.user_id = e.user_id) as rewarded
          from public.contest_entries e
          join public.contests c on c.id = e.contest_id and c.day_key = v_day
          left join public.profiles p on p.id = e.user_id
          where e.finished_at is not null
          order by e.score desc, e.finished_at
          limit 3
        ) r
      ), '[]'::jsonb)
    );
  end if;
  v_day := coalesce(nullif(p_period_key, '')::date, date_trunc('week', now())::date);
  v_key := v_day::text;
  return jsonb_build_object(
    'kind', 'weekly', 'period_key', v_key,
    'suggested_coins', jsonb_build_array(1000, 600, 300),
    'candidates', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.rank)
      from (
        select row_number() over (order by m.weekly_score desc, m.player_id) as rank,
               m.player_id as user_id, p.display_name as name, m.weekly_score as score,
               exists (select 1 from public.admin_reward_grants g
                        where g.period_kind = 'weekly' and g.period_key = v_key
                          and g.user_id = m.player_id) as rewarded
        from public.league_memberships m
        left join public.profiles p on p.id = m.player_id
        where m.week_start = v_day
        order by m.weekly_score desc, m.player_id
        limit 3
      ) r
    ), '[]'::jsonb)
  );
end;
$fn$;

-- İlk 3'teki birine tek dokunuşla jeton ve/veya (yalnız daily) rozet.
-- Kişinin gerçekten o dönemin ilk 3'ünde olduğu SUNUCUDA doğrulanır.
create or replace function public.admin_grant_reward(
  p_kind text, p_period_key text, p_user_id uuid, p_coins integer,
  p_badge_slug text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_cands jsonb;
  v_rank int;
  v_contest uuid;
  v_badge uuid;
begin
  perform public.admin_assert();
  if p_coins is null or p_coins not between 0 and 5000 then
    raise exception 'bad_coins' using errcode = '22023';
  end if;
  if p_coins = 0 and p_badge_slug is null then
    raise exception 'nothing_to_grant' using errcode = '22023';
  end if;
  v_cands := public.admin_list_reward_candidates(p_kind, p_period_key) -> 'candidates';
  select (e ->> 'rank')::int into v_rank
    from jsonb_array_elements(v_cands) e
   where (e ->> 'user_id')::uuid = p_user_id;
  if v_rank is null then raise exception 'not_in_top3' using errcode = '22023'; end if;

  if p_badge_slug is not null then
    if p_kind <> 'daily' then raise exception 'badge_requires_daily' using errcode = '22023'; end if;
    select id into v_badge from public.contest_badges where slug = p_badge_slug;
    select id into v_contest from public.contests where day_key = p_period_key::date limit 1;
    if v_badge is null or v_contest is null then
      raise exception 'badge_not_found' using errcode = 'P0002';
    end if;
  end if;

  begin
    insert into public.admin_reward_grants
      (period_kind, period_key, user_id, rank, coins, badge_slug, granted_by)
    values (p_kind, p_period_key, p_user_id, v_rank, p_coins, p_badge_slug, auth.uid());
  exception when unique_violation then
    -- İkinci ödül verilmez; sessiz değil, açık sonuç.
    return jsonb_build_object('granted', false, 'reason', 'already_rewarded');
  end;

  perform public._admin_credit_coins(p_user_id, p_coins, 'admin_' || p_kind || '_reward');
  if v_badge is not null then
    insert into public.user_contest_badges (user_id, badge_id, contest_id)
    values (p_user_id, v_badge, v_contest);
  end if;
  perform public.admin_log('reward_grant', 'user', p_user_id::text,
    jsonb_build_object('kind', p_kind, 'period', p_period_key, 'rank', v_rank,
                       'coins', p_coins, 'badge', p_badge_slug));
  return jsonb_build_object('granted', true, 'rank', v_rank);
end;
$fn$;

create or replace function public.admin_get_auto_reward()
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((select (value)::text::boolean from public.admin_settings where key = 'auto_reward'), true);
end;
$fn$;

-- Yalnız ayar. Otomatik verme işi (dönem sonu cron) bu göçte YOK; ayar
-- açıkken kimse kendiliğinden ödül almaz — ayrı, test'li göç.
create or replace function public.admin_set_auto_reward(p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  insert into public.admin_settings (key, value, updated_by)
  values ('auto_reward', to_jsonb(coalesce(p_enabled, false)), auth.uid())
  on conflict (key) do update
    set value = excluded.value, updated_by = excluded.updated_by, updated_at = now();
  perform public.admin_log('auto_reward_set', 'setting', 'auto_reward',
    jsonb_build_object('enabled', coalesce(p_enabled, false)));
end;
$fn$;

-- ── Kullanıcılar / şikâyetler ────────────────────────────────────────

-- Şikâyet edenin kimliği ASLA dönmez (taciz riski).
create or replace function public.admin_list_user_reports(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return coalesce((
    select jsonb_agg(to_jsonb(r))
    from (
      select pr.reported_id as user_id, p.display_name as name,
             count(*) filter (where pr.handled_at is null) as open_reports,
             (array_agg(pr.reason order by pr.created_at desc))[1] as last_reason,
             m.state, m.until
      from public.profile_reports pr
      left join public.profiles p on p.id = pr.reported_id
      left join public.user_moderation m on m.user_id = pr.reported_id
      group by pr.reported_id, p.display_name, m.state, m.until
      having count(*) filter (where pr.handled_at is null) > 0 or m.state is not null
      order by count(*) filter (where pr.handled_at is null) desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) r
  ), '[]'::jsonb);
end;
$fn$;

-- NOT: durum yazılır; oyun RPC'lerinde uygulanması AYRI göçtür (üstteki not).
create or replace function public.admin_moderate_user(
  p_user_id uuid, p_action text, p_days integer default null, p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  if p_action not in ('warn', 'block', 'suspend', 'lift') then
    raise exception 'bad_action' using errcode = '22023';
  end if;
  if p_user_id = auth.uid() or exists (select 1 from public.admins where user_id = p_user_id) then
    raise exception 'cannot_moderate_admin' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if p_action = 'suspend' and (p_days is null or p_days not between 1 and 365) then
    raise exception 'bad_days' using errcode = '22023';
  end if;

  if p_action = 'lift' then
    delete from public.user_moderation where user_id = p_user_id;
  else
    insert into public.user_moderation (user_id, state, until, note, updated_by)
    values (
      p_user_id,
      case p_action when 'warn' then 'warned' when 'block' then 'blocked' else 'suspended' end,
      case when p_action = 'suspend' then now() + make_interval(days => p_days) end,
      nullif(trim(p_note), ''), auth.uid()
    )
    on conflict (user_id) do update
      set state = excluded.state, until = excluded.until, note = excluded.note,
          updated_by = excluded.updated_by, updated_at = now();
    update public.profile_reports set handled_at = now()
     where reported_id = p_user_id and handled_at is null;
  end if;
  perform public.admin_log('user_' || p_action, 'user', p_user_id::text,
    jsonb_build_object('days', p_days, 'note', p_note));
end;
$fn$;

-- ── Sahibe anlık bildirim ────────────────────────────────────────────

create or replace function public.admin_get_notify_prefs()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  return jsonb_build_object(
    'suggestion', coalesce((select enabled from public.admin_notify_prefs where admin_id = auth.uid() and kind = 'suggestion'), true),
    'report', coalesce((select enabled from public.admin_notify_prefs where admin_id = auth.uid() and kind = 'report'), true)
  );
end;
$fn$;

create or replace function public.admin_set_notify_pref(p_kind text, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  perform public.admin_assert();
  if p_kind not in ('suggestion', 'report') then
    raise exception 'bad_kind' using errcode = '22023';
  end if;
  insert into public.admin_notify_prefs (admin_id, kind, enabled)
  values (auth.uid(), p_kind, coalesce(p_enabled, false))
  on conflict (admin_id, kind) do update set enabled = excluded.enabled;
end;
$fn$;

-- Olay → `push_outbox` (mevcut FCM işçisi gönderir). Gövde YALNIZ tür
-- bilgisi taşır; oyuncu metni bildirime konmaz. Tetikleyici işlevi
-- istemciden çağrılamaz (trigger dönüşlü, EXECUTE kapalı).
create or replace function public.admin_enqueue_push()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_kind text := case tg_table_name when 'suggested_questions' then 'suggestion' else 'report' end;
begin
  insert into public.push_outbox (to_user_id, kind, title, body)
  select a.user_id, 'admin_' || v_kind, 'ZanKurd Yönetim',
         case v_kind when 'suggestion' then 'Yeni soru önerisi' else 'Yeni şikâyet' end
  from public.admins a
  left join public.admin_notify_prefs n on n.admin_id = a.user_id and n.kind = v_kind
  where coalesce(n.enabled, true)
    and a.user_id::text is distinct from
        (to_jsonb(new) ->> case tg_table_name
          when 'suggested_questions' then 'user_id'
          else 'reporter_id'
        end);
  return new;
exception when others then
  -- Bildirim kaydı asıl işlemi (öneri/şikâyet kaydı) ASLA bozmaz.
  return new;
end;
$fn$;

drop trigger if exists trg_admin_push_suggestion on public.suggested_questions;
create trigger trg_admin_push_suggestion after insert on public.suggested_questions
  for each row execute function public.admin_enqueue_push();
drop trigger if exists trg_admin_push_question_report on public.question_reports;
create trigger trg_admin_push_question_report after insert on public.question_reports
  for each row execute function public.admin_enqueue_push();
drop trigger if exists trg_admin_push_profile_report on public.profile_reports;
create trigger trg_admin_push_profile_report after insert on public.profile_reports
  for each row execute function public.admin_enqueue_push();

-- ── Yetkiler ─────────────────────────────────────────────────────────
-- Önce hepsinden al, sonra yalnız `authenticated`a ver. İç yardımcılar
-- (admin_assert, admin_log, _admin_credit_coins, admin_enqueue_push)
-- istemciye HİÇ verilmez; `admin_*` RPC'ler owner olarak çağırır.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.proname like 'admin\_%' or p.proname = '_admin_credit_coins')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    if r.proname not in ('admin_assert', 'admin_log', '_admin_credit_coins', 'admin_enqueue_push') then
      execute format('grant execute on function %s to authenticated', r.sig);
    end if;
  end loop;
end $$;

commit;
