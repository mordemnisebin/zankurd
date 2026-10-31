-- Eski liste davetin görünürlüğünü, engelleri, süreyi ve sayfa sınırını
-- denetler. Yalnız döndürdüğü odaların, kurulumda belirlenen şartlarını ekle.
begin;

create function public.list_my_room_invites_v2()
returns table (
  invite_id uuid, room_id uuid, room_code text, inviter_id uuid,
  inviter_name text, category_name text, player_count integer,
  max_players integer, created_at timestamptz, entry_fee integer,
  question_count integer, seconds_per_question integer
)
language sql volatile security definer
set search_path = ''
as $function$
  select i.invite_id, i.room_id, i.room_code, i.inviter_id, i.inviter_name,
         i.category_name, i.player_count, i.max_players, i.created_at,
         r.entry_fee, r.question_count, r.seconds_per_question
    from public.list_my_room_invites() as i
    join public.rooms as r on r.id = i.room_id
   order by i.created_at desc, i.invite_id;
$function$;

revoke all on function public.list_my_room_invites_v2() from public, anon;
grant execute on function public.list_my_room_invites_v2() to authenticated;

commit;
