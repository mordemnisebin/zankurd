-- Doğru cevabın EKRANDA görünen konumu dengeli mi?
--
-- SALT OKUNUR, TEK sorgu. Hiçbir şeyi değiştirmez.
--
-- ## Niçin "ekranda görünen"
--
-- `QuizQuestion.displayAnswers` şıkları soru id'sinden türeyen sabit bir
-- kaydırmayla döndürür; DEPOLANAN sıra ile GÖRÜNEN sıra farklıdır. Bu
-- sorgu aynı kaydırmayı SQL'de yeniden kurar:
--
--     kaydırma = (id metninin karakter kodları toplamı) mod 4
--     kaydırma = 0 ise 1                                ← istemcideki kural
--     görünen  = (depolanan - kaydırma) mod 4
--
-- `id` sütunu `uuid` tipinde, bu yüzden `id::text` ŞART — istemci de
-- UUID'nin metin hâli üzerinde çalışıyor, tireler dahil 36 karakter.
-- (İlk sürüm bu dönüşümü unutmuştu ve şu hatayı verdi:
--  `function regexp_split_to_table(uuid, unknown) does not exist`.)
--
-- Doğrulama örneği: `0f73398c-f2e2-422c-b7b7-a494fa1f6200` için karakter
-- kodları toplamı 2367, mod 4 = 3, yani kaydırma 3 olmalı.
--
-- ## Niçin ölçülüyor
--
-- Sabit konum ezberlenebilir bir desendir: oyuncu konuyu değil "cevap hep
-- D" kuralını öğrenir. Yerel bankalarda ölçüm (2026-08-01):
--
--     offline    [221, 221, 221, 221]   yayılım   0
--     editorial  [  5,  76,  70, 130]   yayılım 125
--     community  [  0,  11,  12,  23]   yayılım  23
--
-- Editoryal sorularda hep D'ye basan oyuncu %46 doğru yapıyordu. Yereller
-- `tool/rebalance_answer_positions.py` ile dengelendi (yayılım 1). Sunucu
-- bankası ayrı tutulduğu için aynı ölçüm burada da yapılmalı.
--
-- ## Beklenen
--
-- Dört sayı birbirine yakın (%25 ± birkaç puan). Belirgin sapma varsa
-- sunucu bankası da dengelenmeli.

with q as (
  select
    id,
    case correct_option
      when 'A' then 0
      when 'B' then 1
      when 'C' then 2
      else 3
    end as stored_index,
    -- `sum()` bigint döndürür, `chr()` integer ister; cast şart.
    -- (İlk sürüm bunu atlamıştı: `function chr(bigint) does not exist`.)
    (
      select (case when sum(ascii(ch)) % 4 = 0 then 1
                   else sum(ascii(ch)) % 4 end)::int
      from regexp_split_to_table(id::text, '') as ch
    ) as shift
  from public.questions
  -- İstemci boş ve '-' şıkları eliyor (`answers` listesi öyle kuruluyor).
  -- Aynı elemeyi burada da yapmazsak, dört şıkkı olmayan bir soruda
  -- indeksler kayar ve ölçüm yanlış çıkar.
  where btrim(coalesce(option_a, '')) not in ('', '-')
    and btrim(coalesce(option_b, '')) not in ('', '-')
    and btrim(coalesce(option_c, '')) not in ('', '-')
    and btrim(coalesce(option_d, '')) not in ('', '-')
    and correct_option in ('A', 'B', 'C', 'D')
    -- Doğru-yanlış soruları kaydırma uygulanmadan gösteriliyor.
    and coalesce(question_type, '') <> 'true_false'
)
select
  chr(65 + ((stored_index - shift + 4) % 4)) as gorunen_konum,
  count(*)                                   as soru,
  round(100.0 * count(*) / sum(count(*)) over (), 1) as yuzde
from q
group by 1
order by 1;
