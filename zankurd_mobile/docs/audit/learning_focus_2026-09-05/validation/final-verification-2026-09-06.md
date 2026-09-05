# Nihai doğrulama

Tarih: 6 Eylül 2026

- `dart analyze`: `No issues found!`
- `git diff --check`: temiz
- `flutter test --exclude-tags preview`: `2.572` test geçti
- `ZANKURD_URL=http://127.0.0.1:8877 node tools/playwright/learning-focus.mjs`: `errors: []`; tanıtım → ilk 5 soru → sonuç → açıklama/özet → ana sayfa akışı geçti
- Web debug derlemesi: `build/learning_focus_web_2026_09_06`

Playwright ekran görüntüleri bu denetim klasöründeki PNG dosyalarına yazıldı. Doğrulama çevrimdışı mock veri ve yerel debug derlemesiyle yapıldı; canlı ödeme, gerçek cihaz TTS'i, Supabase eşleşmesi ve mağaza onayı bu kaydın kapsamı dışındadır.
