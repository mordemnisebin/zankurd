-- Kanıt betiği: 2026-10-24_bildirim_seri_eposta.sql, bulgular a..p:
-- a sütun varsayılanı (push_duel/push_social açık) · b varsayılan açıkken düello
-- push'u TESLİM edilir · c push_duel kapalıyken düello push'u atlanır · d push_duel kapalıyken arkadaş push'u etkilenmez · e push_social
-- kapalıyken friend_request atlanır · f push_social kapalıyken room_invite
-- atlanır · g set_my_push_prefs null = değişmez · h seri onarımı ilk çağrı
-- 100 jeton keser · i aynı ay + aynı kırılma günüyle ikinci çağrı ÜCRET KESMEZ ·
-- j aynı ay başka kırılma günü monthly_limit · k premium onarım ücretsiz ·
-- l yetersiz bakiyede ücret/kayıt yok · m mark_my_email_verified parola
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
-- Seri onarımı. Kırılma günü: iki gün önce (yerel gün, UTC payı içinde).
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2); c uuid := pg_temp.uid(3);
  ay text := to_char((now() at time zone 'utc'), 'YYYY-MM');
  gun text := to_char((now() at time zone 'utc')::date - 2, 'YYYY-MM-DD');
  gun2 text := to_char((now() at time zone 'utc')::date - 1, 'YYYY-MM-DD');
  b0 int; b1 int; b2 int; r text;
  sql1 text; sql2 text;
begin
  -- A: 500 jeton yükle, bakiye ölç.
  insert into public.coin_transactions (player_id, amount, reason)
  values (a, 500, 'kanit_yukleme');
  b0 := pg_temp.bakiye(a);

  sql1 := format('select public.spend_streak_repair(%L, %L, false)::text', ay, gun);
  r := pg_temp.rpc(sql1, a);
  b1 := pg_temp.bakiye(a);
  insert into _kanit values (12, '(h) ilk onarım çağrısı bakiyeyi düşürür',
    '0', '-100', (b1 - b0)::text);

  r := pg_temp.rpc(sql1, a);
  b2 := pg_temp.bakiye(a);
  insert into _kanit values (13, '(i) aynı ay + aynı gün ikinci çağrı ücret kesmez',
    '0', '0', (b2 - b1)::text);
  insert into _kanit values (14, '(i) ikinci çağrı yanıtı already_repaired',
    'RPC yok', 'true',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'already_repaired', 'yok') end);

  sql2 := format('select public.spend_streak_repair(%L, %L, false)::text', ay, gun2);
  r := pg_temp.rpc(sql2, a);
  b2 := pg_temp.bakiye(a);
  insert into _kanit values (15, '(j) aynı ay başka kırılma günü reddedilir',
    'RPC yok', 'monthly_limit',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);
  insert into _kanit values (16, '(j) reddedilen çağrı ücret kesmedi',
    '0', '0', (b2 - b1)::text);

  -- (k) premium: ücretsiz.
  insert into public.coin_transactions (player_id, amount, reason)
  values (b, 500, 'kanit_yukleme');
  b0 := pg_temp.bakiye(b);
  r := pg_temp.rpc(format(
    'select public.spend_streak_repair(%L, %L, true)::text', ay, gun), b);
  b1 := pg_temp.bakiye(b);
  insert into _kanit values (17, '(k) premium onarım ücretsiz (bakiye farkı)',
    '0', '0', (b1 - b0)::text);
  insert into _kanit values (18, '(k) premium onarım başarı',
    'RPC yok', 'true',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'success', 'yok') end);

  -- (l) yetersiz bakiye: C'nin bakiyesini sıfıra çek (negatif hareket).
  b0 := pg_temp.bakiye(c);
  if b0 > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (c, -b0, 'kanit_sifirla');
  end if;
  r := pg_temp.rpc(format(
    'select public.spend_streak_repair(%L, %L, false)::text', ay, gun), c);
  insert into _kanit values (19, '(l) yetersiz bakiyede hata',
    'RPC yok', 'insufficient balance',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);
  insert into _kanit values (20, '(l) yetersiz bakiyede ücret kesilmedi',
    '0', '0', (pg_temp.bakiye(c) - 0)::text);
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
  insert into _kanit values (21, '(m) parola oturumu doğrulama sayılmaz',
    'RPC yok', 'otp session required',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);

  -- (o) bayat OTP (1 saat önce) reddedilir.
  r := pg_temp.rpc(sql, a, jsonb_build_array(
    jsonb_build_object('method', 'otp', 'timestamp', simdi - 3600)));
  insert into _kanit values (22, '(o) bayat OTP oturumu reddedilir',
    'RPC yok', 'otp session required',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'error', 'yok') end);

  -- (n) taze OTP kabul edilir ve satır yazılır.
  r := pg_temp.rpc(sql, a, jsonb_build_array(
    jsonb_build_object('method', 'password', 'timestamp', simdi - 7200),
    jsonb_build_object('method', 'otp', 'timestamp', simdi)));
  insert into _kanit values (23, '(n) taze OTP oturumu kabul edilir',
    'RPC yok', 'true',
    case when r like 'HATA:%' or r = 'RPC yok' then r
         else coalesce((r::jsonb)->>'success', 'yok') end);
  if pg_temp.sutun_var('email_verified_at') then
    execute 'select (email_verified_at is not null)::text from public.profiles where id = $1'
      into v using a;
  else
    v := 'sütun yok';
  end if;
  insert into _kanit values (24, '(n) email_verified_at yazıldı',
    'sütun yok', 'true', v);

  -- (p) istemci doğrudan yazamaz: B authenticated rolüyle kendi satırını günceller.
  if pg_temp.sutun_var('email_verified_at') then
    perform pg_temp.kimlik(b);
    set local role authenticated;
    begin
      execute 'update public.profiles set email_verified_at = now() where id = $1' using b;
    exception when others then null;
    end;
    reset role;
    execute 'select (email_verified_at is null)::text from public.profiles where id = $1'
      into v using b;
  else
    v := 'sütun yok';
  end if;
  insert into _kanit values (25, '(p) istemci email_verified_at''i doğrudan yazamaz (hâlâ boş)',
    'sütun yok', 'true', v);
exception when others then
  reset role;
  insert into _kanit values (21, '(m..p)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
