-- 2026-10-30 — Çand: tür uyumsuz şablon çeldiricisi (tur 3 simülatör bulgusu).
--
-- Neden: "Îranî û gelek gelên din (wek Newrozê)" ("İranî ve birçok başka halk
-- (Newroz gibi)") bir üretim şablonundan sızmış, hiçbir soruya ait olmayan bir
-- şıktır; zêmarın işlevini, dağların önemini ve şevbêrkî soran üç soruda
-- dördüncü şık olarak duruyor ve bariz yanlış olduğu için soruyu kolaylaştırıyor.
-- Her biri aynı türden makul bir çeldiriciyle değişir. Doğru şık (correct_option)
-- ve öteki şıklar değişmez.
--
--   eedaca71…  yerel offline_2261 (zêmar)      option_d
--   739a56c7…  yerel offline_2724 (çiya)       option_a
--   e9100141…  yalnız sunucu (şevbêrk)        option_d
--
-- KU metinleri TASLAK: Kurmancî jüri onayından önce UYGULANMAZ.
-- Koşul eski değerin birebir eşitliğidir (idempotent; başka değere dönmüş
-- satır 0 etkilenir). Sonda doğrulama: sunucuda olan satırların hepsi yeni
-- değerde olmalı.
-- GERİ ALMA: aynı üç güncellemede eski/yeni yer değiştirerek.

begin;

update questions
   set option_d = 'pîrozkirina dawet û şahiyan'
 where id = 'eedaca71-84cc-5336-bf8b-23aac654c7eb'
   and option_d = 'Îranî û gelek gelên din (wek Newrozê)';

update questions
   set option_a = 'bi navkirina çiyayan di pirtûkên pîroz de'
 where id = '739a56c7-9218-5787-9764-428fe955e1c3'
   and option_a = 'Îranî û gelek gelên din (wek Newrozê)';

update questions
   set option_d = 'Karê hevpar ê dirûnê ji bo amadekariya zivistanê'
 where id = 'e9100141-df1c-48a6-b4ec-9d0d9ad9a956'
   and option_d = 'Îranî û gelek gelên din (wek Newrozê)';

do $$
declare
  n int;
begin
  select count(*) into n
    from questions
   where id in (
     'eedaca71-84cc-5336-bf8b-23aac654c7eb',
     '739a56c7-9218-5787-9764-428fe955e1c3',
     'e9100141-df1c-48a6-b4ec-9d0d9ad9a956'
   )
     and 'Îranî û gelek gelên din (wek Newrozê)' in
         (option_a, option_b, option_c, option_d);
  if n > 0 then
    raise exception 'cand_celdirici: % soruda eski çeldirici kaldı', n;
  end if;
end $$;

commit;
