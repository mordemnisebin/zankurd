-- 2026-09-30: Sînema göçünün SALT OKUNUR doğrulaması.
-- Şema ya da veri değiştirmez; `2026-09-30_sinema_category_and_questions.sql`
-- uygulandıktan sonra çalıştırılır. Beklenen: kategori 1 satır ve aktif,
-- onaylı soru sayısı en az 103, correct_option yalnız A-D, doğru/yanlış
-- satırlarında option_c/d '-' ve 'Rast'/'Şaş' biçimi.

-- 1) Kategori var mı, aktif mi? (beklenen: 1 satır, name 'Sînema', is_active true)
select id, name, slug, is_active, created_at
from categories
where slug = 'sinema';

-- 2) Onaylı soru sayısı ve tür kırılımı (beklenen: toplam >= 103;
--    multiple_choice 100, true_false 3).
select question_type, count(*) as approved_questions
from questions
where category_id = (select id from categories where slug = 'sinema')
  and is_approved = true
  and review_status = 'approved'
group by question_type
union all
select 'TOPLAM', count(*)
from questions
where category_id = (select id from categories where slug = 'sinema')
  and is_approved = true
  and review_status = 'approved'
order by 1;

-- 3) correct_option dağılımı (beklenen: yalnız A, B, C, D; hiçbiri NULL).
select correct_option, count(*) as questions
from questions
where category_id = (select id from categories where slug = 'sinema')
group by correct_option
order by correct_option;

-- 4) Bozuk satır arayışı (beklenen: 0 satır).
select id, question_type, correct_option, difficulty
from questions
where category_id = (select id from categories where slug = 'sinema')
  and (
    coalesce(trim(prompt), '') = ''
    or coalesce(trim(option_a), '') = '' or coalesce(trim(option_b), '') = ''
    or coalesce(trim(option_c), '') = '' or coalesce(trim(option_d), '') = ''
    or correct_option not in ('A', 'B', 'C', 'D')
    or difficulty not between 1 and 5
    or (question_type = 'multiple_choice'
        and (option_c = '-' or option_d = '-'))
    or (question_type = 'true_false'
        and (option_a <> 'Rast' or option_b <> 'Şaş'
             or option_c <> '-' or option_d <> '-'
             or correct_option not in ('A', 'B')))
    or image_url is not null
  );

-- 5) Zorluk dağılımı (bilgi amaçlı; beklenen yaklaşık 1:16 2:29 3:30 4:19 5:9).
select difficulty, count(*) as questions
from questions
where category_id = (select id from categories where slug = 'sinema')
group by difficulty
order by difficulty;

-- 6) İstemcinin gördüğü konu listesi (aktif kategoriler; 'Sînema' içermeli).
select name from categories where is_active = true order by name;
