# correct_option istemciye açık — bilinçli risk kaydı (2026-07-21 denetimi)

## Durum

`public_read_policies.sql` ile `questions` tablosu (onaylılar) `anon` dahil
tüm istemcilere **`correct_option` kolonu dahil** okunabilir. Online 1v1 /
odalarda `submit_answer` doğruluğu sunucuda hesaplasa da, hileci bir istemci
REST API'den sorunun doğru cevabını maçtan önce okuyabilir.

## Neden şimdi kapatılmadı

İstemci solo quiz akışında doğru cevabı yerelde göstermek için
`correct_option`'ı bizzat SELECT ediyor
(`supabase_zankurd_repository.dart:58`). Kolonu RLS/view ile gizlemek solo
modu kırar. Doğru çözüm iki adımlı bir ürün değişikliği gerektirir:

1. Solo quiz'i tamamen offline bankadan besle (zaten 3.147 soru gömülü).
2. Online oda sorularını `correct_option`'sız bir view'dan servis et;
   doğrulama yalnız `submit_answer` RPC'sinde kalsın.

## Öneri (uygulanmadı)

```sql
-- create view public.questions_public as
--   select id, category_id, prompt, option_a, option_b, option_c, option_d,
--          explanation, explanation_ku, explanation_tr, question_type,
--          image_url, difficulty
--   from public.questions where is_approved = true;
-- + istemcinin online modda bu view'ı kullanması, solo modda offline banka
```

Bu değişiklik istemci kodu ile eşzamanlı yapılmalı; tek başına SQL uygulanırsa
solo online-kaynaklı quiz kırılır.
