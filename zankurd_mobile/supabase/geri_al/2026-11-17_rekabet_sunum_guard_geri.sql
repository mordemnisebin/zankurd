-- Geri alma: 2026-11-17_rekabet_sunum_guard.sql
-- Yamalanan 3 işlevin (start_verified_quiz, get_room_questions,
-- _guard_20261101_hide_duel_content) göç anında olcek_tur3_yedek'e alınan eski gövdesini
-- birebir geri yükler; get_verified_daily_question_ids'in authenticated EXECUTE'unu ve
-- room_questions SELECT'ini geri verir. TAMAMEN YA DA HİÇ: önce üç yedek satırı (yalnız
-- bu kesin adlar) ve md5 zincirleri doğrulanır; biri eksik/bozuksa hiçbir şey geri alınmaz.
-- İşlev yoksa ya da canlı gövde göçten sonra değişmişse durur. KAPSAM: olcek_tur3_yedek
-- RLS/yetki kapatması geri ALINMAZ (zararsız); yalnız 'w2:' satırları silinir.
-- UYARI: geri alma eski (sızdıran) yolu yeniden açar; yalnız yeni yol bozulduysa kullan.
begin;

set local lock_timeout = '10s';

create temp table w2g_geri (
  imza text primary key, eski text not null, sahip oid not null, secdef boolean not null,
  ayar text[], acl text, gerek boolean not null
) on commit drop;

do $w2g_geri$
declare
  v_imzalar text[] := array[
    'public.start_verified_quiz(uuid,uuid[],boolean,uuid)',
    'public.get_room_questions(uuid)',
    'public._guard_20261101_hide_duel_content(jsonb)'];
  v_imza text;
  v_oid regprocedure;
  v_yedek text;
  v_eski text;
  v_yama text;
  v_simdi text;
  v_gerek boolean;
begin
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or exists (
       select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
       where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
         and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
     ) then
    raise exception 'w2 guard geri: olcek_tur3_yedek anon/authenticated tarafından yazılabilir; yedek güvenilmez';
  end if;
  foreach v_imza in array v_imzalar loop
    v_oid := to_regprocedure(v_imza);
    if v_oid is null then
      raise exception 'w2 guard geri: % yok; geri alma durdu (yeniden yaratma yok)', v_imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w2:' || v_imza for update;
    if v_yedek is null then
      raise exception 'w2 guard geri: % yedek satırı yok; hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'w2 guard geri: % yedeği bozuk (md5 zinciri); hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) = md5(v_eski) then
      v_gerek := false;
    elsif md5(v_simdi) = v_yama then
      v_gerek := true;
    else
      raise exception 'w2 guard geri: % canlı gövdesi göçün yazdığı gövde değil (başka bir değişiklik araya girmiş); hiçbir işlev geri alınmadı', v_imza;
    end if;
    insert into w2g_geri
    select v_imza, v_eski, p.proowner, p.prosecdef, p.proconfig, p.proacl::text, v_gerek
    from pg_proc p where p.oid = v_oid;
  end loop;
end;
$w2g_geri$;

do $w2g_geri2$
declare r record;
begin
  for r in select * from w2g_geri where gerek loop
    execute r.eski;
  end loop;
end;
$w2g_geri2$;

grant execute on function public.get_verified_daily_question_ids() to authenticated;
grant select on public.room_questions to anon, authenticated;

do $w2g_geri3$
declare r record;
begin
  for r in select * from w2g_geri loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'w2 guard geri: % sahip / search_path / ACL doğrulanamadı', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> md5(r.eski) then
      raise exception 'w2 guard geri: % geri yükleme sonrası gövde eski gövde değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w2 guard geri: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
end;
$w2g_geri3$;

delete from public.olcek_tur3_yedek
where ad in (
  'w2:public.start_verified_quiz(uuid,uuid[],boolean,uuid)',
  'w2:public.get_room_questions(uuid)',
  'w2:public._guard_20261101_hide_duel_content(jsonb)');

commit;
