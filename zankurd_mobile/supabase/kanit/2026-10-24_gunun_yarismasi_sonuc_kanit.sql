-- Kanıt betiği: 2026-10-24_gunun_yarismasi_sonuc.sql, bulgular a..l:
-- a ilk sonuç kaydı true · b aynı gün ikinci kayıt false (ilk bitiş kalır) ·
-- c geçersiz sonuç (doğru > toplam) false · d kimliksiz çağrı false ·
-- e sıralama doğru çok -> süre az · f kendi sıram · g katılımcı sayısı ·
-- h engellediğim oyuncu listede ve sırada YOK · i dünün birincisi ·
-- j anon panoyu çağıramaz · k authenticated tabloyu doğrudan okuyamaz ·
-- l süre 3600'e kırpılır · m dünün sonucu bugünün sırasına karışmaz.
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `durum`: SONRA-OK (gozlenen = beklenen_sonra), ONCE-DURUMU (gozlenen =
-- beklenen_once; göç henüz yok), BEKLENMEDIK (ikisi de değil). RPC/tablo
-- yoksa gözlem 'RPC yok' yazar (HATA değil); başka bir adım hata verirse
-- satırda 'HATA: ...' görünür (diğer adımlar sürer).
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_gunun_yarismasi_sonuc_kanit.sql
--
-- Göçle BİRLİKTE denemek için (tek işlemde, yine geri alınır):
--   göç dosyasının `begin;` ile `rollback;` arasına konması yeterlidir.
--
-- Hiçbir auth.users satırı eklenmez: gerçek profillerden beşi seçilir;
-- kimlik set_config('request.jwt.claims') ile taklit edilir. Betik, bu
-- işlemde bugünün ve dünün sonuç satırlarını SİLER (gerçek oyuncu satırı
-- sıralamayı bulandırmasın); silme de rollback ile geri alınır.
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid, ad text) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id,
       coalesce(nullif(btrim(p.display_name), ''), 'Oyuncu')
from (select pr.id, pr.display_name from public.profiles pr order by pr.id limit 5) p;

do $$
begin
  if (select count(*) from _p) < 5 then
    raise exception 'kanit: en az 5 profil gerekli';
  end if;
end $$;

create function pg_temp.uid(p_n int) returns uuid
language sql as $f$ select id from _p where n = p_n $f$;

-- Kimliği taklit edip sonuç kaydeder; 'true'/'false' ya da 'RPC yok' döner.
create function pg_temp.kaydet(p_user uuid, p_dogru int, p_toplam int, p_sn int)
returns text
language plpgsql as $f$
declare v boolean;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '{}' else json_build_object('sub', p_user)::text end,
    true);
  begin
    execute 'select public.submit_daily_event_result($1, $2, $3)'
      into v using p_dogru, p_toplam, p_sn;
    return v::text;
  exception
    when undefined_function then return 'RPC yok';
    when others then return 'HATA: ' || sqlerrm;
  end;
end $f$;

-- Kimliği taklit edip panoyu okur; jsonb döner (yoksa null).
create function pg_temp.pano(p_user uuid) returns jsonb
language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user)::text, true);
  begin
    execute 'select public.get_daily_event_board()' into v;
    return v;
  exception
    when undefined_function then return null;
  end;
end $f$;

-- "doğru:süre" listesi, sıra korunarak.
create function pg_temp.siralama(p jsonb) returns text
language sql as $f$
  select coalesce(string_agg(
    (e->>'correct') || ':' || (e->>'seconds'), ',' order by (e->>'rank')::int
  ), 'yok')
  from jsonb_array_elements(coalesce(p->'top', '[]'::jsonb)) e
$f$;

do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2); c uuid := pg_temp.uid(3);
  d uuid := pg_temp.uid(4); e uuid := pg_temp.uid(5);
  r text; pn jsonb; v text;
  tablo boolean := to_regclass('public.daily_event_results') is not null;
begin
  if tablo then
    delete from public.daily_event_results
    where day in (public.app_today(), public.app_today() - 1);
  end if;

  -- (a) A: 9/10 80 sn
  r := pg_temp.kaydet(a, 9, 10, 80);
  insert into _kanit values (1, '(a) ilk sonuç kaydı', 'RPC yok', 'true', r);

  -- (b) A ikinci kez, daha iyi skorla: ilk bitiş kalır.
  r := pg_temp.kaydet(a, 10, 10, 30);
  insert into _kanit values (2, '(b) aynı gün ikinci kayıt', 'RPC yok', 'false', r);

  -- B: 9/10 60 sn; C: 7/10 100 sn.
  perform pg_temp.kaydet(b, 9, 10, 60);
  perform pg_temp.kaydet(c, 7, 10, 100);

  -- (c) geçersiz: doğru > toplam.
  r := pg_temp.kaydet(d, 11, 10, 50);
  insert into _kanit values (3, '(c) geçersiz sonuç (doğru > toplam)', 'RPC yok', 'false', r);

  -- (d) kimliksiz.
  r := pg_temp.kaydet(null, 5, 10, 50);
  insert into _kanit values (4, '(d) kimliksiz çağrı', 'RPC yok', 'false', r);

  -- (l) süre kırpma: E 5/10, 99999 sn -> 3600.
  perform pg_temp.kaydet(e, 5, 10, 99999);
  begin
    execute 'select seconds::text from public.daily_event_results where user_id = $1 and day = public.app_today()'
      into v using e;
  exception when others then v := 'RPC yok';
  end;
  insert into _kanit values (5, '(l) süre 3600''e kırpılır', 'RPC yok', '3600', coalesce(v, 'satır yok'));

  -- (e) C gözüyle sıralama (hiç engel yok): doğru çok -> süre az.
  pn := pg_temp.pano(c);
  insert into _kanit values (6, '(e) ilk üç sırası (doğru:süre)', 'yok',
    '9:60,9:80,7:100', pg_temp.siralama(pn));
  insert into _kanit values (7, '(f) C''nin kendi sırası', 'yok', '3',
    coalesce(pn->'me'->>'rank', 'yok'));
  insert into _kanit values (8, '(g) bugünkü katılımcı sayısı', 'yok', '4',
    coalesce(pn->>'participants', 'yok'));

  -- (h) A, B''yi engeller: A'nın panosunda B yok, sıralar kayar.
  insert into public.blocked_users (blocker_id, blocked_id) values (a, b);
  pn := pg_temp.pano(a);
  insert into _kanit values (9, '(h) engellediğim oyuncu listede yok (doğru:süre)', 'yok',
    '9:80,7:100,5:3600', pg_temp.siralama(pn));
  insert into _kanit values (10, '(h) engel sonrası katılımcı sayısı', 'yok', '3',
    coalesce(pn->>'participants', 'yok'));
  delete from public.blocked_users where blocker_id = a and blocked_id = b;

  -- (i)/(m) dünün birincisi: D 8/10 50 sn ve B 6/10 40 sn dün; D kazanır.
  if tablo then
    insert into public.daily_event_results (day, user_id, correct_count, total_count, seconds)
    values (public.app_today() - 1, d, 8, 10, 50),
           (public.app_today() - 1, b, 6, 10, 40);
  end if;
  pn := pg_temp.pano(c);
  insert into _kanit values (11, '(i) dünün birincisi (ad)', 'yok',
    (select ad from _p where n = 4), coalesce(pn->'yesterday'->>'name', 'yok'));
  insert into _kanit values (12, '(i) dünün birincisi (doğru)', 'yok', '8',
    coalesce(pn->'yesterday'->>'correct', 'yok'));
  insert into _kanit values (13, '(m) dünün satırı bugünün sırasına karışmaz', 'yok',
    '4', coalesce(pn->>'participants', 'yok'));
exception when others then
  insert into _kanit values (99, '(a..m)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- (j) anon çalıştıramaz, (k) authenticated tabloyu okuyamaz.
insert into _kanit
select 20, '(j) anon panoyu çağırabilir mi', 'RPC yok', 'false',
  case when to_regprocedure('public.get_daily_event_board()') is null then 'RPC yok'
       else has_function_privilege('anon', 'public.get_daily_event_board()', 'execute')::text end;
insert into _kanit
select 21, '(k) authenticated tabloyu doğrudan okuyabilir mi', 'RPC yok', 'false',
  case when to_regclass('public.daily_event_results') is null then 'RPC yok'
       else has_table_privilege('authenticated', 'public.daily_event_results', 'select')::text end;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
