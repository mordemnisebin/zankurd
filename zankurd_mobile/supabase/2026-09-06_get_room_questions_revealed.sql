-- 2026-09-06: get_room_questions yalnız geçilmiş soruda doğru şıkkı açar.
--
-- Aktif ve gelecek sorularda correct_option hâlâ gizlidir. Geçilmiş
-- index (current_question_index'den küçük) veya bitmiş oda inceleme
-- için şıkkı döndürür. questions tablosu SELECT kapalı kalır.
-- Idempotent: create or replace.

create or replace function public.get_room_questions(
  p_room_id uuid
) returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_index integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = auth.uid()
  ) and not exists (
    select 1
    from public.rooms r
    where r.id = p_room_id
      and r.host_id = auth.uid()
  ) then
    raise exception 'Player is not in the room';
  end if;

  select r.status, coalesce(r.current_question_index, 0)
    into v_status, v_index
  from public.rooms r
  where r.id = p_room_id;

  return query
  select jsonb_build_object(
    'id', q.id,
    'category_name', coalesce(c.name, 'Ziman'),
    'prompt', q.prompt,
    'option_a', q.option_a,
    'option_b', q.option_b,
    'option_c', q.option_c,
    'option_d', q.option_d,
    'question_type', q.question_type,
    'image_url', q.image_url,
    'difficulty', q.difficulty,
    'correct_option', case
      when v_status = 'finished' or rq.question_index < v_index
        then q.correct_option
      else null
    end
  )
  from public.room_questions rq
  join public.questions q on q.id = rq.question_id
  left join public.categories c on c.id = q.category_id
  where rq.room_id = p_room_id
  order by rq.question_index;
end;
$$;

revoke all on function public.get_room_questions(uuid) from public, anon;
grant execute on function public.get_room_questions(uuid) to authenticated;
grant execute on function public.get_room_questions(uuid) to service_role;
