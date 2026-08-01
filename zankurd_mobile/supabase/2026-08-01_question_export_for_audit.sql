-- Sunucu sorularını yerel dil politikasıyla denetlemek için dışa aktarır.
--
-- SALT OKUNUR. TEK sorgu — Supabase SQL Editor birden çok ifade
-- çalıştırıldığında yalnız SONUNCUNUN sonucunu gösteriyor, bu yüzden
-- `2026-08-01_question_bank_drift_audit.sql` içindeki beş sorgu ekranda
-- tek tek okunamıyordu.
--
-- ## Nasıl kullanılır
--
--   1. Bu dosyanın tamamını SQL Editor'e yapıştır ve çalıştır.
--   2. Sonuç tablosunun sağ üstündeki **Export → Download CSV**.
--   3. İnen dosyayı şu ada koy:
--        zankurd_mobile/tool/server_questions_export.csv
--
-- Oyuncunun görebileceği bütün yayınlanmış sorular dışa aktarılır;
-- karantinadaki eski adaylar aktif kalite sonucunu kirletmez.
--
-- Sonra çıktı, uygulamanın kendi `QuestionLanguagePolicy` sınıfından
-- geçirilir — harf temelli SQL taraması `Dibistan` gibi özel harfsiz
-- kelimeleri kaçırdığı için gerçek denetim yerelde yapılmalı.
--
-- ## Niçin gerekli
--
-- Yerel bankalar (1787 soru) 2026-08-01'de tamamen temiz. Ama oda maçları
-- soruları SUNUCUDAN alıyor ve sunucu bankası ayrışmış. Canlı bir maçta:
--
--   Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
--     A) Öğrenmek  B) Öğretmen  C) Sandalye ✓  D) Dibistan
--
-- Üç Türkçe şıkkın yanında bir Kurmancî çeldirici. Soru "bi Tirkî çi ye?"
-- diyorsa o şık bakar bakmaz elenir; bilgi ölçmeyen bedava ipucu.
-- Bu soru yerel bankaların hiçbirinde yok.

select
  q.id,
  q.prompt,
  q.option_a,
  q.option_b,
  q.option_c,
  q.option_d,
  q.correct_option,
  case q.correct_option
    when 'A' then q.option_a
    when 'B' then q.option_b
    when 'C' then q.option_c
    else q.option_d
  end as correct_answer
from public.questions q
where q.is_approved = true
  and q.review_status is distinct from 'rejected'
order by q.id;
