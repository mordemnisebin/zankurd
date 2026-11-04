-- GERİ ALMA: 2026-11-10_ilerleme_sema_v3.sql
-- Göç yalnız yeni nesne yarattığı için geri alma yalnız onları kaldırır;
-- get_my_progress, save_my_progress ve save_my_progress_v2 hiç değişmediğinden
-- geri yüklenecek gövde yoktur. Yeni istemci v3 yokken (PGRST202) v2'ye düşer,
-- yani geri alma güvenlidir. UYARI: tetikleyici kalkınca eski şemalı bir yazım
-- yeni şemalı kaydı yeniden ezebilir (göç öncesi davranış); saklanan v2
-- görüntüleri silinmez.
begin;

drop trigger if exists player_progress_schema_guard on public.player_progress;
drop function if exists public.save_my_progress_v3(jsonb, timestamptz);
drop function if exists public.player_progress_schema_guard();
drop function if exists public.progress_snapshot_version(jsonb);

do $sema_geri$
begin
  if to_regprocedure('public.save_my_progress_v3(jsonb,timestamptz)') is not null
     or to_regprocedure('public.player_progress_schema_guard()') is not null
     or to_regprocedure('public.progress_snapshot_version(jsonb)') is not null
     or exists (
       select 1 from pg_trigger t
       where t.tgrelid = 'public.player_progress'::regclass
         and t.tgname = 'player_progress_schema_guard' and not t.tgisinternal) then
    raise exception 'sema_v3 geri: yeni nesneler kaldırılamadı';
  end if;
  if to_regprocedure('public.get_my_progress()') is null
     or to_regprocedure('public.save_my_progress(jsonb)') is null
     or to_regprocedure('public.save_my_progress_v2(jsonb,timestamptz)') is null then
    raise exception 'sema_v3 geri: mevcut işlevler bulunamadı';
  end if;
end
$sema_geri$;

commit;
