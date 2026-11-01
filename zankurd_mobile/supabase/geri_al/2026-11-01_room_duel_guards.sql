-- G6/G7/G8 geri alma: uygulama anında saklanan TAM canlı tanımlara döner.
-- Yalnız operatörün canlı diff/onayı sonrasında; güvenlik korumalarını kaldırır.
begin;
do $rollback$
declare item record;
begin
  if to_regclass('public.room_duel_guards_20261101_backup') is not null then
    for item in select * from public.room_duel_guards_20261101_backup loop
      execute item.definition;
    end loop;
  end if;
end;
$rollback$;
-- Yeni RPC tekrar etkinleştirmeye kadar çağrılamaz. Çekirdek/yedekler
-- özel kalır; veri ve denetim kaydı silinmez.
revoke all on function public.present_async_duel_question_v2(uuid, integer) from public, anon, authenticated;
commit;
