-- ZanKurd: CSV import sonrasi soru temizligi ve kontrol
-- CSV import bittikten sonra bir kez calistir.
-- Ayni prompt varsa yeni zankurd_seed_rich_v2 satiri oncelikli kalir,
-- eski kopyalar is_approved=false yapilir.

update public.questions
set is_approved = false
where id not in (
  select distinct on (lower(trim(prompt))) id
  from public.questions
  order by
    lower(trim(prompt)),
    (source_url = 'zankurd_seed_rich_v2') desc,
    created_at desc,
    id
);

select
  count(*) filter (where source_url = 'zankurd_seed_rich_v2') as imported_v2_rows,
  count(*) filter (
    where source_url = 'zankurd_seed_rich_v2' and is_approved = true
  ) as approved_v2_rows,
  count(*) filter (
    where source_url = 'zankurd_seed_rich_v2' and question_type = 'visual'
  ) as visual_v2_rows,
  count(distinct lower(trim(prompt))) filter (
    where source_url = 'zankurd_seed_rich_v2'
  ) as unique_v2_prompts
from public.questions;
