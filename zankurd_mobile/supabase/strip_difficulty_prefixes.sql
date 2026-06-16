-- Soru promptlarındaki zorluk-katmanı öneklerini temizler:
--   "Temel: ", "Pekiştirme: ", "Ustalık: "
--
-- Bu önekler oyunculara teknik/kafa karıştırıcı göründüğü için kaldırıldı.
-- Seed dosyaları (rich_question_bank_v2*.sql ve *.csv) zaten temizlendi;
-- bu script, önekler CANLI veritabanına önceden yazıldıysa onları düzeltir.
--
-- Güvenli ve idempotent: yalnızca prompt'un BAŞINDAKİ öneki siler
-- (left-anchored). Tekrar çalıştırmak zarar vermez.

update public.questions
set prompt = regexp_replace(prompt, '^(Temel|Pekiştirme|Ustalık): ', '')
where prompt ~ '^(Temel|Pekiştirme|Ustalık): ';

-- Kaç satırın kaldığını doğrulamak için (0 dönmeli):
--   select count(*) from public.questions
--   where prompt ~ '^(Temel|Pekiştirme|Ustalık): ';
