-- `list_friends` puan ve son aktiflik döndürür (forward-only, idempotent).
--
-- Arkadaşlar sekmesi kendini "sıralama" olarak sunuyor (rank rozeti,
-- puan sütunu, çevrimiçi/çevrimdışı noktası —
-- lib/src/screens/leaderboard_screen.dart:_FriendRankRow). Ama
-- `list_friends` hiçbir sürümünde `total_score` / `last_active_at`
-- döndürmedi; `Friend.fromJson` bu alanlar yokken 0 / 1 / null'a
-- düşüyor. Sonuç: her arkadaş satırı, gerçek puanı ne olursa olsun,
-- 0 puan + Seviye 1 + "Çevrimdışı" gösteriyordu — "sıralama" adını
-- taşıyan bölüm hiçbir zaman sıralamıyordu (2026-08-14 denetimi).
--
-- `total_score`, genel liderliğin de kaynağı olan `profiles.xp`'den
-- gelir (bkz. leaderboard_view.sql / baseline'daki
-- `leaderboard_entries` view'ı — ikisi de `coalesce(p.xp, 0)`
-- kullanır). `last_active_at` için ayrı bir aktiflik tablosu yok;
-- `profiles.updated_at`, XP sunucu-otoritesi RPC'leri (bkz.
-- 2026-07-25_xp_server_authority.sql) her ödülde onu `now()`'a
-- çektiği için en yakın dürüst proxy'dir — yeni bir sütun eklemeden
-- "hiç" yerine "en son aktif olduğunda" göstermek daha doğrudur.

begin;

-- `create or replace` reddediyor: yeni sürüm `total_score`/`last_active_at`
-- OUT sütunlarını ekliyor, dönüş satır tipi değişiyor. Önce düşürüp
-- ardından yeniden oluşturmak gerekiyor; grantlar bu yüzden aşağıda
-- (eski haliyle, anon/authenticated/service_role) yeniden verilir.
drop function if exists public.list_friends();

create function public.list_friends()
returns table(
  id uuid,
  friend_id uuid,
  friend_name text,
  friend_avatar_color text,
  created_at timestamp with time zone,
  total_score integer,
  last_active_at timestamp with time zone
)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  return query
  select
    f.id,
    f.friend_id,
    coalesce(nullif(btrim(p.display_name), ''), f.friend_name),
    coalesce(p.avatar_color, f.friend_avatar_color),
    f.created_at,
    coalesce(p.xp, 0),
    p.updated_at
  from friends f
  left join profiles p on p.id = f.friend_id
  where f.user_id = v_user_id
  order by f.created_at desc;
end;
$function$;

grant all on function public.list_friends() to anon;
grant all on function public.list_friends() to authenticated;
grant all on function public.list_friends() to service_role;

commit;
