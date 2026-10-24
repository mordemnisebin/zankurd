-- Salt okuma. Kişi değil yalnız sayı döndürür; kimlik ya da ad çıkmaz.
with etkinlik as (
  select player_id as uid, joined_at as t from public.room_players
  union all select creator_id, created_at from public.async_duels
  union all select opponent_id, matched_at from public.async_duels where matched_at is not null
  union all select player_id, answered_at from public.async_duel_answers
  union all select player_id, created_at from public.coin_transactions
  union all select user_id, last_viewed_at from public.user_lesson_progress where last_viewed_at is not null
  union all select user_id, event_timestamp from public.analytics_events where user_id is not null
  union all select id, last_sign_in_at from auth.users where last_sign_in_at is not null
  union all select id, created_at from auth.users
  -- Tek kişilik oyun yalnız günlük XP toplamını yazar; kullanıcı başına son gün.
  union all select id, xp_daily_date::timestamptz + interval '12 hours' from public.profiles where xp_daily_date is not null
),
hafta as (
  select generate_series(0, 7) as n
),
haftalik as (
  select h.n,
    (date_trunc('day', now()) - (h.n + 1) * interval '7 days')::date as bas,
    (select count(distinct e.uid) from etkinlik e
      where e.t >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and e.t <  date_trunc('day', now()) - h.n * interval '7 days') as aktif,
    (select count(*) from auth.users u
      where u.created_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and u.created_at <  date_trunc('day', now()) - h.n * interval '7 days') as yeni,
    -- Dönüş: o hafta açılan hesapların, açılıştan 1–7 gün sonra yeniden etkin olanları.
    (select count(distinct u.id) from auth.users u join etkinlik e on e.uid = u.id
      where u.created_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and u.created_at <  date_trunc('day', now()) - h.n * interval '7 days'
        and e.t >= u.created_at + interval '1 day'
        and e.t <  u.created_at + interval '8 days') as donen,
    (select count(*) from public.rooms r
      where r.created_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and r.created_at <  date_trunc('day', now()) - h.n * interval '7 days') as oda,
    (select count(*) from public.rooms r
      where r.finished_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and r.finished_at <  date_trunc('day', now()) - h.n * interval '7 days') as biten_oda,
    (select count(*) from public.async_duels d
      where d.created_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and d.created_at <  date_trunc('day', now()) - h.n * interval '7 days') as duello,
    (select count(*) from public.async_duels d
      where d.completed_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and d.completed_at <  date_trunc('day', now()) - h.n * interval '7 days') as biten_duello,
    (select count(*) from public.user_lesson_progress p
      where p.completed_at >= date_trunc('day', now()) - (h.n + 1) * interval '7 days'
        and p.completed_at <  date_trunc('day', now()) - h.n * interval '7 days') as biten_ders
  from hafta h
)
select bas as hafta_basi, aktif, yeni, donen,
  case when yeni > 0 and n > 0 then round(100.0 * donen / yeni) end as donus_yuzde,
  oda, biten_oda, duello, biten_duello, biten_ders
from haftalik order by bas desc;
