-- 2026-10-16: KALABALIK ODA — özel odalarda 2..50 oyuncu (Kahoot gibi).
--
-- NİÇİN: Sahip, oda başına onlarca kişi istedi. Bugün bütün oda mantığı "tam
-- 2 oyuncu" varsayıyordu (join_room_by_code >= 2 dolu, start_room_game tam 2 +
-- herkes hazır, submit_answer/advance_room_question 2 cevap, leave_room ayrılan
-- = oda forfeit, sonuç/anlık görüntü tam 2 oyuncu ...) ve özel oda ile hızlı
-- eşleşme odası birbirinden AYIRT EDİLEMİYORDU. Ayrıca bir veri kaçağı vardı:
-- host_left / stale_timeout / opponent_not_ready / forfeit odalarında giriş
-- ücreti ne ödül ne iade oluyordu (ücret girişte düşer).
--
-- ÖN KOŞUL: `2026-10-16_kalabalik_oda_odul.sql` ÖNCE uygulanır (iade
-- yardımcıları `refund_room_entry_fee(s)` orada; bu dosyadaki fonksiyonlar onları
-- çağırır). Aşağıdaki DO bloğu yardımcı yoksa göçü başlamadan durdurur.
--
-- SÖZLEŞME:
--   * Kalabalık oda = rooms.is_custom AND rooms.max_players > 2. Yalnız bunlar
--     yeni kuralları izler. Hızlı eşleşme odası (is_custom=false, max_players=2,
--     join_matchmaking'in varsayılanı) VE kapasitesi 2 olan özel oda (eski
--     istemcinin create_online_room çağrısı) bugünkü 2 kişilik yolu AYNEN izler:
--     her fonksiyonda yeni dal `if/elsif` ya da `(not v_crowd or ...)` kapısının
--     ARKASINDADIR; eski dal canlı gövdenin metnidir.
--   * room_players.left_at: NULL = aktif. Yalnız kalabalık dallarında yazılır
--     (oyunda ayrılma, hazır olmayanın düşmesi). Eski odada hiç yazılmadığı için
--     `left_at is null` süzgeçleri eski odada hiçbir satırı elemez.
--
-- DEĞİŞEN FONKSİYONLAR (hepsi CANLI tanımdan türetildi; 2026-10-15 1v1 canlılık
-- göçündeki 45 sn, touch_matchmaking ve kalp atışı değişiklikleri KORUNDU):
--   create_online_room (YENİ imza: + p_max_players default 2; eski 4 parametreli
--     imza düşürülür, eski istemci çağrısı varsayılanla 2 kişilik oda kurar),
--   join_room_by_code, start_room_game, mark_room_client_ready,
--   advance_room_question, submit_answer, enforce_current_room_question,
--   recalculate_room_player_scores, leave_room, cleanup_stale_rooms,
--   get_room_result_payload, acknowledge_room_result, delete_my_account,
--   get_my_resumable_room, join_matchmaking, touch_matchmaking,
--   cancel_matchmaking (son üçü ve resumable yalnız: ayrılan oyuncu "canlı oda
--   üyesi" sayılmasın -> `left_at is null`).
-- YENİ İÇ YARDIMCILAR (istemciye açık değil): crowd_room_member_leave,
--   room_result_players, room_result_winner, crowd_room_result_complete.
-- DEĞİŞMEYEN: ödül talebi RPC'si (başka dal değiştiriyor; havuz bölüşümü için
--   odul dosyasındaki TODO'ya bakın), get_my_room_result/get_my_pending_room_result
--   (get_room_result_payload'a sarmalayıcı, otomatik N-güvenli), set_room_ready,
--   finish_room_game, award_room_xp.
--
-- BİLİNÇLİ KARARLAR:
--   * Kalabalık odada istemci-hazır süresi 20 sn (tasarım); 1v1 45 sn kalır.
--   * Kalabalık odada oyundan ayrılan oyuncu satırı silinmez (left_at); sonuç
--     listesinde en sonda, rank'sız ('left': true) görünür ve havuza katılmaz.
--   * Kalan aktif < 2 olunca oda 'completed' biter (kalan kazanır); kalanların
--     giriş ücreti iade edilir, ayrılanlar kaybeder. Havuz bölüşümü yalnız tüm
--     soruları oynanmış odada (ödül talebi RPC'si) yapılır.
--
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-10-16_kalabalik_oda.sql`
-- (önce `...kalabalik_oda_odul.sql`). Geri alma: eski gövdeler
-- 2026-10-15_matchmaking_canlilik.sql, 2026-10-02_room_recent_questions.sql ve
-- 2026-08-02_multiplayer_session_hardening.sql içindedir; sütunlar zararsız kalır.

begin;

do $$
begin
  if to_regprocedure('public.refund_room_entry_fees(uuid, uuid, boolean)') is null
     or to_regprocedure('public.refund_room_entry_fee(uuid, uuid)') is null then
    raise exception
      'Önce 2026-10-16_kalabalik_oda_odul.sql uygulanmalı (iade yardımcıları yok)';
  end if;
end;
$$;

alter table public.rooms
  add column if not exists is_custom boolean not null default false;
alter table public.rooms
  add column if not exists max_players integer not null default 2;
alter table public.room_players
  add column if not exists left_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'rooms_max_players_check'
      and conrelid = 'public.rooms'::regclass
  ) then
    alter table public.rooms
      add constraint rooms_max_players_check
      check (max_players between 2 and 50);
  end if;

  -- Eşleşme odası (is_custom=false) hep 2 kişilik kalır.
  if not exists (
    select 1 from pg_constraint
    where conname = 'rooms_non_custom_two_players_check'
      and conrelid = 'public.rooms'::regclass
  ) then
    alter table public.rooms
      add constraint rooms_non_custom_two_players_check
      check (is_custom or max_players = 2);
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- İç yardımcılar (istemciye açık değil)
-- ---------------------------------------------------------------------
create or replace function public.crowd_room_member_leave(
  p_room_id uuid,
  p_player_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_room public.rooms%rowtype;
  v_left_at timestamp with time zone;
  v_new_host uuid;
  v_active integer;
  v_now timestamp with time zone := clock_timestamp();
begin
  -- İÇ YARDIMCI (istemciye açık değil): leave_room ve delete_my_account
  -- kalabalık odada ayrılma mantığını burada paylaşır. Çağıran odayı zaten
  -- kilitlemiştir; yine de kilidi (aynı transaction) yeniden alırız.
  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  if not (v_room.is_custom and v_room.max_players > 2) then
    raise exception 'Not a crowd room';
  end if;

  select rp.left_at into v_left_at
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.player_id = p_player_id;

  if not found then
    -- leave_room üyeliği zaten doğrular; buraya yalnız delete_my_account'ın
    -- "host ya da üye" taraması üyeliği olmayan bir host için düşebilir.
    return json_build_object(
      'status', 'left',
      'reason', 'not_member',
      'forfeited_by', null
    );
  end if;

  if v_room.status not in ('lobby', 'active') then
    return json_build_object(
      'status', v_room.status,
      'reason', coalesce(v_room.ended_reason, 'already_finished'),
      'forfeited_by', v_room.forfeited_by
    );
  end if;

  if v_room.status = 'lobby' then
    if v_room.host_id = p_player_id then
      -- Lobide host çıkarsa oda KAPANMAZ: host en erken katılan aktif
      -- oyuncuya devredilir. Aktif kimse kalmadıysa oda host_left kapanır.
      select rp.player_id into v_new_host
      from public.room_players rp
      where rp.room_id = p_room_id
        and rp.player_id <> p_player_id
        and rp.left_at is null
      order by rp.joined_at, rp.player_id
      limit 1;

      if v_new_host is null then
        update public.rooms r
        set
          status = 'finished',
          finished_at = coalesce(r.finished_at, v_now),
          ended_reason = 'host_left',
          forfeited_by = null
        where r.id = p_room_id;

        delete from public.matchmaking_queue mq
        where mq.room_id = p_room_id;

        perform public.refund_room_entry_fees(p_room_id, null, true);

        return json_build_object(
          'status', 'finished',
          'reason', 'host_left',
          'forfeited_by', null
        );
      end if;

      -- Ayrılan host kendi ücretini geri alır, satırı silinir.
      perform public.refund_room_entry_fee(p_room_id, p_player_id);

      delete from public.room_players rp
      where rp.room_id = p_room_id
        and rp.player_id = p_player_id;

      update public.rooms r
      set host_id = v_new_host
      where r.id = p_room_id;

      return json_build_object(
        'status', 'left',
        'reason', 'host_transferred',
        'forfeited_by', null,
        'new_host_id', v_new_host
      );
    end if;

    perform public.refund_room_entry_fee(p_room_id, p_player_id);

    delete from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = p_player_id;

    return json_build_object(
      'status', 'left',
      'reason', 'guest_left',
      'forfeited_by', null
    );
  end if;

  -- Oyun sürerken ayrılma: satır silinmez, left_at yazılır (skor/cevaplar
  -- kalır, oyuncu aktif sayılmaz). Oyun diğerleriyle sürer.
  if v_left_at is null then
    update public.room_players rp
    set
      left_at = v_now,
      is_ready = false
    where rp.room_id = p_room_id
      and rp.player_id = p_player_id;
  end if;

  -- host_id canlı odada null olamaz (rooms_live_host_required) ve hesap
  -- silinirse FK onu null'a çekerdi: host oyunu bırakırsa devret.
  if v_room.host_id = p_player_id then
    select rp.player_id into v_new_host
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id <> p_player_id
      and rp.left_at is null
    order by rp.joined_at, rp.player_id
    limit 1;

    if v_new_host is not null then
      update public.rooms r
      set host_id = v_new_host
      where r.id = p_room_id;
    end if;
  end if;

  select count(*)::integer into v_active
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.left_at is null;

  if v_active < 2 and not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
      and rq.started_at is not null
  ) then
    -- Hiçbir soru başlamadan (istemci-hazır penceresinde) herkes ayrıldı:
    -- oynanmış oyun yok; mark_room_client_ready ile aynı sonuç, herkese iade.
    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, v_now),
      ended_reason = 'opponent_not_ready',
      forfeited_by = null
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    perform public.refund_room_entry_fees(p_room_id, null, true);

    return json_build_object(
      'status', 'finished',
      'reason', 'opponent_not_ready',
      'forfeited_by', null
    );
  end if;

  if v_active < 2 then
    -- Kalan 1 (ya da 0) oyuncu: oda 'completed' biter, kalan kazanır.
    -- Sonuç ekranı skor tutarlılığı arar; cevaplanıp henüz açıklanmamış
    -- soru puanı da dahil skor = cevap puanları toplamına eşitlenir.
    update public.room_players rp
    set score = coalesce((
      select sum(pa.points_awarded)::integer
      from public.player_answers pa
      where pa.room_id = rp.room_id
        and pa.player_id = rp.player_id
    ), 0)
    where rp.room_id = p_room_id;

    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, v_now),
      ended_reason = 'completed',
      forfeited_by = null
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    -- Ayrılanlar kaybeder; kalanların girişi iade edilir (ödül havuzu
    -- tamamlanmamış oyunda dağıtılmaz: ödül talebi RPC'si 'completed' ve
    -- tüm soruların oynanmasını ister).
    perform public.refund_room_entry_fees(p_room_id, null, false);

    return json_build_object(
      'status', 'finished',
      'reason', 'completed',
      'forfeited_by', null
    );
  end if;

  return json_build_object(
    'status', 'left',
    'reason', 'left_mid_game',
    'forfeited_by', null
  );
end;
$function$;

create or replace function public.room_result_players(
  p_room_id uuid,
  p_mask_player uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $function$
  -- Kalabalık oda sonucu: AKTİF oyuncular skora göre sıralanır, eşit skor
  -- aynı rank'ı paylaşır (1,1,3 …). Ayrılan/düşen oyuncular listenin sonunda,
  -- rank'sız (null) ve 'left': true ile gelir. p_mask_player: hesabı silinen
  -- oyuncunun kimliği/adı anonimleştirilir (delete_my_account anlık görüntüsü).
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'player_id', case
          when p_mask_player is not null and ranked.player_id = p_mask_player
            then '00000000-0000-0000-0000-000000000000'::uuid
          else ranked.player_id
        end,
        'display_name', case
          when p_mask_player is not null and ranked.player_id = p_mask_player
            then 'Hesabê jêbirî'
          else coalesce(nullif(trim(ranked.display_name), ''), 'Hevrik')
        end,
        'final_score', ranked.score,
        'final_streak', ranked.streak,
        'rank', ranked.player_rank,
        'left', ranked.is_left
      ) order by ranked.is_left, ranked.score desc, ranked.joined_at,
        ranked.player_id
    ),
    '[]'::jsonb
  )
  from (
    select
      rp.player_id,
      p.display_name,
      rp.score,
      rp.streak,
      rp.joined_at,
      (rp.left_at is not null) as is_left,
      case
        when rp.left_at is null then
          rank() over (
            partition by (rp.left_at is null)
            order by rp.score desc
          )::integer
        else null
      end as player_rank
    from public.room_players rp
    join public.profiles p on p.id = rp.player_id
    where rp.room_id = p_room_id
  ) ranked;
$function$;

create or replace function public.room_result_winner(
  p_room_id uuid,
  p_mask_player uuid default null
)
returns uuid
language sql
stable
security definer
set search_path = public
as $function$
  -- Kalabalık odada tek bir birinci varsa onun kimliği; en yüksek skor
  -- paylaşılıyorsa (ya da aktif oyuncu yoksa) null.
  select case
    when count(*) = 1 then
      case
        when p_mask_player is not null
          and (array_agg(top.player_id))[1] = p_mask_player
          then '00000000-0000-0000-0000-000000000000'::uuid
        else (array_agg(top.player_id))[1]
      end
    else null
  end
  from (
    select rp.player_id
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.left_at is null
      and rp.score = (
        select max(best.score)
        from public.room_players best
        where best.room_id = p_room_id
          and best.left_at is null
      )
  ) top;
$function$;

create or replace function public.crowd_room_result_complete(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $function$
  -- Kalabalık oda sonucunun "tamam" sayılma koşulu (get_room_result_payload,
  -- acknowledge_room_result, delete_my_account anlık görüntüsü ortak kullanır).
  --   * oda 'completed' bitmiş ve tam kapanmış;
  --   * ya erken bitti (kalan aktif < 2: current_question_index < soru sayısı),
  --   * ya da bütün sorular açıklanmış ve her AKTİF oyuncu tüm soruları
  --     cevaplamış;
  --   * skorlar cevap puanları toplamıyla tutarlı (ayrılanlar dahil);
  --   * en az bir aktif oyuncu var.
  select exists (
    select 1
    from public.rooms r
    where r.id = p_room_id
      and r.is_custom
      and r.max_players > 2
      and r.status = 'finished'
      and r.ended_reason = 'completed'
      and r.forfeited_by is null
      and r.finished_at is not null
      and r.question_count > 0
      and exists (
        select 1
        from public.room_players active_member
        where active_member.room_id = r.id
          and active_member.left_at is null
      )
      and (
        coalesce(r.current_question_index, -1) < r.question_count
        or (
          exists (
            select 1
            from public.room_questions rq
            where rq.room_id = r.id
            having count(*) = r.question_count
              and count(distinct rq.question_index) = r.question_count
              and min(rq.question_index) = 0
              and max(rq.question_index) = r.question_count - 1
              and bool_and(rq.revealed_at is not null)
          )
          and not exists (
            select 1
            from public.room_players member
            where member.room_id = r.id
              and member.left_at is null
              and (
                select count(*)
                from public.player_answers own_answer
                join public.room_questions own_question
                  on own_question.room_id = own_answer.room_id
                  and own_question.question_id = own_answer.question_id
                where own_answer.room_id = member.room_id
                  and own_answer.player_id = member.player_id
              ) <> r.question_count
          )
        )
      )
      and not exists (
        select 1
        from public.room_players scored_player
        where scored_player.room_id = r.id
          and scored_player.score <> (
            select coalesce(sum(scored_answer.points_awarded), 0)::integer
            from public.player_answers scored_answer
            where scored_answer.room_id = scored_player.room_id
              and scored_answer.player_id = scored_player.player_id
          )
      )
  );
$function$;

revoke all on function public.crowd_room_member_leave(uuid, uuid) from public, anon, authenticated;
grant execute on function public.crowd_room_member_leave(uuid, uuid) to service_role;
revoke all on function public.room_result_players(uuid, uuid) from public, anon, authenticated;
grant execute on function public.room_result_players(uuid, uuid) to service_role;
revoke all on function public.room_result_winner(uuid, uuid) from public, anon, authenticated;
grant execute on function public.room_result_winner(uuid, uuid) to service_role;
revoke all on function public.crowd_room_result_complete(uuid) from public, anon, authenticated;
grant execute on function public.crowd_room_result_complete(uuid) to service_role;

-- ---------------------------------------------------------------------
-- create_online_room: yeni imza (+ p_max_players), eski imza düşer
-- ---------------------------------------------------------------------
drop function if exists public.create_online_room(text, integer, integer, integer);

CREATE OR REPLACE FUNCTION public.create_online_room(p_category_name text, p_seconds_per_question integer, p_question_count integer DEFAULT 10, p_entry_fee integer DEFAULT 0, p_max_players integer DEFAULT 2)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_id uuid;
  v_category_name text;
  v_existing record;
  v_room_id uuid;
  v_room_code text;
  v_attempt integer := 0;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_seconds_per_question is null
     or p_seconds_per_question not in (10, 15, 20, 30, 45, 60) then
    raise exception 'Unsupported seconds per question';
  end if;

  if p_question_count is null
     or p_question_count not in (5, 10, 15) then
    raise exception 'Unsupported question count';
  end if;

  if p_entry_fee is null
     or p_entry_fee not in (0, 25, 50, 100) then
    raise exception 'Unsupported entry fee';
  end if;

  -- Kapasite: 2 = bugünkü ikili özel oda (eski istemci bu varsayılanla gelir),
  -- 4..50 = kalabalık oda. Başka değer reddedilir.
  if p_max_players is null
     or p_max_players not in (2, 4, 8, 16, 30, 50) then
    raise exception 'Unsupported max players';
  end if;

  -- Bakiye kontrolü (ücretli oda için)
  if p_entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < p_entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  select c.id, c.name
  into v_category_id, v_category_name
  from public.categories c
  where upper(c.name) = upper(trim(p_category_name))
    and c.is_active = true
  limit 1;

  if v_category_id is null then
    raise exception 'Category is not available';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Aktif oda varsa snapshot'ı dön
  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    r.is_custom,
    r.max_players,
    coalesce(c.name, 'Ziman') as category_name
  into v_existing
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id and rp.player_id = v_uid
   and rp.left_at is null
  left join public.categories c on c.id = r.category_id
  where r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    delete from public.matchmaking_queue mq
    where mq.player_id = v_uid
      and mq.room_id is null;

    return json_build_object(
      'room_id', v_existing.id,
      'code', v_existing.code,
      'host_id', v_existing.host_id,
      'category_name', v_existing.category_name,
      'question_count', v_existing.question_count,
      'seconds_per_question', v_existing.seconds_per_question,
      'entry_fee', v_existing.entry_fee,
      'max_players', v_existing.max_players,
      'is_custom', v_existing.is_custom,
      'status', v_existing.status
    );
  end if;

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
        entry_fee,
        is_custom,
        max_players,
        status
      ) values (
        v_room_code,
        v_uid,
        v_category_id,
        p_question_count,
        p_seconds_per_question,
        p_entry_fee,
        true,
        p_max_players,
        'lobby'
      ) returning id into v_room_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise;
        end if;
    end;
  end loop;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room_id, v_uid, true);

  -- Giriş ücretini BURADA düş. Kontrol tek başına yetmez: ödül tarafı
  -- kazanana `entry_fee * 2` yazıyor, yani ücret hiç tahsil edilmezse her
  -- ücretli maç yoktan `2 x entry_fee` jeton BASAR ve döngü sınırsız
  -- zenginleşmeye açılır. Düşme oda yaratıldıktan sonra yapılır ki oda
  -- kurulamazsa oyuncudan para gitmesin (hepsi tek transaction içinde).
  if p_entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -p_entry_fee, 'room_entry_fee');
  end if;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room_id,
    'code', v_room_code,
    'host_id', v_uid,
    'category_name', v_category_name,
    'question_count', p_question_count,
    'seconds_per_question', p_seconds_per_question,
    'entry_fee', p_entry_fee,
    'max_players', p_max_players,
    'is_custom', true,
    'status', 'lobby'
  );
end;
$function$;

revoke all on function public.create_online_room(text, integer, integer, integer, integer) from public, anon;
grant execute on function public.create_online_room(text, integer, integer, integer, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- join_room_by_code: dolu = aktif oyuncu >= max_players (yalnız kalabalık)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_room_by_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_existing_room_id uuid;
  v_player_count integer;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and rp.left_at is null
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    r.is_custom,
    r.max_players,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where upper(r.code) = upper(trim(p_code))
    and r.status = 'lobby'
  limit 1
  for update of r;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  if v_existing_room_id is not null
     and v_existing_room_id <> v_room.id then
    raise exception 'Player is already in another live room';
  end if;

  -- Bakiye kontrolü (ücretli oda için)
  if v_room.entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < v_room.entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  if exists (
    select 1
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.player_id = v_uid
  ) then
    return json_build_object(
      'room_id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'entry_fee', v_room.entry_fee,
      'max_players', v_room.max_players,
      'is_custom', v_room.is_custom,
      'category_name', v_room.category_name
    );
  end if;

  -- Engelleme (2026-10-02 M5): oda sahibi ya da odadaki biriyle aramızda
  -- HER İKİ YÖNDE engel varsa katılım reddedilir. Mesaj bilerek mevcut
  -- "bulunamadı" mesajıdır: engelleyen kişinin odasını arayan bir kullanıcı
  -- engellendiğini öğrenmemeli; istemci bunu zaten `notFound`a eşler.
  if exists (
    select 1
    from public.blocked_users b
    where (b.blocker_id = v_uid
           and (b.blocked_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocked_id)))
       or (b.blocked_id = v_uid
           and (b.blocker_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocker_id)))
  ) then
    raise exception 'Room not found or already started';
  end if;

  select count(*)::integer into v_player_count
  from public.room_players rp
  where rp.room_id = v_room.id;

  if v_room.is_custom and v_room.max_players > 2 then
    -- Kalabalık oda: dolu = AKTİF oyuncu sayısı kapasiteye ulaştı. (Lobide
    -- left_at yazılmaz; sayı yine de aktif oyunculardan alınır.)
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.left_at is null;

    if v_player_count >= v_room.max_players then
      raise exception 'Room is full';
    end if;
  elsif v_player_count >= 2 then
    raise exception 'Room is full';
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  -- Katılan oyuncunun ücreti de burada düşer; iki taraf da ödemezse havuz
  -- diye bir şey olmaz, yalnız ödül olur.
  if v_room.entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -v_room.entry_fee, 'room_entry_fee');
  end if;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'entry_fee', v_room.entry_fee,
    'max_players', v_room.max_players,
    'is_custom', v_room.is_custom,
    'category_name', v_room.category_name
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- start_room_game: kalabalıkta host, >= 2 aktif, hazır şartı yok, 20 sn
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_room_game(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_player_count integer;
  v_host_member_count integer;
  v_unready_count integer;
  v_question_count integer;
  v_server_now timestamp with time zone;
  v_crowd boolean;
  v_ready_window interval;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  if v_room.host_id is distinct from v_uid then
    raise exception 'Only the host can start this room';
  end if;

  -- Kalabalık oda = özel oda VE kapasite > 2. is_custom=false (eşleşme) ve
  -- 2 kişilik özel oda aşağıdaki eski yolu AYNEN izler.
  v_crowd := v_room.is_custom and v_room.max_players > 2;
  v_ready_window := case
    when v_crowd then interval '20 seconds'
    else interval '45 seconds'
  end;

  select
    count(*)::integer,
    count(*) filter (where rp.player_id = v_room.host_id)::integer,
    count(*) filter (where not coalesce(rp.is_ready, false))::integer
  into v_player_count, v_host_member_count, v_unready_count
  from public.room_players rp
  where rp.room_id = p_room_id
    and (not v_crowd or rp.left_at is null);

  if v_crowd then
    if v_player_count < 2 then
      raise exception 'At least two players are required';
    end if;
  elsif v_player_count <> 2 then
    raise exception 'Exactly two players are required';
  end if;

  if v_host_member_count <> 1 then
    raise exception 'Room host must be one of the two players';
  end if;

  v_server_now := clock_timestamp();

  -- Aynı host isteği ağ tekrarıyla ikinci kez gelirse aktif turu sıfırlama.
  if v_room.status = 'active' then
    update public.rooms r
    set client_ready_deadline = coalesce(
      r.client_ready_deadline,
      v_server_now + v_ready_window
    )
    where r.id = p_room_id;

    select count(*)::integer into v_question_count
    from public.room_questions rq
    where rq.room_id = p_room_id;
    return json_build_object(
      'status', 'active',
      'question_count', v_question_count
    );
  end if;

  if v_room.status <> 'lobby' then
    raise exception 'Room is not in the lobby';
  end if;

  -- Kalabalık odada "herkes hazır" şartı yoktur; host >= 2 kişiyle başlatır.
  if v_unready_count > 0 and not v_crowd then
    raise exception 'All players must be ready';
  end if;

  update public.room_players rp
  set quiz_ready_at = null
  where rp.room_id = p_room_id;

  -- Soru seçimi: önce son 14 günde odayaki oyuncuların gördüğü sorular
  -- dışlanır (son 14 günde cevaplananlar + oynanan odalarda ekrana gelenler),
  -- görülenler tükenirse eskiden görülenler rastgele sırayla tamamlar.
  if not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
  ) then
    with room_member as (
      select rp.player_id
      from public.room_players rp
      where rp.room_id = p_room_id
    ),
    recent_seen as (
      -- (1) Son 14 günde cevaplanan sorular (timeout cevapları da kayıtlı).
      select distinct pa.question_id
      from public.player_answers pa
      join room_member m on m.player_id = pa.player_id
      where pa.created_at >= v_server_now - interval '14 days'
      union
      -- (2) Son 14 günde oynanan odalarda ekrana gelen, cevaplanmamış
      --     (forfeit/yarım kalan) sorular da dahil görülen sorular.
      select distinct seen_rq.question_id
      from room_member m
      join public.room_players seen_rp
        on seen_rp.player_id = m.player_id
      join public.rooms seen_r
        on seen_r.id = seen_rp.room_id
      join public.room_questions seen_rq
        on seen_rq.room_id = seen_r.id
      where greatest(
        seen_r.created_at,
        seen_r.started_at,
        seen_r.finished_at
      ) >= v_server_now - interval '14 days'
    ),
    candidates as (
      -- Görülmemişler (false < true) önce; her grupta rastgele sıra.
      select
        q.id,
        (s.question_id is not null) as already_seen,
        random() as random_order
      from public.questions q
      left join recent_seen s on s.question_id = q.id
      where q.is_approved = true
        and (
          v_room.category_id is null
          or q.category_id = v_room.category_id
        )
    ),
    ranked as (
      select
        c.id,
        c.random_order,
        row_number() over (
          order by c.already_seen asc, c.random_order
        ) as pick_rank
      from candidates c
    )
    insert into public.room_questions (
      room_id,
      question_id,
      question_index,
      started_at,
      revealed_at
    )
    select
      p_room_id,
      picked.id,
      (
        row_number() over (order by picked.random_order)
      )::integer - 1 as question_index,
      null::timestamp with time zone as started_at,
      null::timestamp with time zone as revealed_at
    from ranked picked
    where picked.pick_rank <= v_room.question_count;
  end if;

  select count(*)::integer into v_question_count
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_question_count <> v_room.question_count then
    raise exception
      'Not enough approved questions for this room: expected %, got %',
      v_room.question_count,
      v_question_count;
  end if;

  update public.room_questions rq
  set
    started_at = null,
    revealed_at = null
  where rq.room_id = p_room_id;

  update public.rooms
  set
    status = 'active',
    current_question_index = 0,
    started_at = v_server_now,
    finished_at = null,
    ended_reason = null,
    forfeited_by = null,
    client_ready_deadline = v_server_now + v_ready_window
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- mark_room_client_ready: kalabalıkta hepsi hazır ya da süre dolunca; düşenler left_at
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_room_client_ready(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_player_count integer;
  v_on_time_ready_count integer;
  v_not_ready_player_id uuid;
  v_server_now timestamp with time zone;
  v_current_started_at timestamp with time zone;
  v_current_deadline timestamp with time zone;
  v_remaining_ms integer := 0;
  v_member_left_at timestamp with time zone;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found or v_room.status <> 'active' then
    raise exception 'Room is not active';
  end if;

  v_server_now := clock_timestamp();

  -- Eski bir aktif oda bu sütun eklenmeden önce açılmışsa ilk çağrı mutlak
  -- bariyeri yalnız bir kez kurar; sonraki retry'lar süreyi uzatamaz.
  if v_room.client_ready_deadline is null then
    v_room.client_ready_deadline := v_server_now + case
      when v_room.is_custom and v_room.max_players > 2
        then interval '20 seconds'
      else interval '45 seconds'
    end;
    update public.rooms r
    set client_ready_deadline = v_room.client_ready_deadline
    where r.id = p_room_id;
  end if;

  -- KALABALIK oda (is_custom ve max_players > 2): ilk soru, AKTİF oyuncuların
  -- hepsi zamanında hazır olunca ya da süre dolunca başlar. Süre dolduğunda
  -- hazır olmayanlar left_at ile düşer; kalan aktif < 2 ise oda
  -- 'opponent_not_ready' ile biter ve giriş ücretleri iade edilir.
  -- Bu blok her durumda `return` eder; eski 2 kişilik yol aşağıda aynen durur.
  if v_room.is_custom and v_room.max_players > 2 then
    select rp.left_at into v_member_left_at
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = v_uid;

    if not found then
      raise exception 'Player is not in the room';
    end if;

    if v_member_left_at is not null then
      return json_build_object(
        'status', 'left',
        'server_now', v_server_now,
        'current_question_index', coalesce(v_room.current_question_index, 0),
        'current_question_started_at', null,
        'current_question_deadline', null,
        'current_question_remaining_ms', 0
      );
    end if;

    update public.room_players rp
    set quiz_ready_at = coalesce(rp.quiz_ready_at, v_server_now)
    where rp.room_id = p_room_id
      and rp.player_id = v_uid;

    select rq.started_at into v_current_started_at
    from public.room_questions rq
    where rq.room_id = p_room_id
      and rq.question_index = coalesce(v_room.current_question_index, 0);

    if not found then
      raise exception 'Current room question is missing';
    end if;

    select
      count(*)::integer,
      count(*) filter (
        where rp.quiz_ready_at is not null
          and rp.quiz_ready_at <= v_room.client_ready_deadline
      )::integer
    into v_player_count, v_on_time_ready_count
    from public.room_players rp
    where rp.room_id = p_room_id
      and rp.left_at is null;

    if v_current_started_at is null then
      if v_player_count >= 2 and v_on_time_ready_count = v_player_count then
        update public.room_questions rq
        set started_at = coalesce(rq.started_at, v_server_now)
        where rq.room_id = p_room_id
          and rq.question_index = coalesce(v_room.current_question_index, 0)
        returning rq.started_at into v_current_started_at;
      elsif v_server_now >= v_room.client_ready_deadline then
        update public.room_players rp
        set
          left_at = coalesce(rp.left_at, v_server_now),
          is_ready = false
        where rp.room_id = p_room_id
          and rp.left_at is null
          and (
            rp.quiz_ready_at is null
            or rp.quiz_ready_at > v_room.client_ready_deadline
          );

        if v_on_time_ready_count < 2 then
          update public.rooms r
          set
            status = 'finished',
            finished_at = coalesce(r.finished_at, v_server_now),
            ended_reason = 'opponent_not_ready',
            forfeited_by = null
          where r.id = p_room_id;

          delete from public.matchmaking_queue mq
          where mq.room_id = p_room_id;

          perform public.refund_room_entry_fees(p_room_id, null, true);

          return json_build_object(
            'status', 'finished',
            'reason', 'opponent_not_ready',
            'forfeited_by', null,
            'server_now', v_server_now,
            'current_question_index', coalesce(v_room.current_question_index, 0),
            'current_question_started_at', null,
            'current_question_deadline', null,
            'current_question_remaining_ms', 0
          );
        end if;

        update public.room_questions rq
        set started_at = coalesce(rq.started_at, v_server_now)
        where rq.room_id = p_room_id
          and rq.question_index = coalesce(v_room.current_question_index, 0)
        returning rq.started_at into v_current_started_at;

        -- Düşen oyuncu bu çağrının sahibiyse kendisine 'left' döner.
        select rp.left_at into v_member_left_at
        from public.room_players rp
        where rp.room_id = p_room_id
          and rp.player_id = v_uid;

        if v_member_left_at is not null then
          return json_build_object(
            'status', 'left',
            'server_now', v_server_now,
            'current_question_index', coalesce(v_room.current_question_index, 0),
            'current_question_started_at', null,
            'current_question_deadline', null,
            'current_question_remaining_ms', 0
          );
        end if;
      end if;
    end if;

    if v_current_started_at is not null then
      v_current_deadline := v_current_started_at + make_interval(
        secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
      );
      v_remaining_ms := least(
        2147483647::bigint,
        greatest(
          0::bigint,
          floor(
            extract(epoch from (v_current_deadline - v_server_now)) * 1000
          )::bigint
        )
      )::integer;
    end if;

    return json_build_object(
      'status', case
        when v_current_started_at is null then 'waiting'
        else 'ready'
      end,
      'server_now', v_server_now,
      'current_question_index', coalesce(v_room.current_question_index, 0),
      'current_question_started_at', v_current_started_at,
      'current_question_deadline', v_current_deadline,
      'current_question_remaining_ms', v_remaining_ms,
      'active_players', v_player_count,
      'ready_players', v_on_time_ready_count
    );
  end if;

  update public.room_players rp
  set quiz_ready_at = coalesce(rp.quiz_ready_at, v_server_now)
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where rp.quiz_ready_at is not null
        and rp.quiz_ready_at <= v_room.client_ready_deadline
    )::integer
  into v_player_count, v_on_time_ready_count
  from public.room_players rp
  where rp.room_id = p_room_id;

  if v_player_count <> 2 then
    raise exception 'Exactly two players are required';
  end if;

  select rq.started_at into v_current_started_at
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_index = coalesce(v_room.current_question_index, 0);

  if not found then
    raise exception 'Current room question is missing';
  end if;

  if v_current_started_at is null
     and v_player_count = 2
     and v_on_time_ready_count = 2 then
    update public.room_questions rq
    set started_at = coalesce(rq.started_at, v_server_now)
    where rq.room_id = p_room_id
      and rq.question_index = coalesce(v_room.current_question_index, 0)
    returning rq.started_at into v_current_started_at;
  end if;

  if v_current_started_at is null
     and v_server_now >= v_room.client_ready_deadline
     and v_on_time_ready_count < 2 then
    -- Tek zamanında hazır oyuncu varsa rakip forfeit olur. İki taraf da
    -- gelmediyse rastgele bir kullanıcıyı suçlamamak için alan null kalır.
    if v_on_time_ready_count = 1 then
      select rp.player_id into v_not_ready_player_id
      from public.room_players rp
      where rp.room_id = p_room_id
        and (
          rp.quiz_ready_at is null
          or rp.quiz_ready_at > v_room.client_ready_deadline
        )
      order by rp.player_id
      limit 1;
    end if;

    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, v_server_now),
      ended_reason = 'opponent_not_ready',
      forfeited_by = v_not_ready_player_id
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    return json_build_object(
      'status', 'finished',
      'reason', 'opponent_not_ready',
      'forfeited_by', v_not_ready_player_id,
      'server_now', v_server_now,
      'current_question_index', coalesce(v_room.current_question_index, 0),
      'current_question_started_at', null,
      'current_question_deadline', null,
      'current_question_remaining_ms', 0
    );
  end if;

  if v_current_started_at is not null then
    v_current_deadline := v_current_started_at + make_interval(
      secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
    );
    v_remaining_ms := least(
      2147483647::bigint,
      greatest(
        0::bigint,
        floor(
          extract(epoch from (v_current_deadline - v_server_now)) * 1000
        )::bigint
      )
    )::integer;
  end if;

  return json_build_object(
    'status', case
      when v_current_started_at is null then 'waiting'
      else 'ready'
    end,
    'server_now', v_server_now,
    'current_question_index', coalesce(v_room.current_question_index, 0),
    'current_question_started_at', v_current_started_at,
    'current_question_deadline', v_current_deadline,
    'current_question_remaining_ms', v_remaining_ms
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- advance_room_question: 2 yerine aktif sayısı (kalabalık)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.advance_room_question(p_room_id uuid, p_expected_question_index integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_count integer;
  v_current_question_index integer;
  v_next integer;
  v_question_id uuid;
  v_answer_count integer;
  v_server_now timestamp with time zone;
  v_question_started_at timestamp with time zone;
  v_revealed_at timestamp with time zone;
  v_deadline timestamp with time zone;
  v_limit_ms integer;
  v_crowd boolean;
  v_expected integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
    and (not (r.is_custom and r.max_players > 2) or rp.left_at is null)
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  -- Beklenen cevap sayısı: eski odada tam 2; kalabalık odada AKTİF oyuncu
  -- sayısı (ayrılanlar/düşenler beklenmez, onlara TIMEOUT satırı yazılmaz).
  v_crowd := v_room.is_custom and v_room.max_players > 2;
  v_expected := case
    when v_crowd then (
      select count(*)::integer
      from public.room_players active_player
      where active_player.room_id = p_room_id
        and active_player.left_at is null
    )
    else 2
  end;

  v_current_question_index := coalesce(v_room.current_question_index, 0);

  -- Terminal ilerletmenin cevabı kaybolursa iki üyeden herhangi biri aynı
  -- CAS isteğini güvenle tekrarlayabilir.
  if v_room.status = 'finished' then
    return v_current_question_index;
  end if;

  if v_room.status <> 'active' then
    raise exception 'Room is not active';
  end if;

  if p_expected_question_index is null then
    raise exception 'Expected question index is required';
  end if;

  select count(*)::integer into v_count
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_count < 1 then
    raise exception 'Room has no questions';
  end if;

  -- Eski sürümden terminal indexte aktif kalmış oda da ilk güvenli çağrıda
  -- atomik biçimde kapanır.
  if v_current_question_index >= v_count then
    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, clock_timestamp()),
      ended_reason = 'completed',
      forfeited_by = null
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;
    return v_current_question_index;
  end if;

  if p_expected_question_index < v_current_question_index then
    return v_current_question_index;
  end if;

  if p_expected_question_index > v_current_question_index then
    raise exception 'Expected question index is ahead of the room';
  end if;

  select rq.question_id, rq.started_at, rq.revealed_at
  into v_question_id, v_question_started_at, v_revealed_at
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_index = v_current_question_index;

  if not found then
    raise exception 'Current room question is missing';
  end if;

  if v_question_started_at is null then
    raise exception 'Room clients are not ready';
  end if;

  v_server_now := clock_timestamp();
  v_limit_ms := greatest(
    1,
    coalesce(v_room.seconds_per_question, 20)
  ) * 1000;
  v_deadline := v_question_started_at + make_interval(
    secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
  );

  select count(distinct pa.player_id)::integer
  into v_answer_count
  from public.player_answers pa
  join public.room_players rp
    on rp.room_id = pa.room_id and rp.player_id = pa.player_id
    and (not v_crowd or rp.left_at is null)
  where pa.room_id = p_room_id
    and pa.question_id = v_question_id;

  -- İlk tamamlayıcı çağrı yalnız sonucu reveal eder. Deadline'da eksik cevap
  -- sunucu TIMEOUT'u olarak aynı transactionda doldurulur; skor/seri iki
  -- oyuncu için cevap kayıtlarından idempotent biçimde yeniden hesaplanır.
  if v_revealed_at is null then
    if v_answer_count <> v_expected and v_server_now < v_deadline then
      raise exception 'Current question is not complete';
    end if;

    if v_answer_count <> v_expected and v_server_now >= v_deadline then
      insert into public.player_answers (
        room_id,
        question_id,
        player_id,
        selected_option,
        is_correct,
        response_ms,
        points_awarded
      )
      select
        p_room_id,
        v_question_id,
        rp.player_id,
        'TIMEOUT',
        false,
        v_limit_ms,
        0
      from public.room_players rp
      where rp.room_id = p_room_id
        and (not v_crowd or rp.left_at is null)
        and not exists (
          select 1
          from public.player_answers existing_answer
          where existing_answer.room_id = p_room_id
            and existing_answer.question_id = v_question_id
            and existing_answer.player_id = rp.player_id
        )
      on conflict do nothing;

      select count(distinct pa.player_id)::integer
      into v_answer_count
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.player_id = pa.player_id
        and (not v_crowd or rp.left_at is null)
      where pa.room_id = p_room_id
        and pa.question_id = v_question_id;
    end if;

    if v_answer_count <> v_expected then
      raise exception 'Current question answer invariant failed';
    end if;

    update public.room_questions rq
    set revealed_at = coalesce(rq.revealed_at, v_server_now)
    where rq.room_id = p_room_id
      and rq.question_index = v_current_question_index
    returning rq.revealed_at into v_revealed_at;

    perform public.recalculate_room_player_scores(
      p_room_id,
      v_question_id
    );

    -- Zorunlu sonuç görünümü başlamadan indeks artırılmaz.
    return v_current_question_index;
  end if;

  if v_answer_count <> v_expected then
    raise exception 'Revealed question answer invariant failed';
  end if;

  -- İki istemci de sonucu en az beş saniye görebilsin. Erken retry hata değil,
  -- mevcut indeks cevabıdır; böylece ağ tekrarı idempotent kalır.
  if v_server_now < v_revealed_at + interval '5 seconds' then
    return v_current_question_index;
  end if;

  v_next := v_current_question_index + 1;

  update public.rooms r
  set current_question_index = v_next
  where r.id = p_room_id
    and coalesce(r.current_question_index, 0) = p_expected_question_index;

  if not found then
    raise exception 'Room question index changed unexpectedly';
  end if;

  if v_next < v_count then
    update public.room_questions rq
    set
      started_at = coalesce(rq.started_at, v_server_now),
      revealed_at = null
    where rq.room_id = p_room_id
      and rq.question_index = v_next;

    if not found then
      raise exception 'Next room question is missing';
    end if;
  else
    -- Terminal indeks ve bitiş aynı oda kilidi/transaction içindedir. Süreç
    -- bu noktada ölse bile yeniden açılış aktif index=count görmez.
    update public.rooms r
    set
      status = 'finished',
      finished_at = coalesce(r.finished_at, v_server_now),
      ended_reason = 'completed',
      forfeited_by = null
    where r.id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;
  end if;

  return v_next;
end;
$function$;

-- ---------------------------------------------------------------------
-- submit_answer: 2 yerine aktif sayısı (kalabalık)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_answer(p_room_id uuid, p_question_id uuid, p_selected_option text, p_response_ms integer DEFAULT 2000)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_received_at timestamp with time zone := clock_timestamp();
  v_room public.rooms%rowtype;
  v_is_correct boolean;
  v_correct_option text;
  v_explanation text;
  v_explanation_ku text;
  v_explanation_tr text;
  v_question_index integer;
  v_question_started_at timestamp with time zone;
  v_revealed_at timestamp with time zone;
  v_deadline timestamp with time zone;
  v_elapsed_ms bigint;
  v_limit_ms integer;
  v_response_ms integer;
  v_points integer := 0;
  v_answer_streak integer := 0;
  v_remaining_ratio numeric;
  v_current_streak integer;
  v_current_score integer;
  v_answer_count integer := 0;
  v_already_answered boolean := false;
  v_revealable boolean := false;
  v_existing_answer record;
  v_crowd boolean;
  v_expected integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  p_selected_option := upper(
    coalesce(nullif(trim(p_selected_option), ''), 'TIMEOUT')
  );
  if p_selected_option not in ('A', 'B', 'C', 'D', 'TIMEOUT') then
    raise exception 'Invalid option';
  end if;

  -- `p_response_ms` yalnız eski istemci imza uyumluluğu için kalır; kayıt ve
  -- puan sunucunun soru başlangıcı ile çağrıyı aldığı andan hesaplanır.
  select r.* into v_room
  from public.rooms r
  where r.id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  v_crowd := v_room.is_custom and v_room.max_players > 2;

  select rp.score, rp.streak
  into v_current_score, v_current_streak
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.player_id = v_uid
    and (not v_crowd or rp.left_at is null)
  for update;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  select
    rq.question_index,
    rq.started_at,
    rq.revealed_at,
    q.correct_option,
    q.explanation,
    q.explanation_ku,
    q.explanation_tr
  into
    v_question_index,
    v_question_started_at,
    v_revealed_at,
    v_correct_option,
    v_explanation,
    v_explanation_ku,
    v_explanation_tr
  from public.room_questions rq
  join public.questions q on q.id = rq.question_id
  where rq.room_id = p_room_id
    and rq.question_id = p_question_id;

  if not found then
    raise exception 'Question is not in this room';
  end if;

  v_limit_ms := greatest(
    1,
    coalesce(v_room.seconds_per_question, 20)
  ) * 1000;
  if v_question_started_at is not null then
    v_deadline := v_question_started_at
      + make_interval(
        secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
      );
  end if;

  -- Duplicate istek önce mevcut satırı yükler. Seçim parametresi farklı gelse
  -- bile kayıt değiştirilmez; pending/full görünürlük kararı yeniden yapılır.
  select
    pa.selected_option,
    pa.is_correct,
    pa.points_awarded,
    pa.response_ms
  into v_existing_answer
  from public.player_answers pa
  where pa.room_id = p_room_id
    and pa.question_id = p_question_id
    and pa.player_id = v_uid;

  if found then
    p_selected_option := v_existing_answer.selected_option;
    v_is_correct := v_existing_answer.is_correct;
    v_points := v_existing_answer.points_awarded;
    v_response_ms := v_existing_answer.response_ms;
    v_already_answered := true;
  else
    if v_room.status <> 'active' then
      raise exception 'Room is not active';
    end if;

    if v_question_index <> coalesce(v_room.current_question_index, 0) then
      raise exception 'Question is not the current active room question';
    end if;

    if v_question_started_at is null then
      raise exception 'Room clients are not ready';
    end if;

    -- Çağrı oda kilidini beklerken başka transaction soruyu başlatmışsa
    -- alınma zamanı started_at'ten eski olabilir. Bunu 0 ms'e sıkıştırmak
    -- azami hız puanı üretirdi; başlangıç öncesi cevap açıkça geçersizdir.
    if v_received_at < v_question_started_at then
      raise exception 'Answer received before question started';
    end if;

    v_elapsed_ms := floor(
      extract(epoch from (v_received_at - v_question_started_at)) * 1000
    )::bigint;
    v_response_ms := least(
      v_limit_ms::bigint,
      v_elapsed_ms
    )::integer;

    if v_received_at >= v_deadline then
      p_selected_option := 'TIMEOUT';
    end if;

    v_is_correct := p_selected_option <> 'TIMEOUT'
      and p_selected_option = v_correct_option;
    if v_is_correct then
      v_answer_streak := v_current_streak + 1;
      v_remaining_ratio := greatest(
        0,
        (v_limit_ms - v_response_ms)::numeric / v_limit_ms
      );
      v_points := 100
        + round(v_remaining_ratio * 100)::integer
        + least(v_answer_streak * 10, 50);
    else
      v_answer_streak := 0;
      v_points := 0;
    end if;

    insert into public.player_answers (
      room_id,
      question_id,
      player_id,
      selected_option,
      is_correct,
      response_ms,
      points_awarded
    ) values (
      p_room_id,
      p_question_id,
      v_uid,
      p_selected_option,
      v_is_correct,
      v_response_ms,
      v_points
    );
  end if;

  v_revealable := v_question_index < coalesce(v_room.current_question_index, 0)
    or v_revealed_at is not null;

  -- Aktif/current soru ikinci cevapla veya sunucu deadline'ıyla finalize olur.
  -- İlk cevap room_players skor/serisini değiştirmez ve aşağıdaki güvenli
  -- pending gövdesinden başka sonuç alanı döndürmez.
  if v_revealable = false
     and v_room.status = 'active'
     and v_question_index = coalesce(v_room.current_question_index, 0) then
    -- Beklenen cevap sayısı: eski odada tam 2; kalabalık odada AKTİF oyuncu
    -- sayısı. Ayrılanlar/düşenler beklenmez ve onlara TIMEOUT yazılmaz.
    v_expected := case
      when v_crowd then (
        select count(*)::integer
        from public.room_players active_player
        where active_player.room_id = p_room_id
          and active_player.left_at is null
      )
      else 2
    end;

    select count(distinct pa.player_id)::integer
    into v_answer_count
    from public.player_answers pa
    join public.room_players rp
      on rp.room_id = pa.room_id and rp.player_id = pa.player_id
      and (not v_crowd or rp.left_at is null)
    where pa.room_id = p_room_id
      and pa.question_id = p_question_id;

    if v_answer_count <> v_expected
       and v_deadline is not null
       and v_received_at >= v_deadline then
      insert into public.player_answers (
        room_id,
        question_id,
        player_id,
        selected_option,
        is_correct,
        response_ms,
        points_awarded
      )
      select
        p_room_id,
        p_question_id,
        rp.player_id,
        'TIMEOUT',
        false,
        v_limit_ms,
        0
      from public.room_players rp
      where rp.room_id = p_room_id
        and (not v_crowd or rp.left_at is null)
        and not exists (
          select 1
          from public.player_answers existing_answer
          where existing_answer.room_id = p_room_id
            and existing_answer.question_id = p_question_id
            and existing_answer.player_id = rp.player_id
        )
      on conflict do nothing;

      select count(distinct pa.player_id)::integer
      into v_answer_count
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.player_id = pa.player_id
        and (not v_crowd or rp.left_at is null)
      where pa.room_id = p_room_id
        and pa.question_id = p_question_id;
    end if;

    if v_answer_count > v_expected then
      raise exception 'Current question answer invariant failed';
    end if;

    if v_answer_count = v_expected then
      update public.room_questions rq
      set revealed_at = coalesce(rq.revealed_at, v_received_at)
      where rq.room_id = p_room_id
        and rq.question_id = p_question_id
      returning rq.revealed_at into v_revealed_at;

      perform public.recalculate_room_player_scores(
        p_room_id,
        p_question_id
      );
      v_revealable := true;
    end if;
  end if;

  if not v_revealable then
    return json_build_object(
      'accepted', true,
      'pending', true,
      'selected_option', p_selected_option,
      'response_ms', v_response_ms,
      'already_answered', v_already_answered
    );
  end if;

  -- Reveal transactionı score/streak'i iki üye için birlikte güncelledi.
  select rp.score, rp.streak
  into v_current_score, v_current_streak
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  return json_build_object(
    'accepted', true,
    'pending', false,
    'selected_option', p_selected_option,
    'is_correct', v_is_correct,
    'points', v_points,
    'new_score', v_current_score,
    'new_streak', v_current_streak,
    'response_ms', v_response_ms,
    'correct_option', v_correct_option,
    'explanation', v_explanation,
    'explanation_ku', v_explanation_ku,
    'explanation_tr', v_explanation_tr,
    'already_answered', v_already_answered
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- enforce_current_room_question: sunucu TIMEOUT'u yalnız aktiflere
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_current_room_question()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_server_timeout_allowed boolean := false;
begin
  if v_uid is not null and new.player_id is distinct from v_uid then
    select exists (
      select 1
      from public.rooms r
      join public.room_questions rq on rq.room_id = r.id
      join public.room_players caller
        on caller.room_id = r.id and caller.player_id = v_uid
      join public.room_players target
        on target.room_id = r.id and target.player_id = new.player_id
      where r.id = new.room_id
        and r.status = 'active'
        and rq.question_id = new.question_id
        and rq.question_index = r.current_question_index
        and rq.started_at is not null
        and clock_timestamp() >= rq.started_at + make_interval(
          secs => greatest(1, coalesce(r.seconds_per_question, 20))
        )
        and new.selected_option = 'TIMEOUT'
        and new.is_correct is false
        and new.response_ms = greatest(
          1,
          coalesce(r.seconds_per_question, 20)
        ) * 1000
        and new.points_awarded = 0
        and (
          (
            not (r.is_custom and r.max_players > 2)
            and (
              select count(*)
              from public.room_players exact_players
              where exact_players.room_id = r.id
            ) = 2
          )
          or (
            -- Kalabalık oda: yalnız AKTİF oyuncular arasında, >= 2 aktif.
            r.is_custom and r.max_players > 2
            and caller.left_at is null
            and target.left_at is null
            and (
              select count(*)
              from public.room_players active_players
              where active_players.room_id = r.id
                and active_players.left_at is null
            ) >= 2
          )
        )
    ) into v_server_timeout_allowed;

    if not v_server_timeout_allowed then
      raise exception 'Answer player does not match authenticated user';
    end if;
  end if;

  if not exists (
    select 1
    from public.room_questions rq
    join public.rooms r on r.id = rq.room_id
    where rq.room_id = new.room_id
      and rq.question_id = new.question_id
      and rq.question_index = r.current_question_index
      and r.status = 'active'
  ) then
    raise exception 'Question is not the current active room question';
  end if;

  return new;
end;
$function$;

-- ---------------------------------------------------------------------
-- recalculate_room_player_scores: aktif sayısı; değişmeyen satırı yazma
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_room_player_scores(p_room_id uuid, p_question_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_question_index integer;
  v_player_count integer;
  v_answer_count integer;
  v_crowd boolean;
begin
  select rq.question_index
  into v_question_index
  from public.room_questions rq
  where rq.room_id = p_room_id
    and rq.question_id = p_question_id
    and rq.revealed_at is not null;

  if not found then
    raise exception 'Question is not revealed';
  end if;

  select (r.is_custom and r.max_players > 2)
  into v_crowd
  from public.rooms r
  where r.id = p_room_id;

  select count(*)::integer
  into v_player_count
  from public.room_players rp
  where rp.room_id = p_room_id
    and (not v_crowd or rp.left_at is null);

  select count(distinct pa.player_id)::integer
  into v_answer_count
  from public.player_answers pa
  join public.room_players rp
    on rp.room_id = pa.room_id and rp.player_id = pa.player_id
    and (not v_crowd or rp.left_at is null)
  where pa.room_id = p_room_id
    and pa.question_id = p_question_id;

  if v_crowd then
    -- Kalabalık oda: kesinleştirme için her AKTİF oyuncunun cevabı gerekir.
    if v_player_count < 2 or v_answer_count <> v_player_count then
      raise exception 'Every active player answer is required to finalize scores';
    end if;
  elsif v_player_count <> 2 or v_answer_count <> 2 then
    raise exception 'Exactly two answers are required to finalize scores';
  end if;

  with per_player as (
    select
      member.player_id,
      coalesce(sum(answer.points_awarded), 0)::integer as score,
      coalesce(
        max(rq.question_index) filter (where answer.is_correct is false),
        -1
      )::integer as last_wrong_index
    from public.room_players member
    left join public.room_questions rq
      on rq.room_id = member.room_id
      and rq.question_index <= v_question_index
    left join public.player_answers answer
      on answer.room_id = rq.room_id
      and answer.question_id = rq.question_id
      and answer.player_id = member.player_id
    where member.room_id = p_room_id
    group by member.player_id
  ), recalculated as (
    select
      stats.player_id,
      stats.score,
      count(answer.question_id) filter (
        where answer.is_correct
          and rq.question_index > stats.last_wrong_index
      )::integer as streak
    from per_player stats
    left join public.room_questions rq
      on rq.room_id = p_room_id
      and rq.question_index <= v_question_index
    left join public.player_answers answer
      on answer.room_id = rq.room_id
      and answer.question_id = rq.question_id
      and answer.player_id = stats.player_id
    group by stats.player_id, stats.score, stats.last_wrong_index
  )
  update public.room_players rp
  set
    score = recalculated.score,
    streak = recalculated.streak
  from recalculated
  where rp.room_id = p_room_id
    and rp.player_id = recalculated.player_id
    -- Kalabalık odada değişmeyen satırı yazma: her UPDATE realtime ile N
    -- aboneye gider. Eski odada koşul yok (davranış aynı).
    and (
      not v_crowd
      or (rp.score, rp.streak) is distinct from
         (recalculated.score, recalculated.streak)
    );
end;
$function$;

-- ---------------------------------------------------------------------
-- leave_room: kalabalıkta host devri / left_at; eski odada iade
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.leave_room(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
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

-- ---------------------------------------------------------------------
-- cleanup_stale_rooms: aktif sayımı + iade
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_stale_rooms()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_room record;
  v_on_time_ready_count integer;
  v_not_ready_player_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));

  for v_room in
    select
      r.id,
      r.status,
      r.client_ready_deadline,
      (r.is_custom and r.max_players > 2) as is_crowd,
      (
        r.status = 'active'
        and r.client_ready_deadline is not null
        and clock_timestamp() >= r.client_ready_deadline
        and exists (
          select 1
          from public.room_questions rq
          where rq.room_id = r.id
            and rq.question_index = coalesce(r.current_question_index, 0)
            and rq.started_at is null
        )
        and (
          select count(*)
          from public.room_players rp
          where rp.room_id = r.id
            and rp.quiz_ready_at is not null
            and rp.quiz_ready_at <= r.client_ready_deadline
            and (not (r.is_custom and r.max_players > 2) or rp.left_at is null)
        ) < 2
      ) as ready_deadline_expired
    from public.rooms r
    where (
      r.status = 'lobby'
      and r.created_at < now() - interval '24 hours'
    ) or (
      r.status = 'active'
      and (
        coalesce(r.started_at, r.created_at) < now() - interval '24 hours'
        or (
          r.client_ready_deadline is not null
          and clock_timestamp() >= r.client_ready_deadline
          and exists (
            select 1
            from public.room_questions rq
            where rq.room_id = r.id
              and rq.question_index = coalesce(r.current_question_index, 0)
              and rq.started_at is null
          )
          and (
            select count(*)
            from public.room_players rp
            where rp.room_id = r.id
              and rp.quiz_ready_at is not null
              and rp.quiz_ready_at <= r.client_ready_deadline
              and (not (r.is_custom and r.max_players > 2) or rp.left_at is null)
          ) < 2
        )
      )
    )
    order by r.id
    for update of r skip locked
  loop
    v_not_ready_player_id := null;

    if v_room.ready_deadline_expired then
      select count(*)::integer
      into v_on_time_ready_count
      from public.room_players rp
      where rp.room_id = v_room.id
        and rp.quiz_ready_at is not null
        and rp.quiz_ready_at <= v_room.client_ready_deadline
        and (not v_room.is_crowd or rp.left_at is null);

      -- Kalabalık odada suçlu tek kişi yoktur: forfeited_by null kalır.
      if v_on_time_ready_count = 1 and not v_room.is_crowd then
        select rp.player_id into v_not_ready_player_id
        from public.room_players rp
        where rp.room_id = v_room.id
          and (
            rp.quiz_ready_at is null
            or rp.quiz_ready_at > v_room.client_ready_deadline
          )
        order by rp.player_id
        limit 1;
      end if;

      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'opponent_not_ready',
        forfeited_by = v_not_ready_player_id
      where r.id = v_room.id;

      -- Oyun hiç başlamadı: herkese giriş ücreti iadesi (hazır süresinde
      -- düşenler dahil).
      perform public.refund_room_entry_fees(v_room.id, null, true);
    else
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'stale_timeout',
        forfeited_by = null
      where r.id = v_room.id;

      -- Bayat oda: ücret ne ödül ne iade oluyordu. Aktif kalan herkese iade
      -- (oyundan kendi ayrılanlar kaybeder).
      perform public.refund_room_entry_fees(v_room.id, null);
    end if;
  end loop;

  delete from public.matchmaking_queue mq
  where (
    mq.room_id is null
    and mq.joined_at < now() - interval '10 minutes'
  ) or exists (
    select 1
    from public.rooms terminal_room
    where terminal_room.id = mq.room_id
      and terminal_room.status not in ('lobby', 'active')
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- get_room_result_payload: kalabalıkta rank'lı oyuncu listesi
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_room_result_payload(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_players jsonb;
  v_question_ids jsonb;
  v_answers jsonb;
  v_winner_id uuid;
  v_crowd boolean := false;
  v_saved_result record;
  v_saved_found boolean := false;
  v_live_found boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select
    saved_result.room_id,
    saved_result.payload,
    saved_result.finished_at,
    saved_result.room_created_at
  into v_saved_result
  from public.room_result_snapshots saved_result
  join public.room_players saved_member
    on saved_member.room_id = saved_result.room_id
    and saved_member.player_id = saved_result.player_id
  where saved_result.player_id = v_uid
    and (p_room_id is null or saved_result.room_id = p_room_id)
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = saved_result.room_id
        and receipt.player_id = v_uid
    )
  order by
    saved_result.finished_at desc,
    saved_result.room_created_at desc,
    saved_result.room_id desc
  limit 1;
  v_saved_found := found;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    r.current_question_index,
    r.ended_reason,
    r.forfeited_by,
    r.finished_at,
    r.created_at,
    r.is_custom,
    r.max_players,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_uid
  left join public.categories c on c.id = r.category_id
  where r.status = 'finished'
    and (p_room_id is null or r.id = p_room_id)
    and r.ended_reason = 'completed'
    and r.forfeited_by is null
    and r.finished_at is not null
    and r.question_count > 0
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = r.id
        and receipt.player_id = v_uid
    )
    and (
      (
        r.is_custom and r.max_players > 2
        -- Ayrılan/düşen oyuncuya bekleyen sonuç sunulmaz.
        and mine.left_at is null
        and public.crowd_room_result_complete(r.id)
      )
      or (
    not (r.is_custom and r.max_players > 2)
    and coalesce(r.current_question_index, -1) = r.question_count
    and exists (
      select 1
      from public.room_players exact_players
      where exact_players.room_id = r.id
      having count(*) = 2
    )
    and exists (
      select 1
      from public.room_questions rq
      where rq.room_id = r.id
      having count(*) = r.question_count
        and count(distinct rq.question_index) = r.question_count
        and min(rq.question_index) = 0
        and max(rq.question_index) = r.question_count - 1
        and bool_and(rq.revealed_at is not null)
    )
    and exists (
      select 1
      from public.player_answers pa
      join public.room_questions answered_question
        on answered_question.room_id = pa.room_id
        and answered_question.question_id = pa.question_id
      join public.room_players answering_player
        on answering_player.room_id = pa.room_id
        and answering_player.player_id = pa.player_id
      where pa.room_id = r.id
      having count(*) = r.question_count * 2
    )
    and not exists (
      select 1
      from public.room_players member
      where member.room_id = r.id
        and (
          select count(*)
          from public.player_answers own_answer
          join public.room_questions own_question
            on own_question.room_id = own_answer.room_id
            and own_question.question_id = own_answer.question_id
          where own_answer.room_id = member.room_id
            and own_answer.player_id = member.player_id
        ) <> r.question_count
    )
    and not exists (
      select 1
      from public.room_players scored_player
      where scored_player.room_id = r.id
        and scored_player.score <> (
          select coalesce(sum(scored_answer.points_awarded), 0)::integer
          from public.player_answers scored_answer
          where scored_answer.room_id = scored_player.room_id
            and scored_answer.player_id = scored_player.player_id
        )
    )
      )
    )
  order by r.finished_at desc, r.created_at desc, r.id desc
  limit 1
  for share of r;
  v_live_found := found;

  if not v_live_found and not v_saved_found then
    return null;
  end if;

  if v_saved_found and (
    not v_live_found
    or row(
      v_saved_result.finished_at,
      v_saved_result.room_created_at,
      v_saved_result.room_id
    ) > row(v_room.finished_at, v_room.created_at, v_room.id)
  ) then
    return v_saved_result.payload;
  end if;

  v_crowd := v_room.is_custom and v_room.max_players > 2;

  if v_crowd then
    -- Kalabalık oda: skora göre sıralı, eşitlikte aynı rank'lı oyuncu listesi.
    v_players := public.room_result_players(v_room.id, null);
  else
  select jsonb_agg(
    jsonb_build_object(
      'player_id', rp.player_id,
      'display_name', coalesce(nullif(trim(p.display_name), ''), 'Hevrik'),
      'final_score', rp.score,
      'final_streak', rp.streak
    ) order by rp.joined_at, rp.player_id
  )
  into v_players
  from public.room_players rp
  join public.profiles p on p.id = rp.player_id
  where rp.room_id = v_room.id;
  end if;

  select jsonb_agg(rq.question_id order by rq.question_index)
  into v_question_ids
  from public.room_questions rq
  where rq.room_id = v_room.id;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', rq.question_id,
      'question_index', rq.question_index,
      'selected_option', pa.selected_option,
      'correct_option', q.correct_option,
      'is_correct', pa.is_correct,
      'points_awarded', pa.points_awarded,
      'response_ms', pa.response_ms,
      'explanation', q.explanation,
      'explanation_ku', q.explanation_ku,
      'explanation_tr', q.explanation_tr
    ) order by rq.question_index
  )
  into v_answers
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  join public.questions q on q.id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid;

  if v_crowd then
    v_winner_id := public.room_result_winner(v_room.id, null);
  else
  select case
    when min(rp.score) = max(rp.score) then null
    else (array_agg(rp.player_id order by rp.score desc, rp.player_id))[1]
  end
  into v_winner_id
  from public.room_players rp
  where rp.room_id = v_room.id;
  end if;

  return json_build_object(
    'room', json_build_object(
      'id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'category_name', v_room.category_name,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'status', 'finished',
      'current_question_index', v_room.current_question_index,
      'is_custom', v_room.is_custom,
      'max_players', v_room.max_players
    ),
    'own_player_id', v_uid,
    'players', v_players,
    'question_ids', v_question_ids,
    'answers', v_answers,
    'winner_id', v_winner_id,
    'ended_reason', v_room.ended_reason,
    'forfeited_by', v_room.forfeited_by,
    'finished_at', v_room.finished_at
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- acknowledge_room_result: kalabalık tamlık koşulu
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.acknowledge_room_result(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_question_count integer;
  v_crowd boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- İlk çağrı commit olup ağ yanıtı kaybolmuş olabilir. Makbuz zaten varsa
  -- kanıt satırları daha sonra anonimleştirilmiş/silinmiş olsa bile aynı
  -- başarılı sonucu döndür; idempotent retry yeniden tamlık aramamalıdır.
  if exists (
    select 1
    from public.room_result_receipts receipt
    where receipt.room_id = p_room_id
      and receipt.player_id = v_uid
  ) then
    return json_build_object('acknowledged', true, 'room_id', p_room_id);
  end if;

  -- Hesap silme öncesi güvenilir fonksiyonun ürettiği immutable snapshot,
  -- silinen rakibin kişisel satırları artık bulunmasa da aynı tamlık kanıtıdır.
  if exists (
    select 1
    from public.room_result_snapshots saved_result
    join public.room_players saved_member
      on saved_member.room_id = saved_result.room_id
      and saved_member.player_id = saved_result.player_id
    join public.rooms saved_room on saved_room.id = saved_result.room_id
    where saved_result.room_id = p_room_id
      and saved_result.player_id = v_uid
      and saved_room.status = 'finished'
      and saved_room.ended_reason = 'completed'
      and saved_result.payload ->> 'own_player_id' = v_uid::text
      and saved_result.payload ->> 'ended_reason' = 'completed'
      and saved_result.payload -> 'room' ->> 'id' = p_room_id::text
      and saved_result.payload -> 'room' ->> 'status' = 'finished'
      and jsonb_array_length(saved_result.payload -> 'question_ids') = (
        saved_result.payload -> 'room' ->> 'question_count'
      )::integer
      and (
        (
          -- Kalabalık oda anlık görüntüsü: oyuncu sayısı değişken, erken
          -- biten odada indeks/cevap sayısı soru sayısından küçük olabilir.
          saved_room.is_custom
          and saved_room.max_players > 2
          and jsonb_array_length(saved_result.payload -> 'players') >= 1
        )
        or (
          not (saved_room.is_custom and saved_room.max_players > 2)
          and (
            saved_result.payload -> 'room' ->> 'current_question_index'
          )::integer = (
            saved_result.payload -> 'room' ->> 'question_count'
          )::integer
          and jsonb_array_length(saved_result.payload -> 'players') = 2
          and jsonb_array_length(saved_result.payload -> 'answers') = (
            saved_result.payload -> 'room' ->> 'question_count'
          )::integer
        )
      )
  ) then
    insert into public.room_result_receipts (room_id, player_id)
    values (p_room_id, v_uid)
    on conflict (room_id, player_id) do nothing;

    return json_build_object('acknowledged', true, 'room_id', p_room_id);
  end if;

  select r.question_count, (r.is_custom and r.max_players > 2)
  into v_question_count, v_crowd
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
    and r.status = 'finished'
    and r.ended_reason = 'completed'
    and r.forfeited_by is null
    and r.finished_at is not null
    and r.question_count > 0
    and (
      coalesce(r.current_question_index, -1) = r.question_count
      -- Kalabalık oda erken bitebilir (kalan aktif < 2): indeks < soru sayısı.
      or (r.is_custom and r.max_players > 2 and rp.left_at is null)
    )
  for share of r;

  if not found then
    raise exception 'Completed room result is unavailable';
  end if;

  if v_crowd then
    if not public.crowd_room_result_complete(p_room_id) then
      raise exception 'Completed room result is incomplete';
    end if;
  elsif not exists (
    select 1
    from public.room_players exact_players
    where exact_players.room_id = p_room_id
    having count(*) = 2
  ) or not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
    having count(*) = v_question_count
      and count(distinct rq.question_index) = v_question_count
      and min(rq.question_index) = 0
      and max(rq.question_index) = v_question_count - 1
      and bool_and(rq.revealed_at is not null)
  ) or not exists (
    select 1
    from public.player_answers pa
    join public.room_questions answered_question
      on answered_question.room_id = pa.room_id
      and answered_question.question_id = pa.question_id
    join public.room_players answering_player
      on answering_player.room_id = pa.room_id
      and answering_player.player_id = pa.player_id
    where pa.room_id = p_room_id
    having count(*) = v_question_count * 2
  ) or exists (
    select 1
    from public.room_players member
    where member.room_id = p_room_id
      and (
        select count(*)
        from public.player_answers own_answer
        join public.room_questions own_question
          on own_question.room_id = own_answer.room_id
          and own_question.question_id = own_answer.question_id
        where own_answer.room_id = member.room_id
          and own_answer.player_id = member.player_id
      ) <> v_question_count
  ) or exists (
    select 1
    from public.room_players scored_player
    where scored_player.room_id = p_room_id
      and scored_player.score <> (
        select coalesce(sum(scored_answer.points_awarded), 0)::integer
        from public.player_answers scored_answer
        where scored_answer.room_id = scored_player.room_id
          and scored_answer.player_id = scored_player.player_id
      )
  ) then
    raise exception 'Completed room result is incomplete';
  end if;

  insert into public.room_result_receipts (room_id, player_id)
  values (p_room_id, v_uid)
  on conflict (room_id, player_id) do nothing;

  return json_build_object('acknowledged', true, 'room_id', p_room_id);
end;
$function$;

-- ---------------------------------------------------------------------
-- delete_my_account: kalabalık anlık görüntü + ayrılma; eski odada iade
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_room record;
  v_completed_room record;
  v_remaining_player record;
  v_players jsonb;
  v_question_ids jsonb;
  v_answers jsonb;
  v_winner_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  -- Silinen oyuncunun cascade'i bitmiş maçtaki iki-skor kanıtını kaldırmadan
  -- önce, yalnız kalan ve henüz onaylamamış oyuncu için anonim snapshot yaz.
  for v_completed_room in
    select
      completed_room.id,
      completed_room.code,
      completed_room.host_id,
      completed_room.question_count,
      completed_room.seconds_per_question,
      completed_room.current_question_index,
      completed_room.is_custom,
      completed_room.max_players,
      completed_room.ended_reason,
      completed_room.forfeited_by,
      completed_room.finished_at,
      completed_room.created_at,
      coalesce(category.name, 'Ziman') as category_name
    from public.rooms completed_room
    join public.room_players deleting_member
      on deleting_member.room_id = completed_room.id
      and deleting_member.player_id = v_user_id
    left join public.categories category
      on category.id = completed_room.category_id
    where completed_room.status = 'finished'
      and completed_room.ended_reason = 'completed'
      and completed_room.forfeited_by is null
      and completed_room.finished_at is not null
      and completed_room.question_count > 0
      and (
        (
          completed_room.is_custom and completed_room.max_players > 2
          and public.crowd_room_result_complete(completed_room.id)
        )
        or (
      not (completed_room.is_custom and completed_room.max_players > 2)
      and coalesce(completed_room.current_question_index, -1)
        = completed_room.question_count
      and exists (
        select 1
        from public.room_players exact_players
        where exact_players.room_id = completed_room.id
        having count(*) = 2
      )
      and exists (
        select 1
        from public.room_questions revealed_question
        where revealed_question.room_id = completed_room.id
        having count(*) = completed_room.question_count
          and count(distinct revealed_question.question_index)
            = completed_room.question_count
          and min(revealed_question.question_index) = 0
          and max(revealed_question.question_index)
            = completed_room.question_count - 1
          and bool_and(revealed_question.revealed_at is not null)
      )
      and exists (
        select 1
        from public.player_answers exact_answer
        join public.room_questions answered_question
          on answered_question.room_id = exact_answer.room_id
          and answered_question.question_id = exact_answer.question_id
        join public.room_players answering_player
          on answering_player.room_id = exact_answer.room_id
          and answering_player.player_id = exact_answer.player_id
        where exact_answer.room_id = completed_room.id
        having count(*) = completed_room.question_count * 2
      )
      and not exists (
        select 1
        from public.room_players member
        where member.room_id = completed_room.id
          and (
            select count(*)
            from public.player_answers own_answer
            join public.room_questions own_question
              on own_question.room_id = own_answer.room_id
              and own_question.question_id = own_answer.question_id
            where own_answer.room_id = member.room_id
              and own_answer.player_id = member.player_id
          ) <> completed_room.question_count
      )
      and not exists (
        select 1
        from public.room_players scored_player
        where scored_player.room_id = completed_room.id
          and scored_player.score <> (
            select coalesce(sum(scored_answer.points_awarded), 0)::integer
            from public.player_answers scored_answer
            where scored_answer.room_id = scored_player.room_id
              and scored_answer.player_id = scored_player.player_id
          )
      )
        )
      )
    order by completed_room.id
    for update of completed_room
  loop
    for v_remaining_player in
      select remaining.player_id
      from public.room_players remaining
      where remaining.room_id = v_completed_room.id
        and remaining.player_id <> v_user_id
        -- Kalabalık odada ayrılan/düşen oyuncuya anlık görüntü yazılmaz.
        and (
          not (v_completed_room.is_custom and v_completed_room.max_players > 2)
          or remaining.left_at is null
        )
        and not exists (
          select 1
          from public.room_result_receipts receipt
          where receipt.room_id = remaining.room_id
            and receipt.player_id = remaining.player_id
        )
    loop
      select jsonb_agg(
        jsonb_build_object(
          'player_id', case
            when rp.player_id = v_user_id then
              '00000000-0000-0000-0000-000000000000'::uuid
            else rp.player_id
          end,
          'display_name', case
            when rp.player_id = v_user_id then 'Hesabê jêbirî'
            else coalesce(nullif(trim(profile.display_name), ''), 'Hevrik')
          end,
          'final_score', rp.score,
          'final_streak', rp.streak
        ) order by rp.joined_at, rp.player_id
      )
      into v_players
      from public.room_players rp
      join public.profiles profile on profile.id = rp.player_id
      where rp.room_id = v_completed_room.id;

      -- Kalabalık oda: rank'lı oyuncu listesi (silinen hesap anonim).
      if v_completed_room.is_custom and v_completed_room.max_players > 2 then
        v_players := public.room_result_players(
          v_completed_room.id,
          v_user_id
        );
      end if;

      select jsonb_agg(rq.question_id order by rq.question_index)
      into v_question_ids
      from public.room_questions rq
      where rq.room_id = v_completed_room.id;

      select jsonb_agg(
        jsonb_build_object(
          'question_id', rq.question_id,
          'question_index', rq.question_index,
          'selected_option', pa.selected_option,
          'correct_option', question.correct_option,
          'is_correct', pa.is_correct,
          'points_awarded', pa.points_awarded,
          'response_ms', pa.response_ms,
          'explanation', question.explanation,
          'explanation_ku', question.explanation_ku,
          'explanation_tr', question.explanation_tr
        ) order by rq.question_index
      )
      into v_answers
      from public.player_answers pa
      join public.room_questions rq
        on rq.room_id = pa.room_id and rq.question_id = pa.question_id
      join public.questions question on question.id = pa.question_id
      where pa.room_id = v_completed_room.id
        and pa.player_id = v_remaining_player.player_id;

      select case
        when min(rp.score) = max(rp.score) then null
        when (array_agg(
          rp.player_id order by rp.score desc, rp.player_id
        ))[1] = v_user_id then
          '00000000-0000-0000-0000-000000000000'::uuid
        else (array_agg(
          rp.player_id order by rp.score desc, rp.player_id
        ))[1]
      end
      into v_winner_id
      from public.room_players rp
      where rp.room_id = v_completed_room.id;

      if v_completed_room.is_custom and v_completed_room.max_players > 2 then
        v_winner_id := public.room_result_winner(
          v_completed_room.id,
          v_user_id
        );
      end if;

      insert into public.room_result_snapshots (
        room_id,
        player_id,
        payload,
        finished_at,
        room_created_at
      ) values (
        v_completed_room.id,
        v_remaining_player.player_id,
        jsonb_build_object(
          'room', jsonb_build_object(
            'id', v_completed_room.id,
            'code', v_completed_room.code,
            'host_id', case
              when v_completed_room.host_id = v_user_id then null
              else v_completed_room.host_id
            end,
            'category_name', v_completed_room.category_name,
            'question_count', v_completed_room.question_count,
            'seconds_per_question', coalesce(
              v_completed_room.seconds_per_question,
              30
            ),
            'status', 'finished',
            'current_question_index',
              v_completed_room.current_question_index,
            'is_custom', v_completed_room.is_custom,
            'max_players', v_completed_room.max_players
          ),
          'own_player_id', v_remaining_player.player_id,
          'players', v_players,
          'question_ids', v_question_ids,
          'answers', v_answers,
          'winner_id', v_winner_id,
          'ended_reason', v_completed_room.ended_reason,
          'forfeited_by', v_completed_room.forfeited_by,
          'finished_at', v_completed_room.finished_at
        ),
        v_completed_room.finished_at,
        v_completed_room.created_at
      )
      on conflict (room_id, player_id) do nothing;
    end loop;
  end loop;

  for v_room in
    select r.id, r.status, r.host_id,
      (r.is_custom and r.max_players > 2) as is_crowd
    from public.rooms r
    where r.status in ('lobby', 'active')
      and (
        r.host_id = v_user_id
        or exists (
          select 1
          from public.room_players rp
          where rp.room_id = r.id
            and rp.player_id = v_user_id
        )
      )
    order by r.id
    for update of r
  loop
    if v_room.is_crowd then
      -- Kalabalık oda: hesabı silen oyuncu "ayrılmış" sayılır; oda başkalarıyla
      -- sürer (lobide host devri, oyunda left_at, aktif < 2 ise erken bitiş).
      perform public.crowd_room_member_leave(v_room.id, v_user_id);
    elsif v_room.status = 'active' then
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'account_deleted',
        forfeited_by = v_user_id
      where r.id = v_room.id;

      delete from public.matchmaking_queue mq
      where mq.room_id = v_room.id;

      perform public.refund_room_entry_fees(v_room.id, v_user_id);
    elsif v_room.status = 'lobby'
          and v_room.host_id = v_user_id then
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'host_left',
        forfeited_by = null
      where r.id = v_room.id;

      delete from public.matchmaking_queue mq
      where mq.room_id = v_room.id;

      perform public.refund_room_entry_fees(v_room.id, v_user_id);
    end if;
  end loop;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_user_id;

  delete from public.favorite_questions
  where player_id = v_user_id;

  delete from public.coin_transactions
  where player_id = v_user_id;

  if to_regclass('public.questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.questions')
         and attname = 'created_by'
         and not attisdropped
     ) then
    execute
      'update public.questions set created_by = null where created_by = $1'
      using v_user_id;
  end if;

  if to_regclass('public.suggested_questions') is not null
     and exists (
       select 1 from pg_catalog.pg_attribute
       where attrelid = to_regclass('public.suggested_questions')
         and attname = 'reviewed_by'
         and not attisdropped
     ) then
    execute
      'update public.suggested_questions set reviewed_by = null '
      || 'where reviewed_by = $1'
      using v_user_id;
  end if;

  update public.question_reports
  set reporter_id = null
  where reporter_id = v_user_id;

  delete from public.player_answers
  where player_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = v_user_id::text;

  delete from auth.users
  where id = v_user_id;

  return json_build_object('deleted', true);
end;
$function$;

-- ---------------------------------------------------------------------
-- get_my_resumable_room: ayrılan geri çağrılmaz; is_custom/max_players
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_resumable_room()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_answers jsonb := '[]'::jsonb;
  v_pending_answer jsonb := null;
  v_own_score integer := 0;
  v_own_streak integer := 0;
  v_correct_count integer := 0;
  v_wrong_count integer := 0;
  v_best_streak integer := 0;
  v_server_now timestamp with time zone;
  v_current_started_at timestamp with time zone;
  v_current_deadline timestamp with time zone;
  v_remaining_ms integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select
    r.id,
    r.code,
    r.host_id,
    r.status,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    coalesce(r.current_question_index, 0) as current_question_index,
    r.is_custom,
    r.max_players,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  left join public.categories c on c.id = r.category_id
  where rp.player_id = v_uid
    -- Oyundan ayrılan/düşen oyuncu odaya geri çağrılmaz.
    and rp.left_at is null
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for share of r;

  if not found then
    return null;
  end if;

  v_server_now := clock_timestamp();

  -- Sonuç alanları yalnız açıkça reveal edilmiş (ve eski veri için geçmiş
  -- indekste kalmış) sorulardan üretilir. Böylece hem cevap listesi hem de
  -- skor/sayaç/seri aynı sızıntısız veri kümesine dayanır.
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'question_index', rq.question_index,
          'question_id', rq.question_id,
          'selected_option', pa.selected_option,
          'is_correct', pa.is_correct,
          'points_awarded', pa.points_awarded,
          'response_ms', pa.response_ms,
          'correct_option', q.correct_option,
          'explanation', q.explanation,
          'explanation_ku', q.explanation_ku,
          'explanation_tr', q.explanation_tr
        ) order by rq.question_index
      ),
      '[]'::jsonb
    ),
    coalesce(sum(pa.points_awarded), 0)::integer,
    count(*) filter (where pa.is_correct)::integer,
    count(*) filter (where not pa.is_correct)::integer
  into v_answers, v_own_score, v_correct_count, v_wrong_count
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  join public.questions q on q.id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid
    and (
      rq.question_index < v_room.current_question_index
      or rq.revealed_at is not null
    );

  select count(*)::integer
  into v_own_streak
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid
    and pa.is_correct
    and (
      rq.question_index < v_room.current_question_index
      or rq.revealed_at is not null
    )
    and rq.question_index > coalesce((
      select max(wrong_rq.question_index)
      from public.player_answers wrong_answer
      join public.room_questions wrong_rq
        on wrong_rq.room_id = wrong_answer.room_id
        and wrong_rq.question_id = wrong_answer.question_id
      where wrong_answer.room_id = v_room.id
        and wrong_answer.player_id = v_uid
        and not wrong_answer.is_correct
        and (
          wrong_rq.question_index < v_room.current_question_index
          or wrong_rq.revealed_at is not null
        )
    ), -1);

  -- Soru sırasındaki reveal edilmiş kesintisiz doğru gruplarının en büyüğü.
  select coalesce(max(streaks.streak_length), 0)::integer
  into v_best_streak
  from (
    select count(*)::integer as streak_length
    from (
      select
        pa.is_correct,
        sum(case when pa.is_correct then 0 else 1 end) over (
          order by rq.question_index
        ) as wrong_group
      from public.player_answers pa
      join public.room_questions rq
        on rq.room_id = pa.room_id and rq.question_id = pa.question_id
      where pa.room_id = v_room.id
        and pa.player_id = v_uid
        and (
          rq.question_index < v_room.current_question_index
          or rq.revealed_at is not null
        )
    ) ordered_answers
    where ordered_answers.is_correct
    group by ordered_answers.wrong_group
  ) streaks;

  -- Mevcut soru için gönderilmiş fakat reveal edilmemiş cevap yalnız güvenli
  -- seçim/zaman alanlarıyla ayrı taşınır.
  select jsonb_build_object(
    'question_index', pending_rq.question_index,
    'question_id', pending.question_id,
    'selected_option', pending.selected_option,
    'response_ms', pending.response_ms
  )
  into v_pending_answer
  from public.player_answers pending
  join public.room_questions pending_rq
    on pending_rq.room_id = pending.room_id
    and pending_rq.question_id = pending.question_id
  where pending.room_id = v_room.id
    and pending.player_id = v_uid
    and pending_rq.question_index = v_room.current_question_index
    and pending_rq.revealed_at is null
  limit 1;

  select rq.started_at
  into v_current_started_at
  from public.room_questions rq
  where rq.room_id = v_room.id
    and rq.question_index = v_room.current_question_index;

  if v_current_started_at is not null then
    v_current_deadline := v_current_started_at + make_interval(
      secs => greatest(1, coalesce(v_room.seconds_per_question, 20))
    );
    v_remaining_ms := least(
      2147483647::bigint,
      greatest(
        0::bigint,
        floor(
          extract(epoch from (v_current_deadline - v_server_now)) * 1000
        )::bigint
      )
    )::integer;
  end if;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'is_custom', v_room.is_custom,
    'max_players', v_room.max_players,
    'status', v_room.status,
    'category_name', v_room.category_name,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'current_question_index', v_room.current_question_index,
    'own_score', v_own_score,
    'own_streak', v_own_streak,
    'correct_count', v_correct_count,
    'wrong_count', v_wrong_count,
    'best_streak', v_best_streak,
    'answers', v_answers,
    'pending_answer', v_pending_answer,
    'server_now', v_server_now,
    'current_question_started_at', v_current_started_at,
    'current_question_deadline', v_current_deadline,
    'current_question_remaining_ms', v_remaining_ms
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- join_matchmaking / touch_matchmaking / cancel_matchmaking: ayrılan oyuncu 'canlı oda üyesi' değil
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_matchmaking(p_category_name text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      and mine.left_at is null
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
      and mine.left_at is null
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
          and live_player.left_at is null
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
  -- 2026-10-15: yalnız 40 sn kuralı değil, kalp atışı da: `last_seen_at`
  -- dolu satır (touch_matchmaking çağıran istemci) 12 sn içinde görülmediyse
  -- hayalettir; NULL (eski istemci) eski 40 sn kuralıyla aynen kalır.
  delete from public.matchmaking_queue mq
  where mq.room_id is null
    and upper(mq.category_name) = upper(v_category_name)
    and not (
        (mq.last_seen_at is null
          and mq.joined_at >= now() - interval '40 seconds')
        or coalesce(mq.last_seen_at > now() - interval '12 seconds', false)
      );

  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)
    and mq.player_id <> v_player_id
    and mq.room_id is null
    and (
        (mq.last_seen_at is null
          and mq.joined_at >= now() - interval '40 seconds')
        or coalesce(mq.last_seen_at > now() - interval '12 seconds', false)
      )
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
        and existing_player.left_at is null
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
$function$;

CREATE OR REPLACE FUNCTION public.touch_matchmaking()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_category text;
  v_snapshot json;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select mq.category_name into v_category
  from public.matchmaking_queue mq
  where mq.player_id = v_player_id
    and mq.room_id is null;

  -- join_matchmaking eşleşmede bekleyen satırı `for update skip locked` ile
  -- seçer; kalp atışı satırı tam o anda kilitlerse çift birbirini kaçırırdı.
  -- Aynı kategori kilidi ikisini sıralar (join de satırdan ÖNCE alır).
  if v_category is not null then
    perform pg_advisory_xact_lock(
      hashtextextended('matchmaking:' || lower(v_category), 0)
    );
  end if;

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
   and mine.left_at is null
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
  limit 1;

  if found then
    return v_snapshot;
  end if;

  if v_category is not null then
    update public.matchmaking_queue mq
    set last_seen_at = now()
    where mq.player_id = v_player_id
      and mq.room_id is null;

    if found then
      return json_build_object('status', 'waiting');
    end if;
  end if;

  return json_build_object('status', 'none');
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_matchmaking()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room_id uuid;
  v_live_room_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Queue işaretinden önce yetkili canlı üyelik kaynak kabul edilir.
  select r.id into v_live_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and rp.left_at is null
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if found then
    return json_build_object(
      'status', 'matched',
      'room_id', v_live_room_id
    );
  end if;

  select mq.room_id into v_room_id
  from public.matchmaking_queue mq
  where mq.player_id = v_uid
  for update;

  if found then
    if v_room_id is not null then
      -- Rakibin transaction'ı queue kilidini bıraktıktan sonra üyeliği tekrar
      -- denetle; ilk sorgu eşleşme commitinden hemen önce çalışmış olabilir.
      select r.id into v_live_room_id
      from public.rooms r
      join public.room_players rp on rp.room_id = r.id
      where r.id = v_room_id
        and rp.player_id = v_uid
        and rp.left_at is null
        and r.status in ('lobby', 'active');

      if found then
        return json_build_object(
          'status', 'matched',
          'room_id', v_live_room_id
        );
      end if;

      delete from public.matchmaking_queue mq
      where mq.player_id = v_uid
        and mq.room_id = v_room_id;
      return json_build_object('status', 'cancelled');
    end if;

    delete from public.matchmaking_queue mq
    where mq.player_id = v_uid
      and mq.room_id is null;
    return json_build_object('status', 'cancelled');
  end if;

  return json_build_object('status', 'idle');
end;
$function$;

-- ---------------------------------------------------------------------
-- Doğrulama
-- ---------------------------------------------------------------------
do $$
declare
  v_missing text;
begin
  select string_agg(x, ', ') into v_missing
  from (values
    ('rooms.is_custom', exists (select 1 from information_schema.columns where table_schema='public' and table_name='rooms' and column_name='is_custom')),
    ('rooms.max_players', exists (select 1 from information_schema.columns where table_schema='public' and table_name='rooms' and column_name='max_players')),
    ('room_players.left_at', exists (select 1 from information_schema.columns where table_schema='public' and table_name='room_players' and column_name='left_at')),
    ('create_online_room(5 arg)', to_regprocedure('public.create_online_room(text, integer, integer, integer, integer)') is not null),
    ('create_online_room(eski 4 arg yok)', to_regprocedure('public.create_online_room(text, integer, integer, integer)') is null),
    ('crowd_room_member_leave', to_regprocedure('public.crowd_room_member_leave(uuid, uuid)') is not null),
    ('crowd_room_result_complete', to_regprocedure('public.crowd_room_result_complete(uuid)') is not null)
  ) as checks(x, ok)
  where not ok;

  if v_missing is not null then
    raise exception 'Kalabalık oda göçü doğrulaması başarısız: %', v_missing;
  end if;
end;
$$;

commit;
