-- ZanKurd 2.2 — Yönetim: moderasyonun OYUNDA uygulanması (CANLIYA UYGULANMADI).
--
-- Niçin: 2026-11-12_yonetim_paneli.sql sahibe "engelle / askıya al" düğmesi
-- verir ve durumu `user_moderation`a yazar; ama oyun yolları o tabloyu hiç
-- okumuyordu. Engelli bir oyuncu odaya katılıp, düello açıp, sohbet yazıp
-- sıralamada görünmeye devam ederdi: düğme yalnız etiketti.
--
-- Kısıtlı = `public.user_is_restricted(uid)` (11-12 göçünde): durum 'blocked'
-- ya da süresi dolmamış 'suspended'. 'warned' kısıtlamaz.
--
-- Ne yapar:
--   YENİ NESNELER (gövde md5 ön koşulu gerekmez; canlı gövdeye dokunmaz):
--   1. room_players BEFORE INSERT  -> kısıtlı hesap odaya (özel oda, eşleşme,
--      davet, rövanş: hepsi bu tabloya yazar) KATILAMAZ / oda KURAMAZ.
--   2. async_duels BEFORE INSERT   -> kısıtlı hesap düello AÇAMAZ (ya da kısıtlı
--      birini davet edemez); BEFORE UPDATE OF opponent_id -> kısıtlı hesap
--      düelloyu KABUL EDEMEZ / eşleşemez.
--   3. room_messages BEFORE INSERT -> kısıtlı hesap oda sohbetine YAZAMAZ.
--      Hepsi errcode 42501, mesaj 'account_restricted'. Zaten odada olan
--      kısıtlı oyuncu odayı terk edebilir (silme/güncelleme engellenmez).
--   YAMALANAN CANLI İŞLEVLER (tam gövde md5 ön koşulu, olcek_tur3_yedek yedeği
--   'yonetim:<imza>', yama md5 zinciri, geri alma dosyası):
--   4. leaderboard_daily_rows(integer,uuid[]) -> get_leaderboard,
--      get_my_leaderboard_rank, get_friends_leaderboard'ın ORTAK kaynağı: kısıtlı
--      hesabın puanı tüm sıralamalardan düşer.
--   5. get_verified_daily_event_board() -> günün yarışması panosu (dünün
--      birincisi dahil) kısıtlı hesabı göstermez.
--
-- CANLI TABAN gövdeleri (md5 = pg_get_functiondef, canlıda DOĞRULANACAK):
--   leaderboard_daily_rows : 2026-11-04_olcek_sertlestirme.sql gövdesi + 2026-11-05_olcek_tur4.sql
--                            yaması (tüm zamanlar player_score_total'dan).
--   get_verified_daily_event_board : 2026-10-24_gunun_yarismasi_sonuc.sql get_daily_event_board
--                            gövdesinin 2026-11-01_solo_daily_verified.sql'deki yeniden adlandırması
--                            (daily_event_results -> verified_daily_event_results) + search_path.
--   Canlı gövde bu tabanlardan HERHANGİ biriyle birebir (md5) uyuşmazsa göç DURUR
--   (başka bir göç araya girmiş olabilir); ya da tam nihai md5'te ve yedek zinciri
--   sağlamsa "zaten uygulanmış" sayılır.
--
-- BİLİNÇLİ AÇIKLAR (yazılı):
--   * Haftalık lig kümeleri (`get_my_league*`) ve turnuva katılımı henüz kısıtlıyı
--     süzmez (ayrı, test'li iş). Ödül adaylarında kısıtlı hesap zaten yok
--     (11-12 göçünün `_admin_reward_top3`ü).
--   * Arkadaş sıralamasında (`get_friends_leaderboard`) kısıtlı arkadaş 0 puanla
--     satırda kalabilir; toplam puanı artık sıralamaya girmez.
--   * Odada ZATEN bulunan kısıtlı oyuncu o oyunu bitirebilir (yeni giriş engelli).
--
-- Önkoşul: 2026-11-12_yonetim_paneli.sql uygulanmış olmalı.
-- Uygulama: supabase db query --linked -f supabase/2026-11-13_yonetim_moderasyon.sql
-- Geri alma: supabase/geri_al/2026-11-13_yonetim_moderasyon_geri.sql
-- Yerel test: node tool/test_yonetim_moderasyon_local.mjs <pglite index.js>
begin;

set local lock_timeout = '10s';

do $yonetim_onkosul$
begin
  if to_regprocedure('public.user_is_restricted(uuid)') is null
     or to_regclass('public.user_moderation') is null
     or to_regprocedure('public.leaderboard_daily_rows(integer,uuid[])') is null
     or to_regprocedure('public.get_verified_daily_event_board()') is null
     or to_regclass('public.room_players') is null
     or to_regclass('public.async_duels') is null
     or to_regclass('public.room_messages') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'yonetim: beklenen canlı nesneler eksik (2026-11-12_yonetim_paneli.sql uygulandı mı?); göçü uygulamadan önce incele';
  end if;
  -- Yedek tablosu istemci rollerine kapalı (geri alma bu satırlardaki gövdeyi
  -- çalıştırır; yazılabilir olması keyfi kod çalıştırmak demektir).
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'yonetim: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) then
    raise exception 'yonetim: olcek_tur3_yedek sahibi dışında alıcıya açık (relacl)';
  end if;
end;
$yonetim_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef). Gövde ya
-- (a) tam bu taban olmalı -> yamalanır, ya (b) tam nihai md5'te ve yedek satırı +
-- md5 zinciri sağlam olmalı -> zaten uygulanmış, atlanır. Başka her durum göçü
-- durdurur. sahip / acl / ayar: yamadan önceki sahip, ACL ve proconfig; yama
-- sonrası değişmediği doğrulanır.
create temp table yonetim_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $yonetim_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.leaderboard_daily_rows(integer,uuid[])', '260271e66cb19aa95204c2db727f5793', '5e385ad884518bcc9581783665818291'),
    ('public.get_verified_daily_event_board()', '338cd6ba9c0890904dd0be9643bdb5cb', '06bf892cb68ba18ddb8cfad50f2fa192')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into yonetim_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'yonetim: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'yonetim:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'yonetim: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into yonetim_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$yonetim_durum$;

-- Yamalayıcı (tur7 ile aynı). Uygulanmış sayılması: yeni parça TAM BİR kez var ve
-- yeni parça çıkarıldığında eski parça kalmamış. Yamalanması: eski parça TAM BİR kez
-- var ve yeni parça YOK. Başka her durum göçü durdurur. Her yamadan önce CANLI gövde
-- (ve md5'i) yedeğe yazılır; bir işlevin birden çok yaması aynı yedek satırını paylaşır
-- (ilk yama ORİJİNALİ yazar).
create or replace function pg_temp.yonetim_yama(p_imza text, p_eski text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_oid regprocedure := to_regprocedure(p_imza);
  v_def text;
  v_eski_n integer;
  v_yeni_n integer;
  v_kalan_n integer;
  v_yedek text;
begin
  if v_oid is null then
    raise exception 'yonetim: işlev yok: %', p_imza;
  end if;
  v_def := pg_get_functiondef(v_oid);
  v_eski_n := (length(v_def) - length(replace(v_def, p_eski, ''))) / length(p_eski);
  v_yeni_n := (length(v_def) - length(replace(v_def, p_yeni, ''))) / length(p_yeni);
  v_kalan_n := (length(replace(v_def, p_yeni, ''))
                - length(replace(replace(v_def, p_yeni, ''), p_eski, ''))) / length(p_eski);
  if v_yeni_n = 1 and v_kalan_n = 0 then
    return; -- zaten uygulanmış
  end if;
  if v_yeni_n <> 0 or v_eski_n <> 1 then
    raise exception 'yonetim: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'yonetim:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('yonetim:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'yonetim:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- 1-3. Tetikleyiciler (yeni nesneler)
-- ---------------------------------------------------------------------------
create or replace function public.moderation_guard_room_player()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if public.user_is_restricted(new.player_id) then
    raise exception 'account_restricted' using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_moderation_room_players on public.room_players;
create trigger trg_moderation_room_players
  before insert on public.room_players
  for each row execute function public.moderation_guard_room_player();

create or replace function public.moderation_guard_async_duel()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if tg_op = 'INSERT' then
    -- Düelloyu AÇAN kısıtlı olamaz; kısıtlı birini davet de edilemez.
    if public.user_is_restricted(new.creator_id)
       or (new.invited_id is not null and public.user_is_restricted(new.invited_id)) then
      raise exception 'account_restricted' using errcode = '42501';
    end if;
  elsif new.opponent_id is not null
        and new.opponent_id is distinct from old.opponent_id
        and public.user_is_restricted(new.opponent_id) then
    -- Düelloyu KABUL EDEN / eşleşen kısıtlı olamaz.
    raise exception 'account_restricted' using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_moderation_async_duels on public.async_duels;
create trigger trg_moderation_async_duels
  before insert or update of opponent_id on public.async_duels
  for each row execute function public.moderation_guard_async_duel();

-- Oda sohbeti: gönderen = çağıranın kimliği (enforce_chat_moderation da sender_id'yi
-- auth.uid() yapar); istemci başkası adına yazamaz, kısıtlı hesap hiç yazamaz.
create or replace function public.moderation_guard_room_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if public.user_is_restricted(auth.uid()) then
    raise exception 'account_restricted' using errcode = '42501';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_moderation_room_messages on public.room_messages;
create trigger trg_moderation_room_messages
  before insert on public.room_messages
  for each row execute function public.moderation_guard_room_message();

revoke all on function public.moderation_guard_room_player() from public, anon, authenticated;
revoke all on function public.moderation_guard_async_duel() from public, anon, authenticated;
revoke all on function public.moderation_guard_room_message() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. leaderboard_daily_rows: kısıtlı hesap TÜM sıralamalardan düşer.
--    Üç UNION kolunun her birine süzgeç eklenir; süzgeç satır başına işlev
--    çağırmaz (tüm zamanlar panosu bütün oyuncuları tarar), küçük user_moderation
--    tablosuna karşı anti-join'dir. Her adım tek başına geçerli gövde üretir.
-- ---------------------------------------------------------------------------
select pg_temp.yonetim_yama(
  'public.leaderboard_daily_rows(integer,uuid[])',
  $e$  where e.ts is not null and a.day > e.d
    and (p_player_ids is null or a.player_id = any(p_player_ids))
$e$,
  $y$  where e.ts is not null and a.day > e.d
    and (p_player_ids is null or a.player_id = any(p_player_ids))
    -- (2026-11-13) Yönetici kısıtlaması: engelli / askıdaki hesap sıralamada yok.
    and not exists (
      select 1 from public.user_moderation m
      where m.user_id = a.player_id
        and (m.state = 'blocked'
             or (m.state = 'suspended' and (m.until is null or m.until > now())))
    )
$y$)
from yonetim_durum d
where d.imza = 'public.leaderboard_daily_rows(integer,uuid[])' and d.gerekli;

select pg_temp.yonetim_yama(
  'public.leaderboard_daily_rows(integer,uuid[])',
  $e$  where p_days <= 0
    and (p_player_ids is null or t.player_id = any(p_player_ids))
$e$,
  $y$  where p_days <= 0
    and (p_player_ids is null or t.player_id = any(p_player_ids))
    -- (2026-11-13) Yönetici kısıtlaması: engelli / askıdaki hesap sıralamada yok.
    and not exists (
      select 1 from public.user_moderation m
      where m.user_id = t.player_id
        and (m.state = 'blocked'
             or (m.state = 'suspended' and (m.until is null or m.until > now())))
    )
$y$)
from yonetim_durum d
where d.imza = 'public.leaderboard_daily_rows(integer,uuid[])' and d.gerekli;

select pg_temp.yonetim_yama(
  'public.leaderboard_daily_rows(integer,uuid[])',
  $e$  where coalesce(r.ended_reason, 'completed') = 'completed'
    and (p_player_ids is null or rp.player_id = any(p_player_ids))
$e$,
  $y$  where coalesce(r.ended_reason, 'completed') = 'completed'
    and (p_player_ids is null or rp.player_id = any(p_player_ids))
    -- (2026-11-13) Yönetici kısıtlaması: engelli / askıdaki hesap sıralamada yok.
    and not exists (
      select 1 from public.user_moderation m
      where m.user_id = rp.player_id
        and (m.state = 'blocked'
             or (m.state = 'suspended' and (m.until is null or m.until > now())))
    )
$y$)
from yonetim_durum d
where d.imza = 'public.leaderboard_daily_rows(integer,uuid[])' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 5. get_verified_daily_event_board: günün yarışması panosu
-- ---------------------------------------------------------------------------
select pg_temp.yonetim_yama(
  'public.get_verified_daily_event_board()',
  $e$        where b.blocker_id = auth.uid() and b.blocked_id = r.user_id
      )
  )$e$,
  $y$        where b.blocker_id = auth.uid() and b.blocked_id = r.user_id
      )
      -- (2026-11-13) Yönetici kısıtlaması: engelli / askıdaki hesap panoda yok.
      and not public.user_is_restricted(r.user_id)
  )$y$)
from yonetim_durum d
where d.imza = 'public.get_verified_daily_event_board()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- Yama sonrası güvenlik doğrulaması: sahip, ACL, proconfig, SECURITY DEFINER
-- DEĞİŞMEDİ; nihai md5 tam; anon/PUBLIC EXECUTE yok.
-- ---------------------------------------------------------------------------
do $yonetim_son$
declare
  r record;
begin
  for r in select * from yonetim_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'yonetim: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'yonetim: % yama sonrası gövde beklenen nihai md5 değil (bulunan %)', r.imza, md5(pg_get_functiondef(to_regprocedure(r.imza)));
    end if;
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                   and p.prosecdef and p.proconfig is not null) then
      raise exception 'yonetim: % SECURITY DEFINER + sabit search_path değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'yonetim: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  -- Tetikleyici işlevleri: definer + sabit search_path + istemciye kapalı.
  for r in
    select p.oid::regprocedure::text as sig, p.prosecdef, p.proconfig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'moderation\_guard\_%'
  loop
    if not r.prosecdef or r.proconfig is null then
      raise exception 'yonetim: % SECURITY DEFINER + sabit search_path değil', r.sig;
    end if;
    if has_function_privilege('anon', r.sig::regprocedure, 'execute')
       or has_function_privilege('authenticated', r.sig::regprocedure, 'execute')
       or has_function_privilege('public', r.sig::regprocedure, 'execute') then
      raise exception 'yonetim: % istemciye açık', r.sig;
    end if;
  end loop;
  if (select count(*) from pg_trigger t
      where t.tgname in ('trg_moderation_room_players', 'trg_moderation_async_duels',
                         'trg_moderation_room_messages') and t.tgenabled <> 'D') <> 3 then
    raise exception 'yonetim: moderasyon tetikleyicileri eksik ya da kapalı';
  end if;
end;
$yonetim_son$;

commit;
