-- Tek kullanımlık yerel Supabase test DB, iki test profili ve iki aday göç.
-- SET zankurd.test_database = 'local-only'; işlem bütünüyle geri alınır.
begin;
do $guard$
begin
  if current_setting('zankurd.test_database', true) is distinct from 'local-only'
     or (inet_server_addr() is not null and not (
       inet_server_addr() <<= '127.0.0.0/8'::inet or inet_server_addr() = '::1'::inet))
     or exists (select 1 from public.push_delivery_v2_config where enabled) then
    raise exception 'Yalnız kapalı gate ile yerel test veritabanında çalıştır';
  end if;
end;
$guard$;
alter table public.push_outbox disable trigger trg_push_outbox_wake_v2;
alter table public.profiles disable trigger trg_push_token_ready_v2;
update public.push_outbox set delivery_status = 'legacy';
update public.push_delivery_v2_config set enabled = true;
do $smoke$
declare
  host uuid; guest uuid; room uuid; prev uuid; next_id uuid; claimed record;
begin
  select id into host from public.profiles order by id limit 1;
  select id into guest from public.profiles where id <> host order by id limit 1;
  if guest is null then raise exception 'İki test profili gerekli'; end if;
  delete from public.room_players where player_id in (host, guest);
  delete from public.blocked_users where blocker_id in (host,guest) and blocked_id in (host,guest);
  update public.profiles set push_social = true, fcm_token = 'local-test' where id = guest;
  insert into public.friends(user_id,friend_id,friend_name) values(host,guest,'test') on conflict do nothing;

  perform set_config('request.jwt.claims',json_build_object('sub',host)::text,true);
  select (public.create_online_room('Ziman',20,5,0,8)->>'room_id')::uuid into room;
  perform public.invite_friends_to_room(room,array[guest]);
  perform public.invite_friends_to_room(room,array[guest]);
  select id into strict prev from public.room_invites where room_id = room and invitee_id = guest;
  if (select count(*) from public.push_outbox where data->>'invite_id'=prev::text) <> 1 then
    raise exception 'İlk bildirim veya 2 dk tekrar koruması bozuk';
  end if;
  if exists (select 1 from public.list_my_room_invites(prev)) then
    raise exception 'Davetçi davetlinin kartını sorguladı';
  end if;
  perform set_config('request.jwt.claims',json_build_object('sub',guest)::text,true);
  if not exists (select 1 from public.list_my_room_invites(prev)
                 where entry_fee=0 and question_count=5 and seconds_per_question=20) then
    raise exception 'Davet koşulları yanlış';
  end if;
  perform public.respond_room_invite(prev,false);
  update public.room_invites set created_at=now()-interval '4 minutes' where id=prev;
  perform set_config('request.jwt.claims',json_build_object('sub',host)::text,true);
  perform public.invite_friends_to_room(room,array[guest]);
  select id into strict next_id from public.room_invites where room_id=room and invitee_id=guest;
  perform set_config('request.jwt.claims',json_build_object('sub',guest)::text,true);
  if next_id=prev or exists (select 1 from public.list_my_room_invites(prev)) then
    raise exception 'Eski bildirim yeni daveti açtı';
  end if;
  select * into strict claimed from public.claim_push_outbox_v2(20);
  if claimed.data->>'invite_id' is distinct from next_id::text
    or claimed.data->>'room_id' is distinct from room::text
    or (select delivery_status from public.push_outbox where data->>'invite_id'=prev::text)
       is distinct from 'skipped' then
    raise exception 'Claim güncel kimliği seçmedi';
  end if;
end;
$smoke$;
rollback;
