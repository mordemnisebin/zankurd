-- 2026-09-30: sıralama 0 puanlı oyuncuları döndürmez.
--
-- Canlı denetimde (simülatör, misafir) bir odaya girip 0 puanla ayrılan
-- oyuncu Gün/Hafta/Ay sıralamalarında "0 puan" satırı olarak çıkıyordu; Ay
-- sekmesinde birden çok ad sıfırla sıralanıyordu. Sıfır puan sıralama değil
-- gürültüdür. İstemci (leaderboard_screen) 2026-09-30'dan beri bu satırları
-- zaten süzüyor; eski sürümler için de kaynağında kesilir.
--
-- Gövde canlıdaki tanımla birebir aynıdır (pg_get_functiondef, 2026-09-30);
-- yalnız `having` satırı eklendi. İmza, dönüş tipi, SECURITY DEFINER ve
-- search_path değişmez; CREATE OR REPLACE mevcut yetkileri korur.
-- Yeniden çalıştırılabilir.

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_days integer DEFAULT '-1'::integer, p_limit integer DEFAULT 10)
 RETURNS TABLE(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(rp.score), 0),
    coalesce(max(rp.streak), 0),
    count(distinct rp.room_id),
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
  group by
    rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(rp.score), 0) > 0
  order by coalesce(sum(rp.score), 0) desc,
    coalesce(max(rp.streak), 0) desc,
    count(distinct rp.room_id) desc
  limit least(greatest(p_limit, 1), 100);
$function$;
