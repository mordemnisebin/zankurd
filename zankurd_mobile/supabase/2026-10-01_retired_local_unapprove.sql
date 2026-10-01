-- 2026-10-01: yerelde EMEKLİ/oynanamaz olup sunucuda hâlâ onaylı duran 28 bilinen-kötü soru onaydan çıkarıldı.
--
-- NİÇİN: yerel banka denetlenir ve kusurlu sorular `retired_question_ids.dart`
-- ile emekliye ayrılır (şablon tanım takası, tür ipucu sızan şıklar, kopya
-- şık, Kürt bağı olmayan genel kültür…) ya da `reviewStatus` ile elenir.
-- Ama oda ve düello sunucudan oynar ve bu kayıtlar sunucuya HİÇ yansımamıştı:
-- yerelde atılan soru odada sorulmaya devam ediyordu. Eşleşme: sunucudaki
-- ONAYLI satırın soru metni + doğru cevabı, oynanamaz bir yerel sorununkiyle
-- eşit (ya da kimliği o yerel sorunun uuid5'i). Bankanın aynı içeriği başka
-- bir kimlikle OYNANABİLİR tuttuğu ve oynanabilir bir yerel sorunun sunucu
-- karşılığı olan satırlar çıkarılmaz.
--
-- KAÇ SORU: 28 satır. Sunucu kategorisine göre:
--   - Sînema: 2
--   - Ziman: 26
-- Yerel elenme nedeni / eşleşme yolu:
--   - retired / eşleşme metin: 26
--   - retired / eşleşme uuid: 2
--
-- Sorular SİLİNMEZ: yalnız is_approved = false (review_status değişmez).
-- Her satırın yanındaki `-- yerel:` yorumu, eşleştiği yerel kimliği gösterir.
--
-- TEKRAR ÇALIŞTIRILABİLİR: zaten onaysız olan satır tekrar onaysız yapılır
-- (değişiklik yok). Doğrulama: listedeki hiçbir satır onaylı kalmamalı ve
-- kategori dağılımı yukarıdakiyle aynı olmalı; tutmazsa tümü geri alınır.
--
-- GERİ ALMA: aynı id listesiyle `update questions set is_approved = true
--   where id in (…)` (çıkarılan kümenin tamamı bu dosyadaki listedir).
--
-- Üretici: tool/sync_local_parity_to_server.py (YEREL_OYNANABILIR: 2579)
-- Uygulama: supabase db query --linked -f supabase/2026-10-01_retired_local_unapprove.sql

begin;

create temp table _canli_emekli(id uuid primary key, category text) on commit drop;
insert into _canli_emekli(id, category) values
  ('b3939387-6fd8-5f6a-9e41-71094a029813'::uuid, 'Sînema'), -- yerel: sf_cin_0054 (retired, uuid)
  ('cd62988d-feed-5fd3-a9a4-a25c1597287f'::uuid, 'Sînema'), -- yerel: edit_sinema_0026 (retired, uuid)
  ('06d9eb7c-cb8b-4f6a-9180-235438b80ba5'::uuid, 'Ziman'), -- yerel: offline_5499 (retired, metin)
  ('11f467d5-4ea7-4fff-8c41-edc441111b1f'::uuid, 'Ziman'), -- yerel: offline_5632 (retired, metin)
  ('1245ee73-5411-41f7-ba9d-2c19471362af'::uuid, 'Ziman'), -- yerel: offline_5099 (retired, metin)
  ('1dbde924-c926-4463-9321-1024d8f82242'::uuid, 'Ziman'), -- yerel: offline_5848 (retired, metin)
  ('680feb70-4faf-4914-8afa-aebe0652760a'::uuid, 'Ziman'), -- yerel: offline_5307 (retired, metin)
  ('7f369099-1d24-4cce-b99d-37b24f7ea18b'::uuid, 'Ziman'), -- yerel: offline_5035 (retired, metin)
  ('8009980a-15a8-4a31-b6b3-1d48e2372173'::uuid, 'Ziman'), -- yerel: offline_5834 (retired, metin)
  ('8183812f-93d0-4eea-9da9-ddda2d820907'::uuid, 'Ziman'), -- yerel: offline_5158 (retired, metin)
  ('87506d5a-fd20-4684-9d82-3de235617807'::uuid, 'Ziman'), -- yerel: offline_5593 (retired, metin)
  ('928afa0e-766b-45d5-95c9-74e45fa33805'::uuid, 'Ziman'), -- yerel: offline_5204 (retired, metin)
  ('94206226-1f97-4ec5-af17-19c850d73e60'::uuid, 'Ziman'), -- yerel: offline_5733 (retired, metin)
  ('94479a16-7437-4681-af09-ad3fd9383925'::uuid, 'Ziman'), -- yerel: offline_5364 (retired, metin)
  ('a9abd7e0-6de5-4c82-912a-6782badd0d67'::uuid, 'Ziman'), -- yerel: offline_5208 (retired, metin)
  ('ab058363-79c3-4654-a996-d7897d378339'::uuid, 'Ziman'), -- yerel: offline_5631 (retired, metin)
  ('ac1a65c2-9e54-4a59-901c-bc5e9ae5d3bc'::uuid, 'Ziman'), -- yerel: offline_5675 (retired, metin)
  ('ac869636-8b35-4636-9167-74b4ef076054'::uuid, 'Ziman'), -- yerel: offline_5676 (retired, metin)
  ('ac88b5c0-cb38-42a2-a782-3d6db469292e'::uuid, 'Ziman'), -- yerel: offline_5941 (retired, metin)
  ('c44339f6-0c04-461a-919a-7648a6b0dac9'::uuid, 'Ziman'), -- yerel: offline_5174 (retired, metin)
  ('c6dfd490-92f1-40bf-92bb-ebce337a5a6e'::uuid, 'Ziman'), -- yerel: offline_5722 (retired, metin)
  ('cba23e51-8f23-41b4-8d9d-1c6345d59f01'::uuid, 'Ziman'), -- yerel: offline_5433 (retired, metin)
  ('ceaf661f-29ea-4a8d-a22e-e0091c39bf29'::uuid, 'Ziman'), -- yerel: offline_0014 (retired, metin)
  ('da7b8a84-6e08-4f55-a1a1-06e5181beb11'::uuid, 'Ziman'), -- yerel: offline_5039 (retired, metin)
  ('ddd7bec4-522c-49cb-8176-96c4b315a3f3'::uuid, 'Ziman'), -- yerel: offline_5475 (retired, metin)
  ('ea75aa74-116d-4e54-a222-9000edfbdc8c'::uuid, 'Ziman'), -- yerel: offline_5314 (retired, metin)
  ('f6bb9c14-bca6-46d2-b785-98b31ae02963'::uuid, 'Ziman'), -- yerel: offline_5168 (retired, metin)
  ('f94fe8b1-209c-42f1-a244-35044c50b019'::uuid, 'Ziman'); -- yerel: offline_5591 (retired, metin)

do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id;
  if v_count <> 28 then
    raise exception 'listedeki % id''den yalnız % sunucuda', 28, v_count;
  end if;
end
$$;

update questions q set is_approved = false
from _canli_emekli e
where e.id = q.id and q.is_approved = true;

do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id
  where q.is_approved = true;
  if v_count <> 0 then
    raise exception 'emekli listesinden % soru hala onayli', v_count;
  end if;

  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id
  where q.category_id = (select id from categories where name = 'Sînema');
  if v_count <> 2 then
    raise exception 'Sînema: listede beklenen 2 satir, bulunan %', v_count;
  end if;
  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id
  where q.category_id = (select id from categories where name = 'Ziman');
  if v_count <> 26 then
    raise exception 'Ziman: listede beklenen 26 satir, bulunan %', v_count;
  end if;
end
$$;

commit;
