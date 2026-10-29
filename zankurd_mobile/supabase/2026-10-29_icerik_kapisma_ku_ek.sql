-- Kapışma KU göçünün eki (2026-10-29): sunucuda şık SIRASI yereldekinden farklı
-- olan 3 soru. Ana göç her alanı yerel sütun konumuyla (option_b vb.) ve eski
-- değerle korur; bu üç soruda eski metin sunucuda başka sütunda durduğu için 4
-- alan 0 satır güncelledi (doğrulama kuru çalıştırmada görüldü). Burada eşleşme
-- METİNLE yapılır: eski metin hangi şık sütunundaysa yalnız o sütun yenilenir.
-- correct_option değişmez (doğru şıkkın sütunu aynı kalır; 20304'te doğru şık
-- metni yenilenir, harfi D kalır). İstemci cevabı metinden anahtara çevirdiği
-- için sıra farkı oyunu bozmaz.
-- Kuru çalıştırma: begin…rollback ile; doğrulama bloğu 4 alan bekler.

begin;

update questions set option_a = 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '4fccdab1-1beb-534e-a9f8-2c28be060e00' and option_a = 'ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir'; -- offline_10071
update questions set option_b = 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '4fccdab1-1beb-534e-a9f8-2c28be060e00' and option_b = 'ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir'; -- offline_10071
update questions set option_c = 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '4fccdab1-1beb-534e-a9f8-2c28be060e00' and option_c = 'ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir'; -- offline_10071
update questions set option_d = 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '4fccdab1-1beb-534e-a9f8-2c28be060e00' and option_d = 'ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir'; -- offline_10071
update questions set option_a = 'Feqiyê Teyran' where id = 'd5d1dc8d-428e-5d48-865f-1693c1ce35ed' and option_a = 'kovara Hawarê'; -- offline_curated_20251
update questions set option_b = 'Feqiyê Teyran' where id = 'd5d1dc8d-428e-5d48-865f-1693c1ce35ed' and option_b = 'kovara Hawarê'; -- offline_curated_20251
update questions set option_c = 'Feqiyê Teyran' where id = 'd5d1dc8d-428e-5d48-865f-1693c1ce35ed' and option_c = 'kovara Hawarê'; -- offline_curated_20251
update questions set option_d = 'Feqiyê Teyran' where id = 'd5d1dc8d-428e-5d48-865f-1693c1ce35ed' and option_d = 'kovara Hawarê'; -- offline_curated_20251
update questions set option_a = 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe ya felsefî û tesewifî tê naskirin' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_a = 'kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye'; -- offline_curated_20304
update questions set option_b = 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe ya felsefî û tesewifî tê naskirin' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_b = 'kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye'; -- offline_curated_20304
update questions set option_c = 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe ya felsefî û tesewifî tê naskirin' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_c = 'kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye'; -- offline_curated_20304
update questions set option_d = 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe ya felsefî û tesewifî tê naskirin' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_d = 'kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye'; -- offline_curated_20304
update questions set option_a = 'helbestvanê kurd ê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_a = 'nivîskarê destana nemir a "Mem û Zîn" ku hîmê ramanî yê kurdewariyê daniye'; -- offline_curated_20304
update questions set option_b = 'helbestvanê kurd ê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_b = 'nivîskarê destana nemir a "Mem û Zîn" ku hîmê ramanî yê kurdewariyê daniye'; -- offline_curated_20304
update questions set option_c = 'helbestvanê kurd ê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_c = 'nivîskarê destana nemir a "Mem û Zîn" ku hîmê ramanî yê kurdewariyê daniye'; -- offline_curated_20304
update questions set option_d = 'helbestvanê kurd ê klasîk ê ku mesnewiya Mem û Zînê nivîsî' where id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and option_d = 'nivîskarê destana nemir a "Mem û Zîn" ku hîmê ramanî yê kurdewariyê daniye'; -- offline_curated_20304

do $$
declare n int;
begin
  select count(*) into n from questions q
   where (q.id = '4fccdab1-1beb-534e-a9f8-2c28be060e00' and 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî' in (q.option_a,q.option_b,q.option_c,q.option_d))
      or (q.id = 'd5d1dc8d-428e-5d48-865f-1693c1ce35ed' and 'Feqiyê Teyran' in (q.option_a,q.option_b,q.option_c,q.option_d))
      or (q.id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe ya felsefî û tesewifî tê naskirin' in (q.option_a,q.option_b,q.option_c,q.option_d))
      or (q.id = '7c6a799d-67a2-5261-8d52-a289f517c3e2' and 'helbestvanê kurd ê klasîk ê ku mesnewiya Mem û Zînê nivîsî' in (q.option_a,q.option_b,q.option_c,q.option_d));
  if n <> 3 then raise exception 'kapisma-ku-ek: beklenen 3 soru (4 alan), bulunan %', n; end if;
end $$;

commit;
