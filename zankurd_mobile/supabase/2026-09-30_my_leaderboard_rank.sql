-- 2026-09-30: sabitlenen "benim sıram" satırı DÖNEM (Gün/Hafta/Ay) puanını
-- gösterir.
--
-- NİÇİN: sıralama listesi `get_leaderboard(p_days, p_limit)` RPC'sinden
-- geliyor — yalnız BİTEN çevrimiçi odalar (`room_players` x `rooms`,
-- `rooms.status = 'finished'`), dönem `p_days` (<= 0 = tüm zamanlar) ve
-- `having coalesce(sum(rp.score), 0) > 0`. Oysa listenin altına sabitlenen
-- "senin sıran" satırı `getPlayerStats()` ile `leaderboard_entries`
-- görünümünden okunuyordu: orada `total_score = profiles.xp` (TOPLAM XP) ve
-- sıra TÜM profiller içinde. Sonuç: aynı ekranda iki ayrı sayı aynı
-- etiketle sunuluyordu (liste "bu hafta 210" derken sabit satır 1143
-- yazabiliyor) ve oyuncunun dönem puanı yokken bile satır çizilebiliyordu.
-- Artık sabit satır da AYNI süzgeçten gelen dönem sonucunu çizer.
--
-- Gövde `2026-09-30_leaderboard_positive_scores.sql`deki `get_leaderboard`
-- ile BİREBİR aynı süzgeç ve aynı sıralama anahtarlarını taşır:
--   sum(score) desc, max(streak) desc, count(distinct room_id) desc.
-- Yalnız `auth.uid()` oyuncusunun satırı döner (başkasının verisi yok);
-- puanı olmayan oyuncu için boş sonuç gelir ve istemci satırı çizmez.
--
-- `language sql stable security definer set search_path = public`; anon ve
-- public çalıştıramaz, yalnız authenticated. `create or replace` ile begin/
-- commit içinde tekrar çalıştırılabilir.

begin;

create or replace function public.get_my_leaderboard_rank(
  p_days integer default -1
)
returns table (
  rank bigint,
  player_id uuid,
  display_name text,
  total_score bigint,
  best_streak bigint,
  rooms_played bigint,
  avatar_icon text,
  avatar_color text,
  avatar_url text,
  avatar_frame text,
  showcase_title text
)
language sql
stable security definer
set search_path = public
as $$
  with board as (
    select
      rp.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(rp.score), 0) as total_score,
      coalesce(max(rp.streak), 0) as best_streak,
      count(distinct rp.room_id) as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    left join public.profiles p on p.id = rp.player_id
    where r.status = 'finished'
      and (p_days <= 0
        or r.finished_at >= now() - make_interval(days => p_days))
    group by
      rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(rp.score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc
      ) as row_no
    from board b
  )
  select
    o.row_no as rank,
    o.player_id,
    o.display_name,
    o.total_score,
    o.best_streak,
    o.rooms_played,
    o.avatar_icon,
    o.avatar_color,
    o.avatar_url,
    o.avatar_frame,
    o.showcase_title
  from ordered o
  where o.player_id = auth.uid()
  limit 1;
$$;

revoke all on function public.get_my_leaderboard_rank(integer)
  from public, anon;
grant execute on function public.get_my_leaderboard_rank(integer)
  to authenticated;

commit;
