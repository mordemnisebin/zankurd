-- 2026-10-02: canlı sunucudaki onaylı sorulardan 237 yinelenen satır onaydan çıkarıldı.
--
-- NİÇİN: yerel–sunucu eşitlemesi (2026-10-01) yerel denetlenmiş soruları
-- uuid5 kimlikle ekledi; eski sunucu satırlarının bir kısmı aynı soruyu başka
-- bir kalıpla zaten taşıyordu ("Peyva "pirtûk" bi Tirkî çi ye?" ile "Wateya
-- Tirkî ya peyva "pirtûk" kîjan e?" gibi). Oda soruları rastgele seçildiği
-- ve sunucuda çeviri çifti tekilleştirmesi olmadığı için oyuncu aynı soruyu
-- bir odada iki kez görebiliyordu (Ziman'da en çok).
--
-- Yöntem: kategori içinde normalize metin eşitliği, aynı doğru cevap +
-- yüksek sözcük örtüşmesi ve aynı tırnaklı terim + aynı cevap kümeleri
-- (172 küme). Her kümede bir satır korunur (önce uuid5/yerel denetimli,
-- sonra review_status=approved); ötekiler burada. Aynı soruyu farklı cevap
-- metniyle taşıyan 13 küme ana ajanın gözünden geçti (ör. "Nûbihara Biçûkan"
-- için doğru tanım olan "kurdî-erebî ferhenga helbestî" korundu).
-- Kayıt: scratchpad/denge/dup_candidates.json (bu oturumun denetimi).
--
-- Sorular SİLİNMEZ: yalnız is_approved = false. Geri alma: aynı id listesiyle
-- is_approved = true.
-- Uygulama: supabase db query --linked -f supabase/2026-10-02_server_duplicates_unapprove.sql

begin;

create temp table _emekli(id uuid primary key) on commit drop;
insert into _emekli(id) values
  ('009cca2c-d8e6-40e2-8ddf-fce65e7c14ef'::uuid),
  ('00be1132-62e6-4b27-a883-f9e03cd9db60'::uuid),
  ('027fb397-97c3-4a53-ab82-9a0677d9fa09'::uuid),
  ('036ca12e-3b32-4634-9fb4-db6b97baaf46'::uuid),
  ('0379c63b-59c6-466f-adae-5d3e4fda1297'::uuid),
  ('03c6b627-49ec-495b-a49f-14efffd2de86'::uuid),
  ('05088ba8-eaf5-4a07-a1e0-52ca91b048e0'::uuid),
  ('05a7389a-5c6e-401c-87c6-d0cdf55f8df7'::uuid),
  ('05b274cd-3346-420d-9e9f-e94602a0a854'::uuid),
  ('0905640a-2f54-4a39-9203-676b51830805'::uuid),
  ('098be855-3175-4262-a9bc-35ddd32ca3d9'::uuid),
  ('0996a060-4f60-4df8-bb02-386dabc7dec3'::uuid),
  ('0c8c5156-9402-5d93-9138-7f598408b936'::uuid),
  ('0db7425d-48fe-467a-9345-6d777c762809'::uuid),
  ('0e90b0c0-0691-4f7e-9cf0-148586bbf348'::uuid),
  ('0eb324b7-2ab6-40e5-a675-cdcc0f2f4c4c'::uuid),
  ('112a64c5-d8a2-4663-b646-d4bb76cb75ab'::uuid),
  ('11cee6ed-b83c-4058-979f-b478f63a63f3'::uuid),
  ('12b43963-482c-4207-ac9b-2970574ff51f'::uuid),
  ('12cd4547-3b25-4ab2-91fa-8b31f50b12db'::uuid),
  ('131cfea9-6eb9-4d2e-958c-2561df0f797f'::uuid),
  ('13b6e323-06c5-4ff0-8c26-e6fa27481949'::uuid),
  ('144b2bee-d5c6-4243-bb0b-068bfcab590c'::uuid),
  ('15fe0ade-e6ab-474f-8112-9194d3ec6358'::uuid),
  ('16e01f2e-05b4-4d7b-819f-ef0764510dd9'::uuid),
  ('172103e4-24e6-42e4-baae-186ba2700e64'::uuid),
  ('187bdcea-c0e3-4b38-8594-96dc8cc187fc'::uuid),
  ('194850c6-49be-4fc1-a338-39eb4277fc6a'::uuid),
  ('195d7069-ebd8-47b0-85dc-2c198cb66ab0'::uuid),
  ('1a16762e-4a39-48cb-b611-66583813b30d'::uuid),
  ('1ada6483-488c-4ebd-b5a4-cf94b3d3b577'::uuid),
  ('1be0af38-519c-4cd8-9bff-4b9b34db5e83'::uuid),
  ('1e3c44c2-6e40-40a5-abe2-bac3bf38fc34'::uuid),
  ('205f518d-ea71-41dd-a319-5e88b9f8e570'::uuid),
  ('20cef2c6-59ef-4cb4-ae32-c9b0f63f8299'::uuid),
  ('2166cbf7-6d85-427e-ad2a-22693da43b03'::uuid),
  ('21b795ec-c97a-4e1a-b780-028dead37ad0'::uuid),
  ('2226270d-607d-4396-9ec5-380143fe63d6'::uuid),
  ('236e7770-36b9-4a6f-b9bb-75fcdedf1529'::uuid),
  ('245f91df-7967-4f85-a3cc-cee938eb2e22'::uuid),
  ('24697a21-c36f-42f1-bd2e-b67ce4c5908c'::uuid),
  ('267b7097-c6a1-44af-82ca-f6067c9fd665'::uuid),
  ('26bd6c80-f680-450c-9c64-2417069ebbf7'::uuid),
  ('27b70417-c167-4ebd-aaaa-9fd95eb1c78e'::uuid),
  ('2a49caef-bc88-433f-a6ba-4f3d8a859575'::uuid),
  ('2a75dc26-a0f7-427e-b7b7-61d6c098586d'::uuid),
  ('2bc5bc29-0064-4063-a6f0-844f70caf8d0'::uuid),
  ('2e0660fc-7312-46c1-ab0c-3b22e16f4c48'::uuid),
  ('2ed3fe61-1f92-490d-a93d-fff99c8f516d'::uuid),
  ('2fab431f-4fef-4cf9-be5d-8e4d2325457c'::uuid),
  ('3032b998-65c3-4e68-ab4f-547d67688420'::uuid),
  ('319dc093-a25d-4862-8f47-d2b62e6d74f9'::uuid),
  ('31b37951-5dbf-4a47-85e1-45d5513e5a03'::uuid),
  ('326672a0-95ff-42bb-a03f-f6c2de176a5a'::uuid),
  ('334961ca-e81c-4aad-9c56-fdcdab3cb7b3'::uuid),
  ('34d2e77d-42d0-4863-9247-f962490c41f0'::uuid),
  ('35501218-3f4c-4875-a056-68646377f8d0'::uuid),
  ('3564c5c7-a983-497b-9557-e198107ee901'::uuid),
  ('3595a796-44b0-43a9-bd92-6b2c42bb4239'::uuid),
  ('3693edc9-a7cb-48fe-86ac-8ede0db9645b'::uuid),
  ('371a0948-f8c1-419d-8d25-18bd856533f1'::uuid),
  ('37724fae-9846-4a54-acc6-ad1882d15c15'::uuid),
  ('38ba5837-7085-4905-a35e-26b25a457cc7'::uuid),
  ('393ab3c6-0c79-412d-a2a8-d2e6764158a9'::uuid),
  ('3a86363b-9715-4d4f-ad3b-a7ea4054d931'::uuid),
  ('3b904ac6-c65c-47c9-9a45-8a678759fa61'::uuid),
  ('3bd3efb1-a64f-4ede-8e99-e3bd5c1faef4'::uuid),
  ('3c8c7306-0e75-42c9-a8e2-83c6b3501d4b'::uuid),
  ('3d05bc28-53dd-4c57-9946-caddd69ca3df'::uuid),
  ('3d29e580-9e55-56fc-b738-071562af70cf'::uuid),
  ('4047934c-fdd6-4223-81ba-123727c782a3'::uuid),
  ('40b9cb58-abad-4422-a544-aa16f9ac32b5'::uuid),
  ('41bbcfff-ce12-4f4c-8de9-c2a08501e313'::uuid),
  ('41ee5c3b-0e43-4ce0-afba-78e2ff0705ef'::uuid),
  ('4201427b-e063-44b9-9db6-41f6f3d96df9'::uuid),
  ('42796724-6a67-4b83-be3b-9a125156b3f2'::uuid),
  ('44f9df2f-5bb8-455c-ad6e-f2910d1bde02'::uuid),
  ('45064d61-df58-4aea-8327-9d464dcec763'::uuid),
  ('46fa37b7-bd4c-4960-9133-b19dbc1d92c4'::uuid),
  ('47978831-ce21-4f4a-8316-9a586f9a4b78'::uuid),
  ('47ba24ea-1619-44b3-9b39-7174b9add727'::uuid),
  ('48854ace-3b50-4bb6-b47d-be95df79add5'::uuid),
  ('491f7aab-a854-4239-b345-53d1268ef653'::uuid),
  ('494ea656-e79f-4ce8-ae3e-46ccf8095cbe'::uuid),
  ('4a0b7b89-a507-4284-9e2c-736cd358623b'::uuid),
  ('4a4fed94-a6c0-461b-bf9e-cae14ad3f05e'::uuid),
  ('4a5315ea-60c5-4add-95b5-c6864931e649'::uuid),
  ('4b769325-9e02-4e74-b1ab-b9f1891fb5cc'::uuid),
  ('4b7932bc-372b-4ee7-a159-613c669fa339'::uuid),
  ('4bb7d253-c758-448d-aa02-dcb85836356f'::uuid),
  ('4e61e25f-888e-4ade-b59a-22d11567a3bf'::uuid),
  ('5224873a-09e3-4759-9c11-81c63025d725'::uuid),
  ('52f5aba0-3701-454c-a3eb-1e05b26cbff6'::uuid),
  ('53b37b26-ebde-487f-9159-ae8355106578'::uuid),
  ('5414da36-cf9d-4b7f-9345-faf2e01ba2a8'::uuid),
  ('547fbbf6-2926-4b8a-9e76-6aa14cb31f1e'::uuid),
  ('548995d1-81bb-49ac-8233-511c2daa8ec5'::uuid),
  ('55dc1ff1-bcb2-4b9c-b905-d5d8acc2178f'::uuid),
  ('56e70621-385a-4626-80a7-c19e67a74a1a'::uuid),
  ('5766bacf-ee43-43c0-b0d1-897a28d6949f'::uuid),
  ('57a05712-54f2-45fc-b91c-56d1b0080041'::uuid),
  ('5ad1300d-9eba-4091-ae7f-f4131eb9eb93'::uuid),
  ('5ae2e34e-67e5-42a3-b31f-0a3eecd01978'::uuid),
  ('5aea1768-ff8b-4c8f-9ad5-3218356785da'::uuid),
  ('5c6fba8d-0b4b-4190-8ecb-697ab0c44b50'::uuid),
  ('5f5f1dbc-1c5a-4b9d-9518-689c78e336eb'::uuid),
  ('5fb694f7-7d93-41bb-a759-eafb14f94fbd'::uuid),
  ('600ae9bc-05d7-4eab-8b4a-e819e45a2495'::uuid),
  ('61bbd143-1cfc-4834-8beb-ac23e548aa92'::uuid),
  ('6260a228-cb56-4646-867b-172a9e54577f'::uuid),
  ('62816527-f0b1-5b7a-8c74-f1953d7ca558'::uuid),
  ('638b38de-6493-4981-a3b9-32fea1738d52'::uuid),
  ('63b99d58-6509-4158-be1a-5452e4ef8f9c'::uuid),
  ('640c807c-421f-4c67-9f72-a77405df6a42'::uuid),
  ('64aa54d5-093d-4fad-8c06-82a623b9f364'::uuid),
  ('64dbfe63-b56f-4579-a2d8-85d85be4f228'::uuid),
  ('65a9202e-8c6c-4e16-b559-790fc3cc46d7'::uuid),
  ('67a2cd90-215a-4928-b8fe-d9deef69b43e'::uuid),
  ('68519782-fe8a-4f24-980c-237fe65d860e'::uuid),
  ('688ef2cf-4e82-4990-bfeb-789cf49ddfef'::uuid),
  ('69818f6a-67b3-4ece-8a7a-7f7663a38061'::uuid),
  ('6b6a98a7-8ea6-4e05-af56-abff6fbfbe88'::uuid),
  ('6d9d3d82-d2f2-4769-90dd-4001fdd47c94'::uuid),
  ('6ee77d01-6d6e-4d48-a6a6-a3302f43697d'::uuid),
  ('6f811590-f94a-40ab-8a51-2a6caec30582'::uuid),
  ('6fcbaf94-863b-4ab2-8202-e8e9cfdb1645'::uuid),
  ('71054e34-912f-443c-8658-a1b5f84308cf'::uuid),
  ('7578635b-4eaf-43a1-8cdd-0c4ec16b922a'::uuid),
  ('7611a4bc-00f5-43a2-a06d-89b18e8e5e35'::uuid),
  ('76831387-b094-4121-8b41-7f100c4bc26a'::uuid),
  ('78395625-ce3c-44f5-9097-5a82c338825e'::uuid),
  ('7a4b1018-b593-4b89-b1c9-9f029ac267fd'::uuid),
  ('7a9d659a-16ed-417d-9b27-7ed6b6e5810e'::uuid),
  ('7ae8cdd8-c938-4749-bae5-1f218c02af77'::uuid),
  ('7b2ae683-38fa-48c5-a56d-26bb256ba4c1'::uuid),
  ('7da8b2f9-c1e1-4381-a6dd-9ca7baad8543'::uuid),
  ('7ec9e2b0-7762-4de5-bba9-8632ac9b0870'::uuid),
  ('7ee92581-532a-4ad3-b92f-42faa2caee93'::uuid),
  ('7fcdee75-9c1b-4438-b21e-f81bda5f1b7c'::uuid),
  ('809e78be-523e-4ce9-96b2-87d3e576013b'::uuid),
  ('81a7d09f-8c4f-46f9-bf45-debedb6cade8'::uuid),
  ('81e81c4d-c55c-4987-9b1e-a38ed93827e4'::uuid),
  ('827d736e-c8ca-47bd-a059-4a1d9af8bda6'::uuid),
  ('83b04a1a-cca7-4574-9c09-db5f2dd518d0'::uuid),
  ('848da3d8-18d9-48fe-a982-d0058b0722d9'::uuid),
  ('84b81da4-64a1-4453-8d75-6e6130e605b4'::uuid),
  ('855c5e93-1311-460b-a74a-22a4b1080b8a'::uuid),
  ('85d08788-427d-42f4-9f24-9e4f22c9e927'::uuid),
  ('8654d399-0806-4384-af35-6e150db4eccf'::uuid),
  ('87cc6939-6331-41b6-b1ac-8088d92f0138'::uuid),
  ('89a9465a-3be1-434f-a0cd-d5db0477abdd'::uuid),
  ('8b519afa-5e46-473f-a5f4-84cab54ae756'::uuid),
  ('8c131d5d-d56e-4135-80de-a9159fa54086'::uuid),
  ('8c235ec1-bd0b-47fa-8400-37860fc8bc98'::uuid),
  ('8e4862df-e06b-47fb-80c6-263bef4fc1c1'::uuid),
  ('8e518bd7-b150-453c-8a1b-aa704a47bd9e'::uuid),
  ('8f7ab9e0-e968-48c1-84ce-1ba716af77a2'::uuid),
  ('918c2a97-99d8-4062-8e95-2d448d406751'::uuid),
  ('91d51b14-5a11-4b7f-8b4e-67c0b0596a9f'::uuid),
  ('94dd8f5e-7bde-42fd-bb0e-e057bd572e11'::uuid),
  ('95189d7f-1db3-44c8-9781-aab22a929c51'::uuid),
  ('95a2e552-b902-42b0-9aa1-1a955d5d398e'::uuid),
  ('9831af25-4cc7-4745-8af6-010066f3366c'::uuid),
  ('9a3e735e-f823-4934-bc66-798686067ac1'::uuid),
  ('9d681213-a56d-48cb-b4de-270363503982'::uuid),
  ('9da1c229-d79c-4a7f-8798-c874770d80be'::uuid),
  ('9f41d3e1-d80f-4417-a9ba-808df31043f6'::uuid),
  ('a09c603c-97ad-4223-b276-236fce3dd18d'::uuid),
  ('a39aeabe-9c44-465d-bd40-94a6c3f5dcd9'::uuid),
  ('a4507082-6405-492f-96c1-f4b0f0dbe788'::uuid),
  ('a5f6b694-0e03-4e8b-a644-4930a95ff9e6'::uuid),
  ('a81ff655-9237-4a01-8cb0-a7fd35de75e4'::uuid),
  ('a90ab94e-2d69-4582-a6dd-0a463c6f1b6d'::uuid),
  ('aa96a730-b2d8-4d98-9c23-56303e41a8b1'::uuid),
  ('ac251ddd-5f4a-4446-acf9-27a88b66a485'::uuid),
  ('acdd0b0a-2567-48d8-bf87-5aec1f513543'::uuid),
  ('af5736a9-24e7-4a7f-a58d-4e31f6dc0f42'::uuid),
  ('af633f6d-5a0b-4a20-a026-4d91981102fc'::uuid),
  ('b29b768e-c690-4de3-9927-947d4b5e337c'::uuid),
  ('b36261d9-f8f7-40a5-80a5-34d13d7e7d06'::uuid),
  ('b4a2c354-0498-4195-838d-26bac5b7cc95'::uuid),
  ('b57501de-a0a7-4577-97d7-f416b8e91fc9'::uuid),
  ('b59151bc-d964-458b-ae10-6e23e74eec4d'::uuid),
  ('b5d201ea-58d8-472b-9eca-cb465ef37391'::uuid),
  ('b5e87997-548c-4153-82f1-8cf877ebabc3'::uuid),
  ('b6290cd2-09c8-471a-99e8-b05219d10e9f'::uuid),
  ('b818cad6-982a-430a-bdd2-a2b67c9dd62b'::uuid),
  ('b89355b2-edfc-4a85-8357-82bae18e5905'::uuid),
  ('b9038f31-0e42-4e27-a5b3-1791969f3928'::uuid),
  ('bb6c83ea-0907-43b6-9ae4-faf7627708a7'::uuid),
  ('bb8b2e23-8e14-408c-8605-287f5a0bbbb6'::uuid),
  ('bced3267-903a-4bd2-964a-b09f9a1fad1f'::uuid),
  ('c04b1b48-af08-4a68-8ae0-461a674a3ad7'::uuid),
  ('c072eae3-a852-4774-8b4e-6b1205b74053'::uuid),
  ('c1305dac-c9f0-4d2a-b1cb-b791f6979298'::uuid),
  ('c56ed3db-d9f9-47bb-b883-9616ecf9da1e'::uuid),
  ('c5aed4c2-e347-46c5-9091-32681a2c6795'::uuid),
  ('c7b6921b-db72-4b19-8a9e-6db0168281b2'::uuid),
  ('cb19f0d5-3614-4a2e-a2c7-12cd5e5abfd9'::uuid),
  ('cbcfd8ec-7743-40b3-8cd7-7c58122f9b69'::uuid),
  ('ccbc9499-c22a-455c-ba1f-3cfadd36e143'::uuid),
  ('ce5964dc-c2b6-4e2c-a6a4-aa33cfb552c6'::uuid),
  ('cef9da2a-6105-408d-baa7-7eece1905818'::uuid),
  ('cfde9cd6-3818-4524-ace1-f6b71d6bc084'::uuid),
  ('d0088dd7-ec08-4944-baa8-40ccdd543877'::uuid),
  ('d2ae1e87-3873-44be-8b8c-8108fccb9350'::uuid),
  ('d3955661-3ea4-4146-affe-ceb1f7bc9b39'::uuid),
  ('d43e907d-22cb-4e32-bc8c-f80553d972fe'::uuid),
  ('d8893e88-7b5b-4a6c-87da-4d5febc6e9e9'::uuid),
  ('da88afd2-575a-4bd5-98c3-43756cfdcc2c'::uuid),
  ('dab11780-c8ff-4b15-942e-fd1146c60094'::uuid),
  ('dbc083c4-12e0-4c0d-8f2b-656f3e0a08db'::uuid),
  ('dded1f26-f4ae-4dda-955b-b6f88721da39'::uuid),
  ('e234ac1c-09f4-4ebe-934c-c414cd104eca'::uuid),
  ('e35be922-7fe9-4133-8244-0cd266330130'::uuid),
  ('e36af13c-594b-416e-a455-51e833c4ef86'::uuid),
  ('e3d3f2dd-352c-4e8d-83fd-f95fb3a35a95'::uuid),
  ('e3eb8a94-8736-447a-9702-bba320432e3f'::uuid),
  ('e4cb5da2-f8a4-4264-bd49-022445359bec'::uuid),
  ('e843f111-7349-44ca-bbb8-c0e26fbe9583'::uuid),
  ('eb1e308b-6258-4c2c-b3db-5b1fb066f630'::uuid),
  ('ec70b297-1d8c-404e-938e-3242d4ddf2ee'::uuid),
  ('ef3de8dc-71ea-468c-8bbd-ccc850a9c41c'::uuid),
  ('f06e8c80-2610-4f35-9551-0b42ca800317'::uuid),
  ('f0a1837d-d07e-4f22-89ea-6d13f435c06c'::uuid),
  ('f1c60093-0a60-4cf8-9880-48090dc57098'::uuid),
  ('f32de1a7-ff03-4d4a-add5-3851be1b0016'::uuid),
  ('f492222d-8bcc-408b-aaf1-3ef69c21965a'::uuid),
  ('f6d1ee25-61a2-48ef-b0dc-d221a7c57075'::uuid),
  ('f70a4bec-0675-4e3f-a0f1-f07c190cc9e5'::uuid),
  ('f738cc17-86a4-4095-aa16-02beee20e0f0'::uuid),
  ('f7d4c207-0862-4b71-8981-cb8ec02cd3af'::uuid),
  ('f80a01aa-1f18-430e-88b3-4e4142f3e832'::uuid),
  ('f834df6a-411f-4bd6-938c-d0eed827ff28'::uuid),
  ('fa754b26-1d3c-4ad2-a0ab-572abccb9a5f'::uuid),
  ('fd61376d-a850-4d73-904d-342500bd28ea'::uuid),
  ('ff210f70-bc74-4fe2-84bf-b57e6a25baa2'::uuid);

do $$
declare
  v_listed int;
  v_known int;
begin
  select count(*) into v_listed from _emekli;
  if v_listed <> 237 then
    raise exception 'liste 237 olmalı, %', v_listed;
  end if;
  select count(*) into v_known from questions q join _emekli e on e.id = q.id;
  if v_known <> 237 then
    raise exception 'listedeki % id sunucuda yok', 237 - v_known;
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
    raise exception 'tekrar listesinden % soru hala onayli', v_left;
  end if;
end
$$;

commit;
