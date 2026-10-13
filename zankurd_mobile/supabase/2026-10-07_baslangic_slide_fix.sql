-- 2026-10-07: "Xwe nasandin" 3. slaytındaki çift nokta düzeltmesi (canlı sunucu).
--
-- NİÇİN: 2026-10-06_baslangic_lessons.sql ile sunucuya giren `xwe-nasandin`
-- dersinin 3. slaytının Türkçe açıklaması `... Stenbol → Stenbolê..` diye iki
-- noktayla bitiyordu (2026-10-07 simülatör QA'sı). Yerel katalogda
-- (`mock_zankurd_repository.dart`) aynı gün düzeltildi; sunucu satırı eski
-- hâlinde kalırsa sunucu katalogunu okuyan derleme yine iki nokta gösterir.
-- Bekçi: `test/lesson_slide_text_hygiene_test.dart`.
--
-- TEKRAR ÇALIŞTIRILABİLİR: yalnız metni `Stenbolê..` ile BİTEN satırı
-- günceller; ikinci çalıştırma 0 satır günceller. Şema salt okunur
-- doğrulandı: `lesson_slides (lesson_id, order_in_lesson, content_ku,
-- content_tr, example_ku)`, `lessons (slug)`.
--
-- GERİ ALMA: gerekmez (yalnız yazım artığı kalkar). İstenirse content_tr'nin
-- sonuna bir nokta daha eklenir.
--
-- Uygulama (ana ajan/kullanıcı; bu dosya ÇALIŞTIRILMADI):
--   supabase db query --linked -f supabase/2026-10-07_baslangic_slide_fix.sql

begin;

update lesson_slides ls
set content_tr = regexp_replace(ls.content_tr, '([^.])\.\.$', '\1.')
from lessons l
where l.id = ls.lesson_id
  and l.slug = 'xwe-nasandin'
  and ls.order_in_lesson = 3
  and ls.content_tr like '%..' and ls.content_tr not like '%...';

do $$
declare
  v_bad int;
  v_ok int;
begin
  select count(*) into v_bad
    from lesson_slides ls join lessons l on l.id = ls.lesson_id
   where l.slug = 'xwe-nasandin' and ls.content_tr like '%..'
     and ls.content_tr not like '%...';  -- üç nokta ("adım ...") meşru
  if v_bad <> 0 then
    raise exception 'xwe-nasandin: cift nokta ile biten % slayt kaldi', v_bad;
  end if;

  select count(*) into v_ok
    from lesson_slides ls join lessons l on l.id = ls.lesson_id
   where l.slug = 'xwe-nasandin' and ls.order_in_lesson = 3
     and ls.content_tr like '%.' and ls.content_tr not like '%..';
  if v_ok <> 1 then
    raise exception 'xwe-nasandin 3. slayt beklenen hâlde degil (%)', v_ok;
  end if;
end
$$;

commit;
