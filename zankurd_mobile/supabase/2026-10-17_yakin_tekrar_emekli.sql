-- 2026-10-17: yakın tekrar sorularının emeklisi (5 soru) — sunucu karşılığı.
--
-- NİÇİN: soru kalite kapısının 182 `near_duplicate_candidate` uyarısından
-- oynanabilir bankalardaki 70 çift Gemini 3.8 Flash ve Grok 4.7 ile oylandı;
-- yalnız İKİSİNİN DE "aynı olgu" dediği 5 çift tekrar sayıldı (oyuncu aynı
-- bilgiyi iki kez sorulmuş hisseder). Her çiftten daha iyi yazılmış/açıklanmış
-- olan kaldı, öteki yerelde `retired_question_ids.dart` ile oynanmaz oldu.
-- Oda ve düello soruları sunucudaki `questions` tablosundan gelir; aynı
-- sorular orada da onaysız yapılır. Silme yok, `is_approved=false` geri alınabilir.
--
-- Kimlik: uuid5(5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77, 'zankurd-local:' + yerel id).
--   ds_cografya_0133  (ova (Deşt) tanımı; kalan: ds_cografya_0129)
--   ds_dirok_0029  (Hawar 1932; kalan: edit_dirok_0001)
--   ds_dirok_0091  (Nippur; kalan: ds_dirok_0055)
--   ds_muzik_0144  (Haydn; kalan: ds_muzik_0133)
--   offline_2668  (Selahaddin doğum yeri; kalan: edit_dirok_0028)

update public.questions
   set is_approved = false
 where id in (
  'fa171689-95a2-57d3-b09a-861cc95ba45f',  -- ds_cografya_0133
  '361dba3f-4d03-54c5-972a-da171d1d0fbc',  -- ds_dirok_0029
  'a4c81747-3400-506d-9d34-32a9c2822992',  -- ds_dirok_0091
  '3ef5dea5-ed87-5c03-81d9-e9916f205ce2',  -- ds_muzik_0144
  '4482f3a3-0b62-51eb-8d00-ba02ee64abda'  -- offline_2668
);
