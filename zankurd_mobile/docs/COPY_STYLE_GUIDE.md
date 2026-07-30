# ZanKurd metin stil rehberi (Ku / Tr)

Kısa, tutarlı UI ve soru metinleri için. Pirs benzeri quiz akışlarında net etiketler önceliklidir.

## Genel

- Cümle sonu: bilgi cümleleri nokta; sorular `?`; emirler nokta veya ünlemsiz.
- UI’da üç nokta tutarlı: `…` kullan.
- Coin birimi: `coin` (küçük harf), örn. `120 coin`.
- Sürüm: `package_info_plus` → `version+buildNumber`.

## Kurmancî (UI)

| Anlam | Tercih | Kaçın |
|--------|--------|--------|
| Tekrar dene | `Dîsa biceribîne` | `Dîsa Bicerib`, `Dûbare` |
| Yüklenemedi | `Barnebû` / `… nehat barkirin` | TR kelime Ku slot’ta |
| Devam et / sonraki adım | `Bidomîne` | `Piştî vê` (UI’da) |
| Kopyalandı | `hat kopîkirin` | `kopî kir` |
| Mağaza | `Dukan` | `Dukan / Mağaza` |
| Coğrafya (görünen) | `Erdnîgarî` | ID hâlâ `Cografya` |
| Etkinlik | `Çalakî` | `Etkinlik` Ku dilinde |
| Sıralama | `Pêşderçûn` | `Leaderboard` |
| Eşleş | `li hev bîne` | `Eşleş` |
| Hızlı düello | `Pêşbirka bilez` | `Duelo bi lez` |
| Ders yolu | `Rêya dersan` | TR kelime Ku slot’ta |
| Konu seç | `Mijar hilbijêre` | `Kategorî hilbijêre` (ana CTA’da) |

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

1. Ekran başına tek baskın eylem — örn. `Derse başla` veya `Yanlışları incele`.
2. Doğrudan alternatifler kısa, nötr yüzeyli ve birincil eylemden küçük olur.
3. Seyrek yollar (`Ana Sayfa`, sıralama, değerlendirme) `Diğer seçenekler` altında toplanır.

## Renk

- Birincil CTA / vurgu buton: `AppTheme.primaryCtaColor(context)` veya `accentGradient`
- Pembe `AppTheme.accent` yeni UI’da kullanma (legacy)
- Ödül: `gold` · Doğru: `correct` · Yanlış: `wrong`

## Contest

- Quiz wiring tamamlanmadan ana menüye bağlama.
- UI: disabled `Yakında` / `Nêzîk e`.
