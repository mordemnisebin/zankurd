-- GERİ ALMA: 2026-11-07_idempotency_tur9.sql
-- Göç yalnız yeni nesne yarattığı için geri alma yalnız onları kaldırır; mevcut
-- işlevler (award_spin_coins, claim_extra_spin, start_async_duel(text),
-- create_async_duel_challenge(text,uuid)) hiç değişmediğinden geri yüklenecek
-- gövde yoktur. Yeni istemci bu işlevler yokken (PGRST202) eski yola düşer, yani
-- geri alma güvenlidir. UYARI: idempotent_ops satırları silinir; geri alma sonrası
-- aynı anahtarla yeniden deneme yeni etki üretir (eski davranışa dönüş).
begin;

drop function if exists public.spin_wheel_once(text);
drop function if exists public.start_async_duel(text, uuid);
drop function if exists public.create_async_duel_challenge(text, uuid, uuid);
drop table if exists public.idempotent_ops;

do $tur9_geri$
begin
  if to_regprocedure('public.spin_wheel_once(text)') is not null
     or to_regprocedure('public.start_async_duel(text,uuid)') is not null
     or to_regprocedure('public.create_async_duel_challenge(text,uuid,uuid)') is not null
     or to_regclass('public.idempotent_ops') is not null then
    raise exception 'tur9 geri: yeni nesneler kaldırılamadı';
  end if;
  if to_regprocedure('public.award_spin_coins()') is null
     or to_regprocedure('public.claim_extra_spin()') is null
     or to_regprocedure('public.start_async_duel(text)') is null
     or to_regprocedure('public.create_async_duel_challenge(text,uuid)') is null then
    raise exception 'tur9 geri: mevcut işlevler bulunamadı';
  end if;
end
$tur9_geri$;

commit;
