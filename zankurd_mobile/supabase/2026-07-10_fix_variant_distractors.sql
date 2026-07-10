-- 2026-07-10: Case-varyant / çöp çeldirici düzeltmesi (30 soru)
-- Sorun: bir çeldirici, başka bir şıkkın büyük/küçük harf kopyasıydı
-- ("ben" vs "Ben"); 2 soruda ayrıca "-a" çöp çeldiricisi vardı.
-- Kural: doğru cevaba ASLA dokunulmaz; yalnızca varyant/çöp çeldirici,
-- satır içinde çakışmayan yeni bir kelimeyle değiştirilir.
-- Uygulama: Supabase Studio SQL Editor'da bu dosyayı çalıştır.

update questions set option_a='Ekmek' where id='1960afc6-27a3-4cb1-af94-08bc19ba49a6';
update questions set option_b='Defter' where id='c92d8048-622b-47d6-b2e0-76525f0c1226';
update questions set option_c='Ekmek' where id='2d07dc2b-10d0-454a-9352-5f903495986e';
update questions set option_c='Gitmek' where id='099f2de2-a0de-450e-a841-af407de0487c';
update questions set option_a='Destan' where id='0940f351-0863-476f-8597-560d2cd8189b';
update questions set option_d='Destan' where id='a86ba158-c5a8-418b-9cf9-2c70661793c2';
update questions set option_d='Roman' where id='5529eb88-38a2-4ac7-ac8c-8550a77defcc';
update questions set option_c='Destan' where id='0acb37f9-1fe0-4c29-b3cd-69b2f0ee2be8';
update questions set option_b='Destan' where id='2953d5d7-7cee-46b5-876e-5cf87803bb26';
update questions set option_d='Roman' where id='ee88ff9c-3594-4c8a-b388-c69172f9bcf4';
update questions set option_c='Meydan' where id='becf1db7-c861-4a3b-9abc-a99f51e3a23a';
update questions set option_c='Deniz' where id='ebb32f84-80d0-41c4-aad2-2d67b9bda1c0';
update questions set option_d='Toprak' where id='e5286205-4586-409d-9e8e-99be8638515d';
update questions set option_d='Kaya' where id='04603370-98e6-40f6-86ab-fca6dccc060a';
update questions set option_d='Orman' where id='d2d61e39-0637-4568-9260-516d4ee50c39';
update questions set option_b='bajar' where id='8aa26f22-54c3-482b-81d8-4aaf03295d3a';
update questions set option_c='Gitmek' where id='076d6376-75e0-487a-a2e1-8a90fe865fed';
update questions set option_d='yol' where id='51eeb791-cfd4-40ff-b0c9-a10468377cc3';
update questions set option_a='Amca' where id='71054e34-912f-443c-8658-a1b5f84308cf';
update questions set option_d='Uyumak' where id='2a49caef-bc88-433f-a6ba-4f3d8a859575';
update questions set option_c='Bulut', option_b='Toprak' where id='88295905-7b2b-4e60-82e8-7a5bb77d25f4';
update questions set option_b='Dede' where id='1595e62e-d777-4835-bd95-5b4455d6848d';
update questions set option_c='Amca' where id='e47f4e78-d413-47d2-8f3b-a6f945b04f92';
update questions set option_d='roj' where id='31cb4364-425c-454e-9f70-6ca818408d9a';
update questions set option_c='kulak' where id='f1f68af6-42a3-4b1c-952e-64ac928ef267';
update questions set option_c='Sandalye' where id='bf2b907d-1340-474a-8666-0e4d218b999d';
update questions set option_b='Fare' where id='7ee92581-532a-4ad3-b92f-42faa2caee93';
update questions set option_d='Sabah' where id='4cc49390-695c-475f-8001-5ee7b9f184b2';
update questions set option_c='Deve', option_d='Koyun' where id='869351a3-1f01-48d4-af2f-705a3fba548a';
update questions set option_c='sabah' where id='6a666a67-d6d9-4740-af7b-3e2d0d92e198';

-- Doğrulama (0 dönmeli):
-- select count(*) from questions where option_c <> '-'
--   and (lower(option_a)=lower(option_b) or lower(option_a)=lower(option_c)
--     or lower(option_a)=lower(option_d) or lower(option_b)=lower(option_c)
--     or lower(option_b)=lower(option_d) or lower(option_c)=lower(option_d));
