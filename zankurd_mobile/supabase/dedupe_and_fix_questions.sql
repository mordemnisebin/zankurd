-- ZanKurd soru bankasi tekillestirme + kalite duzeltmesi
-- 1) Ayni prompt'un kopyalarindan yalnizca biri onayli kalir
--    (en dusuk zorluk, sonra en eski id tercih edilir).
-- 2) Cevap sizintisi tespit edilen satirlarin onayi kaldirilir.
-- Satirlar SILINMEZ; is_approved=false yapilir, admin sonra duzeltebilir.

update public.questions
set is_approved = false
where id not in (
  select distinct on (lower(trim(prompt))) id
  from public.questions
  order by lower(trim(prompt)), difficulty, created_at, id
);

update public.questions set is_approved = false
where id in (
  '0123f45c-5baa-4000-be1a-8f72674ec3c8',
  '051b28dc-e212-4cdd-851a-32815baaa573',
  '080b62b6-0481-4e81-8b34-1e750e1bf9a5',
  '148d7227-c9f1-4d3e-b5d6-180cbb44d9e8',
  '1a67f095-83ac-404b-86cd-73a338ed0bdc',
  '1c33e483-6b51-4def-9ed8-e1a814507b01',
  '224daa7a-1d54-4edd-8fea-9f6f53e34593',
  '25a07074-2fc2-41ba-a77e-8626a0262d8c',
  '265cd74b-390b-4b55-803f-054e6456cda5',
  '2670230a-edb4-48b2-93d9-90597c094244',
  '2863b4d6-8e30-4c5e-874b-aaef7a5de329',
  '28c53619-261f-420a-b04a-35c9ee99fe1c',
  '2df2f5bc-bbff-4a3e-a4fd-357b42773631',
  '30a0aac3-36d4-4dc6-b222-2e571df4d2a0',
  '362c26f2-2780-4140-b5c9-e83aff1a951c',
  '368fd290-1c2d-45f3-8d01-5ab1e390779e',
  '3b8c8827-e120-4547-8378-20c680622638',
  '3bab267a-0c53-4db7-b537-a345870847de',
  '470ba3ab-fe1b-4b96-9024-ba04b6642b15',
  '48fd81ab-6531-4969-8650-2918ea632448',
  '4cde4332-e75d-4dda-aa64-23f85bc68188',
  '51dd382c-d593-4c44-ae3e-c55e1fbf8b1c',
  '554712b1-8e44-488f-9e3c-17574bdde35b',
  '56c663d9-8870-4ef3-bccb-f0aae7984b5e',
  '56cee29f-962c-44a4-a2e2-48c9907cc68f',
  '5acb6bcc-fda4-4766-9c46-845785a6cf11',
  '6060cee1-5f25-4c48-ba29-6b4aaa531113',
  '621a0615-8235-4763-9628-d4ab0c30cd83',
  '62a2b9b6-14f4-4251-81d0-8431bb9a2aea',
  '69090855-374f-4549-9553-ad605519d9be',
  '6c6bef59-b624-4a5b-826d-3ab88311acb3',
  '72da6915-fc2f-44d2-a0d8-ae4292ece298',
  '73b5e868-9074-436a-b3a1-e37cd2b52772',
  '777eef43-b0c4-4d24-8c86-56b63c3fd9ef',
  '78f04c09-5db7-4f9d-90c5-fc64c927e637',
  '84e2afb7-4723-4b71-9af8-49b0e8d174a5',
  '8badd604-bd76-40b6-838c-20d26e401236',
  '948a6ec7-2922-43a9-8e79-ddf9fea559d4',
  '9571ff5d-751a-46ad-8a6a-d338beb01218',
  '96afbf60-f4ae-4946-a219-b6d259c554b0',
  '97206c3e-82f4-4c35-80ae-90e63b9e6024',
  '991aa89a-0da4-4f6c-b4ff-95efbe22fcb3',
  '9b63c684-5124-4384-98bb-7b06f6cb4509',
  '9ca87956-e090-47e2-a25e-ff87f423cf8b',
  'a2ef12ae-e251-4a20-9c7c-1cdfd76489e0',
  'a42e2a0b-5145-4ae5-882b-f46527b864a0',
  'a7445312-5281-4aff-8846-4be9aefaecc5',
  'a8b40453-890c-45d8-8f20-819fe2acf1ed',
  'adc7b0c4-e7e4-47b3-9c35-2cb214b3e45a',
  'b1495aef-f587-41c0-9ba4-52e7fc69e469',
  'b2410909-11d3-4b96-9669-f9cc0bf6f96a',
  'b939b3ef-8ef0-4bf6-86b4-cf694ba27802',
  'bbaf7425-2279-4d73-9216-2c0f12337ca7',
  'be0840d3-580d-4e89-89a0-3a14ea47b443',
  'c391bcda-3055-4c2b-bd35-5fc8fffa0360',
  'c8bb36b0-eb24-4f4a-87a5-27548776997f',
  'd797c5a8-ce08-427b-9227-92d0d08f5844',
  'daf8ca0e-754f-4f00-9430-6c80a46fff9d',
  'db5bc567-8eec-430e-afbc-e29704f95be9',
  'dd06345d-6517-4413-afaa-95da1a6f2041',
  'dfca8e9b-48d7-4af2-98bd-cdd3de9136ea',
  'e134cd31-de9c-4190-b777-13f9ba3ce88b',
  'e4268899-e82e-4396-bac5-53338cc20acd',
  'e56d5983-d6ac-4dc9-ae02-59035f1aae22',
  'e69364be-a218-4008-ac43-d14fad024bd4',
  'e744294c-7ce3-406d-81c2-58a771c19fe7',
  'ebd2a0d1-d55c-4c15-94e2-65ce51651173',
  'ecae64ac-2125-40fa-b6cd-8860b72283d5',
  'ef2f7e3f-8b9e-4d71-9b0c-909708645a2e',
  'f64a9914-fa79-4689-a61f-f8e0df2f46dc',
  'f6563ae8-7252-4eb5-86f0-558f004d3eef',
  'f767d6f5-a4c8-4044-9642-45cf9e52beb9',
  'fbf1018c-d21c-4d04-bcea-96a3bc012ca5',
  'fcc8cf3a-c20c-421e-be13-cc51b09e410a',
  'fef5b54d-4048-474d-87e3-1bd4acdc2dd9'
);
