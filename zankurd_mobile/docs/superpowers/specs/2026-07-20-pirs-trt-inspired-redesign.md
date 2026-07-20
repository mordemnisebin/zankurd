# ZanKurd — Pirs + TRT Bil Bakalım İlhamlı Tam Görsel Yenileme

**Tarih:** 2026-07-20  
**Karar:** Kullanıcı son karar — "benzeri uygulamalara göre yap tamamen"  
**Araştırma kaynakları:** Pirs APK (paketten çıkartılmış XML + layout), önceki TRT araştırması

---

## 1. Teşhis — Neden Şu Hali "Cansız"?

Koddan çıkan gerçek sorunlar:

| Sorun | Kaynak | Pirs'te Nasıl? |
|---|---|---|
| `homeHeaderGradient = #0B251C → #1A4E3B` — koyu orman yeşili, ağır | `app_theme.dart:408` | Turuncu gradient header + kullanıcı profili |
| Cevap seçenekleri: A=kırmızı, B=mavi, C=yeşil, D=sarı — 4 renk aynı anda | `app_theme.dart:560-565` | Nötr `#F1F1F4` bg + sadece harf badgesi renkli |
| Light mode `lightBg = #FBF9F6` — sıcak bej, parlak değil | `app_theme.dart:371` | `~#F3F3F3` (soğuk açık gri, temiz) |
| Ana header: küçük maskot + "ZanKurd" yazısı | `home_header.dart:29-61` | CircleAvatar + isim + coin/skor/streak chip'leri |
| Oyun modu kartları (QuickPlay) küçük grid | `quick_play_grid.dart` | Tam genişlik, büyük gradient kartlar |
| Varsayılan: koyu tema algısı yüksek (karanlık header göze çarpıyor) | `app_theme.dart:408` | Açık tema birincil, turuncu header |

---

## 2. Pirs APK'dan Çıkarılan Gerçek Renk Değerleri

APK binary XML dosyalarından literal hex değerler (AARRGGBB formatından çevrildi):

```
gradient_orange.xml:
  startColor: #E37A42  (sıcak terrakota turuncu)
  endColor:   #EC9B40  (altın-turuncu)

gradient_category.xml (örnek mor kategori):
  startColor: #A25BDF  (mor/violet)
  endColor:   #EA7AC6  (pembe/magenta)

ic_coinsmax.xml (coin ikonu):
  fill1: #FEA832  (parlak altın turuncu — logo rengi)
  fill2: #FE9923  (koyu altın)
  highlight: #FEDB41  (açık sarı-altın)

option_bg.xml (cevap seçenek arka planı):
  color: #F1F1F4  (çok açık gri, neredeyse beyaz)

ic_battle_quiz.xml (ikon secondary text):
  color: #4E5366  (mavi-gri — ikincil ikon/metin)

Uygulama genel arka plan (activity_main bg ref'inden çıkarım + option bg ile tutarlı):
  ~#F3F3F3 → #FFFFFF (kartlar)

Layer-list gölge (main_btn.xml, answer_bg.xml):
  shadow: #BBBDCB  (mavi-gri gölge, 3D etkisi)
  base:   #FFFFFF  (düz beyaz üst katman)
```

---

## 3. Yeni Renk Paleti (app_theme.dart değişiklikleri)

### Light Mode (Birincil — Pirs hizası)

```dart
// ZEMİN
static const lightBg = Color(0xFFF3F3F5);       // #F3F3F5 — Pirs-stil soğuk açık gri (eski #FBF9F6 yerine)
static const lightBgDeep = Color(0xFFEAEAED);   // kartların içinde derin zemin
static const lightSurface = Color(0xFFFFFFFF);  // Beyaz kart yüzeyi (değişmez)
static const lightSurfaceHi = Color(0xFFF7F7F9); // yüksek yüzey

// SINIR
static const lightBorder = Color(0xFFE2E2E8);   // #E2E2E8 — Pirs-stil soğuk kenarlık

// METİN
static const lightTextPrimary = Color(0xFF1A1A24); // #1A1A24 — derin lacivert/siyah
static const lightTextSub = Color(0xFF4E5366);     // #4E5366 — Pirs'in gerçek ikon rengi
static const lightTextMuted = Color(0xFF7A7D8F);   // #7A7D8F — soluk metin

// MARKA (değişmez)
// brandGreen = #F5931E — ZanKurd turuncu (Pirs hizası) — zaten doğru

// PIRS GERÇEK TURUNCU GRADİENT (header + CTA kartlar için)
static const pirsOrangeStart = Color(0xFFE37A42); // Pirs gradient_orange.xml startColor
static const pirsOrangeEnd   = Color(0xFFEC9B40); // Pirs gradient_orange.xml endColor

// HOME HEADER GRADİENT — ESKİ KOYU YEŞİL YERİNE TURUNCU
static const homeHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [pirsOrangeStart, pirsOrangeEnd],
);
// NOT: dark mod için homeHeaderGradient aynı gradient (Pirs varsayılan açık)
```

### Cevap Seçenek Renkleri (Pirs Stili)

```dart
// ESKİ: Her seçenek farklı renkli bg (4 renk aynı anda — yoğun)
// YENİ: Nötr bg + sadece harf badgesi renkli (Pirs stili, temiz)

static const answerOptionBg = Color(0xFFF1F1F4);  // Pirs option_bg.xml — nötr
static const answerOptionBorder = Color(0xFFE2E2E8); // İnce kenarlık

// Harf badge renkleri (A/B/C/D — küçük daire, köşe değil tüm bg)
static const List<Color> answerOptionColors = [
  Color(0xFFE8482F), // A — kırmızı (harf badge)
  Color(0xFF1A6FCF), // B — mavi (harf badge)
  Color(0xFF0D8A4C), // C — yeşil (harf badge)
  Color(0xFFE6B800), // D — amber (harf badge)
];
// NOT: Bu renkler artık sadece harf badge'ine uygulanır, seçenek bg'sine değil
```

### Dark Mode (İkincil — Pirs de dahice açık varsayılan kullanır)

Dark mod mevcut token'ları büyük ölçüde koruyabilir. Sadece:
```dart
// bg = #0B0F0D (kalır)
// surface, surfaceHi (kalır)
// homeHeaderGradient — dark modda da turuncu (marka tutarlılığı)
```

---

## 4. Ekran Bazlı Tasarım Kararları

### 4.1 Ana Ekran Header (`home_header.dart`)

**Mevcut:** Maskot ikonu + "ZanKurd" yazısı + coin badge + dil toggle + tema toggle (hepsi tek satırda)

**Yeni (Pirs stili):** Gradient arka planlı tam genişlik header şeridi

```
┌─────────────────────────────────────────────┐
│  [🟠 GRADIENT ARKA PLAN: #E37A42 → #EC9B40] │
│  ┌──────────────────────────────────────┐   │
│  │ ⬤ [Avatar]  ZanKurd         💰 142  │   │
│  │             Pêşbirka Kurmancî  🔥 7  │   │
│  │                              🏆 #12  │   │
│  └──────────────────────────────────────┘   │
│  Dil: KU/TR toggle (ikon)  Tema: ☀/🌙      │
└─────────────────────────────────────────────┘
```

**Widget değişiklikleri (`home_header.dart`):**
- `HomeHeader` widget'ına `Container` ile turuncu gradient bg ekle (16dp altta yuvarlatılmış köşeler)
- Coin badge: `goldGradient` yerine nötr pill (beyaz bg + altın metin) — daha temiz
- Streak: ateş ikonu + sayı, kompakt
- Skor/sıralama: opsiyonel (profil yoksa gizle)

### 4.2 Oyun Modu Kartları (`quick_play_grid.dart`)

**Mevcut:** 2×2 küçük grid (QuickPlay kartlar)

**Yeni (Pirs stili):** Tam genişlik dikey sıralı büyük kartlar, her kartın sağında büyük dekoratif ikon

```
┌─────────────────────────────────────────────┐
│  ⚡ ÇABUK OYNA         →   [🎮 ikon 50% alpha] │
│     "Rastgele soru seti"                    │
│  [GRADİENT: turuncu/kırmızı → koyu]        │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  👥 GRUP SAVAŞI        →   [⚔️ ikon 50% alpha] │
│     "Arkadaşlarınla yarış"                  │
│  [GRADİENT: mor → koyu mor]                │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  🤺 1v1 MAÇI           →   [🏹 ikon 50% alpha] │
│     "Birebir rekabet"                       │
│  [GRADİENT: pembe → koyu pembe]            │
└─────────────────────────────────────────────┘
```

**Widget değişiklikleri:**
- `QuickPlayGrid` → `QuickPlayCards` (list değil sıralı Column)
- Her kart: `height: 88`, `borderRadius: 16`, tam genişlik (`double.infinity`)
- Sağda dekoratif ikon: `Positioned(right: 16, child: Icon(size: 48, color: Colors.white.withOpacity(0.25)))`
- Kart arası boşluk: 10dp

### 4.3 Quiz Cevap Seçenekleri (`quiz_screen.dart`)

**Mevcut:**
```dart
Container(
  color: AppTheme.answerOptionColors[index],  // Her seçenek farklı renk bg
  child: Text(answer),
)
```

**Yeni (Pirs stili — nötr bg + harf badge):**
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.answerOptionBg,           // #F1F1F4 nötr (light)
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppTheme.answerOptionBorder),
    // Seçilince / doğru/yanlış: renk burada gelir
  ),
  child: Row(
    children: [
      // Harf badge (sadece bu renkli)
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppTheme.answerOptionColors[index],  // A/B/C/D rengi
          shape: BoxShape.circle,
        ),
        child: Text(['A','B','C','D'][index], style: ...white bold),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(answer, style: AppTypography.quizAnswer)),
    ],
  ),
)
```

**Durum renklendirmesi:**
- Seçildi (bekliyor): kenarlık `accent` (turuncu), bg açık turuncu tint
- Doğru: kenarlık + bg tint `correct` (#3DA968)
- Yanlış: kenarlık + bg tint `wrong` (#E5533D)

### 4.4 Kategori Kartları (`home_screen.dart` grid)

Mevcut kategori gradientleri zaten iyi (canlı renkler). **Değişiklik yok.** Sadece:
- Kart yüksekliği: tutarlı `88–96dp` (şu an değişken olabilir)
- İkon: `35dp`, `alpha: 0.5` dekoratif (Pirs gibi, mevcut tasarıma zaten benzer)

### 4.5 Hero Card (`hero_card.dart`)

**Yeni:** Pirs'in "SpinBanner" eşdeğeri — günlük/öne çıkan kart

```
┌─────────────────────────────────────────────┐
│  BUGÜNÜN KONUSU                             │
│  "Kürt Tarihi"           [📚 ikon]          │
│                                             │
│  [▶ BAŞLA]  kart tüm genişlik              │
│  [GRADİENT: pirsOrangeStart → pirsOrangeEnd]│
└─────────────────────────────────────────────┘
```

### 4.6 Sonuç Ekranı (`quiz_result_screen.dart`)

- Kazanma: başlık gradient turuncu, `🎉` animasyonu
- Puan: büyük `display` yazı tipi, ortada
- Doğru/Yanlış/Boş: küçük stat chip'leri
- CTA: "YENİDEN OYNA" FilledButton (turuncu), "Ana Menü" OutlinedButton

---

## 5. Şekil ve Gölge Dili

Pirs'ten çıkan şekil kararları:

```
Kart köşeleri:     16dp (AppRadius.md) — Pirs cardCornerRadius
Buton köşeleri:    12dp (AppRadius.sm) — şu anki değer korunuyor
İkon badge:        daire (BoxShape.circle) — harf badge için
Kart gölgesi:      BoxShadow(color: #BBBDCB at 0.15, blurRadius: 8, offset: (0,3))
                   — Pirs layer-list gölge yaklaşımı
Gradient açısı:    topLeft → bottomRight (45°, Pirs gradient.xml angle=45)
```

---

## 6. Uygulama Sırası (Faz Planı)

### Faz 1 — Token güncelleme (1 dosya, risk: sıfır)
**`lib/src/theme/app_theme.dart`**
- [ ] `lightBg`: `#FBF9F6` → `#F3F3F5`
- [ ] `lightBgDeep`: `#F0EBE6` → `#EAEAED`
- [ ] `lightBorder`: `#E8E4DF` → `#E2E2E8`
- [ ] `lightTextSub`: mevcut → `#4E5366` (Pirs gerçek değeri)
- [ ] `homeHeaderGradient`: `#0B251C→#1A4E3B` → `#E37A42→#EC9B40` (veya `brandGreen→brandGreenDeep`)
- [ ] `answerOptionBg` ve `answerOptionBorder` token'ları ekle
- [ ] `pirsOrangeStart`, `pirsOrangeEnd` token'ları ekle

> **Test:** `dart analyze` + uygulamayı başlat, renklerin değiştiğini gözle doğrula.

### Faz 2 — Home Header yenileme (1 dosya)
**`lib/src/screens/home/home_header.dart`**
- [ ] Tüm `HomeHeader` widget'ını turuncu gradient arka planlı konteynere sar
- [ ] Coin badge: minimal pill tasarımı
- [ ] Streak badge: kompakt (ikon + sayı)
- [ ] Avatar: `CircleAvatar` (harf tabanlı, renk profil senkronize)

> **Test:** Home ekranına git, header'ın turuncu gradient'li ve profil bilgisiyle göründüğünü doğrula.

### Faz 3 — Quiz cevap seçenekleri (1 dosya)
**`lib/src/screens/quiz_screen.dart`** (veya ilgili widget)
- [ ] Seçenek konteynerini: renkli bg → nötr `answerOptionBg` + renkli harf badge
- [ ] Durum rengi mantığı: kenarlık + bg tint (bg değişmez, vurgu kenarlıkta)

> **Test:** Oyun başlat, 4 cevap seçeneğinin nötr bg + renkli harf ile göründüğünü doğrula.

### Faz 4 — Oyun modu kartları (1–2 dosya)
**`lib/src/screens/home/quick_play_grid.dart`**
- [ ] Grid'i Column'a çevir (2×2 → dikey liste)
- [ ] Her kart: tam genişlik, 88dp yükseklik, gradient bg, dekoratif ikon
- [ ] Kart başlık + alt başlık (şu an sadece ikon var)

> **Test:** Home'un modu kartlarını kontrol et.

### Faz 5 — Kart köşe tutarlılığı
- [ ] Tüm `CardType.secondary` ve `CardType.primary` kullanımlarında `radius: 16` (AppRadius.md) kullan
- [ ] Hero card güncelleme

### Faz 6 — Sonuç + Profil ekranı temizleme (opsiyonel polish)

---

## 7. Korunanlar (Değiştirilmeyecekler)

- **Kategori gradient listesi** (`categoryGradients`) — zaten canlı ve doğru
- **Correct/Wrong renkleri** (`#3DA968` / `#E5533D`) — semantik anlam koruyucu
- **Gold** (`#E7B53C`) — coin/ödül semantiği korunuyor
- **Dark mode palette** — büyük ölçüde kalır, sadece homeHeaderGradient güncellenir
- **`isTemplateExplanation` guard** — dokunulmaz
- **Repository pattern** — mimari değişmez
- **Tüm test'ler** — 635 test geçiyor, faz sonunda da geçmeli

---

## 8. Önce Değil Sonra

**Önce:** Koyu ağır yeşil header, renkli cevap seçenekleri, küçük oyun modu grid'i  
**Sonra:** Turuncu gradient header + profil, nötr cevap seçenekleri + harf badge, tam genişlik mod kartları

Pirs farkı: Kullanıcı uygulamayı açtığında ilk gördüğü şey artık **turuncu, enerjik, profil odaklı bir header** olacak — Pirs ve TRT gibi quiz uygulamalarının ortak dili bu.
