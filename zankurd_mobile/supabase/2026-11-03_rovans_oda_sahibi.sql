-- T2 Rövanş ve oda sahipliği (2026-11-03). CANLIYA UYGULANMADI.
--
-- Niçin: kullanıcı geri bildirimi — "Rövanş"a basınca oda yeni bir kodla
-- açılıyor, oda sahibi rövanşa İLK BASAN oluyor, sahip ayrılınca iki kişilik
-- özel oda lobide kapanıyor ve lobide kimse (sahip bile) kategori, süre ya da
-- soru sayısını değiştiremiyor.
--
-- Ne yapar (hepsi özel odada; eşleşme/1v1 hızlı yolu değişmez):
--   1. create_room_rematch(uuid): imza ve dönüş anahtarları AYNI. Yeni lobi
--      eski bitmiş odanın KODUYLA açılır (kod o an başka AÇIK odada değilse;
--      çakışırsa create_online_room_impl'in ürettiği yeni kod kalır). Önceki
--      sahip oyunda kaldıysa rematch_owner_id ona yazılır: rövanşa ilk basan
--      geçici sahiptir, sahip lobiye girince (join yolu ya da room_heartbeat)
--      sahiplik ona geçer. Sahip ayrıldıysa basan kişi sahip kalır.
--   2. leave_room(uuid): iki kişilik ÖZEL odada lobide sahip çıkınca oda
--      host_left ile kapanmaz, en eski kalan üyeye devredilir.
--   3. room_heartbeat(uuid) YENİ: üye kendi last_seen_at'ini yazar (10 sn'de
--      en çok bir yazım) ve lobi durumunu (sahip, kategori, süre, soru sayısı)
--      döndürür. Sahip 45 sn sessiz kalırsa en eski AKTİF üyeye devredilir.
--      last_seen_at NULL = hiç sinyal vermemiş (build 42/43 istemcisi):
--      sessiz sayılmaz, böylece eski istemcideki sahip haksız yere düşmez.
--   4. update_room_settings(uuid, text[], int, int) YENİ: yalnız sahip, yalnız
--      lobide kategori, soru süresi ve soru sayısını değiştirir; giriş ücreti
--      ve kapasite DEĞİŞMEZ (ücretler ödendi). Değişimde sahip dışındaki
--      üyelerin hazır işareti sıfırlanır.
-- Eski RPC imzaları korunur; eski istemci yeni alanları görmez (devir ve ayar
-- değişikliğini lobi yoklamasında görür).
--
-- Gövdeler uygulama anındaki CANLI tanımdan (aşağıdaki ön koşul bloğu) ve
-- 2026-10-23_oda_tekrar_oyna.sql / 2026-10-24_sunucu_sertlestirme.sql
-- metinlerinden türetildi; yalnız "T2" yorumlu parçalar yenidir.
-- Geri alma: supabase/geri_al/2026-11-03_rovans_oda_sahibi.sql.
-- Çalıştırma: supabase db query --linked -f supabase/2026-11-03_rovans_oda_sahibi.sql

begin;

set local lock_timeout = '5s';

do $t2_guard$
begin
  if to_regprocedure('public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)') is null
     or to_regprocedure('public.refund_room_entry_fee(uuid,uuid)') is null
     or to_regprocedure('public.room_category_label(uuid[],text)') is null then
    raise exception 'T2: gerekli oda fonksiyonları yok';
  end if;
  if pg_get_functiondef('public.create_room_rematch(uuid)'::regprocedure) !~ 'rematch_room_id'
     and pg_get_functiondef('public.create_room_rematch(uuid)'::regprocedure) !~ 'T2 \(2026-11-03\)' then
    raise exception 'T2: canlı create_room_rematch beklenen kaynakta değil; dışa aktarıp yeniden incele';
  end if;
  if pg_get_functiondef('public.leave_room(uuid)'::regprocedure) !~ 'v_final_revealed'
     and pg_get_functiondef('public.leave_room(uuid)'::regprocedure) !~ 'T2 \(2026-11-03\)' then
    raise exception 'T2: canlı leave_room beklenen kaynakta değil; dışa aktarıp yeniden incele';
  end if;
end;
$t2_guard$;

alter table public.rooms
  add column if not exists rematch_owner_id uuid;

alter table public.room_players
  add column if not exists last_seen_at timestamptz;

-- Lobi durumunun tek JSON biçimi (room_heartbeat ve update_room_settings
-- aynı anahtarları döndürür). İç yardımcı: istemciye açık değil.
create or replace function public.room_lobby_state_json(p_room_id uuid)
returns json
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select json_build_object(
    'room_id', r.id,
    'code', r.code,
    'host_id', r.host_id,
    'status', r.status,
    'category_name', public.room_category_label(r.category_ids, c.name),
    'question_count', r.question_count,
    'seconds_per_question', coalesce(r.seconds_per_question, 20),
    'entry_fee', coalesce(r.entry_fee, 0),
    'max_players', r.max_players,
    'is_custom', r.is_custom
  )
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where r.id = p_room_id;
$function$;

revoke all on function public.room_lobby_state_json(uuid)
  from public, anon, authenticated;
grant execute on function public.room_lobby_state_json(uuid) to service_role;

-- create_room_rematch: aynı kod + önceki sahip.
create or replace function public.create_room_rematch(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_next record;
  v_names text[];
  v_result json;
  v_joined json;
  v_new_id uuid;
  v_kept_code boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.status <> 'finished' or not v_room.is_custom then
    raise exception 'Rematch not available';
  end if;

  if not exists (
    select 1 from public.room_players rp
    where rp.room_id = p_room_id and rp.player_id = v_uid
  ) then
    raise exception 'Rematch not available';
  end if;

  -- Biri yeni lobiyi zaten kurduysa ona katıl.
  if v_room.rematch_room_id is not null then
    select r.id, r.code, r.status, r.host_id, r.rematch_owner_id into v_next
    from public.rooms r
    where r.id = v_room.rematch_room_id;
    if found and v_next.status = 'lobby' then
      v_joined := public.join_room_by_code(v_next.code);

      -- T2 (2026-11-03): önceki sahip rövanşa katılınca sahiplik ona döner.
      if v_next.rematch_owner_id = v_uid and v_next.host_id <> v_uid then
        update public.rooms r
        set host_id = v_uid,
            last_activity_at = now()
        where r.id = v_next.id
          and r.status = 'lobby'
          and exists (
            select 1 from public.room_players rp
            where rp.room_id = v_next.id
              and rp.player_id = v_uid
              and rp.left_at is null
          );
        if found then
          v_joined := (v_joined::jsonb || jsonb_build_object('host_id', v_uid))::json;
        end if;
      end if;
      return v_joined;
    end if;
  end if;

  if v_room.category_ids is not null and cardinality(v_room.category_ids) > 0 then
    select array_agg(c.name order by c.name) into v_names
    from public.categories c
    where c.id = any(v_room.category_ids);
  elsif v_room.category_id is not null then
    select array[c.name] into v_names
    from public.categories c
    where c.id = v_room.category_id;
  else
    v_names := null; -- Karışık
  end if;

  -- T2: create_online_room_impl çağıranın MEVCUT açık odasını da döndürür;
  -- o durumda "rövanş" ilgisiz bir odayı işaretlerdi. Üyelik kilidi altında
  -- önce kontrol edilir: başka açık odadaysa rövanş reddedilir ve yardımcı
  -- yalnızca gerçekten YENİ oda kurar. (Aynı eski oda satırı yukarıda
  -- kilitli: eşzamanlı ikinci basan bu noktaya gelmeden rematch_room_id'yi
  -- görüp o lobiye katılır.)
  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  if exists (
    select 1
    from public.rooms r
    join public.room_players rp on rp.room_id = r.id
    where rp.player_id = v_uid
      and rp.left_at is null
      and r.status in ('lobby', 'active')
  ) then
    raise exception 'Player is already in another live room';
  end if;

  v_result := public.create_online_room_impl(
    v_names,
    coalesce(v_room.seconds_per_question, 20),
    v_room.question_count,
    coalesce(v_room.entry_fee, 0),
    coalesce(v_room.max_players, 2),
    false
  );

  v_new_id := (v_result ->> 'room_id')::uuid;

  -- Yardımcı yukarıdaki denetimden sonra yeni oda kurmuştur; yine de kodu
  -- ve sahip adayını yalnız BU çağrının kurduğu lobiye (tek üyeli, çağıran
  -- sahip, eski odadan farklı) yaz.
  if v_new_id is distinct from p_room_id
     and exists (
       select 1 from public.rooms r
       where r.id = v_new_id
         and r.status = 'lobby'
         and r.host_id = v_uid
         and (select count(*) from public.room_players rp
              where rp.room_id = r.id) = 1
     ) then
    -- Aynı kodu koru. Kod başka AÇIK odada varsa benzersiz dizin
    -- (rooms_open_upper_code_uidx) reddeder; o zaman üretilen yeni kod kalır.
    begin
      update public.rooms r
      set code = v_room.code
      where r.id = v_new_id;
      v_kept_code := true;
    exception
      when unique_violation then
        v_kept_code := false;
    end;

    if v_kept_code then
      v_result := (v_result::jsonb || jsonb_build_object('code', v_room.code))::json;
    end if;

    -- Önceki sahip oyunda kaldıysa ve basan o değilse: sahip adayı o.
    if v_room.host_id is not null
       and v_room.host_id <> v_uid
       and v_room.forfeited_by is distinct from v_room.host_id
       and exists (
         select 1 from public.room_players rp
         where rp.room_id = p_room_id
           and rp.player_id = v_room.host_id
           and rp.left_at is null
       ) then
      update public.rooms r
      set rematch_owner_id = v_room.host_id
      where r.id = v_new_id;
    end if;

    update public.rooms
    set rematch_room_id = v_new_id
    where id = p_room_id;
  end if;

  return v_result;
end;
$function$;

revoke all on function public.create_room_rematch(uuid) from public, anon;
grant execute on function public.create_room_rematch(uuid) to authenticated;

-- leave_room: iki kişilik özel odada lobide sahip devri.
CREATE OR REPLACE FUNCTION public.leave_room(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_final_revealed boolean;
  v_new_host uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  -- Tekrarlanan çıkış terminal maçın tarihsel üyeliğini değiştirmez.
  if v_room.status not in ('lobby', 'active') then
    return json_build_object(
      'status', v_room.status,
      'reason', coalesce(v_room.ended_reason, 'already_finished'),
      'forfeited_by', v_room.forfeited_by
    );
  end if;

  -- Lobiden biri ayrılınca lobi etkinliği yenilenir: misafirin room_players
  -- satırı silindiğinden joined_at kaybolur, bayat-lobi süzgeci (30 dk)
  -- bu zaman damgasına bakar. Kalabalık odayı da kapsar (aşağıdaki
  -- ortak yardımcıdan ÖNCE yazılır).
  if v_room.status = 'lobby' then
    update public.rooms r
    set last_activity_at = now()
    where r.id = p_room_id;
  end if;

  -- Kalabalık oda (is_custom ve max_players > 2): ayrılma mantığı ortak
  -- yardımcıda (lobide host devri, oyunda left_at, aktif < 2 ise erken bitiş).
  -- Aşağıdaki eski 2 kişilik yol DEĞİŞMEDEN kalır (yalnız iade çağrıları eklendi).
  if v_room.is_custom and v_room.max_players > 2 then
    return public.crowd_room_member_leave(p_room_id, v_uid);
  end if;

  update public.room_players rp
  set is_ready = false
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if v_room.status = 'active' then
    -- Son soru açıklandıktan sonra (bütün sorular bitti) çıkış maçı
    -- terketme sayılmaz: skorlar kesinleşti, kazanan 'completed' odanın XP,
    -- jeton ve lig puanını alır. crowd_room_member_leave ile aynı koruma;
    -- kaybeden son anda çıkıp kazananın ödülünü engelleyemez. İade YOK
    -- (havuz ödül talebiyle dağıtılır; ayrılan havuza katılmaz).
    select count(*) = v_room.question_count
           and bool_and(rq.revealed_at is not null)
    into v_final_revealed
    from public.room_questions rq
    where rq.room_id = p_room_id;
    v_final_revealed := coalesce(v_final_revealed, false);

    if v_final_revealed then
      update public.rooms r
      set
        status = 'finished',
        current_question_index = r.question_count,
        finished_at = coalesce(r.finished_at, now()),
        ended_reason = 'completed',
        forfeited_by = null
      where r.id = p_room_id;

      delete from public.matchmaking_queue mq
      where mq.room_id = p_room_id;

      return json_build_object(
        'status', 'finished',
        'reason', 'completed',
        'forfeited_by', null
      );
    end if;

    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'forfeit',
      forfeited_by = v_uid
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    -- Ayrılan kaybeder; haksız yere oyunsuz kalan rakibin giriş ücreti iade.
    perform public.refund_room_entry_fees(p_room_id, v_uid);

    return json_build_object(
      'status', 'finished',
      'reason', 'forfeit',
      'forfeited_by', v_uid
    );
  end if;

  if v_room.status = 'lobby' and v_room.host_id = v_uid then
    -- T2 (2026-11-03): iki kişilik ÖZEL odada da lobide sahip çıkınca oda
    -- kapanmaz; en eski kalan üyeye devredilir (kalabalık yolu
    -- crowd_room_member_leave zaten böyle). Eşleşme odası (is_custom değil)
    -- eski davranışta kalır. Kalan üye yoksa aşağıdaki host_left kapanışı.
    if v_room.is_custom then
      select rp.player_id into v_new_host
      from public.room_players rp
      where rp.room_id = p_room_id
        and rp.player_id <> v_uid
        and rp.left_at is null
      order by rp.joined_at, rp.player_id
      limit 1;

      if v_new_host is not null then
        -- Ayrılan sahip kendi ücretini geri alır, satırı silinir.
        perform public.refund_room_entry_fee(p_room_id, v_uid);

        delete from public.room_players rp
        where rp.room_id = p_room_id
          and rp.player_id = v_uid;

        update public.rooms r
        set host_id = v_new_host,
            last_activity_at = now()
        where r.id = p_room_id;

        return json_build_object(
          'status', 'left',
          'reason', 'host_transferred',
          'forfeited_by', null,
          'new_host_id', v_new_host
        );
      end if;
    end if;

    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'host_left',
      forfeited_by = null
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    perform public.refund_room_entry_fees(p_room_id, null);

    return json_build_object(
      'status', 'finished',
      'reason', 'host_left',
      'forfeited_by', null
    );
  end if;

  if v_room.status = 'lobby' then
    -- Lobiden çıkan misafir kendi giriş ücretini geri alır (satır silinmeden önce).
    perform public.refund_room_entry_fee(p_room_id, v_uid);

    delete from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = v_uid;
    return json_build_object(
      'status', 'left',
      'reason', 'guest_left',
      'forfeited_by', null
    );
  end if;

  return json_build_object(
    'status', v_room.status,
    'reason', coalesce(v_room.ended_reason, 'already_finished'),
    'forfeited_by', v_room.forfeited_by
  );
end;
$function$;

revoke all on function public.leave_room(uuid) from public, anon;
grant execute on function public.leave_room(uuid) to authenticated;

-- room_heartbeat: üye sinyali + lobi durumu + sahiplik süpürmesi.
create or replace function public.room_heartbeat(p_room_id uuid)
returns json
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_new_host uuid;
  v_owner_back boolean;
  v_host_silent boolean;
  c_grace constant interval := interval '45 seconds';
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = v_uid
      and rp.left_at is null
  ) then
    raise exception 'Player is not in the room';
  end if;

  -- En çok 10 sn'de bir yazım: 50 kişilik lobide yazma yükü düşük kalır.
  update public.room_players rp
  set last_seen_at = clock_timestamp()
  where rp.room_id = p_room_id
    and rp.player_id = v_uid
    and (rp.last_seen_at is null
         or rp.last_seen_at < clock_timestamp() - interval '10 seconds');

  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id;

  if found and v_room.status = 'lobby' and v_room.is_custom then
    -- Kilitsiz ön okuma: çoğu çağrıda devir gerekmez, oda satırı kilitlenmez.
    v_owner_back := v_room.rematch_owner_id is not null
      and v_room.host_id <> v_room.rematch_owner_id;
    v_host_silent := exists (
      select 1 from public.room_players rp
      where rp.room_id = p_room_id
        and rp.player_id = v_room.host_id
        and rp.left_at is null
        and rp.last_seen_at is not null
        and rp.last_seen_at < clock_timestamp() - c_grace
    );

    if v_owner_back or v_host_silent then
      select r.* into v_room
      from public.rooms r
      where r.id = p_room_id
      for update;

      if v_room.status = 'lobby' then
        v_new_host := null;

        -- Rövanşın önceki sahibi lobide ve sessiz değilse sahiplik onundur.
        if v_room.rematch_owner_id is not null
           and v_room.host_id <> v_room.rematch_owner_id
           and exists (
             select 1 from public.room_players rp
             where rp.room_id = p_room_id
               and rp.player_id = v_room.rematch_owner_id
               and rp.left_at is null
               and (rp.last_seen_at is null
                    or rp.last_seen_at >= clock_timestamp() - c_grace)
           ) then
          v_new_host := v_room.rematch_owner_id;
        elsif exists (
          select 1 from public.room_players rp
          where rp.room_id = p_room_id
            and rp.player_id = v_room.host_id
            and rp.left_at is null
            and rp.last_seen_at is not null
            and rp.last_seen_at < clock_timestamp() - c_grace
        ) then
          -- Sessiz sahip: en eski AKTİF (son 45 sn içinde sinyal vermiş) üye.
          select rp.player_id into v_new_host
          from public.room_players rp
          where rp.room_id = p_room_id
            and rp.player_id <> v_room.host_id
            and rp.left_at is null
            and rp.last_seen_at >= clock_timestamp() - c_grace
          order by rp.joined_at, rp.player_id
          limit 1;
        end if;

        if v_new_host is not null and v_new_host <> v_room.host_id then
          update public.rooms r
          set host_id = v_new_host,
              -- Devirden sonra önceki sahibe geri dönüş döngüsü olmasın.
              rematch_owner_id = case
                when r.rematch_owner_id = v_new_host then r.rematch_owner_id
                else null
              end,
              last_activity_at = now()
          where r.id = p_room_id;
        end if;
      end if;
    end if;
  end if;

  return public.room_lobby_state_json(p_room_id);
end;
$function$;

revoke all on function public.room_heartbeat(uuid) from public, anon;
grant execute on function public.room_heartbeat(uuid) to authenticated;

-- update_room_settings: lobide sahip ayarları (ücret/kapasite hariç).
create or replace function public.update_room_settings(
  p_room_id uuid,
  p_category_names text[],
  p_seconds_per_question integer,
  p_question_count integer
)
returns json
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_category_id uuid;
  v_category_ids uuid[];
  v_wanted text[];
  v_found_ids uuid[];
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- create_online_room_impl ile AYNI izinli değerler (2026-10-31_room_limits).
  if p_seconds_per_question is null
     or p_seconds_per_question not in (10, 15, 20, 30, 45, 60, 90, 120) then
    raise exception 'Unsupported seconds per question';
  end if;

  if p_question_count is null
     or p_question_count not in (5, 10, 15, 20, 25, 30, 40, 50) then
    raise exception 'Unsupported question count';
  end if;

  -- Kategori: NULL ya da boş dizi = Karışık; tek ad = category_id; çok ad =
  -- category_ids (create_online_room_impl ile aynı kural).
  if p_category_names is not null and cardinality(p_category_names) > 0 then
    if cardinality(p_category_names) > 12
       or exists (
         select 1 from unnest(p_category_names) n
         where nullif(btrim(n), '') is null
       ) then
      raise exception 'Category is not available';
    end if;

    select array_agg(distinct upper(btrim(n))) into v_wanted
    from unnest(p_category_names) n;

    select array_agg(c.id order by c.name) into v_found_ids
    from public.categories c
    where upper(c.name) = any(v_wanted)
      and c.is_active = true;

    if v_found_ids is null
       or cardinality(v_found_ids) <> cardinality(v_wanted) then
      raise exception 'Category is not available';
    end if;

    if cardinality(v_found_ids) = 1 then
      v_category_id := v_found_ids[1];
    else
      v_category_ids := v_found_ids;
    end if;
  end if;

  -- start_room_game ile aynı oda satır kilidi: ayar değişimi ve başlatma
  -- yarışamaz.
  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found or v_room.host_id is distinct from v_uid then
    raise exception 'Only the room host can change settings';
  end if;

  if v_room.status <> 'lobby' or not v_room.is_custom then
    raise exception 'Room settings can only change in the lobby';
  end if;

  if (v_room.category_id is distinct from v_category_id
      or v_room.category_ids is distinct from v_category_ids
      or v_room.seconds_per_question is distinct from p_seconds_per_question
      or v_room.question_count is distinct from p_question_count) then
    update public.rooms r
    set category_id = v_category_id,
        category_ids = v_category_ids,
        seconds_per_question = p_seconds_per_question,
        question_count = p_question_count,
        last_activity_at = now()
    where r.id = p_room_id;

    -- Ayarı görmeden "hazırım" demiş olanlar yeniden onaylar.
    update public.room_players rp
    set is_ready = false
    where rp.room_id = p_room_id
      and rp.player_id <> v_uid
      and rp.left_at is null;
  end if;

  return public.room_lobby_state_json(p_room_id);
end;
$function$;

revoke all on function public.update_room_settings(uuid, text[], integer, integer)
  from public, anon;
grant execute on function public.update_room_settings(uuid, text[], integer, integer)
  to authenticated;

commit;
