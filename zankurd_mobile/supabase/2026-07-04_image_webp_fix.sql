-- ============================================================
-- questions.image_url: .png -> .webp duzeltmesi (2026-07-04)
--
-- Bu oturumda yerel WebP asset donusumu (AAB 106MB -> 61MB) yapilirken
-- assets/question_images/*.png dosyalari silinip *.webp ile
-- degistirildi ve tum LOKAL Dart kod referanslari guncellendi
-- (offline_question_bank.dart, category_visuals.dart, vb.) — ama canli
-- Supabase questions.image_url kolonu unutuldu. Sonuc: 75/75 gorselli
-- soru satiri hala eski .png yoluna isaret ediyordu, uygulamada tum
-- gorselli sorularda 404 (kirik gorsel) olusuyordu.
--
-- 2026-07-04 kesif turunda tespit edildi: canli sorgu
--   png_sayisi: 75, webp_sayisi: 0
-- Uygulamadan once 72 farkli dosya adi tek tek yerel
-- assets/question_images/*.webp seti ile karsilastirildi, hepsi
-- eslesti (guvenli, tek-tek dogrulanmis mekanik string degisimi).
--
-- Uygulama sonrasi dogrulama: png_sayisi: 0, webp_sayisi: 75.
-- ============================================================

UPDATE public.questions
SET image_url = REPLACE(image_url, '.png', '.webp')
WHERE image_url LIKE '%.png';
