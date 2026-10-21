-- 2026-10-21 jüri onaylı slayt düzeltmeleri (3 modelin ya da 2 modelin uzlaştığı).
-- Her güncelleme yalnız belirtilen satırı ve yalnız eski metin hâlâ duruyorsa değiştirir.
-- Canlıdan okunan metin yerelle aynıydı (2026-10-21).
-- Beklenen: dry-run'da 5 güncelleme, her biri 1 satır (toplam 5).

-- 1) DRY-RUN (ROLLBACK): sonuçta her UPDATE için "UPDATE 1" görülmeli.
begin;
-- alfabe s1
update lesson_slides set content_ku = replace(content_ku, '• Alfabe: Alfabe', '• Elîfbê: Alfabe')
  where id = '5e78b509-d7db-4b1d-a289-4598da645036' and content_ku like '%• Alfabe: Alfabe%';
-- las s4
update lesson_slides set content_ku = replace(content_ku, '• Lingê min diêşe: Bacağım', '• Linga min diêşe: Bacağım')
  where id = '473ce30f-86ad-457a-be76-652dc3798f52' and content_ku like '%• Lingê min diêşe: Bacağım%';
-- hewa s5
update lesson_slides set content_tr = replace(content_tr, 'Hava için e, kişi için im kullanırız: Hewa sar e. Ez sar im.', 'Ek, önündeki sözcüğün son sesine göre değişir: ünsüzden sonra e / im, ünlüden sonra ye / me. Hewa sar e. Ez sar im.')
  where id = '19aaa825-72fa-4bac-a90a-82017dd8a588' and content_tr like '%Hava için e, kişi için im kullanırız: Hewa sar e. Ez sar im.%';
-- pise s1
update lesson_slides set content_tr = replace(content_tr, 'Bu derste 12 meslek öğreneceğiz.', 'Bu derste 7 meslek öğreneceğiz.')
  where id = '74d7f64d-5a70-458c-a12a-fc9923e81c36' and content_tr like '%Bu derste 12 meslek öğreneceğiz.%';
-- dibistan s5
update lesson_slides set content_ku = replace(content_ku, '• guhdar dike: dinliyor', '• guhdarî dike: dinliyor')
  where id = 'ea71ab0c-2fea-4757-bf85-4b275e421baf' and content_ku like '%• guhdar dike: dinliyor%';
rollback;

-- 2) UYGULAMA: dry-run 5 x "UPDATE 1" verdiyse aşağıdaki bloğun yorumunu kaldırıp çalıştır.
-- begin;
-- -- alfabe s1
-- update lesson_slides set content_ku = replace(content_ku, '• Alfabe: Alfabe', '• Elîfbê: Alfabe')
--   where id = '5e78b509-d7db-4b1d-a289-4598da645036' and content_ku like '%• Alfabe: Alfabe%';
-- -- las s4
-- update lesson_slides set content_ku = replace(content_ku, '• Lingê min diêşe: Bacağım', '• Linga min diêşe: Bacağım')
--   where id = '473ce30f-86ad-457a-be76-652dc3798f52' and content_ku like '%• Lingê min diêşe: Bacağım%';
-- -- hewa s5
-- update lesson_slides set content_tr = replace(content_tr, 'Hava için e, kişi için im kullanırız: Hewa sar e. Ez sar im.', 'Ek, önündeki sözcüğün son sesine göre değişir: ünsüzden sonra e / im, ünlüden sonra ye / me. Hewa sar e. Ez sar im.')
--   where id = '19aaa825-72fa-4bac-a90a-82017dd8a588' and content_tr like '%Hava için e, kişi için im kullanırız: Hewa sar e. Ez sar im.%';
-- -- pise s1
-- update lesson_slides set content_tr = replace(content_tr, 'Bu derste 12 meslek öğreneceğiz.', 'Bu derste 7 meslek öğreneceğiz.')
--   where id = '74d7f64d-5a70-458c-a12a-fc9923e81c36' and content_tr like '%Bu derste 12 meslek öğreneceğiz.%';
-- -- dibistan s5
-- update lesson_slides set content_ku = replace(content_ku, '• guhdar dike: dinliyor', '• guhdarî dike: dinliyor')
--   where id = 'ea71ab0c-2fea-4757-bf85-4b275e421baf' and content_ku like '%• guhdar dike: dinliyor%';
-- commit;
