-- Push bildirimleri için cihaz FCM token'ını profiles tablosuna ekler.
-- Sunucu tarafı (Edge Function / cron) bu token'ları kullanarak bildirim yollar.

alter table public.profiles
  add column if not exists fcm_token text;

-- Token'ı yalnızca sahibi güncelleyebilsin diye RPC (RLS güvenli).
create or replace function public.set_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;
  update public.profiles set fcm_token = p_token where id = v_uid;
end;
$$;
