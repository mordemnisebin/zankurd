-- 2026-11-18: yeni sorular 3 paketinden 7 soruyu eler (is_approved = false, review_status = 'rejected')
--
-- NICIN: Paket 3 (2026-11-14_yeni_sorular_3.sql) canlida; tam CI'da 7 soru
-- bekcileri kirdi ve yerel JSON'dan CIKARILDI:
--   * 6 soruda dogru cevap soru metninde yaziyor (answer_not_in_prompt_test,
--     question_bank_test "prompts do not leak"): oyuncu okumadan cozer;
--   * 1 soru, zaten oynanabilir olan edit_dirok_0001 ile ayni metinli tekrar
--     (playable_prompt_uniqueness_test).
-- Sunucu da yerel kopyayla ayni kume kalsin diye bu satirlar elenir. Satirlar
-- SILINMEZ (oyun gecmisi/sikayet bagi bozulmasin); yalniz oynanamaz isaretlenir.
--
-- KAPSAM: yalniz paket-3 kimlikleri (7). Baska paketin satirina dokunmaz.
-- ON KOSUL: satir hala paket-3 icerigindedir: prompt eski metne esit,
-- is_approved = true, review_status = 'approved'. Aksi halde dokunulmaz ve sayilir.
-- IDEMPOTENT: zaten elenmis satir "zaten" sayilir.
-- Geri alma: supabase/geri_al/2026-11-18_yeni_sorular_3_eleme_geri.sql

begin;

create temp table _eleme (local_id text, id uuid, prompt text, neden text) on commit drop;

insert into _eleme (local_id, id, prompt, neden) values
  ('r15_cand_B2_39', '1661c771-2d6e-551d-9835-33ca7485ece6'::uuid, 'Di kevneşopiya serdana malbateke ku kesek ji dest daye de, ji gotinên dilovaniyê re bi Kurmancî çi tê gotin?', 'cevap ele veriyor: Turkce istem "basagligi", dogru sik "Basagligi" (answer_not_in_prompt)'),
  ('r15_cihan_B1_10', '082e49ba-75f4-5a7f-a8c6-16e2fead8281'::uuid, 'Tirtûla perperokê piştî guherîna xwe ya tevahî dibe çi?', 'cevap ele veriyor: istemde "perperok", dogru sik "Perperok" (iki dilde)'),
  ('r15_dirok_A1_21', 'bdaff1e3-926e-560e-8d0a-bee609b98ac3'::uuid, 'Kê di sala 1526an de Împaratoriya Baburiyan damezirand?', 'cevap ele veriyor: Turkce istem "Babur Imparatorlugu", dogru sik "Babur"'),
  ('r15_edebiyat_B3_17', 'c0562584-28a7-5f06-bdcd-053b1552d3ca'::uuid, 'Kîjan romana J. R. R. Tolkien bi hevoka «Hobîtek di kunekê de li binê erdê dijîbû» dest pê dike?', 'cevap ele veriyor: Turkce istem "hobbit", dogru sik "Hobbit"'),
  ('r15_teknoloji_B1_01', '35b67dce-6051-5771-9f1a-14646d4a572f'::uuid, 'Di nav astên cacheya L1, L2 û L3 de, kîjan ast bi gelemperî herî nêzîkî navika pêvajokarê ye?', 'cevap ele veriyor: istemde "L1", dogru sik "L1" (iki dilde)'),
  ('r15_teknoloji_B2_08', 'c9dcf170-5ba3-5ea5-9c98-a906a0b4bbc4'::uuid, 'Di nav hejmarên 2, 4, 9, 15 û 100 de, medyan (median) çend e?', 'cevap ele veriyor: istemde "9", dogru sik "9" (iki dilde)'),
  ('r15_edebiyat_B1_05', '7672f0a0-70d6-5633-bb1e-dca85606af28'::uuid, 'Kovara Hawar di kîjan salê de dest bi weşanê kir?', 'ayni metinli tekrar: edit_dirok_0001 ("Kovara Hawar di kijan sale de dest bi weshane kir?") zaten oynanabilir havuzda');

do $$
declare
  r record;
  v_uygulanan int := 0;
  v_zaten int := 0;
  v_uyusmayan int := 0;
  v_yok int := 0;
  q record;
begin
  for r in select * from _eleme loop
    select id, prompt, is_approved, review_status into q from questions where id = r.id;
    if not found then
      v_yok := v_yok + 1;
    elsif q.is_approved = false and q.review_status = 'rejected' then
      v_zaten := v_zaten + 1;
    elsif q.prompt = r.prompt and q.is_approved = true and q.review_status = 'approved' then
      update questions set is_approved = false, review_status = 'rejected'
       where id = r.id and prompt = r.prompt and is_approved = true and review_status = 'approved';
      v_uygulanan := v_uygulanan + 1;
    else
      v_uyusmayan := v_uyusmayan + 1;
      raise notice 'uyusmayan, dokunulmadi: % (%)', r.local_id, r.neden;
    end if;
  end loop;
  raise notice 'eleme gocu: uygulanan=% zaten=% uyusmayan=% bulunamayan=% (toplam %)',
    v_uygulanan, v_zaten, v_uyusmayan, v_yok, (select count(*) from _eleme);
end $$;

commit;
