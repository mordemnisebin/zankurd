-- Doğru cevabın EKRANDA görünen konumu dengeli mi?
--
-- SALT OKUNUR, TEK sorgu.
--
-- `QuizQuestion.displayAnswers` şıkları soru id'sinden türeyen sabit bir
-- kaydırmayla döndürür; depolanan sıra ile görünen sıra farklıdır. Bu
-- sorgu aynı kaydırmayı SQL'de yeniden kurar ve görünen konumu sayar.
--
-- Yerel bankalarda ölçüm (2026-08-01) şuydu:
--
--     offline    [221, 221, 221, 221]   yayılım   0
--     editorial  [  5,  76,  70, 130]   yayılım 125
--     community  [  0,  11,  12,  23]   yayılım  23
--
-- Editoryal sorularda hep D'ye basan oyuncu %46 doğru yapıyordu. Yereller
-- `tool/rebalance_answer_positions.py` ile dengelendi (yayılım 1). Sunucu
-- bankası ayrı tutulduğu için aynı ölçüm burada da yapılmalı.
--
-- Beklenen: dört sayı birbirine yakın. Belirgin sapma varsa oyuncu konuyu
-- değil konumu öğrenir.

with q as (
  select
    id,
    case correct_option when 'A' then 0 when 'B' then 1
                        when 'C' then 2 else 3 end as stored_index,
    -- id karakter kodlarının toplamı mod 4; 0 ise 1 (istemciyle aynı).
    (select case when sum(ascii(ch)) % 4 = 0 then 1
                 else sum(ascii(ch)) % 4 end
       from regexp_split_to_table(id, '') as ch) as shift
  from public.questions
  where option_a is not null and option_b is not null
    and option_c is not null and option_d is not null
)
select
  chr(65 + ((stored_index - shift + 4) % 4)) as gorunen_konum,
  count(*) as soru,
  round(100.0 * count(*) / sum(count(*)) over (), 1) as yuzde
from q
group by 1
order by 1;
