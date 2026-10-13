-- 2026-10-13: BAŞLANGIÇ YOLU II–III — üç dersin Kurmancî başlık/açıklaması.
--
-- NİÇİN: 2026-10-08 göçlerindeki ders adları slayt başlıklarından mekanik
-- türetilmişti ve dil denetiminden geçmemişti. Gemini 3.8 Flash ve Grok 4.7
-- ayrı ayrı okudu; ikisinin birleştiği üç madde:
--   pirs        başlık 'Pirs' ("soru") → 'Peyvên pirsê' ("soru kelimeleri")
--   pise        açıklama 'Pîşe çi ye?' ("meslek nedir?", tanım sorusu)
--               → 'Navên pîşeyan' (meslek adları)
--   kirin       açıklama 'Silav li dikanê' ("dükkana selam", alışverişi
--               anlatmıyor) → 'Kirîn û firotin' (alışveriş)
-- Ayrıca pirs açıklamasında 'Ku?' → 'Li ku?' ("ku" tek başına "ki" bağlacıyla
-- karışır; tek model önerdi, belirsizliği gidermek için alındı).
-- Yerel katalog (mock_zankurd_repository.dart) aynı metne çekildi.
--
-- Idempotent: yalnız eski metni taşıyan satırı günceller.
-- Uygulama: supabase db query --linked -f supabase/2026-10-13_ders_basliklari.sql

begin;

update lessons set title_ku = 'Peyvên pirsê', description_ku = 'Kî? Çi? Li ku? Kengî?'
  where slug = 'pirs' and title_ku = 'Pirs';
update lessons set description_ku = 'Navên pîşeyan'
  where slug = 'pise' and description_ku = 'Pîşe çi ye?';
update lessons set description_ku = 'Kirîn û firotin'
  where slug = 'kirin' and description_ku = 'Silav li dikanê';

do $$
begin
  if (select count(*) from lessons where
        (slug = 'pirs' and title_ku = 'Peyvên pirsê' and description_ku = 'Kî? Çi? Li ku? Kengî?')
     or (slug = 'pise' and description_ku = 'Navên pîşeyan')
     or (slug = 'kirin' and description_ku = 'Kirîn û firotin')) <> 3 then
    raise exception 'ders_basliklari: üç satır beklenen metne ulaşmadı';
  end if;
end $$;

commit;
