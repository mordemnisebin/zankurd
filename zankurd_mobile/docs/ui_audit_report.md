# ZanKurd UI Audit Raporu

> **Tarih:** 2026-07-08  
> **Branch:** `ui-quality-system`  
> **Commit:** `4c0eb37`  
> **Durum:** Kod değişikliği yok — sadece analiz

---

## 1. Sabit Renk Kullanımları

| Renk | Konum | Sayı | Risk |
|---|---|---|---|
| `Colors.white` | `home_screen.dart`, `hero_card.dart`, `profile_screen.dart`, `quiz_result_screen.dart`, `shop_screen.dart`, `subcategory_screen.dart`, `matchmaking_screen.dart` | ~40+ satır | Düşük (çoğu koyu gradient üstünde haklı) ama `subcategory_screen.dart:33,37` AppBar'da light modda okunmaz |
| `Colors.black` | `home_header.dart`, `categories_tab.dart`, `app_shell.dart` | ~5 satır | Düşük |
| `Colors.orange` | `quiz_widgets.dart:310`, `profile_screen.dart:1747`, `quiz_screen.dart:762` | 3+ satır | Orta — tema token'ı yok, koyu modda düşük kontrast |
| `Colors.redAccent` | `matchmaking_screen.dart:769`, `quiz_widgets.dart:325` | 2+ satır | Orta — "VS" ve quiz stat ikonu |
| `Color(0xFF...)` | Tüm ekranlara yayılmış | ~135 satır | Yüksek — çoğu `AppTheme` sabitleriyle değiştirilebilir |

**En kritik:** `quiz_result_screen.dart:366` `Color(0xFF13222F)` sabit navy header — light modda koyu metinle düşük kontrast.

---

## 2. Sabit Radius Kullanımları

| Değer | Nerelerde | AppRadius token'ı |
|---|---|---|
| 2 | `section_header.dart`, `categories_tab.dart` | Yok → `AppRadius.xs` kullanılmalı |
| 3,4,5,6,7 | `profile_screen`, `daily_missions_card`, `quiz_widgets`, `home_screen.dart` | Yok |
| 8 | `settings_screen`, `subcategory_screen`, `quiz_widgets`, `room_screen` | `AppRadius.xs` (=8) var ama kullanılmıyor |
| 10 | `home_screen.dart`, `daily_missions_card`, `shop_screen.dart`, `quiz_widgets`, `quiz_result_screen.dart` | `AppRadius.sm` (=10) var ama kullanılmıyor |
| 12 | En yaygın (52 kullanım) — hemen her ekranda | `AppRadius.md` (=16!) |
| 14 | `home_header.dart`, `matchmaking_screen.dart`, `subcategory_screen.dart` | Yok |
| 16 | İkinci en yaygın (44 kullanım) | `AppRadius.card` ✓ |
| 18,20,24 | `profile_screen.dart`, `home_screen.dart`, `quiz_result_screen.dart` | `AppRadius.xl` (=24) var |
| 99 | `profile_screen.dart`, `settings_screen.dart`, `quiz_widgets.dart` | `AppRadius.pill` (=99) ✓ |
| 999 | `profile_screen.dart`, `quiz_effects.dart` | Yok |

**Toplam 16 farklı radius değeri.** `AppRadius` token kümesi mevcut ama ekranların %90'ında kullanılmıyor.

---

## 3. Sabit FontSize Kullanımları

| Değer | Risk |
|---|---|
| **9** | `categories_tab.dart:357`, `profile_screen.dart:1301` — erişilebilirlik için çok küçük |
| **10** | `profile_screen.dart`, `daily_missions_card.dart`, `quiz_widgets.dart` — P2 |
| **10.5** | `daily_missions_card.dart:273`, `quiz_widgets.dart:594` — yarı-değer, okunabilirlik düşük |
| **12.5, 13.5** | `matchmaking_screen.dart:599`, `quiz_result_screen.dart:929` — yarı-değer, token'a uymaz |
| **30** | `subcategory_screen.dart:174` — `categoryTitle` token'ı varken literal |
| **52** | `quiz_result_screen.dart:472` — dev skor, tasarım amaçlı, kabul edilebilir |

**Toplam 21 farklı fontSize değeri.** `AppTypography` sadece 2 stil içeriyor, genişletilmeli.

---

## 4. Touch Target Riski (<44px)

| Konum | Öğe | Boyut | Risk |
|---|---|---|---|
| `home_header.dart:98-99` | Dil hızlı toggle | 42×38 | **P0** — ana sayfada |
| `home_header.dart:142-143` | Tema hızlı toggle | 38×38 | **P0** — ana sayfada |
| `settings_screen.dart:802-823` | Dil chip (KU/TR) | ~28px | **P0** — ayarlarda |
| `settings_screen.dart:393-429` | Bildirim saati InkWell | ~34px | P1 |
| `profile_screen.dart:1338-1344` | "Tüm Rozetler" TextButton | Sıfır padding + shrinkWrap | P1 — bilinçli ama erişilebilirlik sorunu |
| `shop_screen.dart:382-388` | Satın al butonu | ~36px | **P0** — ana CTA |
| `profile_screen.dart:1090-1143` | Dil tab/toggle | ~32px | P1 |

---

## 5. Overflow Riski

| Konum | Sorun | Risk |
|---|---|---|
| `quiz_result_screen.dart:450-463` | Row başlık Expanded'siz | P1 — uzun Kürtçe lokalizasyonda taşar |
| `quiz_result_screen.dart:534-561` | 4 metric `spaceAround` Expanded'siz | P1 — dar ekranda taşma |
| `subcategory_screen.dart:167-184` | Başlık `fontSize:30` maxLines yok | P1 — uzun kategori adı |
| `shop_screen.dart:358-364` | Açıklama Text maxLines yok | P2 — liste sarsılır |
| `quick_play_grid.dart:81` | `mainAxisExtent:112` sabit + maxLines:2 | P1 — "Pêşbirka Rojê" gibi uzun başlık |
| `profile_screen.dart:300-330` | Seviye/XP Row Expanded'siz | P1 |
| `matchmaking_screen.dart:579-603` | Kategori chip satırı | P2 |

---

## 6. Light/Dark Kontrast Riski

| Konum | Sorun | Risk |
|---|---|---|
| `quiz_result_screen.dart:366,477` | Sabit navy bg + `AppTheme.textPrimary` statik → dark text on dark | **P0** |
| `subcategory_screen.dart:33,37` | AppBar `Colors.white` hardcoded + light gradient bg → beyaz üstüne beyaz | **P0** |
| `quiz_result_screen.dart:1099-1142` | Beyaz metin + gold gradient → düşük kontrast | P1 |
| `profile_screen.dart:417,1372` | `AppTheme.textMuted` const, context'siz | P1 |
| `daily_missions_card.dart:99,120` | Progress ring `textPrimaryColor` + `borderColor 0.3` bg → light modda zayıf | P1 |
| `section_header.dart:94` | Subtitle `textMutedColor + fontSize:13` | P2 |

---

## 7. Tekrar Eden UI Component Adayları

| # | Pattern | Nerelerde | Yeni Component |
|---|---|---|---|
| 1 | **Kart (surface/gradient)** | `hero_card.dart`, `daily_missions_card.dart`, `room_screen.dart`, `shop_screen.dart`, `subcategory_screen.dart` | `ZankurdCard` |
| 2 | **Buton (filled/outlined)** | `home_screen.dart`, `shop_screen.dart`, `quiz_screen.dart`, `settings_screen.dart`, `matchmaking_screen.dart` | `ZankurdButton` |
| 3 | **Section header (accent bar)** | `section_header.dart` (kullanılıyor), `profile_screen.dart` (manuel), `settings_screen.dart` (manuel) | `ZankurdSectionHeader` |
| 4 | **Metric tile** | `quiz_result_screen.dart` (coin/XP tile), `profile_screen.dart` (`_StatTile`), `shop_screen.dart` (balance), `stats_row.dart` | `ZankurdMetricTile` |
| 5 | **Quiz option** | `quiz_widgets.dart` (`_AnswerButton`), `quiz_screen.dart` | `ZankurdQuizOption` (statik) |
| 6 | **List row (icon+text+trailing)** | `shop_screen.dart` (ShopItemCard), `subcategory_screen.dart` (`_SubcategoryCard`), `settings_screen.dart` | Yeni `ZankurdListRow` |
| 7 | **Back button daire** | `quiz_screen.dart:470-490`, `quiz_result_screen.dart:395-415` | Yeni `ZankurdBackButton` |
| 8 | **Dil değiştirici** | `settings_screen.dart` (`_LangSwitch`), `profile_screen.dart` (`_LangToggle`) | Yeni `ZankurdLanguageToggle` |
| 9 | **Coin/XP reward tile** | `quiz_result_screen.dart:641-733` ve `746-836` (birebir kopya) | `ZankurdMetricTile` + varyant |
| 10 | **Chip/pill** | `quiz_widgets.dart` (`_TinyTag`), `quiz_result_screen.dart` (`_ResultRewardChip`), `room_screen.dart` (`_Pill`) | Yeni `ZankurdChip` |
| 11 | **Hero gradient kart** | `hero_card.dart`, `room_screen.dart`, `matchmaking_screen.dart` | `ZankurdCard` (premium) |

---

## 8. Yeni Component'lere Geçiş Planı (Ekran Bazlı)

### 🏠 Home

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdCard` | `hero_card.dart`, `daily_missions_card.dart` | Düşük | Küçük — `Container+decoration` → `ZankurdCard` |
| `ZankurdSectionHeader` | `section_header.dart` (zaten var, değişebilir) | Düşük | Küçük |
| `ZankurdMetricTile` | `stats_row.dart` | Düşük | Küçük |
| `ZankurdButton` | `room_actions.dart`, `hero_card.dart` butonları | Orta | Orta — buton varyant eşleştirme |

**Önerilen sıra:** 4. sırada (Quiz Result ve Shop'tan sonra)

### ❓ Quiz

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdQuizOption` | `quiz_widgets.dart` `_AnswerButton` | **Yüksek** | Büyük — logic ile iç içe, state yönetimi var |
| `ZankurdButton` | `quiz_screen.dart:757-812` rating butonları | Düşük | Küçük |

**Önerilen sıra:** 5. sırada (en riskli, en son)

### 📊 Quiz Result

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdMetricTile` | Coin tile (L641-733), XP tile (L746-836) | Düşük | Küçük — birebir kopya, tek component yeter |
| `ZankurdCard` | Header kartı, achievement kartı | Orta | Orta — sabit renkler düzeltilmeli |
| `ZankurdSectionHeader` | İstatistik bölümleri | Düşük | Küçük |

**Önerilen sıra:** 1. sırada (en güvenli, en yüksek etki)

### 🛒 Shop

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdButton` | Satın al butonu (L382-388) | Düşük | Küçük — touch target da düzelir |
| `ZankurdCard` | Shop item kartları (L324-424) | Orta | Orta |
| `ZankurdMetricTile` | Balance paneli | Düşük | Küçük |

**Önerilen sıra:** 2. sırada

### 📂 Category / Subcategory

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdCard` | `categories_tab.dart` kategori kartı | Orta | Orta — gradient yapısı karmaşık |
| `ZankurdSectionHeader` | Alt kategori başlıkları | Düşük | Küçük |

**Önerilen sıra:** 6. sırada

### ⚙️ Profile / Settings

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdSectionHeader` | `profile_screen.dart` manuel başlıklar, `settings_screen.dart` | Düşük | Küçük |
| `ZankurdMetricTile` | `_StatTile` (L1146-1193) | Düşük | Küçük |
| `ZankurdCard` | Avatar kartı, rozet bölümü | Orta | Orta |
| `ZankurdButton` | Çıkış/sil butonları | Düşük | Küçük |

**Önerilen sıra:** 3. sırada

### 🎮 Room / Matchmaking / 1vs1

| Component | Dosya | Risk | Değişiklik |
|---|---|---|---|
| `ZankurdCard` | `room_screen.dart` hero, `matchmaking_screen.dart` random card | Orta | Orta |
| `ZankurdButton` | "Join"/"Create" butonları | Düşük | Küçük |

**Önerilen sıra:** 7. sırada

---

## 9. Önceliklendirme

### P0 — Kritik (Okunurluk / Kontrast / Taşma)

| # | Sorun | Ekran | Dosya |
|---|---|---|---|
| 1 | Light modda koyu metin + koyu navy bg | Quiz Result | `quiz_result_screen.dart:366,477` |
| 2 | Light modda beyaz AppBar + açık gradient | Subcategory | `subcategory_screen.dart:33,37` |
| 3 | Dil/tema toggle <44px touch target | Home | `home_header.dart:98,142` |
| 4 | Satın al butonu ~36px + dil chip ~28px | Shop, Settings | `shop_screen.dart:382`, `settings_screen.dart:802` |
| 5 | Quiz Result başlık Expanded'siz | Quiz Result | `quiz_result_screen.dart:450-463` |

### P1 — Tekrar Eden Component Refactor'leri

| # | Hedef | Ekran |
|---|---|---|
| 1 | `ZankurdMetricTile` → Coin/XP reward tile birleştir | Quiz Result |
| 2 | `ZankurdButton` → Satın al, rating, oda butonları | Shop, Quiz, Room |
| 3 | `ZankurdSectionHeader` → Profil/ayarlar başlıkları | Profile, Settings |
| 4 | `ZankurdCard` → Hero, daily missions, shop item | Home, Shop |
| 5 | Back button daire birleştir | Quiz, Quiz Result |

### P2 — Görsel Kalite / Premiumlaştırma

| # | Hedef | Ekran |
|---|---|---|
| 1 | `AppRadius` token'larına geçiş (16 farklı → 6 token) | Tüm ekranlar |
| 2 | `AppTypography` genişlet ve fontSize sabitlerini temizle | Tüm ekranlar |
| 3 | `AppTheme.textMuted` → context-aware `textMutedColor(context)` | Profile, Matchmaking |
| 4 | `Colors.orange` / `Colors.redAccent` → tema token'ı | Quiz, Profile |
| 5 | Dil değiştirici birleştir (settings ↔ profile) | Settings, Profile |

### P3 — Gelecek İyileştirmeler

| # | Hedef |
|---|---|
| 1 | `ZankurdQuizOption` → quiz logic ile entegrasyon (en karmaşık) |
| 2 | List row component (shop + subcategory + settings) |
| 3 | Chip/pill component |
| 4 | Language toggle component |
| 5 | Hero gradient kart standardizasyonu |

---

## 10. Güvenli Uygulama Sırası (Önerilen)

```
1. Quiz Result — ZankurdMetricTile (coin/XP birleştir)
   ├─ En güvenli: birebir kopya 2 tile → 1 component
   ├─ Risk: Düşük
   └─ Tahmini değişiklik: Küçük (~30 satır)

2. Shop — ZankurdButton (satın al)
   ├─ Touch target düzelir, basit değişiklik
   ├─ Risk: Düşük
   └─ Tahmini değişiklik: Küçük (~10 satır)

3. Profile/Settings — ZankurdSectionHeader + ZankurdMetricTile
   ├─ Manuel başlıklar → component
   ├─ Risk: Düşük-Orta
   └─ Tahmini değişiklik: Orta (~50 satır)

4. Home — ZankurdCard (hero, missions) + ZankurdButton (room actions)
   ├─ Kart ve buton component'leri
   ├─ Risk: Orta
   └─ Tahmini değişiklik: Orta (~80 satır)

5. Quiz — ZankurdQuizOption (en karmaşık)
   ├─ Logic + state + provider ile iç içe
   ├─ Risk: YÜKSEK
   └─ Tahmini değişiklik: Büyük (önce plan gerekir)

6. Category/Subcategory — ZankurdCard
   ├─ Gradient yapısı karmaşık
   ├─ Risk: Orta
   └─ Tahmini değişiklik: Orta

7. Room/Matchmaking — ZankurdCard + ZankurdButton
   ├─ Hero kartlar ve butonlar
   ├─ Risk: Orta
   └─ Tahmini değişiklik: Orta
```

---

## Özet

| Metrik | Değer |
|---|---|
| Taranan ekran | 7 |
| Sabit renk kullanımı | ~135 `Color(0xFF...)` satırı |
| Farklı radius değeri | 16 |
| Farklı fontSize değeri | 21 |
| Touch target riski | 7 nokta (3 P0) |
| Overflow riski | 8 nokta |
| Kontrast riski | 9 nokta (2 P0) |
| Tekrar eden component adayı | 11 |
| Yeni component'e geçiş noktası | 20+ |
