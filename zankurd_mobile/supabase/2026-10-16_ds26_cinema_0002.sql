-- ds26_cinema_0002: Kurmancî şıkların parantez açıklamaları karışık dildeydi
-- (iki İngilizce, iki Türkçe; "baş üstü çekim" standart değil). Bankanın
-- üslubuna göre hepsi Türkçe ve Türkçe şıkla aynı: Gemini 3.8 Flash ve
-- Grok 4.7 üç şıkta anlaştı; ilk şıkta ayrıştılar ("açılış" / "kurucu"),
-- ana ajan Türkçe şıktaki "geniş açılış çekimi"ni seçti. Yalnız bu (id,
-- alan) çiftleri; doğru şık A değişmez.
begin;
update public.questions
set option_a = 'plana damezrîner (geniş açılış çekimi)',
    option_c = 'plana serpîrî (tepe çekimi)',
    option_d = 'çarçoveya cemidî (dondurulmuş kare)'
where id = '6776da15-b5ed-5a97-84eb-df64318d31cd'
  and option_a = 'plana damezrîner (establishing shot)';
commit;
