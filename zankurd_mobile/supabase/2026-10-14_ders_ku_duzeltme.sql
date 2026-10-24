-- 2026-10-14: ders_2026_10_01 bankasında Kurmancî düzeltmeleri canlıya.
--
-- NİÇİN: Gemini Argon'un içerik denetimi (Grok 4.7 + Gemini 3.8 Flash çoğunluk
-- onayı) bu 5 soruda yazım/anlam hatası buldu: "şaşîyek"→"şaşiyek",
-- "rojîyê/rêwîtîyê"→"rojiyê/rêwîtiyê", "şirîn"→"şîrîn", "evînê dike" doğal
-- değil, 0024'te "Dîlan" ikinci doğru cevaptı. Yerel bankada düzeldiler; oda
-- ve düello soruları sunucudan çektiği için canlı kopya eski kalıyordu.
--
-- Satırlar tool/sync_sinema_to_server.py `to_row` ile üretildi (aynı uuid5,
-- aynı şık sırası). Yalnız metin sütunları güncellenir; tekrar çalıştırılabilir.
-- Uygulama: supabase db query --linked -f supabase/2026-10-14_ders_ku_duzeltme.sql

begin;

-- ders_2026_10_01_0016
update questions set
  prompt = 'Te şaşiyek kir, tu çi dibêjî? ___',
  option_a = 'Spas', option_b = 'Fermo', option_c = 'Bibexşîne', option_d = 'Kerem bike',
  correct_option = 'C',
  explanation = 'Dema em şaşiyekê dikin, em dibêjin "Bibexşîne".',
  explanation_ku = 'Dema em şaşiyekê dikin, em dibêjin "Bibexşîne".',
  explanation_tr = 'Hata yapınca "Bibexşîne" deriz.'
where id = '1802aa7c-7cdf-5092-b1ac-d3a8ba085c6a';
-- ders_2026_10_01_0024
update questions set
  prompt = 'Di dawetê de em ___ digirin.',
  option_a = 'Stran', option_b = 'Klam', option_c = 'Govend', option_d = 'Xwarin',
  correct_option = 'C',
  explanation = 'Di dawetê de em govendê digirin.',
  explanation_ku = 'Di dawetê de em govendê digirin.',
  explanation_tr = 'Düğünde halay oynarız.'
where id = 'dead804b-5e06-506b-bc15-096db5ecc09b';
-- ders_2026_10_01_0030
update questions set
  prompt = 'Malbat di "Cejna Remezanê" de çi dike?',
  option_a = 'Cejnê pîroz dike', option_b = 'Rojiyê digire', option_c = 'Qurbanê serjê dike', option_d = 'Dikeve rêwîtiyê',
  correct_option = 'A',
  explanation = 'Di cejnê de malbat cejnê pîroz dike.',
  explanation_ku = 'Di cejnê de malbat cejnê pîroz dike.',
  explanation_tr = 'Bayramda aile bayramı kutlar.'
where id = 'e558d5e2-5997-58b5-b08f-7e82df03f758';
-- ders_2026_10_01_0038
update questions set
  prompt = '"Üzüm" bi kurmancî çi ye?',
  option_a = 'Tirî', option_b = 'Hejîr', option_c = 'Sêv', option_d = 'Pîvaz',
  correct_option = 'A',
  explanation = '"Tirî" fêkiyekî biçûk û şîrîn e.',
  explanation_ku = '"Tirî" fêkiyekî biçûk û şîrîn e.',
  explanation_tr = '"Tirî" küçük ve tatlı bir meyvedir.'
where id = 'ca887c15-acb9-5a3a-a95f-ea600acfb9a2';
-- ders_2026_10_01_0056
update questions set
  prompt = '"Aşık" bi kurmancî çi ye?',
  option_a = 'Dilşikestî', option_b = 'Tirsiyayî', option_c = 'Evîndar', option_d = 'Bêhêvî',
  correct_option = 'C',
  explanation = '"Evîndar" ji bo kesê ku ji kesekî hez dike tê gotin.',
  explanation_ku = '"Evîndar" ji bo kesê ku ji kesekî hez dike tê gotin.',
  explanation_tr = '"Evîndar" aşık olan kişi için söylenir.'
where id = 'ea32613d-a665-55f6-b505-db035fd0c493';

do $$
declare v_count integer;
begin
  select count(*) into v_count from questions where id in ('1802aa7c-7cdf-5092-b1ac-d3a8ba085c6a', 'dead804b-5e06-506b-bc15-096db5ecc09b', 'e558d5e2-5997-58b5-b08f-7e82df03f758', 'ca887c15-acb9-5a3a-a95f-ea600acfb9a2', 'ea32613d-a665-55f6-b505-db035fd0c493');
  if v_count <> 5 then
    raise exception 'beklenen 5 soru, bulunan %', v_count;
  end if;
end
$$;

commit;
