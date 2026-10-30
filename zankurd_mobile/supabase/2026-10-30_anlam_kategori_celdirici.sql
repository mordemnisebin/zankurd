-- T7 / tur 5: sözcük anlamı doğru kategoriye; tartışmalı düşünür çeldiricisi.
-- TASLAK: canlı veritabanına bağlanılmadı, UYGULANMADI.
-- Kimlikler yerel geçmiş göçlerden, kökler tur 5 ekranlarından doğrulandı.
-- Tek tek (id, alan, eski değer) koruması; farklı canlı içerikte işlem durur.
-- İkinci çalıştırma değişiklik yapmaz. Fonksiyon/şema/doğru cevap değişmez.
-- KU: Gemini 3.8 Flash + Gemini 4 Argon ONAY; Grok 4.7 kota nedeniyle yok.
-- Geri alma: aynı korumalarla Ziman -> Paradigma, Thomas Hobbes -> Murray Bookchin.

begin;

do $t7$
declare
  v_language uuid;
  v_science uuid;
  v_word public.questions%rowtype;
  v_thinker public.questions%rowtype;
  v_options text[];
  v_correct text;
begin
  select id into strict v_language from public.categories where slug = 'ziman';
  select id into strict v_science from public.categories where slug = 'paradigma';

  select * into strict v_word from public.questions
   where id = 'f1aadc8a-c7d6-5a52-916b-8aeb903694a2' for update;
  if v_word.prompt is distinct from
     'Di vê hevokê de peyva "berxwedan" çi dide zanîn? "Berxwedana wan dom kir."'
     or v_word.category_id is null
     or v_word.category_id not in (v_science, v_language) then
    raise exception 'T7: berxwedan kimlik/kök/kategori beklenenden farklı';
  end if;

  select * into strict v_thinker from public.questions
   where id = '1ddad401-4ea2-4d31-94ac-0d81549d2bdf' for update;
  v_options := array[v_thinker.option_a, v_thinker.option_b,
                     v_thinker.option_c, v_thinker.option_d];
  v_correct := case v_thinker.correct_option
    when 'A' then v_thinker.option_a when 'B' then v_thinker.option_b
    when 'C' then v_thinker.option_c when 'D' then v_thinker.option_d end;
  if v_thinker.prompt is distinct from
     'Ramanerê ku feraseta konfederalîzma demokratîk pêşxist kî ye?'
     or v_correct is distinct from 'Abdullah Öcalan'
     or not (v_options @> array['Frantz Fanon', 'Antonio Gramsci', 'Abdullah Öcalan'])
     or (select count(*) from unnest(v_options) as o(value)
          where value in ('Murray Bookchin', 'Thomas Hobbes')) <> 1 then
    raise exception 'T7: düşünür kimlik/kök/şık/doğru cevap beklenenden farklı';
  end if;

  update public.questions set category_id = v_language
   where id = v_word.id and category_id = v_science
     and prompt = v_word.prompt;

  -- Sunucudaki slot sırası varsayılmaz; yalnız eski metnin bulunduğu alan.
  update public.questions
     set option_a = case when option_a = 'Murray Bookchin' then 'Thomas Hobbes' else option_a end,
         option_b = case when option_b = 'Murray Bookchin' then 'Thomas Hobbes' else option_b end,
         option_c = case when option_c = 'Murray Bookchin' then 'Thomas Hobbes' else option_c end,
         option_d = case when option_d = 'Murray Bookchin' then 'Thomas Hobbes' else option_d end
   where id = v_thinker.id and prompt = v_thinker.prompt
     and 'Murray Bookchin' in (option_a, option_b, option_c, option_d);

  -- Doğrulama: iki kayıt mevcut, hedef alanlar doğru, cevap anahtarı aynı.
  if not exists (
    select 1 from public.questions where id = v_word.id
      and category_id = v_language and prompt = v_word.prompt
      and correct_option = v_word.correct_option
  ) or not exists (
    select 1 from public.questions where id = v_thinker.id
      and prompt = v_thinker.prompt
      and correct_option = v_thinker.correct_option
      and 'Thomas Hobbes' in (option_a, option_b, option_c, option_d)
      and 'Murray Bookchin' not in (option_a, option_b, option_c, option_d)
  ) then
    raise exception 'T7: sonuç doğrulaması başarısız';
  end if;
end $t7$;

commit;
