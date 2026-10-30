-- T1: açık rızalı, sunucu saatli varlık. CANLIYA UYGULANMADI.
-- Profil RLS / updated_at tetikleyicileri değişmez; misafir authenticated'dir.
-- Eski list_friends gövdesi dosyadan kopyalanmaz: uygulama anındaki tanım
-- aynı OID ile yeniden adlandırılır; tüm eski çıktı alanları korunur.
-- Uygulama öncesi pg_get_functiondef('public.list_friends()'::regprocedure)
-- incelemesi ve yerel/rollback duman testi gerekir. Bu dosya canlıya bağlanmaz.
begin;

create table if not exists public.user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  visible boolean not null default false,
  last_seen_at timestamptz,
  -- Gizleme/açma ile 60 sn sınırı aşılamasın; paylaşılmayan iç zaman.
  last_touch_at timestamptz,
  constraint presence_hidden_has_no_time check (visible or last_seen_at is null)
);
alter table public.user_presence enable row level security;
revoke all on public.user_presence from public, anon, authenticated;
grant select (user_id, visible, last_seen_at) on public.user_presence to authenticated;

drop policy if exists presence_read on public.user_presence;
create policy presence_read on public.user_presence for select to authenticated
using (
  user_id = (select auth.uid())
  or (visible and exists (
    select 1 from public.friends f
    where f.user_id = (select auth.uid()) and f.friend_id = user_presence.user_id
  ))
);

create or replace function public.get_presence_visibility()
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $function$
  select coalesce((select p.visible from public.user_presence p
                   where p.user_id = auth.uid()), false);
$function$;

create or replace function public.set_presence_visibility(p_visible boolean)
returns void language plpgsql security definer
set search_path = pg_catalog, public
as $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise insufficient_privilege using message = 'authentication required'; end if;
  if p_visible is null then raise invalid_parameter_value using message = 'visibility required'; end if;
  insert into public.user_presence as p (user_id, visible)
  values (v_uid, p_visible)
  on conflict (user_id) do update set
    visible = excluded.visible,
    last_seen_at = case when excluded.visible then p.last_seen_at else null end;
end;
$function$;

create or replace function public.touch_presence()
returns void language plpgsql security definer
set search_path = pg_catalog, public
as $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
begin
  if v_uid is null then raise insufficient_privilege using message = 'authentication required'; end if;
  -- Tek atomik UPDATE: eşzamanlı iki çağrı da aynı satır kilidini kullanır.
  -- Kapalı/hiç izin vermemiş kullanıcı için INSERT ve zaman yazımı yok.
  update public.user_presence set last_seen_at = v_now, last_touch_at = v_now
  where user_id = v_uid and visible
    and (last_touch_at is null or last_touch_at <= v_now - interval '60 seconds');
end;
$function$;

revoke all on function public.get_presence_visibility() from public, anon;
revoke all on function public.set_presence_visibility(boolean) from public, anon;
revoke all on function public.touch_presence() from public, anon;
grant execute on function public.get_presence_visibility() to authenticated;
grant execute on function public.set_presence_visibility(boolean) to authenticated;
grant execute on function public.touch_presence() to authenticated;

-- Yeni OUT sütunu CREATE OR REPLACE ile eklenemez. Önce mevcut fonksiyonu
-- koru, sonra canlı dönüş sözleşmesinden sarmalayıcı üret. İkinci çalıştırma
-- yedeği değiştirmez. Beklenmedik şemada tüm işlem geri alınır.
do $migration$
declare
  v_result text;
  v_definition text;
begin
  if to_regprocedure('public.list_friends_before_presence()') is null then
    if to_regprocedure('public.list_friends()') is null then
      raise exception 'list_friends missing; inspect deployed schema';
    end if;
    v_definition := pg_get_functiondef('public.list_friends()'::regprocedure);
    v_result := pg_get_function_result('public.list_friends()'::regprocedure);
    if v_result not like 'TABLE(%' or v_result like '%last_seen_at%' then
      raise exception 'unexpected list_friends contract; inspect deployed definition';
    end if;
    alter function public.list_friends() rename to list_friends_before_presence;
    -- İsmi hariç uygulanan canlı gövdenin aynen kaldığını doğrula.
    if replace(pg_get_functiondef('public.list_friends_before_presence()'::regprocedure),
               'public.list_friends_before_presence()', 'public.list_friends()') <> v_definition then
      raise exception 'original list_friends definition was not preserved';
    end if;
  elsif to_regprocedure('public.list_friends()') is null
     or pg_get_functiondef('public.list_friends()'::regprocedure)
        not like '%from public.list_friends_before_presence() f%' then
    -- Aynı adı taşıyan ilgisiz yedeği / daha sonra değiştirilmiş RPC'yi ezme.
    raise exception 'presence wrapper drifted; inspect deployed definition';
  end if;
  v_result := pg_get_function_result('public.list_friends_before_presence()'::regprocedure);
  if v_result not like 'TABLE(%' or v_result like '%last_seen_at%' then
    raise exception 'unexpected preserved list_friends contract';
  end if;
  v_result := left(v_result, length(v_result) - 1) || ', last_seen_at timestamp with time zone)';
  execute format($ddl$
    create or replace function public.list_friends()
    returns %s language sql stable security invoker
    set search_path = pg_catalog, public
    as $body$
      select f.*, case when p.visible then p.last_seen_at else null end
      from public.list_friends_before_presence() f
      left join public.user_presence p on p.user_id = f.friend_id
      where auth.uid() is not null
    $body$
  $ddl$, v_result);
end;
$migration$;

-- Yardımcı fonksiyon yalnız eski alanları döndürür; yeni varlıkta bir kaçış
-- kapısı değildir. Eski fonksiyondaki invoker/definer ve RLS aynen korunur.
revoke all on function public.list_friends_before_presence() from public, anon;
revoke all on function public.list_friends() from public, anon;
grant execute on function public.list_friends_before_presence() to authenticated;
grant execute on function public.list_friends() to authenticated;

do $verify$
declare v_name text;
begin
  if not (select relrowsecurity from pg_class where oid = 'public.user_presence'::regclass) then
    raise exception 'presence RLS is off';
  end if;
  if has_table_privilege('anon', 'public.user_presence', 'SELECT')
     or has_table_privilege('authenticated', 'public.user_presence', 'INSERT,UPDATE,DELETE')
     or has_column_privilege('authenticated', 'public.user_presence', 'last_touch_at', 'SELECT') then
    raise exception 'presence table permissions are unsafe';
  end if;
  foreach v_name in array array['get_presence_visibility()', 'set_presence_visibility(boolean)',
                               'touch_presence()', 'list_friends()', 'list_friends_before_presence()'] loop
    if has_function_privilege('anon', 'public.' || v_name, 'EXECUTE') then
      raise exception 'anon may execute %', v_name;
    end if;
  end loop;
  if exists (
    select 1 from pg_proc where oid in (
      'public.touch_presence()'::regprocedure,
      'public.set_presence_visibility(boolean)'::regprocedure,
      'public.get_presence_visibility()'::regprocedure
    ) and (not prosecdef or not coalesce(proconfig @> array['search_path=pg_catalog, public'], false))
  ) then raise exception 'presence definer configuration is unsafe'; end if;
  if pg_get_function_result('public.list_friends()'::regprocedure) not like '%last_seen_at timestamp with time zone)' then
    raise exception 'last_seen_at missing';
  end if;
end;
$verify$;

-- Geri alma (ayrı, onaylı işlem): önce istemciyi geri al; transaction içinde
-- DROP FUNCTION public.list_friends(); ALTER FUNCTION
-- public.list_friends_before_presence() RENAME TO list_friends; ardından
-- üç presence RPC'sini ve user_presence tablosunu kaldır. Eski anon yetkisini
-- geri verme. Varlık tercih/zaman verilerinin silineceğini sahibine bildir.
commit;
