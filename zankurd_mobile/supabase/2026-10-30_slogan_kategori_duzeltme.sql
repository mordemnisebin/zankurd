-- 2026-10-30 — "Jin, jiyan, azadî" soruları Bilim (Paradigma) kategorisinden çıkar.
--
-- Neden (kurul 3 D6, Astra + Terra + Sol 3/3): canlı düelloda "Di salên dawî
-- de dirûşma 'Jin, jiyan, azadî' çi bandor kir?" sorusu künyede "Bilim"
-- (Paradigma'nın görünen adı) altında geliyordu; slogan sorusu bilim turunda
-- yersiz. Sözcük anlamı soranlar Ziman'a, hareketi/olayı soranlar Siyaset'e
-- taşınır. Metin, şık, doğru cevap değişmez.
--
-- Koruma: her güncelleme kimlik + ESKİ kategori (paradigma) ile koşullu;
-- elle değişmiş satır 0 satır etkiler. Doğrulama bloğu paradigma'da slogan
-- sorusu kalırsa durur.
-- Geri alma: aynı kimliklerde category_id'yi paradigma'ya döndür.
-- UYGULANMADI (ana ajan kuru çalıştırıp uygular).

begin;

-- Sözcük anlamı / dil → Ziman
update questions set category_id = (select id from categories where slug = 'ziman')
 where id in (
   '0c6d4c35-90a3-4478-b7cf-175e75e8fc83',
   '5bf70dd2-55be-4628-867d-47ff0f460ef8',
   '844eeac4-dbe3-451c-bc15-d810ec0fdccc',
   '89a9465a-3be1-434f-a0cd-d5db0477abdd',
   'e96aa5c5-3221-4b5f-b648-db728eadc2d7'
 )
   and category_id = (select id from categories where slug = 'paradigma');

-- Hareket / olay / etki → Siyaset
update questions set category_id = (select id from categories where slug = 'siyaset')
 where id in (
   '005a95d6-0e8c-58c0-9a4d-18f796dee23f',
   '8333f45c-b440-4a2f-95f6-3b52a7eee1f4',
   '87d03be3-9613-43b8-aca7-e3a4625cfe6a'
 )
   and category_id = (select id from categories where slug = 'paradigma');

do $$
declare n int;
begin
  select count(*) into n
    from questions q join categories c on c.id = q.category_id
   where c.slug = 'paradigma'
     and (q.prompt ilike '%jin, jiyan%' or q.prompt ilike '%jin jiyan%');
  if n > 0 then
    raise exception 'slogan_kategori: paradigma''da % slogan sorusu kaldı', n;
  end if;
end $$;

commit;
