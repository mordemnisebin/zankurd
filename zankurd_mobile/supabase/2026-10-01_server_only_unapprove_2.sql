-- 2026-10-01 (ikinci adım): yalnız sunucudaki denetlenmemiş sorulardan 43
-- tanesi daha onaydan çıkarıldı.
--
-- NİÇİN: `2026-10-01_server_only_unapprove.sql` uygulandığında üçüncü oy
-- (Grok 4.7) paketlerin bir kısmında henüz yoktu; yalnız Flash ve Muse'un
-- birlikte EMEKLİ dediği sorular alındı. Grok bitince yeniden sayıldı: en az
-- iki oyun EMEKLİ dediği 43 soru daha çıktı (önceden iki oy ayrışıyordu).
-- Ölçüt ve oylar aynı: orkestra/sunucu_denetim/sonuc/karar.json.
--
-- Sorular SİLİNMEZ: yalnız is_approved = false. Geri alma: aynı id listesiyle
-- is_approved = true.
-- Uygulama: supabase db query --linked -f supabase/2026-10-01_server_only_unapprove_2.sql

begin;

create temp table _emekli(id uuid primary key) on commit drop;
insert into _emekli(id) values
  ('7f68d39f-843f-4663-bb9f-956aea18407d'::uuid),
  ('7f8af538-4590-4b6c-91b3-63dfa9de5ef7'::uuid),
  ('80de41a4-0130-4e68-92fc-3d5d7a3d9a17'::uuid),
  ('81af48b4-7fb2-4426-8b0d-ecce23489269'::uuid),
  ('81d1f669-0aad-4a42-9561-d3b59e184d6f'::uuid),
  ('83102a3e-3310-4cf8-bc22-8accd4c91ba9'::uuid),
  ('836059a0-b2cd-47ae-a121-69b08d1c2945'::uuid),
  ('8c02838e-3fb0-4b12-bd5b-bc44fafce5d4'::uuid),
  ('91cdcd2f-b2b1-4e4e-8106-db40cc37b5d1'::uuid),
  ('9a6e2642-bcd4-4e04-8d73-bf23658e8a97'::uuid),
  ('9c04284f-3b72-4170-a19a-07ec168ed170'::uuid),
  ('a2412a23-ca26-408a-bfce-4671b032c4fb'::uuid),
  ('a2539c99-8918-4710-bc92-47f7779f6c80'::uuid),
  ('a264d693-a6ec-4bcd-8969-95e79c9ae775'::uuid),
  ('a7a57255-605f-49fb-a314-3993eff62296'::uuid),
  ('b6b0e724-4149-48e3-b8c7-06918716a6bc'::uuid),
  ('bf452303-9f04-4e1b-875f-b881ed301058'::uuid),
  ('c3ed01b9-95b4-4386-ab55-20fbb921fc65'::uuid),
  ('c40f3f6c-f263-4f7a-a07f-ce3d5583e895'::uuid),
  ('c5e77700-466f-40cd-b519-6cca34b731f3'::uuid),
  ('c9859d76-5163-4962-bbee-0d9d68a6c9ca'::uuid),
  ('cb3bff9c-f114-4e06-bfe2-2bcb8f0ee966'::uuid),
  ('cebecac2-68e5-4131-9af7-058beacb23e0'::uuid),
  ('d09253cb-f5d7-40d6-93f4-1fee1bd1fba2'::uuid),
  ('d0cbed37-464d-4e90-9b9a-d3d0d92112ca'::uuid),
  ('d41994a1-2b3c-4ae8-b8fb-dc4ce9a74835'::uuid),
  ('d4957055-2a36-4ce6-83f9-de9847d08756'::uuid),
  ('d5cc6dc3-cdb9-44c6-8ebc-b46eeb6795bc'::uuid),
  ('d858ffd2-a5d4-4efd-8c28-e1de0787c323'::uuid),
  ('d926144d-418d-44b1-a975-920f015222fc'::uuid),
  ('d9b6bbf8-0930-43fe-80b3-2314644770f7'::uuid),
  ('d9f40c9f-a1fb-404c-a786-20c41fef0984'::uuid),
  ('dc2ccfe7-746f-4977-979b-6e256d9d6db4'::uuid),
  ('dd0eadc1-87b7-44f3-8172-00c7109be96e'::uuid),
  ('de16634c-f918-4eb8-af09-d752d839f998'::uuid),
  ('e1a2c251-702e-4476-a86f-f66d4c12cbd6'::uuid),
  ('e6043c33-590a-41fd-87dc-faeadc535328'::uuid),
  ('eea6d8df-00e3-4fd3-8477-c73ffaff601e'::uuid),
  ('ef380720-67b9-48e8-bd9e-77eb5ba279c7'::uuid),
  ('f333990a-263a-4dea-b2ce-00523b1272ad'::uuid),
  ('f610f67d-cc74-4253-95a7-ab9432d24be2'::uuid),
  ('f88395e4-b205-4bb0-a332-ae09f6f60fa1'::uuid),
  ('fb00fc4f-cff2-4e17-aa80-12bb66cbf71c'::uuid);

do $$
declare
  v_listed int;
  v_known int;
begin
  select count(*) into v_listed from _emekli;
  if v_listed <> 43 then
    raise exception 'liste 43 olmalı, %', v_listed;
  end if;
  select count(*) into v_known from questions q join _emekli e on e.id = q.id;
  if v_known <> 43 then
    raise exception 'listedeki % id sunucuda yok', 43 - v_known;
  end if;
end
$$;

update questions q set is_approved = false
from _emekli e
where e.id = q.id and q.is_approved = true;

do $$
declare
  v_left int;
begin
  select count(*) into v_left
  from questions q join _emekli e on e.id = q.id
  where q.is_approved = true;
  if v_left <> 0 then
    raise exception 'emekli listesinden % soru hala onayli', v_left;
  end if;
end
$$;

commit;
