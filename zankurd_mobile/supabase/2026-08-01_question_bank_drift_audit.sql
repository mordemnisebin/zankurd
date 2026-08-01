-- Sunucu soru bankasının yerel bankalardan ayrılan yerlerini bulur.
--
-- SALT OKUNUR. Hiçbir şeyi değiştirmez; yalnız rapor döndürür.
--
-- ## Niçin gerekli
--
-- Yerel bankalar (`assets/data/*.json`, 1787 soru) `QuestionLanguagePolicy`
-- ile denetleniyor ve 2026-08-01 itibarıyla tamamen temiz: dili uyumsuz
-- çeldirici yok, doğru cevabı dil ele veren soru yok.
--
-- Ama oda maçları soruları SUNUCUDAN alıyor ve sunucu bankası yerelden
-- ayrışmış. Canlı bir maçta şu çıktı:
--
--   Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
--     A) Öğrenmek   B) Öğretmen   C) Sandalye ✓   D) Dibistan
--
-- Üç Türkçe şıkkın yanında bir Kurmancî çeldirici. Dil farkı bilgi
-- gerektirmeyen bir ipucudur: soru "bi Tirkî çi ye?" diyorsa Kurmancî
-- görünen şık bakar bakmaz elenir. Bu soru yerel bankaların HİÇBİRİNDE
-- yok, yani kusur yalnız canlıda duruyor ve yerel denetimler onu
-- göremiyor.
--
-- ## Ne yapıyor
--
-- 1. Sunucu ve yerel banka büyüklüklerini yan yana koyar (ayrışmanın
--    ölçüsü).
-- 2. "Türkçesi nedir" diye sorup şıklarında Kurmancî'ye özgü harf taşıyan
--    (î ê û) ya da tersini yapan soruları listeler.
-- 3. Aynı kelime çiftini iki yönde soran soruları eşleştirir — biri
--    diğerinin cevabını veriyor.
--
-- Harf temelli tarama kaba: `Dibistan` gibi özel harfsiz kelimeleri
-- kaçırır. Bu yüzden 4. sorgu, incelenmesi gereken TÜM çeviri sorularını
-- döker; çıktı yerel politika ile aynı sınıflandırıcıdan geçirilebilir.

-- ============================================================
-- 1. Ayrışmanın ölçüsü
-- ============================================================
select
  (select count(*) from public.questions) as sunucu_soru,
  (select count(*) from public.questions
    where prompt ilike '%bi Tirkî%' or prompt ilike '%bi Kurmancî%')
    as ceviri_sorusu,
  1787 as yerel_soru_2026_08_01;

-- ============================================================
-- 2. "Türkçesi nedir?" diye sorup Kurmancî şık taşıyanlar
-- ============================================================
-- Soru Türkçe cevap istiyorsa hiçbir şık Kurmancî'ye özgü harf
-- taşımamalı. Taşıyorsa o şık bilgisiz elenir.
select q.id, q.prompt, o.secenek
from public.questions q
cross join lateral (
  values (q.option_a), (q.option_b), (q.option_c), (q.option_d)
) as o(secenek)
where q.prompt ilike '%bi Tirkî%'
  and o.secenek ~ '[îêû]'
order by q.id;

-- ============================================================
-- 3. "Kurmancîsi nedir?" diye sorup Türkçe şık taşıyanlar (ayna kusur)
-- ============================================================
select q.id, q.prompt, o.secenek
from public.questions q
cross join lateral (
  values (q.option_a), (q.option_b), (q.option_c), (q.option_d)
) as o(secenek)
where q.prompt ilike '%bi Kurmancî%'
  and o.secenek ~ '[ğıİ]'
order by q.id;

-- ============================================================
-- 4. Aynı kelime çiftini iki yönde soranlar
-- ============================================================
-- «X» → Y soran bir soru ile «Y» → X soran başka bir soru aynı turda
-- çıkarsa ikincisi bedava puandır. Yerel seçim bunu 2026-08-01'de
-- kapattı (`SeenQuestionStore._dedupeByTranslationPair`); sunucu
-- tarafında aynı korumanın olup olmadığı bu listeyle görülür.
with terim as (
  select
    q.id,
    q.prompt,
    lower(trim((regexp_match(q.prompt, '[«""]([^«»""]{2,40})[»""]'))[1]))
      as sorulan,
    lower(trim(
      case q.correct_option
        when 'A' then q.option_a
        when 'B' then q.option_b
        when 'C' then q.option_c
        else q.option_d
      end
    )) as cevap
  from public.questions q
)
select
  least(a.sorulan, a.cevap) || ' / ' || greatest(a.sorulan, a.cevap) as cift,
  count(*) as soru_sayisi,
  array_agg(a.id order by a.id) as sorular
from terim a
where a.sorulan is not null
  and a.cevap is not null
  and a.sorulan <> a.cevap
group by 1
having count(*) > 1
order by count(*) desc, 1;

-- ============================================================
-- 5. Yerel politikayla denetlenmek üzere çeviri sorularını dök
-- ============================================================
-- Harf taraması özel harfsiz kelimeleri kaçırır (`Dibistan` gibi).
-- Bu çıktı, yereldeki `QuestionLanguagePolicy` ile aynı sınıflandırıcıdan
-- geçirilebilecek biçimdedir.
select json_agg(
  json_build_object(
    'id', q.id,
    'prompt', q.prompt,
    'answers', json_build_array(
      q.option_a, q.option_b, q.option_c, q.option_d
    ),
    'correctAnswer', case q.correct_option
      when 'A' then q.option_a
      when 'B' then q.option_b
      when 'C' then q.option_c
      else q.option_d
    end
  )
) as sorular_json
from public.questions q
where q.prompt ilike '%bi Tirkî%' or q.prompt ilike '%bi Kurmancî%';
