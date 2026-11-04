-- Geri alma: 2026-11-05_olcek_tur3.sql
-- Yamalanan işlevleri (join_matchmaking, touch_matchmaking, cleanup_stale_rooms,
-- on_room_score_daily) yamalı metni eskisine çevirerek, get_my_leaderboard_rank'ı
-- göç anında yedeklenen (olcek_tur3_yedek) tam gövdeye döndürür; yedek yoksa ve
-- canlı gövde eski değilse durur;
-- yeni işlevleri, tabloyu, küçük indeksi ve cron işlerini kaldırır. BÜYÜK
-- indeksler (CONCURRENTLY dosyası) zararsızdır, kalır; istenirse transaction
-- dışında: drop index concurrently if exists public.idx_rooms_open_created,
-- public.push_outbox_terminal_created_idx, public.rate_limit_events_created_idx;
-- (idx_rooms_finished_at_finished 11-04 dosyasına ait, silinmez).
begin;

set local lock_timeout = '10s';

-- (2026-11-06) Ters göç sırası: olcek_tur3_yedek ortak yedek tablosudur; tur4/5/6/7
-- göçleri kendi geri alma gövdelerini 'turN:<imza>' satırlarında burada tutar. Bu dosya
-- tabloyu düşürürse o geri almalar imkânsızlaşır: sonraki göçler önce geri alınmalı.
do $tur3_sira$
begin
  if to_regclass('public.olcek_tur3_yedek') is not null
     and exists (select 1 from public.olcek_tur3_yedek where ad ~ '^tur[0-9]+:') then
    raise exception 'tur3 geri: olcek_tur3_yedek''te sonraki göçlerin (tur4+) yedek satırları var; önce onları ters sırayla geri al (tur7, tur6, tur5, tur4), sonra bunu çalıştır';
  end if;
end;
$tur3_sira$;

create or replace function pg_temp.tur3_geri(p_imza text, p_yamali text, p_asil text)
returns void language plpgsql as $geri$
declare
  v_def text;
  v_adet integer;
begin
  v_def := pg_get_functiondef(to_regprocedure(p_imza));
  if v_def is null then
    raise exception 'tur3 geri: işlev yok: %', p_imza;
  end if;
  if position(p_yamali in v_def) = 0 then
    return;
  end if;
  v_adet := (length(v_def) - length(replace(v_def, p_yamali, ''))) / length(p_yamali);
  if v_adet <> 1 then
    raise exception 'tur3 geri: % için yamalı metin % kez bulundu (1 beklenir)', p_imza, v_adet;
  end if;
  execute replace(v_def, p_yamali, p_asil);
end;
$geri$;

create or replace function pg_temp.tur3_geri2(
  p_imza text, p_y1 text, p_e1 text, p_y2 text, p_e2 text)
returns void language plpgsql as $geri2$
declare
  v_def text;
begin
  v_def := pg_get_functiondef(to_regprocedure(p_imza));
  if v_def is null then
    raise exception 'tur3 geri: işlev yok: %', p_imza;
  end if;
  if position(p_y1 in v_def) = 0 and position(p_y2 in v_def) = 0 then
    return;
  end if;
  if (length(v_def) - length(replace(v_def, p_y1, ''))) / length(p_y1) <> 1
     or (length(v_def) - length(replace(v_def, p_y2, ''))) / length(p_y2) <> 1 then
    raise exception 'tur3 geri: % için yamalı metin 1 kez bulunamadı', p_imza;
  end if;
  execute replace(replace(v_def, p_y1, p_e1), p_y2, p_e2);
end;
$geri2$;

-- join_matchmaking: önce loop çifti, sonra bayat silme, kilit satırı, bildirim.
select pg_temp.tur3_geri2('public.join_matchmaking(text)',
  $a$  v_pass := 0;
  loop
  v_pass := v_pass + 1;
  v_opponent := null;
  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)$a$,
  $a$  select mq.player_id into v_opponent
  from public.matchmaking_queue mq
  where upper(mq.category_name) = upper(v_category_name)$a$,
  $a$  if v_opponent is null and v_pass = 1 then
    -- İkinci geçiş: kategori kilidi (kendi satırından SONRA ama hiçbir satır
    -- kilidi beklemeden; bayat silme skip locked, rakip arama skip locked).
    perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));
    continue;
  end if;
  if v_opponent is null and v_pass < 6 and exists (
    select 1
    from public.matchmaking_queue w
    where upper(w.category_name) = upper(v_category_name)
      and w.player_id <> v_player_id
      and w.room_id is null
      and (
          (w.last_seen_at is null
            and w.joined_at >= now() - interval '40 seconds')
          or coalesce(w.last_seen_at > now() - interval '12 seconds', false)
        )
  ) then
    -- Aday var ama kilitli (kalp atışı/başka eşleşme): kısa bekle, yeniden ara.
    perform pg_sleep(0.03);
    continue;
  end if;
  exit;
  end loop;

  if v_opponent is null then
    insert into public.matchmaking_queue ($a$,
  $a$  if v_opponent is null then
    insert into public.matchmaking_queue ($a$);
select pg_temp.tur3_geri('public.join_matchmaking(text)',
  $a$  delete from public.matchmaking_queue mq
  where mq.ctid in (
    select s.ctid
    from public.matchmaking_queue s
    where s.room_id is null
      and upper(s.category_name) = upper(v_category_name)
      and not (
          (s.last_seen_at is null
            and s.joined_at >= now() - interval '40 seconds')
          or coalesce(s.last_seen_at > now() - interval '12 seconds', false)
        )
    for update skip locked
  );$a$,
  $a$  delete from public.matchmaking_queue mq
  where mq.room_id is null
    and upper(mq.category_name) = upper(v_category_name)
    and not (
        (mq.last_seen_at is null
          and mq.joined_at >= now() - interval '40 seconds')
        or coalesce(mq.last_seen_at > now() - interval '12 seconds', false)
      );$a$);
select pg_temp.tur3_geri('public.join_matchmaking(text)',
  $a$  -- (2026-11-05) matchmaking:<kategori> kilidi artık yalnız ikinci geçişte
  -- (rakip bulunamadıysa) alınır; ilk geçiş kilitsizdir.$a$,
  $a$  perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));$a$);
select pg_temp.tur3_geri('public.join_matchmaking(text)',
  $a$  v_attempt integer;
  v_pass integer;
begin
  if v_player_id is null then$a$,
  $a$  v_attempt integer;
begin
  if v_player_id is null then$a$);

-- touch_matchmaking
select pg_temp.tur3_geri('public.touch_matchmaking()',
  $a$  -- (2026-11-05) Kategori kilidi KALDIRILDI: join ikinci geçişte satır kilidi
  -- tutarken kategori kilidini bekler; burada tersi sıra kilitlenme üretirdi.
  -- Arama kilitli satırı görürse kısa yeniden dener.$a$,
  $a$  if v_category is not null then
    perform pg_advisory_xact_lock(
      hashtextextended('matchmaking:' || lower(v_category), 0)
    );
  end if;$a$);

-- cleanup_stale_rooms
select pg_temp.tur3_geri('public.cleanup_stale_rooms()',
  $a$        coalesce(r.started_at, r.created_at) < now() - interval '10 minutes'
        and greatest(
          coalesce(r.started_at, r.created_at),$a$,
  $a$        greatest(
          coalesce(r.started_at, r.created_at),$a$);
select pg_temp.tur3_geri('public.cleanup_stale_rooms()',
  $a$      r.status = 'lobby'
      and r.created_at < now() - interval '30 minutes'
      and greatest($a$,
  $a$      r.status = 'lobby'
      and greatest($a$);

-- on_room_score_daily
select pg_temp.tur3_geri2('public.on_room_score_daily()',
  $a$    select rp.player_id from public.room_players rp where rp.room_id = new.id
    order by rp.player_id
  loop$a$,
  $a$    select rp.player_id from public.room_players rp where rp.room_id = new.id
  loop$a$,
  $a$    if v_old_day is not null and (v_new_day is null or v_old_day <= v_new_day) then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;
    if v_new_day is not null and v_new_day is distinct from v_old_day then
      perform public.recompute_player_score_day(v_player, v_new_day);
    end if;
    if v_old_day is not null and v_new_day is not null and v_old_day > v_new_day then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;$a$,
  $a$    if v_old_day is not null then
      perform public.recompute_player_score_day(v_player, v_old_day);
    end if;
    if v_new_day is not null and v_new_day is distinct from v_old_day then
      perform public.recompute_player_score_day(v_player, v_new_day);
    end if;$a$);

-- get_my_leaderboard_rank: göç anında yedeklenen tam gövde.
do $tur3_rank_geri$
declare
  v_yedek text;
  v_def text := pg_get_functiondef('public.get_my_leaderboard_rank(integer)'::regprocedure);
begin
  if position('row_number() over' in v_def) > 0 then
    return; -- zaten eski gövde
  end if;
  if to_regclass('public.olcek_tur3_yedek') is not null then
    select y.tanim into v_yedek from public.olcek_tur3_yedek y
    where y.ad = 'get_my_leaderboard_rank(integer)';
  end if;
  if v_yedek is null then
    raise exception 'tur3 geri: get_my_leaderboard_rank yedeği yok ve canlı gövde eski değil; elle incele';
  end if;
  execute v_yedek;
end;
$tur3_rank_geri$;

select cron.unschedule('reconcile-player-score-daily')
where exists (select 1 from cron.job where jobname = 'reconcile-player-score-daily');
select cron.unschedule('push-outbox-retention')
where exists (select 1 from cron.job where jobname = 'push-outbox-retention');
select cron.unschedule('rate-limit-events-sweep')
where exists (select 1 from cron.job where jobname = 'rate-limit-events-sweep');

drop function if exists public.reconcile_player_score_daily(integer);
drop function if exists public.push_outbox_retention(integer, integer);
drop function if exists public.rate_limit_events_sweep(integer);
drop function if exists public.touch_presence_v2();
drop table if exists public.score_reconcile_log;
drop table if exists public.score_reconcile_failures;
-- Yedek tablosu yalnız tur3'ün kendi satırları silinince ve başka satır kalmamışsa düşer.
do $tur3_yedek_temizle$
begin
  if to_regclass('public.olcek_tur3_yedek') is not null then
    delete from public.olcek_tur3_yedek where ad !~ '^tur[0-9]+:';
    if not exists (select 1 from public.olcek_tur3_yedek) then
      drop table public.olcek_tur3_yedek;
    end if;
  end if;
end;
$tur3_yedek_temizle$;
drop index if exists public.matchmaking_queue_waiting_idx;

commit;
