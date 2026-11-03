-- Geri alma: 2026-11-04_oda_kategori_havuzu.sql
-- Sekiz Paradigma sorusu yeniden onaylanır (silinmemişti).
begin;

with ids(id) as (values
  ('8c4bbd0e-34d9-5dcc-a89d-484efaa40f91'::uuid), -- curated_paradigma_0001
  ('3736ddc3-402a-5cea-95a8-4a22e12bacd7'::uuid), -- curated_paradigma_0002
  ('ac77fa76-0c60-57ab-93f1-9a2dbaa2160c'::uuid), -- curated_paradigma_0003
  ('c78cf9a6-d577-5bbb-9e6a-76c0d297fb72'::uuid), -- curated_paradigma_0004
  ('e67ab304-9e45-53d9-b7e4-48984ccb3e72'::uuid), -- curated_paradigma_0005
  ('6093f353-ef60-5fe9-a160-f7c2b5b27341'::uuid), -- curated_paradigma_0006
  ('d9f2629c-cdef-5f47-b594-0c2ed0cc2ffa'::uuid), -- curated_paradigma_0007
  ('f6d29730-f83d-528b-87c6-ea9e11c939b9'::uuid) -- curated_paradigma_0010
)
update public.questions q
set is_approved = true
from ids
where q.id = ids.id;

commit;
