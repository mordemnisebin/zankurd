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
  '09ee8855-9989-413f-902c-54c52c8722b5',
  '0db5f493-43d8-4918-b1b5-d76145ae0b59',
  '149cf5b1-1147-4111-b58b-eae6036eb3c2',
  '1bc1d1cd-e273-4ecc-bbe3-19a3f870b565',
  '244b3b1e-51f1-4f57-99fb-0104d4848037',
  '2eba9a25-3ed5-4027-9d44-d7429c80df90',
  '3a287cc2-e435-49f5-8481-f791fb7322d8',
  '4071753a-708f-4a1f-87ac-956de425746e',
  '49ad383e-0eb4-46d2-8941-bcd12f6a9fde',
  '83abb3ea-470e-404e-b18d-07252f54feb5',
  '9f7b8b61-8be5-43d8-9c7c-f0450838d26e',
  'e3862f30-9ccc-454e-a109-504dc2742206'
);
