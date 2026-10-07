-- 2026-09-30: "Dema Hespên Serxweş" hêstir sorusu — iki doğru şık.
--
-- NİÇİN: Soru "katırlara ne verilir?" diye soruyor, şıklarda hem Vodka hem
-- Viskî var ve doğru cevap Viskî. Kaynaklar çelişiyor: aynı Wikipedia
-- maddesi olay özetinde viski, başka bir cümlede votka diyor. Oyuncu Vodka
-- deyip "yanlış" duyabiliyordu. Gemini denetimi (FACT) bunu yakaladı, ana
-- ajan kaynaktan doğruladı. Soru, kaynakların uzlaştığı düzeye çekildi:
-- doğru cevap "alkollü içki", çeldiriciler alkolsüz.
--
-- Yerel banka (assets/data/expansion_2026_09_28_questions.json,
-- ex28_yilmaz_guney_018) aynı gün aynı metne çekildi; kimlik
-- tool/sync_sinema_to_server.py'nin uuid5 eşlemesidir.
begin;

update questions set
  option_a = 'Çaya germ',
  option_b = 'Vexwarina alkolî',
  option_c = 'Şîrê germ',
  option_d = 'Ava bi xwê',
  correct_option = 'B',
  explanation = 'Qaçaxçî vexwarina alkolî (çavkanî carinan viskî, carinan jî vodka dibêjin) didin hêstiran da ku li ber zivistana dijwar a çiyê xwe ragirin; navê fîlmê jî ji vê dîmenê tê.',
  explanation_ku = 'Qaçaxçî vexwarina alkolî (çavkanî carinan viskî, carinan jî vodka dibêjin) didin hêstiran da ku li ber zivistana dijwar a çiyê xwe ragirin; navê fîlmê jî ji vê dîmenê tê.',
  explanation_tr = 'Kaçakçılar katırların dağın sert kışına dayanabilmesi için onlara alkollü içki verir (kaynaklarda kimi zaman viski, kimi zaman votka diye geçer); filmin adı da bu sahneden gelir.',
  last_content_check_at = now()
where id = '24a329bf-7cfd-53e6-b627-226f13c4c61f';

do $$
begin
  if not exists (select 1 from questions where id = '24a329bf-7cfd-53e6-b627-226f13c4c61f' and option_b = 'Vexwarina alkolî') then
    raise exception 'Sinema hespen fix: satir guncellenmedi';
  end if;
end
$$;

commit;
