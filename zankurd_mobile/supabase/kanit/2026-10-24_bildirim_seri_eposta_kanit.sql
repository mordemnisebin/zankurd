-- Kanıt betiği: 2026-10-24_bildirim_seri_eposta.sql, bulgular a..p:
-- a sütun varsayılanı (push_duel/push_social açık) · b varsayılan açıkken düello
-- push'u TESLİM edilir · c push_duel kapalıyken düello push'u atlanır · d push_duel kapalıyken arkadaş push'u etkilenmez · e push_social
-- kapalıyken friend_request atlanır · f push_social kapalıyken room_invite
-- atlanır · g set_my_push_prefs null = değişmez · h seri onarımı ilk çağrı
-- 100 jeton keser (ay sunucuda) · i aynı gün ikinci çağrı ÜCRET KESMEZ · i2 geç
-- tekrar already_repaired · j aynı ay başka kırılma günü monthly_limit · k p_premium
-- yok sayılır · l0 24 saat dışı gün reddi · l yetersiz bakiyede ücret/kayıt yok · o2
-- gelecek amr · o3 telefon OTP · q guard tetikleyici bağları · m mark_my_email_verified parola
-- oturumunu REDDEDER · n taze OTP oturumunu kabul eder · o bayat OTP oturumunu
-- reddeder · p istemci email_verified_at'i doğrudan yazamaz (guard).
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `durum`: SONRA-OK (gozlenen = beklenen_sonra), ONCE-DURUMU (gozlenen =
-- beklenen_once; göç henüz yok), BEKLENMEDIK (ikisi de değil). Her sorgu
-- dinamik SQL'dir (sütun/RPC yokken betik hata vermez: 'sütun yok' / 'RPC
-- yok' yazar); başka bir adım hata verirse satırda 'HATA: ...' görünür.
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_bildirim_seri_eposta_kanit.sql
--
-- Hiçbir auth.users satırı eklenmez: auth.users'ta e-postası olan gerçek
-- profillerden üçü seçilir; kimlik set_config('request.jwt.claims') ile
-- taklit edilir. Jeton, push ve profil değişiklikleri bu işlemde kurulur,
-- rollback hepsini siler.
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid, email text) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id, lower(u.email)
from (
  select pr.id
  from public.profiles pr
  join auth.users au on au.id = pr.id
  where au.email is not null and au.email <> ''
  order by pr.id
  limit 3
) p
join auth.users u on u.id = p.id;

do $$
begin
  if (select count(*) from _p) < 3 then
    raise exception 'kanit: auth.users e-postası olan en az 3 profil gerekli';
  end if;
end $$;

create function pg_temp.uid(p_n int) returns uuid
language sql as $f$ select id from _p where n = p_n $f$;

-- Kimliği taklit eder; amr verilirse JWT'ye yazar.
create function pg_temp.kimlik(p_user uuid, p_amr jsonb default null)
returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object(
      'sub', p_user,
      'email', (select email from _p where id = p_user),
      'is_anonymous', false,
      'amr', coalesce(p_amr, '[]'::jsonb)
    )::text, true);
end $f$;

-- RPC çağırır; json metni, hata iletisi ya da 'RPC yok' döner.
create function pg_temp.rpc(p_sql text, p_user uuid, p_amr jsonb default null)
returns text language plpgsql as $f$
declare r text;
begin
  perform pg_temp.kimlik(p_user, p_amr);
  begin
    execute p_sql into r;
    return r;
  exception
    when undefined_function then return 'RPC yok';
    when others then return 'HATA: ' || sqlerrm;
  end;
end $f$;

create function pg_temp.bakiye(p_user uuid) returns int
language sql as $f$
  select coalesce(sum(amount), 0)::int from public.coin_transactions
  where player_id = p_user
$f$;

-- Bir tercih sütunu var mı.
create function pg_temp.sutun_var(p_col text) returns boolean
language sql as $f$
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = p_col)
$f$;

-- push_outbox satırı koyar, claim eder; çağıranın satırı geri dönerse 1.
create function pg_temp.push_teslim(p_to uuid, p_kind text) returns int
language plpgsql as $f$
declare n int;
begin
  update public.profiles set fcm_token = 'kanit-token' where id = p_to;
  insert into public.push_outbox (to_user_id, kind, title, body)
  values (p_to, p_kind, 'kanit', 'kanit');
  select count(*)::int into n
  from public.claim_push_outbox(100) c
  where c.to_user_id = p_to and c.kind = p_kind;
  return n;
end $f$;

-- ---------------------------------------------------------------- (a)
insert into _kanit values (1, '(a) push_duel sütunu varsayılan true',
  'sütun yok', 'true',
  case when pg_temp.sutun_var('push_duel')
    then (select column_default from information_schema.columns
          where table_schema = 'public' and table_name = 'profiles'
            and column_name = 'push_duel')
    else 'sütun yok' end);
insert into _kanit values (2, '(a) push_social sütunu varsayılan true',
  'sütun yok', 'true',
  case when pg_temp.sutun_var('push_social')
    then (select column_default from information_schema.columns
          where table_schema = 'public' and table_name = 'profiles'
            and column_name = 'push_social')
    else 'sütun yok' end);

-- ------------------------------------------------------- (b)..(f) push
-- Önce kuyruğu boşalt: gerçek bekleyen satırlar sayımı bozmasın (rollback).
update public.push_outbox set claimed_at = now() where claimed_at is null;

do $$
declare
  a uuid := pg_temp.uid(1);
  n int;
begin
  -- (b) varsayılan açık: düello push'u teslim edilir.
  n := pg_temp.push_teslim(a, 'async_duel_turn');
  insert into _kanit values (3, '(b) varsayılan açıkken düello push''u teslim',
    '1', '1', n::text);

  if pg_temp.sutun_var('push_duel') then
    -- (c) düello kapalı: atlanır, satır gönderilmeden kapatılır.
    execute 'update public.profiles set push_duel = false where id = $1' using a;
    n := pg_temp.push_teslim(a, 'async_duel_turn');
    insert into _kanit values (4, '(c) push_duel kapalıyken düello push''u teslim',
      '1', '0', n::text);
    -- (d) düello kapalıyken arkadaş türü etkilenmez.
    n := pg_temp.push_teslim(a, 'friend_accept');
    insert into _kanit values (6, '(d) push_duel kapalıyken friend_accept teslim',
      '1', '1', n::text);
    execute 'update public.profiles set push_duel = true where id = $1' using a;
  else
    insert into _kanit values (4, '(c) push_duel kapalıyken düello push''u teslim',
      'sütun yok', '0', 'sütun yok');
    insert into _kanit values (6, '(d) push_duel kapalıyken friend_accept teslim',
      'sütun yok', '1', 'sütun yok');
  end if;

  if pg_temp.sutun_var('push_social') then
    execute 'update public.profiles set push_social = false where id = $1' using a;
    n := pg_temp.push_teslim(a, 'friend_request');
    insert into _kanit values (7, '(e) push_social kapalıyken friend_request teslim',
      '1', '0', n::text);
    n := pg_temp.push_teslim(a, 'room_invite');
    insert into _kanit values (8, '(f) push_social kapalıyken room_invite teslim',
      '1', '0', n::text);
    n := pg_temp.push_teslim(a, 'async_duel_result');
    insert into _kanit values (9, '(f) push_social kapalıyken düello sonucu teslim',
      '1', '1', n::text);
    execute 'update public.profiles set push_social = true where id = $1' using a;
  else
    insert into _kanit values (7, '(e) push_social kapalıyken friend_request teslim',
      'sütun yok', '0', 'sütun yok');
    insert into _kanit values (8, '(f) push_social kapalıyken room_invite teslim',
      'sütun yok', '0', 'sütun yok');
    insert into _kanit values (9, '(f) push_social kapalıyken düello sonucu teslim',
      'sütun yok', '1', 'sütun yok');
  end if;
exception when others then
  insert into _kanit values (3, '(b..f) push süzgeci', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (g)
do $$
declare
  a uuid := pg_temp.uid(1);
  r text; v text;
begin
  r := pg_temp.rpc('select public.set_my_push_prefs(false, null)::text', a);
  if r like 'HATA:%' or r = 'RPC yok' then
    insert into _kanit values (10, '(g) set_my_push_prefs(false, null): social değişmez',
      'RPC yok', 'true', r);
  else
    v := pg_temp.rpc('select (public.get_my_account_flags()->>''push_social'')', a);
    insert into _kanit values (10, '(g) set_my_push_prefs(false, null): social değişmez',
      'RPC yok', 'true', v);
    v := pg_temp.rpc('select (public.get_my_account_flags()->>''push_duel'')', a);
    insert into _kanit values (11, '(g) set_my_push_prefs(false, null): duel kapandı',
      'RPC yok', 'false', v);
  end if;
exception when others then
  insert into _kanit values (10, '(g)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ (h)..(l)
-- Seri onarımı. Ay ve gün SUNUCUDA (Europe/Istanbul); kırılan gün dün.
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2); c uuid := pg_temp.uid(3);
  bugun date := (now() at time zone 'Europe/Istanbul')::date;
  ay text := to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM');
  gun text := to_char(bugun - 1, 'YYYY-MM-DD');
  gun2 text := to_char(bugun, 'YYYY-MM-DD');
  eski text := to_char(bugun - 5, 'YYYY-MM-DD');
  b0 int; b1 int; b2 int; r text;
  sql1 text; sql2 text;
begin
  insert into public.coin_transactions (player_id, amount, reason)
  values (a, 500, 'kanit_yukleme');
  b0 := pg_temp.bakiye(a);

  -- p_month bilerek SAÇMA: sunucu yok sayar, kendi ayını kullanır.
  sql1 := format('select public.spend_streak_repair(%L, %L, false)::text', '1999-01', gun);
  r := pg_temp.rpc(sql1, a);
  b1 := pg_temp.bakiye(a);
  insert into _kanit values (12, '(h) ilk onarım çağrısı bakiyeyi düşürür (p_month yok sayılır)',
    '0', '-100', (b1 - b0)::text);
  select count(*)::text into r from public.coin_transactions
   where player_id = a and reason = 'streak_repair:' || ay;
  insert into _kanit values (13, '(h) ücret sunucu ayıyla yazıldı (streak_repair:<ay>)',
    '0', '1', r);

  r := pg_temp.rpc(sql1, a);
  b2 := pg_temp.bakiye(a);
  insert into _kanit values (14, '(i) aynı gün ikinci çağrı ücret kesmez',
    '0', '0', (b2 - b1)::text);
  insert into _kanit values (15, '(i) ikinci çağrı yanıtı already_repaired',
    'RPC yok', 'true',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'already_repaired', 'yok') end);

  -- (i2) Gece yarısı geçmiş gibi: kayıtlı kırılma günü 5 gün öncesine çekilir;
  -- aynı eski parametreyle tekrar, tarih denetiminden ÖNCE bakılıp
  -- already_repaired döner, ücret kesilmez.
  if to_regclass('public.streak_repairs') is not null then
    execute 'update public.streak_repairs set break_day = $1 where player_id = $2'
      using bugun - 5, a;
  end if;
  r := pg_temp.rpc(format('select public.spend_streak_repair(%L, %L, false)::text', ay, eski), a);
  insert into _kanit values (16, '(i2) geç tekrar (eski gün) already_repaired',
    'RPC yok', 'true',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'already_repaired', 'yok') end);
  insert into _kanit values (17, '(i2) geç tekrar ücret kesmedi',
    '0', '0', (pg_temp.bakiye(a) - b1)::text);

  -- (i3) Ay geçişi: kayıt önceki aya aitmiş gibi (31 Ekim onarımı, 1 Kasım
  -- tekrarı). Aynı kırılma günüyle tekrar ücret KESMEMELİ. Sonra ay geri
  -- alınır ki aşağıdaki aylık sınır satırları etkilenmesin.
  if to_regclass('public.streak_repairs') is not null then
    execute 'update public.streak_repairs set month_key = to_char((now() at time zone ''Europe/Istanbul'') - interval ''1 month'', ''YYYY-MM''), break_day = $2 where player_id = $1'
      using a, bugun - 1;
    update public.coin_transactions
       set reason = 'streak_repair:' || to_char((now() at time zone 'Europe/Istanbul') - interval '1 month', 'YYYY-MM')
     where player_id = a and reason = 'streak_repair:' || ay;
  end if;
  b1 := pg_temp.bakiye(a);
  r := pg_temp.rpc(format('select public.spend_streak_repair(%L, %L, false)::text', ay, gun), a);
  insert into _kanit values (171, '(i3) ay geçişinde aynı kırılma günü tekrarı ücret kesmez',
    '0', '0', (pg_temp.bakiye(a) - b1)::text);
  if to_regclass('public.streak_repairs') is not null then
    execute 'update public.streak_repairs set month_key = $2, break_day = $3 where player_id = $1'
      using a, ay, bugun - 5;
    delete from public.coin_transactions
     where player_id = a and reason = 'streak_repair:' || ay
       and created_at > now() - interval '1 minute'
       and exists (select 1 from public.coin_transactions c2 where c2.player_id = a
                   and c2.reason = 'streak_repair:' || to_char((now() at time zone 'Europe/Istanbul') - interval '1 month', 'YYYY-MM'));
    update public.coin_transactions
       set reason = 'streak_repair:' || ay
     where player_id = a and reason = 'streak_repair:' || to_char((now() at time zone 'Europe/Istanbul') - interval '1 month', 'YYYY-MM');
  end if;

  sql2 := format('select public.spend_streak_repair(%L, %L, false)::text', ay, gun2);
  r := pg_temp.rpc(sql2, a);
  insert into _kanit values (18, '(j) aynı ay başka kırılma günü reddedilir',
    'RPC yok', 'monthly_limit',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);
  insert into _kanit values (19, '(j) reddedilen çağrı ücret kesmedi',
    '0', '0', (pg_temp.bakiye(a) - b1)::text);

  -- (k) p_premium=true YOK SAYILIR: B yine 100 öder.
  insert into public.coin_transactions (player_id, amount, reason)
  values (b, 500, 'kanit_yukleme');
  b0 := pg_temp.bakiye(b);
  r := pg_temp.rpc(format(
    'select public.spend_streak_repair(%L, %L, true)::text', ay, gun), b);
  insert into _kanit values (20, '(k) p_premium=true yok sayılır: bakiye farkı',
    '0', '-100', (pg_temp.bakiye(b) - b0)::text);

  -- (l0) aralık dışı kırılma günü (3 gün önce) reddedilir, ücret yok.
  b0 := pg_temp.bakiye(c);
  r := pg_temp.rpc(format(
    'select public.spend_streak_repair(%L, %L, false)::text', ay,
    to_char(bugun - 3, 'YYYY-MM-DD')), c);
  insert into _kanit values (21, '(l0) 24 saat dışı kırılma günü reddedilir',
    'RPC yok', 'break day out of range',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);
  insert into _kanit values (22, '(l0) reddedilen çağrı ücret kesmedi',
    '0', '0', (pg_temp.bakiye(c) - b0)::text);

  -- (l) yetersiz bakiye: C'nin bakiyesini sıfıra çek.
  b0 := pg_temp.bakiye(c);
  if b0 > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (c, -b0, 'kanit_sifirla');
  end if;
  r := pg_temp.rpc(format(
    'select public.spend_streak_repair(%L, %L, false)::text', ay, gun), c);
  insert into _kanit values (23, '(l) yetersiz bakiyede hata',
    'RPC yok', 'insufficient balance',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);
  insert into _kanit values (24, '(l) yetersiz bakiyede ücret kesilmedi',
    '0', '0', pg_temp.bakiye(c)::text);
exception when others then
  insert into _kanit values (12, '(h..l)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------ (m)..(p)
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2);
  simdi bigint := extract(epoch from now())::bigint;
  r text; v text;
  sql text := 'select public.mark_my_email_verified()::text';
begin
  -- (m) parola oturumu reddedilir.
  r := pg_temp.rpc(sql, a, jsonb_build_array(
    jsonb_build_object('method', 'password', 'timestamp', simdi)));
  insert into _kanit values (30, '(m) parola oturumu doğrulama sayılmaz',
    'RPC yok', 'otp session required',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);

  -- (o) bayat OTP (1 saat önce) reddedilir.
  r := pg_temp.rpc(sql, a, jsonb_build_array(
    jsonb_build_object('method', 'otp', 'timestamp', simdi - 3600)));
  insert into _kanit values (31, '(o) bayat OTP oturumu reddedilir',
    'RPC yok', 'otp session required',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);

  -- (o2) gelecek zaman damgalı OTP reddedilir.
  r := pg_temp.rpc(sql, a, jsonb_build_array(
    jsonb_build_object('method', 'otp', 'timestamp', simdi + 3600)));
  insert into _kanit values (32, '(o2) gelecek zaman damgalı OTP reddedilir',
    'RPC yok', 'otp session required',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);

  -- (o3) telefon OTP'si: auth.users.phone dolu hesap reddedilir (geri alınır).
  update auth.users set phone = '+900000000000' where id = b;
  r := pg_temp.rpc(sql, b, jsonb_build_array(
    jsonb_build_object('method', 'otp', 'timestamp', simdi)));
  update auth.users set phone = null where id = b;
  insert into _kanit values (33, '(o3) telefonu dolu hesapta OTP kabul edilmez',
    'RPC yok', 'email mismatch',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);

  -- (n) taze OTP kabul edilir; adres saklanır.
  r := pg_temp.rpc(sql, a, jsonb_build_array(
    jsonb_build_object('method', 'password', 'timestamp', simdi - 7200),
    jsonb_build_object('method', 'otp', 'timestamp', simdi)));
  insert into _kanit values (34, '(n) taze OTP oturumu kabul edilir',
    'RPC yok', 'true',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'success', 'yok') end);
  if pg_temp.sutun_var('email_verified_at') then
    execute 'select (email_verified_at is not null)::text from public.profiles where id = $1'
      into v using a;
  else
    v := 'sütun yok';
  end if;
  insert into _kanit values (35, '(n) email_verified_at yazıldı',
    'sütun yok', 'true', v);
  if pg_temp.sutun_var('email_verified_address') then
    execute 'select (email_verified_address = (select email from _p where id = $1))::text from public.profiles where id = $1'
      into v using a;
  else
    v := 'sütun yok';
  end if;
  insert into _kanit values (36, '(n) email_verified_address mevcut e-postayla aynı',
    'sütun yok', 'true', coalesce(v, 'null'));

  -- (p) istemci doğrudan yazamaz: B authenticated rolüyle kendi satırını günceller.
  if pg_temp.sutun_var('email_verified_at') then
    perform pg_temp.kimlik(b);
    set local role authenticated;
    begin
      execute 'update public.profiles set email_verified_at = now(), email_verified_address = ''x@y.z'' where id = $1' using b;
    exception when others then null;
    end;
    reset role;
    execute 'select (email_verified_at is null and email_verified_address is null)::text from public.profiles where id = $1'
      into v using b;
  else
    v := 'sütun yok';
  end if;
  insert into _kanit values (37, '(p) istemci email_verified_at/address yazamaz (hâlâ boş)',
    'sütun yok', 'true', v);
exception when others then
  reset role;
  insert into _kanit values (30, '(m..p)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ------------------------------------------------------------------ (q)
-- Guard tetikleyicileri: UPDATE guard'ı ve INSERT yetki tetikleyicisi bağlı
-- ve ikisi de email_verified_at/address'i dondurur ya da sıfırlar.
insert into _kanit
select 40, '(q) profiles_client_write_guard_trg UPDATE için bağlı', 'true', 'true',
  coalesce((select ((tgtype & 16) = 16 and (tgtype & 1) = 1 and tgenabled <> 'D')::text
            from pg_trigger where tgrelid = 'public.profiles'::regclass
              and tgname = 'profiles_client_write_guard_trg'), 'yok');
insert into _kanit
select 41, '(q) profiles_client_insert_authority_trg INSERT için bağlı', 'true', 'true',
  coalesce((select ((tgtype & 4) = 4 and (tgtype & 1) = 1 and tgenabled <> 'D')::text
            from pg_trigger where tgrelid = 'public.profiles'::regclass
              and tgname = 'profiles_client_insert_authority_trg'), 'yok');
insert into _kanit
select 42, '(q) UPDATE guard gövdesi email_verified_at/address dondurur', 'false', 'true',
  (pg_get_functiondef('public.profiles_client_write_guard()'::regprocedure)
     like '%new.email_verified_at := old.email_verified_at%'
   and pg_get_functiondef('public.profiles_client_write_guard()'::regprocedure)
     like '%new.email_verified_address := old.email_verified_address%')::text;
insert into _kanit
select 43, '(q) INSERT tetikleyici gövdesi email_verified_at/address sıfırlar', 'false', 'true',
  (pg_get_functiondef('public.profiles_client_insert_authority()'::regprocedure)
     like '%new.email_verified_at := null%'
   and pg_get_functiondef('public.profiles_client_insert_authority()'::regprocedure)
     like '%new.email_verified_address := null%')::text;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
