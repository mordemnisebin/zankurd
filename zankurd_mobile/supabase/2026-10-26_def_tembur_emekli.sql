-- 2026-10-26: ds_cand_0041 (def/tembûr) emeklisi — sunucu karşılığı.
--
-- NİÇİN: "Kürt düğünlerinde tembûra genellikle def eşlik eder" ve "diğer
-- aletler geleneksel değildir" genellemeleri kaynakla doğrulanamadı
-- (docs/content_batches/ds_cand_0041_kaynak_incelemesi_2026_10_26.md).
-- Yerelde retired_question_ids.dart ile emekli; canlıda onaylı kaldığı için
-- online oda/düello havuzu soruyu getirmeye devam ederdi.
--
-- Silme yok; is_approved=false geri alınabilir (aynı id ile true).
-- Kimlik: uuid5(5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77, 'zankurd-local:ds_cand_0041').
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-26_def_tembur_emekli.sql

begin;

update public.questions
   set is_approved = false
 where id = '2a1f76a9-d54e-5daf-898f-40cfd3f6a67c';  -- ds_cand_0041

commit;
