-- 2026-10-02: uçtan uca QA'da çıkan iki yerel soru düzeltmesini sunucuya yansıt (canlı sunucu).
--
-- NİÇİN: iki soru yerel bankada düzeltildi (bkz. test/e2e_content_fixes_test.dart)
-- ve sunucudaki uuid5 kimlikli kopyaları eski hâlinde kaldı; oda ve düello
-- soruları sunucudan çekildiği için tek kişilik modda düzeltilmiş soru, odada
-- hatalı hâliyle gelirdi.
--
--   1) c835ddee-ac34-596d-a4d3-04e98d8740bb ('"su" bi Kurmancî çi ye?',
--      yerel offline_0757): kategori Cografya -> Ziman. Sorulan şey bir sözcük
--      çevirisi; coğrafya değil.
--   2) 59d0294e-b34c-5b22-9933-1f7fb0ca8c75 (koordinat sorusu,
--      yerel ds_cografya_0177): şık D 'Dirêjahî û firehî' -> 'Dem û lez'.
--      Eski çeldirici de enlem/boylam için geçerli bir Kurmancî ifade
--      (dirêjahî = boylam, firehî = enlem): iki doğru şık vardı. Doğru cevap C
--      aynı kalır.
--
-- Yerelde ayrıca offline_0110 (görselli) ve offline_tf_muz_0020..0024 (Türkçe
-- metin) düzeltildi; ikisi de sunucuda yok (görselli sorular 2.0.0 sonrası
-- eşitlenir; Türkçe çeviri sunucuda tutulmaz), bu göçe girmez.
--
-- TEKRAR ÇALIŞTIRILABİLİR: aynı değerleri yazar. Doğrulama bloğu iki satırın
-- beklenen hâlde olduğunu denetler; tutmazsa işlem geri alınır.
--
-- GERİ ALMA: category_id'yi 'Cografya', option_d'yi 'Dirêjahî û firehî'
-- yaparak (üstteki iki satır için).
--
-- Uygulama (ana ajan/kullanıcı; bu dosya ÇALIŞTIRILMADI):
--   supabase db query --linked -f supabase/2026-10-02_e2e_content_fixes.sql

begin;

do $$
begin
  if not exists (select 1 from categories where name = 'Ziman') then
    raise exception 'Eksik kategori: Ziman';
  end if;
end
$$;

update questions
set category_id = (select id from categories where name = 'Ziman'),
    updated_at = now()
where id = 'c835ddee-ac34-596d-a4d3-04e98d8740bb'
  and prompt = '"su" bi Kurmancî çi ye?';

update questions
set option_d = 'Dem û lez',
    updated_at = now()
where id = '59d0294e-b34c-5b22-9933-1f7fb0ca8c75'
  and option_c = 'Hêlîpan û hêlîdirêj'
  and correct_option = 'C';

do $$
declare
  v_ok int;
begin
  select count(*) into v_ok from questions q
  where (q.id = 'c835ddee-ac34-596d-a4d3-04e98d8740bb'
         and q.category_id = (select id from categories where name = 'Ziman'))
     or (q.id = '59d0294e-b34c-5b22-9933-1f7fb0ca8c75'
         and q.option_d = 'Dem û lez' and q.correct_option = 'C');
  if v_ok <> 2 then
    raise exception 'Beklenen 2 düzeltilmiş satır, bulunan %', v_ok;
  end if;
end
$$;

commit;
