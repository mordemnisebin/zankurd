-- 2026-07-21 denetimi: canlı questions tablosundaki "Di asta …" şablon
-- öneklerini kaldırır (offline bankada aynı temizlik 8195415 commit'iyle
-- yapıldı; canlı ile offline kopyanın tutarlı kalması için).
-- HENÜZ CANLIYA UYGULANMADI. Uygulama: Supabase SQL Editor.
-- Not: Türkçe/Kurmancî karakter içerdiği için Management API ile gönderirken
-- memory'deki Python-urllib yöntemini kullan ([[supabase-prefix-migration-pending]]).

update public.questions
set prompt = upper(left(
      regexp_replace(prompt, '^Di asta (destpêkê|navîn de|pêşketî de), ', ''),
      1
    )) || substr(
      regexp_replace(prompt, '^Di asta (destpêkê|navîn de|pêşketî de), ', ''),
      2
    )
where prompt ~ '^Di asta (destpêkê|navîn de|pêşketî de), ';

-- Doğrulama:
-- select count(*) from public.questions where prompt like 'Di asta %';  -- 0 olmalı
