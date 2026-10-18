-- Duman testi: 2026-10-18_oda_davet.sql uygulandıktan SONRA, geri alınan
-- işlemde çalıştırılır (CANLIYA YAZMAZ: sonda rollback).
--   supabase db query --linked -f supabase/2026-10-18_oda_davet_duman.sql
-- Üç gerçek profil (a=host, b=arkadaş, c=arkadaş değil) seçilir; arkadaşlık
-- satırı, oda ve davetler işlemin içinde kurulur.
begin;

do $$
declare
  a uuid; b uuid; c uuid;
  v_room json; v_room_id uuid; v_code text;
  v_n integer; v_inv uuid; v_got text;
begin
  select id into a from public.profiles order by id limit 1;
  select id into b from public.profiles where id <> a order by id limit 1;
  select id into c from public.profiles where id not in (a, b) order by id limit 1;
  if a is null or b is null or c is null then
    raise exception 'duman: en az 3 profil gerekli';
  end if;

  delete from public.room_players where player_id in (a, b, c);
  insert into public.friends (user_id, friend_id, friend_name)
  values (a, b, 'B'), (b, a, 'A') on conflict do nothing;

  -- host a: oda kur (auth.uid() = a)
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  select public.create_online_room('Ziman', 20, 5, 0, 8) into v_room;
  v_room_id := (v_room->>'room_id')::uuid;

  -- arkadaş b davet edilir, c (arkadaş değil) sessizce atlanır
  select public.invite_friends_to_room(v_room_id, array[b, c]) into v_n;
  if v_n <> 1 then raise exception 'duman: beklenen 1 davet, gelen %', v_n; end if;
  if not exists (select 1 from public.push_outbox
                 where to_user_id = b and kind = 'room_invite') then
    raise exception 'duman: push kuyruklanmadı';
  end if;

  -- kendini / tekrar davet: sayı 1, tek satır
  perform public.invite_friends_to_room(v_room_id, array[b, b, a]);
  if (select count(*) from public.room_invites where room_id = v_room_id) <> 1 then
    raise exception 'duman: tekil davet bozuldu';
  end if;

  -- b listeyi görür, c görmez
  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  select invite_id into v_inv from public.list_my_room_invites() limit 1;
  if v_inv is null then raise exception 'duman: b daveti görmedi'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', c)::text, true);
  if exists (select 1 from public.list_my_room_invites()) then
    raise exception 'duman: c başkasının davetini gördü';
  end if;
  begin
    perform public.respond_room_invite(v_inv, true);
    raise exception 'duman: c başkasının davetini kabul edebildi';
  exception when others then
    if sqlerrm not like '%Invite not found%' then raise; end if;
  end;

  -- b kabul eder: oda kodu döner
  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  select public.respond_room_invite(v_inv, true) into v_got;
  if v_got is null or v_got <> (select code from public.rooms where id = v_room_id) then
    raise exception 'duman: kabul oda kodunu döndürmedi';
  end if;

  -- kabul davet durumunu DEĞİŞTİRMEZ (katılım henüz olmadı)
  if (select status from public.room_invites where id = v_inv) <> 'pending' then
    raise exception 'duman: kabul katılımdan önce durumu değiştirdi';
  end if;

  -- v2: yanlış kod JSON döner ve kalıcı sayılır
  select public.join_room_by_code_v2('000000') into v_room;
  if v_room->>'error' is distinct from 'room_not_found' then
    raise exception 'duman: yanlış kod room_not_found dönmedi: %', v_room;
  end if;
  if (select count(*) from public.room_code_misses where player_id = b) <> 1 then
    raise exception 'duman: yanlış deneme kaydedilmedi';
  end if;

  -- doğru kod: katılır, davet accepted olur, liste artık göstermez
  select public.join_room_by_code_v2(v_got) into v_room;
  if (v_room->>'room_id')::uuid is distinct from v_room_id then
    raise exception 'duman: v2 katılım odayı döndürmedi: %', v_room;
  end if;
  if (select status from public.room_invites where id = v_inv) <> 'accepted' then
    raise exception 'duman: katılımdan sonra davet accepted olmadı';
  end if;
  if exists (select 1 from public.list_my_room_invites()) then
    raise exception 'duman: odadaki oyuncuya davet gösteriliyor';
  end if;
  perform public.leave_room(v_room_id);

  -- 20 başarısız deneme sonrası v2 kilitlenir (c, 20 kayıt eklenir)
  insert into public.room_code_misses (player_id)
  select c from generate_series(1, 20);
  perform set_config('request.jwt.claims', json_build_object('sub', c)::text, true);
  select public.join_room_by_code_v2(v_got) into v_room;
  if v_room->>'error' is distinct from 'too_many_attempts' then
    raise exception 'duman: sınır çalışmadı: %', v_room;
  end if;

  -- oda sahibi ile davetli arasında engel: davet atlanır
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  insert into public.blocked_users (blocker_id, blocked_id) values (b, a);
  select public.invite_friends_to_room(v_room_id, array[b]) into v_n;
  if v_n <> 0 then raise exception 'duman: engelli davetli davet edildi'; end if;
  delete from public.blocked_users where blocker_id = b and blocked_id = a;

  -- red: yeniden davet sonrası declined
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  perform public.invite_friends_to_room(v_room_id, array[b]);
  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  select invite_id into v_inv from public.list_my_room_invites() limit 1;
  if public.respond_room_invite(v_inv, false) is not null then
    raise exception 'duman: red kod döndürmemeli';
  end if;
  if (select status from public.room_invites where id = v_inv) <> 'declined' then
    raise exception 'duman: red durumu yazılmadı';
  end if;

  -- 30 dk sonra: süresi dolmuş davet kabul edilemez
  update public.room_invites set status = 'pending',
    created_at = now() - interval '31 minutes' where id = v_inv;
  begin
    perform public.respond_room_invite(v_inv, true);
    raise exception 'duman: süresi dolan davet kabul edildi';
  exception when others then
    if sqlerrm not like '%Invite expired%' then raise; end if;
  end;

  raise notice 'duman: oda daveti tamam';
end $$;

rollback;
