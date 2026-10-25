-- 2026-10-25: oda sohbetine sunucu tarafı hız sınırı.
--
-- NİÇİN: `room_messages` BEFORE INSERT tetikleyicisi (`enforce_chat_moderation`)
-- içerik, üyelik ve gönderen kimliğini denetliyor ama hız sınırı yok. İstemci
-- süzgeci atlanıp REST üzerinden doğrudan yazılarak oda sohbeti saniyede onlarca
-- mesajla doldurulabilir (realtime ile tüm oyunculara yayılır).
--
-- NASIL: aynı kullanıcı aynı odada son 10 sn içinde 5 mesaj attıysa 6.'sı
-- `chat_rate_limited` (P0001, PostgREST → HTTP 400) ile reddedilir. Aynı
-- (kullanıcı, oda) için eşzamanlı eklemeler işlem kilidiyle sıraya girer; yoksa
-- paralel istekler sayımı birlikte geçebilirdi. Gövde CANLI tanımdan
-- (pg_get_functiondef, 2026-10-25) türetildi; yalnız kilit + sayım bloğu eklendi.
-- `created_at` tetikleyicide sunucu saatine (clock_timestamp) yazıldığı için sayım istemci saatine bağlı değil.
--
-- İstemci: 2.1.x `chat_rate_limited` için ayrı metin göstermez; genel
-- `K.chatSendFailed` ("Mesaj gönderilemedi. Tekrar dene.") görünür.
--
-- Test: begin … rollback içinde gerçek bir profille geçici oda kurulup
-- 6 ardışık insert; ilk 5 geçer, 6.'sı chat_rate_limited (bkz. applied.md).
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-25_sohbet_hiz_siniri.sql

begin;

create index if not exists idx_room_messages_room_sender_created
  on public.room_messages (room_id, sender_id, created_at desc);

CREATE OR REPLACE FUNCTION public.enforce_chat_moderation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.chat_message_is_clean(new.text) then
    raise exception 'chat_message_rejected';
  end if;

  -- Yalnız odanın üyesi yazabilir.
  if not exists (
    select 1 from public.room_players rp
     where rp.room_id = new.room_id and rp.player_id = v_uid
  ) then
    raise exception 'not_a_room_member';
  end if;

  -- Hız sınırı: aynı odada son 10 sn içinde en çok 5 mesaj.
  perform pg_advisory_xact_lock(
    hashtextextended('chat:' || v_uid::text || ':' || new.room_id::text, 0));
  -- now() işlem başı anıdır; kilit beklemesinden sonra geçmiş zamanlı kayıt
  -- sınırı deliyordu (Codex incelemesi 2026-10-25). Duvar saati kullanılır.
  v_now := clock_timestamp();
  if (
    select count(*) from public.room_messages m
     where m.room_id = new.room_id
       and m.sender_id = v_uid
       and m.created_at > v_now - interval '10 seconds'
  ) >= 5 then
    raise exception 'chat_rate_limited' using errcode = 'P0001';
  end if;

  new.sender_id := v_uid;
  new.sender_name := coalesce(
    (select p.display_name from public.profiles p where p.id = v_uid),
    new.sender_name
  );
  new.created_at := v_now;
  new.text := trim(new.text);
  return new;
end;
$function$;

commit;
