-- ds26_cinema_0002: Kurmancî şıkların parantez açıklamaları karışık dildeydi
-- (iki İngilizce, iki Türkçe; "baş üstü çekim" standart değil). Bankanın
-- üslubuna göre hepsi Türkçe ve Türkçe şıkla aynı: Gemini 3.8 Flash ve
-- Grok 4.7 üç şıkta anlaştı; ilk şıkta ayrıştılar ("açılış" / "kurucu"),
-- Grok'un "kurucu çekim"i seçildi: "açılış" ı/ş harfleriyle doğru
-- şıkkı Türkçe gösterip cevabı dilden ele veriyordu (all_banks_quality_test). Yalnız bu (id,
-- alan) çiftleri; doğru şık A değişmez.
begin;
update public.questions
set option_a = 'plana damezrîner (kurucu çekim)',
    option_c = 'plana serpîrî (tepe çekimi)',
    option_d = 'çarçoveya cemidî (dondurulmuş kare)'
where id = '6776da15-b5ed-5a97-84eb-df64318d31cd'
  and option_a in ('plana damezrîner (establishing shot)',
                   'plana damezrîner (geniş açılış çekimi)',
                   'plana damezrîner (açılış çekimi)');
commit;
