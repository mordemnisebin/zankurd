-- 2026-10-21: biçimi bozuk 8 sorunun sunucuda da oynanmaması.
--
-- NİÇİN: Uygulamada bu 8 soru `retired_question_ids.dart` ile havuzdan çıktı
-- (metin yeniden yazılmadı):
--   * dersler2_2026_10_08_0104–0109: çeviri parantezine de `___` konmuş
--     (çift boşluk). Boşluk doldurma türü sunucu şemasına sığmadığı için bu
--     6 sorunun sunucuda satırı YOKTUR; yapılacak bir şey yok.
--   * offline_5016 ("aslan" bi Kurmancî çi ye?) ve offline_5225 ("göz" bi
--     Kurmancî çi ye?): şıkta sözcük olmayan "di-" eki var. Bunlar
--     2026-10-01_local_parity_sync_ziman.sql ile sunucuya gitti; oda ve
--     düello sorularını `questions` tablosundan çektiği için orada hâlâ
--     onaylı duruyorlar.
--
-- NE YAPAR: iki satırı silmez, `is_approved = false` yapar (geri alınabilir).
--
-- ÖNCE DRY-RUN: aşağıdaki ilk blok ROLLBACK ile biter, hiçbir şey kalıcı
-- olmaz; sayıyı (2) doğrular. Doğruysa ikinci bloğu (COMMIT'li) çalıştır.

-- ===== 1) DRY-RUN (ROLLBACK) =====
begin;

update questions
   set is_approved = false
 where id in (
   'a6cd0c08-6c0d-55ec-b398-2d26348fb2df', -- offline_5016 "aslan"
   '1d005fbe-d39c-521f-9edd-a78947aabd79'  -- offline_5225 "göz"
 )
   and is_approved = true;

do $$
declare n int;
begin
  select count(*) into n from questions
   where id in (
     'a6cd0c08-6c0d-55ec-b398-2d26348fb2df',
     '1d005fbe-d39c-521f-9edd-a78947aabd79'
   ) and is_approved = false;
  if n > 2 then
    raise exception 'beklenmeyen satır sayısı: %', n;
  end if;
  raise notice 'dry-run: % satır onaysız (en çok 2; zaten onaysızsa daha az olabilir)', n;
end $$;

rollback;

-- ===== 2) UYGULA (dry-run temizse çalıştır) =====
-- begin;
--
-- update questions
--    set is_approved = false
--  where id in (
--    'a6cd0c08-6c0d-55ec-b398-2d26348fb2df',
--    '1d005fbe-d39c-521f-9edd-a78947aabd79'
--  )
--    and is_approved = true;
--
-- commit;
