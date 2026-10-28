-- 2026-10-28: soru puanlama (beğendim / beğenmedim).
--
-- NİÇİN: Soru kalitesini şimdiye dek yalnız "bildir" düğmesi (hata avı)
-- ölçüyordu; oyuncunun "bu soru güzeldi / sıkıcıydı" demesi için yol yoktu.
-- Sahibin içeriği ölçebilmesi için tur sonu cevap incelemesinde her soruya
-- başparmak yukarı / aşağı eklenir (TRT Bil Bakalım'daki soru puanı gibi).
--
-- TASARIM:
--   * `question_ratings` (user_id, question_id) birincil anahtarlı: kullanıcı
--     başına soru başına TEK oy; yeni oy eskisini değiştirir (upsert). Oy
--     silme yok; aynı başparmağa yeniden basmak aynı değeri yollar.
--   * `question_id` text: yerel banka kimlikleri (`ziman_x_0035`) UUID değil;
--     `questions.id` ile yabancı anahtar BİLEREK yok (report_question'daki
--     uuid = text hatası tekrarlanmasın).
--   * RLS açık, istemciye doğrudan politika YOK: tablo yalnız aşağıdaki
--     SECURITY DEFINER RPC ile yazılır; oy kimliği `auth.uid()`den gelir,
--     istemci başkası adına oy veremez.
--   * `rate_question`: oturumsuz çağrı hata verir; puan yalnız -1/+1; kimlik
--     uzunluğu 1..128 (anahtar şişirme saldırısına karşı).
--
-- İDEMPOTENT: tablo `if not exists`, indeks `if not exists`, fonksiyon
-- `create or replace`; yeniden çalıştırmak zararsız.
--
-- GERİ ALMA:
--   drop function public.rate_question(text, smallint);
--   drop table public.question_ratings;
--
-- UYGULAMA: supabase db query --linked -f supabase/2026-10-28_soru_puani.sql

create table if not exists public.question_ratings (
  user_id uuid not null references auth.users (id) on delete cascade,
  question_id text not null,
  rating smallint not null check (rating in (-1, 1)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, question_id)
);

alter table public.question_ratings enable row level security;
-- Doğrudan istemci politikası yok: yazma/okuma yalnız RPC ile.

create index if not exists question_ratings_question_id_idx
  on public.question_ratings (question_id);

create or replace function public.rate_question(
  p_question_id text,
  p_rating smallint
) returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_rating is null or p_rating not in (-1, 1) then
    raise exception 'invalid rating' using errcode = '22023';
  end if;
  if p_question_id is null
     or char_length(p_question_id) < 1
     or char_length(p_question_id) > 128 then
    raise exception 'invalid question id' using errcode = '22023';
  end if;

  insert into public.question_ratings (user_id, question_id, rating)
  values (v_uid, p_question_id, p_rating)
  on conflict (user_id, question_id)
  do update set rating = excluded.rating, updated_at = now();
end;
$function$;

revoke all on function public.rate_question(text, smallint)
  from public, anon;
grant execute on function public.rate_question(text, smallint)
  to authenticated;
