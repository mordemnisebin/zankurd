-- Sunucu bankasında doğru cevabın EKRANDA görünen konumunu dengeler.
--
-- ## Ölçüm (2026-08-01)
--
--     A  1960  %21.6
--     B  2401  %26.5
--     C  2099  %23.1
--     D  2615  %28.8      ← hep D'ye basan %28.8 doğru yapıyor
--
-- 9075 soru üzerinde χ² ≈ 115 (df = 3): tesadüf değil. Etki ölçülü ama
-- gerçek — sabit konum ezberlenebilir bir desendir, oyuncu konuyu değil
-- "cevap hep D" kuralını öğrenir.
--
-- Yerel bankalarda aynı ölçüm çok daha kötüydü (editorial'de A %1.8 /
-- D %46) ve `tool/rebalance_answer_positions.py` ile düzeltildi.
--
-- ## Yöntem — şıkların YERİ değişir, METNİ değişmez
--
-- `QuizQuestion.displayAnswers` şıkları soru id'sinden türeyen sabit bir
-- kaydırmayla döndürür, yani depolanan sıra ile görünen sıra farklıdır:
--
--     kaydırma s = (id metninin karakter kodları toplamı) mod 4, 0 ise 1
--     görünen    = (depolanan - s) mod 4
--
-- Her soruya `row_number() ... % 4` ile yeni bir GÖRÜNEN konum atanır —
-- bu, dağılımı tanım gereği eşitler. Sonra o görünen konumun karşılığı
-- olan DEPOLANAN indeks hesaplanır ve doğru cevabın şıkkı oradaki şıkla
-- YER DEĞİŞTİRİR.
--
-- Değişimin niçin güvenli olduğu:
--
--   * Takas iki metni birbirinin yerine koyar; hiçbir metin silinmez,
--     hiçbir yeni metin yazılmaz.
--   * `correct_option` takasın hedef harfine ayarlanır, yani DOĞRU
--     CEVABIN METNİ aynı kalır — yalnız hangi harfte durduğu değişir.
--   * Görünen konumu zaten hedefine eşit olan sorular hiç
--     güncellenmez (`where new_display <> cur_display`).
--
-- ## Kapsam
--
-- İstemcinin `answers` listesini kurarken yaptığı eleme birebir
-- tekrarlanır: boş ve '-' şıklar dört şıklı soru saymaz, doğru-yanlış
-- soruları da kaydırma görmez. Aynı elemeyi yapmazsak indeksler kayar ve
-- takas yanlış şıkkı taşır.
--
-- ## Algoritma yerel veriyle doğrulandı
--
-- Aynı algoritma, yerel bankaların dengelenmeden ÖNCEKİ hâline
-- uygulandı (2026-08-01):
--
--     bozuk girdi        [226, 308, 303, 374]   yayılım 148
--     algoritma sonrası  [303, 303, 303, 302]   yayılım   1
--     taşınan soru       1001
--     doğru cevap metni değişen   0   ← değişmez
--     şık kaybı / ikizlenme       0   ← değişmez
--
-- ## Uygulandıktan sonra
--
-- `2026-08-01_answer_position_balance_check.sql` yeniden çalıştırılır;
-- dört sayı %25'e yakın olmalı. Dosyanın sonundaki iki doğrulama sorgusu
-- da metin bütünlüğünü ölçer.

begin;

with src as (
  select
    id,
    option_a,
    option_b,
    option_c,
    option_d,
    case correct_option
      when 'A' then 0
      when 'B' then 1
      when 'C' then 2
      else 3
    end as sc,
    (
      select (case when sum(ascii(ch)) % 4 = 0 then 1
                   else sum(ascii(ch)) % 4 end)::int
      from regexp_split_to_table(id::text, '') as ch
    ) as shift
  from public.questions
  where btrim(coalesce(option_a, '')) not in ('', '-')
    and btrim(coalesce(option_b, '')) not in ('', '-')
    and btrim(coalesce(option_c, '')) not in ('', '-')
    and btrim(coalesce(option_d, '')) not in ('', '-')
    and correct_option in ('A', 'B', 'C', 'D')
    and coalesce(question_type, '') <> 'true_false'
),
planned as (
  select
    src.*,
    ((sc - shift + 4) % 4)                              as cur_display,
    ((row_number() over (order by id) - 1) % 4)::int     as new_display
  from src
),
mv as (
  select
    planned.*,
    ((new_display + shift) % 4)::int as st,
    array[option_a, option_b, option_c, option_d] as opts
  from planned
  where new_display <> cur_display
)
update public.questions q
set
  option_a = case
    when mv.sc = 0 then mv.opts[mv.st + 1]
    when mv.st = 0 then mv.opts[mv.sc + 1]
    else q.option_a
  end,
  option_b = case
    when mv.sc = 1 then mv.opts[mv.st + 1]
    when mv.st = 1 then mv.opts[mv.sc + 1]
    else q.option_b
  end,
  option_c = case
    when mv.sc = 2 then mv.opts[mv.st + 1]
    when mv.st = 2 then mv.opts[mv.sc + 1]
    else q.option_c
  end,
  option_d = case
    when mv.sc = 3 then mv.opts[mv.st + 1]
    when mv.st = 3 then mv.opts[mv.sc + 1]
    else q.option_d
  end,
  correct_option = chr(65 + mv.st)
from mv
where q.id = mv.id;

commit;

-- ============================================================
-- DOĞRULAMA 1 — dağılım (beklenen: dördü de ~%25)
-- ============================================================
-- with q as (
--   select id,
--     case correct_option when 'A' then 0 when 'B' then 1
--                         when 'C' then 2 else 3 end as stored_index,
--     (select (case when sum(ascii(ch)) % 4 = 0 then 1
--                   else sum(ascii(ch)) % 4 end)::int
--        from regexp_split_to_table(id::text, '') as ch) as shift
--   from public.questions
--   where btrim(coalesce(option_a, '')) not in ('', '-')
--     and btrim(coalesce(option_b, '')) not in ('', '-')
--     and btrim(coalesce(option_c, '')) not in ('', '-')
--     and btrim(coalesce(option_d, '')) not in ('', '-')
--     and correct_option in ('A', 'B', 'C', 'D')
--     and coalesce(question_type, '') <> 'true_false'
-- )
-- select chr(65 + ((stored_index - shift + 4) % 4)) as gorunen_konum,
--        count(*) as soru,
--        round(100.0 * count(*) / sum(count(*)) over (), 1) as yuzde
-- from q group by 1 order by 1;

-- ============================================================
-- DOĞRULAMA 2 — metin bütünlüğü (beklenen: 0 satır)
-- ============================================================
-- Takas hiçbir metni silmemeli, boşaltmamalı ya da ikizlememeli.
--
-- select id, option_a, option_b, option_c, option_d, correct_option
-- from public.questions
-- where coalesce(question_type, '') <> 'true_false'
--   and correct_option in ('A', 'B', 'C', 'D')
--   and (
--        btrim(coalesce(option_a, '')) = ''
--     or btrim(coalesce(option_b, '')) = ''
--     or btrim(coalesce(option_c, '')) = ''
--     or btrim(coalesce(option_d, '')) = ''
--     or cardinality(
--          array(select distinct unnest(
--            array[option_a, option_b, option_c, option_d]))) <> 4
--   );
