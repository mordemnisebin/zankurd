-- 2026-09-30: Paradigma, Siyaset ve Teknolojî sunucuda yeniden etkin.
--
-- Neden: ürün sahibi 2026-09-30'da tam uygulamanın yayınlanmasına karar
-- verdi ve bu üç kategoriyi uygulamada yeniden açtı
-- (lib/src/config/category_visibility.dart `hiddenCategoryIds` boşaltıldı).
-- 2026-09-28_hidden_categories_inactive.sql sunucu tarafını kapatmıştı:
-- hızlı düellonun "Rastgele" kuyruğu (`join_matchmaking`), oda kurma
-- (`create_online_room`) ve `categories` okuma politikaları yalnız
-- `is_active = true` kategoriyi kabul eder. İstemci açık, sunucu kapalı
-- kalırsa üç kategori listede görünür ama odada/düelloda seçilemez, rastgele
-- eşleşme de onlara hiç düşmez.
--
-- Gizlemenin gerekçeleri artık kategori bazında değil SORU bazında
-- çözülüyor: tartışmalı bir siyasi görüşü doğru şık diye sunan sorular
-- lib/src/config/retired_question_ids.dart ile tek tek emekliye ayrılır
-- (sunucuda ayrı bir göçle eşlenir). Bu dosya soruya (`is_approved`)
-- dokunmaz; yalnız kategori etkinliğini geri açar.
--
-- Bilinen kalan iş: `start_async_duel` (2026-09-28_async_duels.sql) seçimden
-- önce `c.name not in ('Paradigma', 'Siyaset', 'Teknolojî')` süzgecini kendi
-- gövdesinde taşıyor. Bu göç o süzgeci DEĞİŞTİRMEZ; sırayla düello bu üç
-- kategoriyi ayrıca bir `create or replace function` göçüne kadar yine dışlar.
--
-- Tekrar çalıştırılabilir: zaten etkin satır yeniden etkinleştirilir (no-op).
-- Sunucuda üç slugdan biri yoksa ya da etkinleşmediyse aşağıdaki doğrulama
-- bloğu hata verir ve `begin`/`commit` arasındaki her şey geri alınır.
--
-- Geri alma (kategoriler yeniden kapatılacaksa, istemci listesiyle birlikte):
--   update public.categories set is_active = false
--   where slug in ('paradigma', 'siyaset', 'teknoloji');
--
-- Postflight:
--   select name, slug, is_active from public.categories order by name;

begin;

update public.categories
set is_active = true
where slug in ('paradigma', 'siyaset', 'teknoloji');

do $$
declare
  v_active integer;
begin
  select count(*) into v_active
  from public.categories
  where slug in ('paradigma', 'siyaset', 'teknoloji')
    and is_active = true;

  if v_active <> 3 then
    raise exception
      'hidden_categories_reopen: paradigma/siyaset/teknoloji üçü de etkin olmalı, etkin sayısı %',
      v_active;
  end if;
end
$$;

commit;
