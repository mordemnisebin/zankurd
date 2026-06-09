-- ZanKurd: eski v1 seed temizliği
-- Neden: rich_question_bank_v2 (2250 soru, asset:// görseller) eski v1 seed'inin
-- (30 soru) yerini aldı. v1'in 7 görsel sorusu hâlâ placehold.co URL'leri
-- kullanıyor ve uygulamada kırık/yavaş görsel olarak görünebilir.
--
-- Bu script:
--   1. zankurd_seed_rich_v1 kaynaklı 30 soruyu siler.
--   2. Hâlâ placehold.co görseli kullanan diğer satırları siler.
--
-- Çalıştırma: Supabase Dashboard > SQL Editor > yapıştır > Run

delete from public.questions
where source_url = 'zankurd_seed_rich_v1';

delete from public.questions
where image_url like '%placehold.co%';
