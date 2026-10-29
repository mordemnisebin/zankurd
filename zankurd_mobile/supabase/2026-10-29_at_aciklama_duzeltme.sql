-- 2026-10-29: "Ajalê ku bi tirkî "at" e…" sorusunun (doğru cevap Hesp) üç
-- açıklama alanı da yanlış şıkkı (Bizin = keçi) öğretiyordu. Codex GPT-6
-- Astra içerik denetimi buldu; yerel kopya (ziman_x_0014) düzeltildi.
-- KU metni kurul oybirliği: Gemini 3.8 Flash, Gemini 4 Argon, GPT-6.1 Sol.
-- Korumalı: yalnız id + eski metin eşleşirse günceller (idempotent).
update public.questions
   set explanation = 'Hesp, Türkçede "at" demektir.',
       explanation_tr = 'Hesp, Türkçede "at" demektir.',
       explanation_ku = '"Hesp" bi Tirkî "at" e.'
 where id = 'f590dc44-aa39-5063-a321-8c39c1e0b833'
   and explanation_ku = '"Bizin" bi Tirkî "keçi" ye.';
