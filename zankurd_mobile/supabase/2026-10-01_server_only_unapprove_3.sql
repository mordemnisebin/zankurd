-- 2026-10-01 (üçüncü adım): üç modelin ayrıştığı 116 sunucu sorusu Gemini 3.1
-- Pro hakemliğiyle onaydan çıkarıldı.
--
-- NİÇİN: yalnız sunucudaki denetlenmemiş sorularda üç oy (Gemini 3.8 Flash,
-- Grok 4.7, Muse Spark 1.3) 128 soruda çoğunluk vermedi. Bu sorular Gemini
-- 3.1 Pro'ya üç oyun gerekçeleriyle birlikte hakem olarak verildi; 116'ını
-- EMEKLİ, 12'sini DÜZELT olarak işaretledi (düzeltmeler doğrulamadan sonra
-- ayrı göçle). Kayıt: orkestra/sunucu_denetim/hakem/gemini/.
--
-- Sorular SİLİNMEZ: yalnız is_approved = false. Geri alma: aynı id listesiyle
-- is_approved = true.
-- Uygulama: supabase db query --linked -f supabase/2026-10-01_server_only_unapprove_3.sql

begin;

create temp table _emekli(id uuid primary key) on commit drop;
insert into _emekli(id) values
  ('00c1eade-f056-40ec-90f1-fa085a1dcc71'::uuid),
  ('00c25aba-c640-4985-9c6a-b6bc8017eaf2'::uuid),
  ('017a9684-ac4f-4849-8900-3c3eda0c4251'::uuid),
  ('07776dd7-07c9-43ea-a1b8-1899440f83f0'::uuid),
  ('0ba1bf12-7e80-4582-bad6-8e8af421d0e0'::uuid),
  ('0d703a2f-1837-4008-86e8-cdefa92e9fa8'::uuid),
  ('0e34bcdc-9e94-44fd-89c4-fb9b15653738'::uuid),
  ('0f2d0946-6c45-4219-b87f-4f200f24a569'::uuid),
  ('11df6a85-dda6-49f3-83d0-a91534c58b7b'::uuid),
  ('11fc3c95-aa7e-42f0-a7dd-2e21c5e385e2'::uuid),
  ('13130317-65b9-4222-922c-f6e45e4e363b'::uuid),
  ('14087352-60ae-4b01-8842-5442d24a3952'::uuid),
  ('181cf12f-68f7-4cef-9e85-e2cbcbabf1b5'::uuid),
  ('1c975046-0729-46a5-a290-2e460633a497'::uuid),
  ('1d5c7a47-464b-4704-9a96-eb37f2995044'::uuid),
  ('1d657650-f39c-407d-8c42-1d22e9bda49f'::uuid),
  ('21d4bde7-249b-4bfe-b173-ddbf5e6c9ba5'::uuid),
  ('24371a2f-57e7-4087-a5b4-4bf643aa37fa'::uuid),
  ('253cd7b5-5075-40e4-ab8a-3079fd3629a6'::uuid),
  ('261fed89-743c-44d5-b259-250740c01842'::uuid),
  ('2734c8e6-1f42-4d00-9e63-5bdba81901f6'::uuid),
  ('28cd988a-a098-4fe9-942e-60ff4b3b4ce4'::uuid),
  ('294f0a13-aea9-4488-a543-9965b63644bf'::uuid),
  ('2b336360-bfbd-4692-a358-e6c8f7911fdd'::uuid),
  ('2d577c10-7650-4533-a106-fe396f8e9f9d'::uuid),
  ('2d913dbd-e0f1-4508-9055-55b318faddb5'::uuid),
  ('2fb40436-8a05-4a64-b4a2-3762ef43081c'::uuid),
  ('348fd079-3414-4a39-a6ab-e6566e77f56f'::uuid),
  ('359581a6-40db-449f-8827-87166c5b2176'::uuid),
  ('375a5d46-dc95-4006-a114-3d35db967559'::uuid),
  ('375dfbe5-162a-48cb-b1d2-41c10e8afa18'::uuid),
  ('3881db37-c72b-4fea-8ab0-ed3a11efab28'::uuid),
  ('391f5114-145e-49dd-a058-b70e66793719'::uuid),
  ('3a89831b-eb8b-41da-9065-8a058f1ffde9'::uuid),
  ('3a9f6b81-73ce-4bb5-8837-4161265ad414'::uuid),
  ('3de41dee-65a5-49ce-b6cf-1357bb516354'::uuid),
  ('401a6429-2922-42de-a9e9-4de7a5a526e4'::uuid),
  ('41011654-94c2-43a3-a1e0-1b6da5fbaff1'::uuid),
  ('504bf2c0-b272-468a-9589-86257a2bc062'::uuid),
  ('5336eaa3-837f-427e-8a33-d301f500523c'::uuid),
  ('544b357e-f792-48ba-8977-129a2e09bb00'::uuid),
  ('54fcfd97-cc55-40f3-bb0b-39eb0c9fe45d'::uuid),
  ('56d94be4-3036-4be4-b476-cfbfb216ee6a'::uuid),
  ('598c5626-6dd1-4540-9ce5-20d399059233'::uuid),
  ('5d886719-e2b3-496b-ae26-c80f12ead512'::uuid),
  ('5e0c42eb-57f5-4496-93b7-defa6d0e8c50'::uuid),
  ('60e1e0af-f4ab-4d04-ba7c-36edab5ddb30'::uuid),
  ('61be163f-1fea-4a91-a8ed-5abddbcc5342'::uuid),
  ('62b74667-2c0b-4d83-9cdb-4b497f37da06'::uuid),
  ('63808bd4-27c7-49c9-b635-05031de77e62'::uuid),
  ('63a41108-6aa2-482b-ad1a-bed61270cc4c'::uuid),
  ('6792d4d1-553b-4ad3-a65f-26205c70e0a4'::uuid),
  ('679ebe50-5e19-4eac-9616-c97dc8d71452'::uuid),
  ('68e346d3-b743-404e-a5b4-b2cb8f2e87cd'::uuid),
  ('6a9388b3-05ea-4737-bd27-932c8503e4ee'::uuid),
  ('6d512739-ae17-4ff9-9b1e-fb973d0726da'::uuid),
  ('70795e27-d568-4ec5-9fd9-be8bfc2007fe'::uuid),
  ('709db9e3-fad5-4b53-94ab-2553c3d3b624'::uuid),
  ('71b0f744-e95d-4d21-9294-8b9af77498b1'::uuid),
  ('72c65471-6e43-43c5-92af-9fc1eb5091af'::uuid),
  ('7471a2f7-4dc2-46bb-8dfd-f535002c475d'::uuid),
  ('75180ebe-9e10-4b70-beed-61d5a9b40d81'::uuid),
  ('77510e99-6f51-42e0-b70a-a6431f4463ec'::uuid),
  ('77f1f88c-a3cf-47ee-b4cf-8b7d50789c0f'::uuid),
  ('786c24c5-75f4-473d-bee0-927e0de8d5fe'::uuid),
  ('788b3905-19e3-4b26-994b-61f5926eb310'::uuid),
  ('794721a9-905a-4d20-b1f0-420f386e61b6'::uuid),
  ('7adf2c9f-28be-4fb8-a6a9-98e96826672d'::uuid),
  ('7c1000a4-6576-47d3-8010-45326a7006cb'::uuid),
  ('7e815d8d-ec1c-467e-a804-a9686bb4c6cc'::uuid),
  ('7ee74032-7bab-4c94-8532-40e8ecf80a7f'::uuid),
  ('80bf64af-a17f-4646-9c5f-d7b39a21c978'::uuid),
  ('8b669974-8233-49e2-aede-18133d2b7dbb'::uuid),
  ('8d2d8da4-7cf0-40a7-abb9-b7225bf981d8'::uuid),
  ('8ebb2bb0-5167-46b9-8ad0-4e0f77480982'::uuid),
  ('909d2267-c633-45f7-86f5-0734619644ac'::uuid),
  ('949e248e-a0ef-4079-9377-8db1e606da2f'::uuid),
  ('95cd7c4c-6cfa-42cc-a432-1d4495c71cf9'::uuid),
  ('9ac00c86-d811-4b3d-9d70-8aa00a2631bf'::uuid),
  ('a17fd371-d38b-4d7a-b9b7-573273c03069'::uuid),
  ('a1ad69e4-6c0a-4a6a-8d9c-7da1d482e7e4'::uuid),
  ('a260737b-c10f-4502-a410-6701bda9902e'::uuid),
  ('a3505be6-e898-4b76-88db-0666f6c73df7'::uuid),
  ('a49c7af7-9970-41ef-9fe6-c512e281a4e3'::uuid),
  ('a973c086-e4b5-4762-b16e-b802156c9f73'::uuid),
  ('abe2ed0e-af4a-4be3-b206-70a2cf7ae738'::uuid),
  ('b6c0f87f-0039-4287-8909-dccb796730e2'::uuid),
  ('c26d3239-9a5b-4b2d-8f4f-b62a3707d3e6'::uuid),
  ('c2d0574c-7eec-4141-a046-a7e3fa6017f6'::uuid),
  ('c5a0047b-6260-4589-9ecd-808f04f963e7'::uuid),
  ('c7b4379e-ee39-41d4-aec5-06df26a6c436'::uuid),
  ('d115d9da-5658-46a4-a331-c0cf81fb9f47'::uuid),
  ('d2558ca1-1433-4de1-a412-3cc87e21ee81'::uuid),
  ('d3a84799-f48d-435d-aa2a-02292c1833bb'::uuid),
  ('d451c0a7-6c53-40c3-b7a2-c169404e6314'::uuid),
  ('d4f0fa1b-fa33-4a7f-8e33-21440c4e27ae'::uuid),
  ('d53a1b9c-611b-4301-a492-f5bdedf76824'::uuid),
  ('d7778f22-2135-42e4-a453-d40b152c5878'::uuid),
  ('d88ef3a0-3d60-4159-99fa-1a268b3ee4c2'::uuid),
  ('dd8465d9-2204-41f5-94a0-58cf52015610'::uuid),
  ('e153be38-cb66-4641-81df-920217df265d'::uuid),
  ('e1909f64-717c-4feb-a9e6-c827a02732f2'::uuid),
  ('e2165eeb-45e4-42e1-bdf6-7786bcf5b498'::uuid),
  ('e601d49c-57df-445e-b3c5-38f90aa35a91'::uuid),
  ('e6d2be97-0c88-4b03-a7e2-40e1ab372452'::uuid),
  ('e8826732-746d-4113-9e1f-479e840088ec'::uuid),
  ('ea219059-6f28-4325-8ae1-6726ee202a48'::uuid),
  ('ef165899-fad9-429d-9e00-c962698f6a47'::uuid),
  ('f1e897bd-18dc-4207-b0f2-762cd6fc32e2'::uuid),
  ('f3a635b3-988d-4ec6-80a0-f1f4c6df9d3e'::uuid),
  ('f76708a4-794a-4964-b895-9e72084b6b11'::uuid),
  ('f8a0660f-8541-488d-a023-41fa833e06ee'::uuid),
  ('fcbfa042-f632-493e-9e2b-3dd5b2f96cf4'::uuid),
  ('fcdf8533-db71-4d91-b213-f79eb16ea768'::uuid),
  ('fd2f93d9-1428-4f3a-9477-84ced7dd251d'::uuid),
  ('ffd852a1-080f-43e8-acc4-b9126fc72924'::uuid);

do $$
declare
  v_listed int;
  v_known int;
begin
  select count(*) into v_listed from _emekli;
  if v_listed <> 116 then
    raise exception 'liste 116 olmalı, %', v_listed;
  end if;
  select count(*) into v_known from questions q join _emekli e on e.id = q.id;
  if v_known <> 116 then
    raise exception 'listedeki % id sunucuda yok', 116 - v_known;
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
