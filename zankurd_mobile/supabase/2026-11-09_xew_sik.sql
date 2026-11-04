-- 2026-11-09 — "xew" sorusunun doğru şıkkı daha anlaşılır yazılır.
--
-- NİÇİN: Simülatör turu 5'te ("85B") test oyuncusu "Di kurmancî de peyva
-- "xew" çi wateyê dide?" sorusunda hiçbir şıkkın "uyku" olmadığını sandı:
-- doğru şık "nivistina mirovan" (nivistin = uyumak/yatmak) yazı fiili
-- "nivîsîn" ile karışıyordu. Anahtar DOĞRU (C = uyku); yalnız şık metni
-- yaygın ve karışmayan "razana mirovan" olur. Sahibin içerik ilkesi: tek
-- (soru kimliği, alan) çifti; Gemini 3.8 Flash ve Gemini 4 Argon AYNI nihai
-- metinde ONAY verdi. Soru silinmez, correct_option ('C') ve diğer şıklar
-- değişmez.
--
-- Eski metne bağlıdır: canlıda şık eskisinden farklıysa hiçbir şey yapılmaz.
-- GERİ ALMA: geri_al/2026-11-09_xew_sik_geri.sql
begin;

update questions
   set option_c = 'razana mirovan'
 where id = '75c2140f-7d76-5625-9dc6-d256096a5783'
   and option_c = 'nivistina mirovan'
   and correct_option = 'C';

commit;
