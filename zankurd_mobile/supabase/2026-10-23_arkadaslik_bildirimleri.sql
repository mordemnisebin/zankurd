-- Arkadaşlık bildirimleri: anlaşılır metin + "isteğin kabul edildi" (2026-10-23).
--
-- Niçin: kullanıcı bildirimi — "arkadaş daveti, arkadaşlık isteği, oyuna davet
-- için bildirim yok". Kuyruk ve gönderici çalışıyor (14/14 gönderilmiş), ama:
--   * arkadaşlık isteği bildiriminin gövdesi yalnız gönderenin adıydı
--     ("Merve"); telefonda ne olduğu anlaşılmıyordu;
--   * isteği gönderen, kabul edildiğinde hiç haber almıyordu.
-- Metin, öteki bildirimlerdeki gibi iki dilli ("KU · TR"): sunucu alıcının
-- arayüz dilini bilmiyor. KU jüri: Grok + Gemini + Claude Opus 5 OK; kabul
-- cümlesi uygulamadaki onaylı K.huhuPArkadaslikIstegini ile aynı.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-23_arkadaslik_bildirimleri.sql

begin;

create or replace function public.enqueue_friend_request_push()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_name text := coalesce(nullif(trim(new.from_user_name), ''), 'ZanKurd');
begin
  insert into public.push_outbox (to_user_id, kind, title, body)
  values (
    new.to_user_id,
    'friend_request',
    'ZanKurd',
    v_name || ' ji te re daxwaza hevaltiyê şand · '
      || v_name || ' sana arkadaşlık isteği gönderdi'
  );
  return new;
end;
$function$;

create or replace function public.enqueue_friend_accept_push()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_name text;
begin
  select coalesce(nullif(trim(p.display_name), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = new.to_user_id;

  insert into public.push_outbox (to_user_id, kind, title, body)
  values (
    new.from_user_id,
    'friend_accept',
    'ZanKurd',
    coalesce(v_name, 'ZanKurd') || ' daxwaza hevaltiya te qebûl kir · '
      || coalesce(v_name, 'ZanKurd') || ' arkadaşlık isteğini kabul etti'
  );
  return new;
end;
$function$;

drop trigger if exists trg_friend_accept_push on public.friend_requests;
create trigger trg_friend_accept_push
after update of status on public.friend_requests
for each row
when (old.status is distinct from 'accepted' and new.status = 'accepted')
execute function public.enqueue_friend_accept_push();

commit;
