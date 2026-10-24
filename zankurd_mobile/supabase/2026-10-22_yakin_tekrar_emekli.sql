-- 2026-10-22: yakın tekrar sorularının ikinci emeklisi (4 soru) — sunucu karşılığı.
--
-- NİÇİN: soru kalite kapısındaki 182 `near_duplicate_candidate` uyarısının
-- tamamı incelendi. Doğru cevabı farklı 160 çift farklı bilgiyi soruyor
-- (aynı kalıp, başka sözcük/yer). Cevabı aynı 22 çift Grok 4.7 (Cursor) ve
-- ana ajan (Opus) ile oylandı; ikisinin de "aynı" dediği ve henüz emekli
-- olmayan çiftlerden biri kalır, öteki onaysız olur. Silme yok.
--
-- Kimlik: uuid5(5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77, 'zankurd-local:' + yerel id).
--   hat_0043  (Yılmaz Güney doğum yılı; kalan: ex28_yilmaz_guney_005)
--   hat_0109  (Xoybûn kuruluş yılı; kalan: hat_0104)
--   hat_0112  (Şêx Seîd serhildanı yılı; kalan: hat_0105)
--   hat_0118  (HDP kuruluş yılı; kalan: hat_0107)
-- Yerelde ayrıca baslangic_2026_10_06_0068 emekli (sunucuda yok; kalan:
-- dersler3_2026_10_08_0008, aynı "Ew doktor ___." boşluğu).

update public.questions
   set is_approved = false
 where id in (
  '8cdf9888-1a49-5625-8431-80b7659aa8b2',  -- hat_0043
  '09a89675-b657-55a0-ac1b-fba510b55c61',  -- hat_0109
  '5df299c2-d7fc-51be-a98d-a47080c3cdb1',  -- hat_0112
  'c2b99455-4082-577f-88cf-4df16ad66a0f'   -- hat_0118
);
