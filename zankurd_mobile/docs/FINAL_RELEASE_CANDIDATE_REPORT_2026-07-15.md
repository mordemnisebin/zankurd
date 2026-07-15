# ZanKurd final release-candidate raporu — 2026-07-15

## 1. Branch ve HEAD

- Branch: `codex/final-release-candidate-polish-2026-07-15`
- Doğrulanan kod HEAD'i: `37f52fc` (`feat: polish final app accessibility and hierarchy`)
- Başlangıç: `027868cfa597a898f2b238742b0642ac009dc94f`

## 2. Düzeltilen auditor hataları

Docs/rapor çıktıları discovery dışına alındı; correct-answer ve duplicate-option kontrolleri ayrıldı; punctuation-only seçenekler korundu; dar kanıtlı answer-leak false positive'leri giderildi. Production soru içeriği değiştirilmedi.

## 3. Gate sonucu

`dart run tool/question_quality/question_quality_audit.dart gate` exit `0`; unknown source `0`. Gate physical/canonical: `13571/13571`. Baseline SHA-256 değişmedi: `FEB81CE8DCC50CAC35812DAAD294C8C7B15BF955CCAFE165BBCDB53A36507BEA`.

## 4. Görsel olarak değişen ekranlar

Ana sayfa başlığı ve oyun merkezi hiyerarşisi, quiz timeout sunumu, sonuç ekranı, liderlik yenile eylemi ve ayarlar erişilebilirliği dar kapsamda iyileştirildi.

## 5. Açık tema kontrast sonucu

Ana sayfa ve sonuç hero foreground'ları daha koyu/okunaklı token ve gradient kullanıyor. Kullanıcı adı, ikonlar, coin/XP ve istatistikler açık temada görünür; koyu tema korunuyor.

## 6. Sonuç ekranı CTA hiyerarşisi

Yalnız `Dîsa bilîze` ve `Sereke` baskın eylem. Cevap inceleme, hatalar, liderlik ve paylaşım daha düşük ağırlıklı `Vebijarkên Te` bölümünde; hedef ve sonuç mantığı değişmedi.

## 7. Timeout geri bildirimi

Mevcut timeout state'i için ikon, görünür `Demjimêr · 00:00 / Zamanlayıcı · 00:00` mesajı ve live-region semantics eklendi. Timer/state-machine değiştirilmedi.

## 8. Erişilebilirlik iyileştirmeleri

Tema/dil/coin, liderlik yenile, ayar satırları ve sonuç eylemlerine tooltip/semantics eklendi; dekoratif ikonlar ekran okuyucudan çıkarıldı.

## 9. Responsive sonuçları

`320×568`, `390×844`, `844×390`, `768×1024` ve `1440×900` test edildi. CTA, alt navigation, landscape sonuç kimliği ve max-width düzeninde overflow görülmedi.

## 10. Test sayısı

- Question-quality: `51/51`
- Tam suite (`--exclude-tags preview`): `612/612`
- Değişen ekranlara ait dar widget testleri ayrıca geçti.

## 11. Analyzer sonuçları

Uygulama kökü `dart analyze`: temiz. Widgetbook `dart analyze`: temiz.

## 12. Web/WASM build sonucu

Standart `flutter build web`: başarılı; `main.dart.js` SHA-256 `E638CBF71E60FFC80D48DFC7FABF02DD4F0DBC049FAF33DFC2230D27E8B4D541`. İlk `flutter build web --wasm`: başarılı; temiz tekrar gerekmedi (`main.dart.wasm`: 4,497,181 bayt).

## 13. Final ekran görüntüsü dizini

`docs/screenshots/final_release_candidate/2026-07-15/` altında 17 PNG ve README indeksi. Gerçek Playwright akışında konsol: 0 hata, 0 uyarı.

## 14. Dokunulmayan logic/data alanları

Production soru Dart/CSV/JSON/SQL içeriği, Supabase, auth, route, matchmaking/realtime/polling, oda, reward/coin, contest, signing, service worker ve bağımlılık listesi değişmedi. Push, merge, deploy veya production yazımı yapılmadı.

## 15. Açık kalan gerçek ürün riskleri

Fiziksel Android/iOS cihaz ve gerçek ekran okuyucu doğrulaması bu web turunun dışında. Canlı 1v1 ağ hatası/retry senaryosu üretim servisine bağlanmadan doğrulanmadı; isteğe bağlı retry kapsamı bu nedenle değiştirilmedi.

## 16. Commit listesi

1. `3a8c033` — `fix: remove question auditor false positives`
2. `37f52fc` — `feat: polish final app accessibility and hierarchy`
3. Bu rapor ve ekran kanıtları — `docs: add final release candidate evidence`

## 17. git status --short

Dokümantasyon commit'i sonrası temiz olması kapanış kontrolünde zorunlu olarak doğrulanır.

## 18. Ana checkout kanıtı

Ana checkout'a build/test yazılmadı ve yalnız önceden var olan ` M macos/Flutter/GeneratedPluginRegistrant.swift` durumu korunarak kapanışta tekrar doğrulanır.
