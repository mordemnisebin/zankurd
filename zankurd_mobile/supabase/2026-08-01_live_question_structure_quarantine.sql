-- 2026-08-01 live question structural quarantine
-- Non-destructive: rows remain available for editorial repair.
-- Keep the oldest active copy of an exact prompt and hide the extras.

begin;
set local role postgres;

with active_duplicates as (
  select
    id,
    row_number() over (
      partition by lower(trim(prompt))
      order by created_at nulls last, id
    ) as prompt_rank
  from public.questions
  where is_approved = true
    and review_status is distinct from 'rejected'
)
update public.questions q
set is_approved = false
from active_duplicates d
where q.id = d.id
  and d.prompt_rank > 1;

update public.questions
set is_approved = false
where is_approved = true
  and review_status is distinct from 'rejected'
  and nullif(btrim(source_url), '') is null;

commit;

-- Expected rows affected: 15 exact-prompt copies + 2 source gaps.
