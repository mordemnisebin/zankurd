# ZanKurd metin stil rehberi (Ku / Tr)

Kısa, tutarlı UI ve soru metinleri için. Pirs benzeri quiz akışlarında net etiketler önceliklidir.

## Genel

- Cümle sonu: bilgi cümleleri nokta; sorular `?`; emirler nokta veya ünlemsiz.
- UI’da üç nokta `…` veya `...` tutarlı: tercihen `...` (ASCII).
- Coin birimi: `coin` (küçük harf), örn. `120 coin`.
- Sürüm: `package_info_plus` → `version+buildNumber`.

## Kurmancî (UI)

| Anlam | Tercih | Kaçın |
|--------|--------|--------|
| Tekrar dene | `Dîsa biceribîne` | `Dîsa Bicerib`, `Dûbare` |
| Yüklenemedi | `Barnebû` / `… nehat barkirin` | TR kelime Ku slot’ta |
| Sonraki | `Piştre` | `Piştî vê` (UI’da) |
| Kopyalandı | `hat kopîkirin` | `kopî kir` |
| Mağaza | `Dukan` | `Dukan / Mağaza` |
| Coğrafya (görünen) | `Erdnîgarî` | ID hâlâ `Cografya` |
| Etkinlik | `Çalakî` | `Etkinlik` Ku dilinde |
| Sıralama | `Pêşderçûn` | `Leaderboard` |
| Eşleş | `li hev bîne` | `Eşleş` |

## Türkçe (UI)

- Cümle başı büyük harf; butonlarda kısa emir: `Tekrar dene`, `Oda kur`, `Kodla katıl`.
- Hata mesajları tam cümle + nokta: `Etkinlik yüklenemedi.`
- İngilizce UI kelimesi yok (`Leaderboard`, `Contest`, `Coins`).

## Soru bankası

- Prompt’ta şablon artığı yok: `(Şablon N)` yasak.
- `correctAnswer` mutlaka `answers` içinde birebir.
- Görsel Ziman: açıklama kısa ve öğretici; “kelimesini pekiştirir” şablonu yerine kavramı açıkla.
- Kategori **ID**’leri değiştirilmez (`Cografya`, `Ziman`…); sadece görünen etiket `CategoryNames.localized`.

## CTA hiyerarşisi (Pirs ilhamı)

1. Tek birincil eylem (coral gradient) — örn. `1vs1 — Hemen oyna`.
2. İkincil oda eylemleri outline — `Oda kur` / `Kodla katıl`.
3. Hızlı grid: günlük / çark / turnuva (dürüst etiket: bot kupa).

## Renk

- Birincil CTA / vurgu buton: `AppTheme.primaryGradientStart` veya `accentGradient`
- Pembe `AppTheme.accent` yeni UI’da kullanma (legacy)
- Ödül: `gold` · Doğru: `correct` · Yanlış: `wrong`

## Contest

- Quiz wiring tamamlanmadan ana menüye bağlama.
- UI: disabled `Yakında` / `Nêzîk e`.
