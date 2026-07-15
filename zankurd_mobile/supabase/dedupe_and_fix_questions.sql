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
  '061a7bdb-23da-4923-b086-52612a438cae',
  '075c308e-63c4-4d1d-a7c4-31f642490432',
  '0fdb8c11-a2a3-4239-b62b-b500ac497cfa',
  '18296ba7-a512-4a26-a5a4-65a3f1ecdccc',
  '1f345cc5-b602-4ea8-8927-d682ff0f0907',
  '2827186b-2e7e-4937-8d36-7b60273dacfa',
  '44ed6a92-1bdf-4586-a1da-50016a67481e',
  '4953e36f-40b0-4c4b-b24f-66fe63f0b282',
  '49efc11a-a3a3-4482-9cda-35fd20a6019e',
  'ae5550d3-378b-464d-bc89-1128a8892ff7',
  'c73a1d8c-82e3-4706-90ad-f988f658ab6d',
  'd8c7405d-6df6-4c89-b893-16be57e89236',
  'df1b4189-e646-407a-977f-a0e159f37826',
  'ed84d446-99bd-46b6-af4c-2c3c23a12f04',
  'f02052c0-b990-4ec9-8796-cc89b1adfc40'
);
