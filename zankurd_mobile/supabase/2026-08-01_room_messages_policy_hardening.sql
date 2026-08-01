-- Chat mesajları için tek, birleşik authenticated SELECT politikası.
-- Eski public politika, engellenen gönderenleri gizleme koşulunu diğer
-- permissive politika üzerinden bypass ediyordu.

begin;

drop policy if exists room_messages_read on public.room_messages;
drop policy if exists room_messages_member_select on public.room_messages;

create policy room_messages_member_select
on public.room_messages
for select
to authenticated
using (
  (
    exists (
      select 1
      from public.room_players rp
      where rp.room_id = room_messages.room_id
        and rp.player_id = auth.uid()
    )
    or exists (
      select 1
      from public.rooms r
      where r.id = room_messages.room_id
        and r.host_id = auth.uid()
    )
  )
  and not exists (
    select 1
    from public.blocked_users b
    where b.blocker_id = auth.uid()
      and b.blocked_id = room_messages.sender_id
  )
);

commit;
