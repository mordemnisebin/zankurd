# Pure Kurmancî Soru Dalgası 1

- Üretim tarihi: 2026-07-13
- Toplam soru: 10.000
- Kategori dağılımı: 8 kategori x 1.250
- Benzersiz prompt: 10.000 / 10.000
- Dil kontrolü: Türkçe `ı`, `ü`, `ö`, `ğ` kalıntısı yok
- Görünen kategori adları: `wêje`, `erdnîgarî`
- Veritabanı anahtarları: `Edebiyat`, `Cografya` korunuyor
- Üretim modu: deterministik yerel fallback; Gemini yalnızca açık opt-in ile kullanılabilir

## Doğrulama

- `python -m py_compile tools/generate_pure_kurdish_questions.py`: geçti
- Üretici varyant/deadlock smoke testi: geçti
- SQL satır ve benzersizlik smoke testi: geçti
- `dart analyze lib/src/data/curated_question_bank.dart test/curated_question_bank_test.dart`: geçti
- `flutter test test/curated_question_bank_test.dart`: 5 test geçti
- Proje geneli `dart analyze`: 124 saniyede zaman aşımına uğradı; hedefli analiz temiz.

Canlı Supabase’e uygulanmadı; SQL önce editoryal ve operasyonel incelemeden geçmelidir.
