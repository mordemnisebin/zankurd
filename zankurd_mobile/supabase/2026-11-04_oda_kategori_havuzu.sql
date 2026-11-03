-- 2026-11-04: Bilim (Paradigma) odasında hareket öğretisi sorusu çıkmasın.
--
-- NİÇİN: 2026-11-03 simülatör turunda "Bilim" kategorili özel odada
-- "Abdullah Öcalan ... -îzm" sorusu (curated_paradigma_0004) çıktı. Oda
-- havuzu DOĞRU çalışıyor: start_room_game yalnız odanın category_id /
-- category_ids kategorilerinden çeker. "Bilim" oyuncuya görünen ad;
-- iç kimlik 'Paradigma' (bkz. category_visuals.dart) ve soru gerçekten o
-- kategoride duruyordu. Asıl kusur veriydi: 2026-09-30 "tartışmalıları
-- ayıkla" göçü (contested_questions_unapprove) sunucudaki o günkü 502
-- soruyu kapattı; 2026-10-01_local_parity_sync_paradigma.sql ise yerel
-- bankadan 40 soruyu `is_approved = true` ile yeniden ekledi ve bunların
-- 8'i tek bir hareketin öğretisini doğru cevap diye sunuyor. Yerel banka
-- bu 8'i emekli listesine almamıştı; hem sunucu hem paket aynı ayıklamadan
-- geçmemişti.
--
-- NE DEĞİŞTİ: yalnız veri; fonksiyon gövdesine dokunulmaz. 8 soru
-- is_approved = false (silinmez). Yerel paketteki karşılığı
-- retired_question_ids.dart (altıncı dalganın ardından).
-- Geri alma: geri_al/2026-11-04_oda_kategori_havuzu_geri.sql.
-- Uygulama: supabase db query --linked -f supabase/2026-11-04_oda_kategori_havuzu.sql
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
set is_approved = false
from ids
where q.id = ids.id;

do $verify$
begin
  if exists (
    select 1 from public.questions q
    where q.is_approved = true
      and q.id in (
        '8c4bbd0e-34d9-5dcc-a89d-484efaa40f91'::uuid,
        '3736ddc3-402a-5cea-95a8-4a22e12bacd7'::uuid,
        'ac77fa76-0c60-57ab-93f1-9a2dbaa2160c'::uuid,
        'c78cf9a6-d577-5bbb-9e6a-76c0d297fb72'::uuid,
        'e67ab304-9e45-53d9-b7e4-48984ccb3e72'::uuid,
        '6093f353-ef60-5fe9-a160-f7c2b5b27341'::uuid,
        'd9f2629c-cdef-5f47-b594-0c2ed0cc2ffa'::uuid,
        'f6d29730-f83d-528b-87c6-ea9e11c939b9'::uuid
      )
  ) then
    raise exception 'Dogrulama hatasi: hareket ogretisi sorulari hala onayli';
  end if;
end;
$verify$;

commit;
