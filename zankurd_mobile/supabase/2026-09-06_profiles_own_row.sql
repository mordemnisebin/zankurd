-- 2026-09-06: profiles SELECT own-row.
--
-- 2026-09-02 anon SELECT kapandı ama authenticated `USING (true)` ile
-- bütün profilleri sayfalayabiliyordu. Oda/engel yüzeyi başka oyuncunun
-- adını `from('profiles')` ile okuduğu için tam kapatma bir RPC ister.
-- Idempotent.

drop policy if exists "Profiles are readable by signed-in users" on public.profiles;
drop policy if exists "Users can read own profile" on public.profiles;

create policy "Users can read own profile"
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create or replace function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  player_tag text,
  avatar_icon text,
  avatar_color text,
  avatar_url text,
  avatar_frame text,
  showcase_title text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.display_name,
    p.player_tag,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.profiles p
  where p.id = any (coalesce(p_ids, array[]::uuid[]));
$$;

revoke all on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;
grant execute on function public.get_public_profiles(uuid[]) to service_role;
