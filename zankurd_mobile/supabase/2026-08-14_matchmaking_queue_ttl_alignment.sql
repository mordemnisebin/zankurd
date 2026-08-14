-- İstemci-sunucu hayalet kuyruk satırı zaman aşımı uyuşmazlığını kapatır.
--
-- `matchmaking_screen.dart` oyuncu 20 saniyede eşleşme bulamazsa yerel
-- olarak vazgeçip `cancelMatchmaking()` çağırıyor ve bot teklifini açıyor.
-- Ama `join_matchmaking()` içindeki hayalet-satır temizliği (aşağıdaki
-- `2026-08-02_multiplayer_session_hardening.sql`'den devralınan tarama)
-- yalnız 2 DAKİKADAN eski satırları siliyordu. `cancelMatchmaking()` RPC'si
-- ağ kopması/uygulamanın arka plana atılması yüzünden sunucuya hiç
-- ulaşmazsa, 20sn'de vazgeçmiş bir oyuncunun satırı sunucuda 100 saniye
-- DAHA "eşleştirilebilir" kalıyor — o sırada gelen üçüncü bir oyuncu,
-- artık orada olmayan biriyle "eşleşebiliyor" (2026-08-14 denetimi).
--
-- İstemci tarafının 20sn'lik vazgeçme süresi BİLEREK KISA tutulmuş bir UX
-- kararı (kimse eşleşme için 2 dakika beklemek istemez) — bu yüzden çözüm
-- istemciyi sunucunun 2 dakikasına UZATMAK değil, sunucunun temizlik
-- penceresini istemcinin gerçek vazgeçme anına YAKLAŞTIRMAK: 20sn + ağ/RPC
-- gecikmesi için cömert bir pay = 40 saniye. Bu, normal eşleşme
-- gecikmesini (birkaç saniye) hâlâ rahatça karşılarken hayalet pencereyi
-- 100 saniyeden ~20 saniyeye indiriyor.
create or replace function public.join_matchmaking(
  p_category_name text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_opponent uuid;
  v_room_id uuid;
  v_room_code text;
  v_queue_room_id uuid;
  v_category_id uuid;
  v_category_name text;
  v_opponent_name text;
  v_snapshot json;
  v_start json;
  v_attempt integer;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));

  -- Aynı oyuncunun ağ tekrarı/çift dokunuş çağrılarını transaction boyunca
  -- sırala. Rakibin kuyruk satırı ayrıca aşağıda `FOR UPDATE` ile kilitlenir.
  perform pg_advisory_xact_lock(hashtextextended(v_player_id::text, 0));

  -- Önce mevcut canlı üyelik: başarılı ilk çağrının cevabı kaybolduysa yeni
  -- oda üretmek yerine aynı sunucu snapshot'ını döndür.
  select json_build_object(
    'status', 'matched',
    'room_id', r.id,
    'code', r.code,
    'host_id', r.host_id,
    'category_name', coalesce(c.name, 'Ziman'),
    'question_count', r.question_count,
    'seconds_per_question', coalesce(r.seconds_per_question, 20),
    'opponent_name', coalesce(opponent.display_name, 'Hevrik')
  )
  into v_snapshot
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_player_id
  left join public.categories c on c.id = r.category_id
  left join lateral (
    select p.display_name
    from public.room_players other
    join public.profiles p on p.id = other.player_id
    where other.room_id = r.id
      and other.player_id <> v_player_id
    order by other.joined_at
    limit 1
  ) opponent on true
  where r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    return v_snapshot;
  end if;

  -- "Rastgele" gerçek bir kategori değil, bütün hızlı eşleşme çağrılarının
  -- buluştuğu sanal kuyruktur. Gerçek kategori ancak iki oyuncu eşleşince
  -- aşağıda bir kez seçilir; aksi hâlde her istemcinin ayrı kategori çekmesi
  -- oyuncu havuzunu parçalar.
  if upper(trim(coalesce(p_category_name, ''))) = 'RASTGELE' then
    v_category_name := 'Rastgele';
  else
    select c.id, c.name
    into v_category_id, v_category_name
    from public.categories c
    where upper(c.name) = upper(trim(p_category_name))
      and c.is_active = true
    limit 1;
  end if;

  if v_category_name is null then
    raise exception 'Category is not available';
  end if;

  -- Farklı iki oyuncunun ilk çağrısı aynı anda geldiğinde ikisinin de
  -- birbirini görmeden ayrı waiting satırı açmasını önler. Bu kilit kendi
  -- queue satırından ÖNCE alınır; ters sıra cancel/join deadlock'u üretirdi.
  perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));

  -- Rakip bu satırı eşleştirme anında kilitlediyse burada beklenir. Kilit
  -- açıldığında `room_id` yeniden değerlendirilir; eşleşmiş satır silinmez.
  select mq.room_id into v_queue_room_id
  from public.matchmaking_queue mq
  where mq.player_id = v_player_id
  for update;

  if found and v_queue_room_id is not null then
    select json_build_object(
      'status', 'matched',
      'room_id', r.id,
      'code', r.code,
      'host_id', r.host_id,
      'category_name', coalesce(c.name, 'Ziman'),
      'question_count', r.question_count,
      'seconds_per_question', coalesce(r.seconds_per_question, 20),
      'opponent_name', coalesce(opponent.display_name, 'Hevrik')
    )
    into v_snapshot
    from public.rooms r
    join public.room_players mine
      on mine.room_id = r.id and mine.player_id = v_player_id
    left join public.categories c on c.id = r.category_id
    left join lateral (
      select p.display_name
      from public.room_players other
      join public.profiles p on p.id = other.player_id
      where other.room_id = r.id
        and other.player_id <> v_player_id
      order by other.joined_at
      limit 1
    ) opponent on true
    where r.id = v_queue_room_id
      and r.status in ('lobby', 'active');

    if found then
      return v_snapshot;
    end if;

    -- Yalnız canlı ve yetkili üyelikle desteklenmeyen eski matched satırı
    -- temizlenir. Aktif eşleşme yukarıdaki üyelik snapshot'ından dönmüştür.
    delete from public.matchmaking_queue mq
    where mq.player_id = v_player_id
      and mq.room_id = v_queue_room_id
      and not exists (
        select 1
        from public.rooms live_room
        join public.room_players live_player
          on live_player.room_id = live_room.id
        where live_room.id = v_queue_room_id
          and live_player.player_id = v_player_id
          and live_room.status in ('lobby', 'active')
      );

    if not found then
      raise exception 'Matched queue membership is unavailable';
    end if;
  end if;

  -- Yalnız hâlâ bekleyen kendi satırı yenilenebilir. `room_id` dolu satır
  -- yukarıda döndürüldüğü için hiçbir retry onu silemez.
  delete from public.matchmaking_queue mq
  where mq.player_id = v_player_id
    and mq.room_id is null;

  -- 2026-08-14: '2 minutes' → '40 seconds' — bkz. dosya başı yorumu.
  delete from public.matchmaking_queue mq
  where mq.room_id is null
    and upper(mq.category_name) = upper(v_category_name)
    and mq.joined_at < now() - interval '40 seconds';

  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)
    and mq.player_id <> v_player_id
    and mq.room_id is null
    and not exists (
      select 1
      from public.blocked_users outbound_block
      where outbound_block.blocker_id = v_player_id
        and outbound_block.blocked_id = mq.player_id
    )
    and not exists (
      select 1
      from public.blocked_users inbound_block
      where inbound_block.blocker_id = mq.player_id
        and inbound_block.blocked_id = v_player_id
    )
    and not exists (
      select 1
      from public.room_players existing_player
      join public.rooms existing_room
        on existing_room.id = existing_player.room_id
      where existing_player.player_id = mq.player_id
        and existing_room.status in ('lobby', 'active')
    )
  order by mq.joined_at asc
  limit 1
  for update skip locked;

  if v_opponent is null then
    insert into public.matchmaking_queue (
      player_id,
      category_name,
      room_id
    ) values (
      v_player_id,
      v_category_name,
      null
    );

    return json_build_object('status', 'waiting');
  end if;

  -- Sanal rastgele kuyruğu aynı rakibi bulduktan sonra tek bir gerçek ve
  -- etkin kategoriye çözülür; iki oyuncu da oda snapshot'ından aynı adı alır.
  if v_category_id is null then
    select c.id, c.name
    into v_category_id, v_category_name
    from public.categories c
    where c.is_active = true
    order by random()
    limit 1;

    if v_category_id is null then
      raise exception 'Category is not available';
    end if;
  end if;

  v_attempt := 0;
  loop
    v_attempt := v_attempt + 1;
    v_room_code := 'ZK-' || upper(
      substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
    );

    begin
      insert into public.rooms (
        code,
        host_id,
        category_id,
        question_count,
        seconds_per_question,
        status
      ) values (v_room_code, v_player_id, v_category_id, 10, 20, 'lobby')
      returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values
    (v_room_id, v_opponent, true),
    (v_room_id, v_player_id, true);

  update public.matchmaking_queue mq
  set room_id = v_room_id
  where mq.player_id = v_opponent;

  v_start := public.start_room_game(v_room_id);

  select p.display_name into v_opponent_name
  from public.profiles p
  where p.id = v_opponent;

  return json_build_object(
    'status', 'matched',
    'room_id', v_room_id,
    'code', v_room_code,
    'host_id', v_player_id,
    'category_name', v_category_name,
    'question_count', (v_start ->> 'question_count')::integer,
    'seconds_per_question', 20,
    'opponent_name', coalesce(v_opponent_name, 'Hevrik')
  );
end;
$$;

revoke all on function public.join_matchmaking(text) from public, anon;
grant execute on function public.join_matchmaking(text) to authenticated;
