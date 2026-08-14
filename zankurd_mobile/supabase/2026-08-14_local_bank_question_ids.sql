-- Favori ve soru bildirimi: paketli (yerel) banka kimlikleri kabul eder
-- (forward-only, idempotent).
--
-- Tek kişilik her tur — Günün Dersi, seviye, kategori, günlük soru —
-- `loadQuestions`/`loadLevelQuestions`/`loadDailyQuestions` üzerinden
-- PAKETLİ bankadan gelir ve kimlikleri `curated_movement_0001` gibi
-- serbest metindir, gerçek uuid değildir. `favorite_questions.question_id`
-- ve `question_reports.question_id` ise `uuid not null` idi. İstemci
-- paketli bir soruyu kaydetmeye ya da bildirmeye çalıştığında sunucu
-- `22P02 invalid input syntax for type uuid` ile reddediyordu — bu iki
-- özellik tek kişilik turların TAMAMINDA sessizce çalışmıyordu
-- (2026-08-14 denetimi).
--
-- Düzeltme kolonu `text`e çevirir ve `questions`e olan FK'yi düşürür:
-- gerçek (uuid) sorular için referans bütünlüğü zaten `get_room_questions`
-- ve `quiz_public_questions`in kendisiyle korunur (var olmayan bir uuid
-- sunucudan hiç dönmez); paketli sorular için böyle bir referans hiçbir
-- zaman kurulamazdı çünkü `questions` tablosunda satırları yoktur.

begin;

alter table public.favorite_questions
  drop constraint if exists favorite_questions_question_id_fkey;
alter table public.favorite_questions
  alter column question_id type text using question_id::text;

alter table public.question_reports
  drop constraint if exists question_reports_question_id_fkey;
alter table public.question_reports
  alter column question_id type text using question_id::text;

commit;
