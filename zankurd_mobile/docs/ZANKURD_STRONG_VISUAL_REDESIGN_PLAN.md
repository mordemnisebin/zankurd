# ZANKURD — Güçlü Görsel Yeniden Tasarım Planı
> **Tarih:** 2026-07-08 | **Durum:** Analiz tamamlandı — Kod değişikliği yok  
> **Amaç:** Uygulamayı mobil mağaza kalitesinde, modern quiz/eğitim/dil öğrenme uygulaması seviyesine taşımak

---

## 1. Neden Aşama 1 İyileştirmeleri Yetersiz Kaldı?

Aşama 1, esas olarak **lokal ve savunmacı** bir polish oldu:

| Yapılan | Neden Yetersiz |
|---|---|
| Spacing/padding düzeltmeleri | Kompozisyon problemi varlığını koruyor |
| Chip/overflow fix | Overflow görünümü düzeltildi ama profil `_StatTile` satır sorunu hâlâ var |
| Kart gölgesi ve border | Kartların kendisi tasarım olarak güçsüz kaldı |
| Renk token temizliği | Renk sistemi değişmedi, aynı soluk palet devam etti |
| Küçük tipografi düzeltmeleri | Typographic hierarchy kurulmadı |

**Kök neden:** Aşama 1 mevcut bileşenlerin içine küçük müdahaleler yaptı. Ama gerçek problem bileşenlerin kendisinin tasarım diliyle, ekranların kompozisyonuyla ve sistemin bütünlüğüyle ilgili. "Kötü yerleşim düzenine gölge eklemek" onu premium yapmaz.

---

## 2. Screenshotlara Göre En Zayıf 10 Görsel Sorun

### Sorun 1 — Onboarding ekranı neredeyse tamamen boş
**Ekran:** `phase1-desktop-current.png` (Hîn bibe sayfası)  
Küçük bir ikon + başlık + altta tek buton. Ekranın %70'i tamamen boş beyaz/krem alan. Bir eğitim uygulamasının onboardinginin bu kadar zayıf olması kullanıcıyı ilk saniyede kaybediyor.

### Sorun 2 — Profile name gate ekranı izole ve yetim görünüyor
**Ekran:** `after_guest.png`  
İkon + başlık + input + buton. Krem arka plan üzerinde hiçbir görsel güç yok. Bu ekran "uygulama kurulum wizard'ı" gibi hissettiriyor, bir dil öğrenme platformu gibi değil.

### Sorun 3 — Profil ekranında `_StatTile` taşıyor
**Ekran:** `profile_for_navigation.png`  
4 adet `_StatTile` yan yana `GridView`'da dizili ama içerik (ikon + value + label) `mainAxisExtent` sınırını aşıyor → `BOTTOM OVERFLOWED BY 3.3 PIXELS` hatası her tile'da görünüyor.

### Sorun 4 — Profil hero alanı cansız
**Ekran:** `profile_for_navigation.png`  
Avatar bir Z harfi olan yuvarlak kart, başlık ve level bar. Bir "oyuncu kimliği" hissi vermiyor. Avatar büyük değil, seviye/XP vurgusu yetersiz. Rozet showcase ve achievement görseli yok.

### Sorun 5 — Ana sayfa header alanı çok geniş ve boş
**Ekran:** `home_quickplay_dark_clean.png`  
Üst kısımda coin göstergesi sol üstte, selamlama ve misyon chip ortada-alt. Ama bu alanın çoğu koyu gradient ile dolu, hiçbir vizüel ağırlık merkezi yok. Streak, seviye veya kullanıcı avatarı bu alanda yer almıyor.

### Sorun 6 — Quick Play kartları "vitrin" gibi hissettirmiyor
**Ekran:** `home_quickplay_dark_clean.png`  
Şerê 1vs1 (kırmızı), Pêşbirka Rojê (sarı), Çerxa Rojê (yeşil), Turnuva (teal) — 4 kart 2x2 grid. Kartlar düz blok renkli, ikon küçük, başlık küçük, alt etiket (Zindî, 10 pirs, 100 coin, Kûpa) çok ufak ve soluk. Bu kartların her biri bir "oyun modu vitrini" gibi olmalı.

### Sorun 7 — Kategori ekranı hiyerarşisi zayıf
**Ekran:** `categories_dark.png`  
Görseller güzel (AI üretimi) ama metin sadece kategori adı + "5 ast · pêşbaz". İlerleme yok, kişiselleştirme yok, lock/unlock hissi yok. Üst kısımda "Kategorî" başlığı + ince alt başlık var ama hero alan kullanılmıyor.

### Sorun 8 — Bottom navigation çok sade ve jenerik
**Ekranlar:** Tüm screenshot'lar  
Material 3 NavigationBar varsayılan görünümü. Seçili tab pembe daire + pembe ikon. Ama bu seçili durum ile seçilmemiş durum arasındaki kontrast yeterli değil. Label'lar küçük, animated indicator basit.

### Sorun 9 — Günlük misyon kartı yeterince önde değil
**Ekran:** `home_quickplay_dark_clean.png` (altta kısmen görünüyor)  
"Erkên Rojane" başlığı, 0/3 progress, %0 chip. Bu kart hiçbir şekilde motive edici görünmüyor. İlerleme çubuğu, ödül önizlemesi, görev sayacı görsel olarak çok zayıf.

### Sorun 10 — Light/dark tutarsızlığı ve renk sisteminin bütünlük eksikliği
**Ekranlar:** Tüm screenshot'lar  
Dark modda ana sayfa daha premium görünüyor. Light modda kategori ekranı beyaz/krem arka planda "çocuksu" bir duygu veriyor. Aynı bileşenler iki modda farklı ağırlık veriyorlar. Tek bir güçlü "ürün hissi" yok.

---

## 3. Zankurd İçin Daha İddialı Yeni Görsel Yön

### 3.1 Ürün Hissi

**Hedef his:** *"Kürt kültürünün modern dijital platformu"*

Referanslar: Duolingo'nun oyunlaştırması + Brilliant'ın premium içerik sunumu + Linear'ın tasarım özeni. Ama bunların Kürtçe/kültürel kimliği olan versiyonu.

- Kullanıcı her ekrana girdiğinde "bu bir ürün" hissini almalı
- Her ekranın bir amacı, bir kahramanı ve bir aksiyonu olmalı
- Görsel yorgunluk yaratmadan enerji ve öğrenme hissi
- Kürt kültürel öğeleri (Roj/güneş motifi, kilim geometry, govend halkası) UI'ye nazik ama özgün biçimde entegre

### 3.2 Renk Sistemi (Yeni)

Mevcut token'lar korunsun ama **daha sistematik** kullanılsın:

| Token | Değer | Kullanım |
|---|---|---|
| `surface-0` | Tam koyu/tam açık zemin | Scaffold bg |
| `surface-1` | Kart/panel zemin | AppPanel |
| `surface-2` | Elevated kart | Modal, seçili kart |
| `accent` (mevcut yeşil) | Ana CTA, quiz correct | Ana buton, progress |
| `coral/kırmızı` | 1vs1, rekabet, wrong | VS kart, hata rengi |
| `amber/gold` | Ödül, liderlik, level | Coin, XP, puan |
| `violet` | Sosyal, takım, oda | Oda kartı, takım modu |
| `teal` | Turnuva, özel mod | Turnuva kartı |
| `pink/rose` | Seçili nav, CTA vurgu | Bottom nav selected |

**Kural:** Gradientler sadece hero alanlarda ve oyun modu kartlarında. Normal panel ve liste öğelerinde flat surface rengi.

### 3.3 Kart Sistemi (Yeni)

**3 kart tipi:**

```
Type A — Surface Card (çoğunluk)
  - Düz surface-1 rengi
  - 16px radius
  - 1px border (borderColor 0.15)
  - subtle shadow (0 2px 8px black 0.08)
  - İçerik: ikon + başlık + metadata

Type B — Accent Card (oyun modları)
  - Güçlü gradient arka plan (mod kimliğine göre)
  - 20px radius
  - Büyük ikon (48px), büyük başlık (18-20px bold)
  - Alt etiket chip (status/ödül bilgisi)
  - Decorative overlay: 0.06 opacity hafif grain

Type C — Hero Card (tek per ekran, maksimum vurgu)
  - Tam genişlik veya 2/3 genişlik
  - Zengin gradient, blur overlay
  - Başlık 22-26px, alt açıklama 14px
  - 2 CTA buton
  - Avatar veya büyük ikon
```

### 3.4 Bottom Navigation Sistemi (Yeni)

**Mevcut sorun:** Material 3 default, sıradan.

**Yeni yön:**
- Seçili item: dolgu rengi pill/lozenge şekli (arka plan accent rengi %15 opacity + ikon tam renk)
- Seçilmemiş: ikon gri/muted, label yok veya çok küçük
- Yükseklik: 64-68px
- Animasyon: seçildiğinde hafif scale up (1.0 → 1.1) + renk fade
- Üst kenar: temiz 0.5px border

### 3.5 Hero Sistemi (Yeni)

Her ana tab için farklı hero tasarımı:

- **Ana Sayfa hero:** Kişiselleştirilmiş (Selamlama + streak + günlük ilerleme) — tam genişlik, koyu gradient
- **Kategori hero:** Minimal başlık + search bar (kartlar kahraman)
- **Xwendin hero:** Öğrenme özeti (son çalışılan) — progress ring ile
- **Pêşbaz hero:** Sıralama + puan — gold/amber temalı
- **Profil hero:** Avatar + seviye + rozet sayısı — kişisel kimlik kartı

### 3.6 Rozet/Ödül Sistemi (Yeni)

**Mevcut:** Rozet adları metin + kilit ikonu.  
**Yeni:**
- Kilit açık rozet: renkli daire + ikon, parlak kenar
- Kilit kapalı rozet: gri/muted daire + kilit, daha küçük
- Coin chip: amber arka plan, coin ikonu + sayı, pill
- XP chip: mor/yeşil, XP ikonu + değer, pill
- Streak chip: turuncu/ateş, zincir/alev ikonu + gün
- Seviye badge: gradient pill, yıldız/kalkan + "Ast X"

### 3.7 Typography Sistemi (Yeni)

**5 seviye hiyerarşi — 11px altı yasak:**

| Seviye | Boyut | Ağırlık | Kullanım |
|---|---|---|---|
| Display | 28-32px | w900 | Splash, büyük onboarding başlığı |
| Heading | 22-24px | w800 | Ekran başlığı, hero başlık |
| Title | 17-20px | w700 | Kart başlığı, section header |
| Body | 14-15px | w500 | Normal metin, açıklama |
| Caption | 11-12px | w500 | Metadata, etiket, chip |

### 3.8 Onboarding Sistemi (Yeni)

Her slide yeni yapısı:

```
┌─────────────────────────────────────┐
│  [Logo küçük] [Derbas bike]         │
├─────────────────────────────────────┤
│                                     │
│   [Büyük illustratif blok]          │ ← %50 yükseklik
│   (gradient bg + büyük ikon/sahne)  │
│                                     │
├─────────────────────────────────────┤
│  [Büyük başlık — 26-28px, w900]     │
│  [Kısa açıklama — maks 2 satır]     │
│                                     │
│  [3 madde — ikon + kısa metin]      │
│                                     │
├─────────────────────────────────────┤
│  [dots indicator]                   │
│  [Piştî vê →]  (geniş, renkli)      │
└─────────────────────────────────────┘
```

---

## 4. Ana Sayfa İçin Güçlü Yeni Kompozisyon

**Mevcut:**
```
[coin] ← sadece sol üst köşe
[geniş boş gradient alan]
[selamlama + isim]
[misyon chip]
[hero card] [2x2 quick play grid]
[günlük görev kartı - yarım görünüyor]
```

**Yeni:**
```
┌──────────────────────────────────────────┐
│ COMPACT HERO BAR                         │
│ [Avatar 36px] [Selamlama + isim]  [coin] │
│ [Streak chip] [Seviye badge]             │
│ [Günlük misyon progress bar — ince]      │
├──────────────────────────────────────────┤
│ LIVE ROOM HERO CARD (tam genişlik)       │
│ Büyük başlık, 2 CTA, canlı oyuncu sayısı│
├──────────────────────────────────────────┤
│ ZÛ BİLİZE — OYUN MODELERİ               │
│ [Şerê 1vs1]  [Pêşbirka Rojê]            │  ← Type B kart
│ [Çerxa Rojê] [Turnuva]                   │
├──────────────────────────────────────────┤
│ ERKÊN ROJANE (Günlük Görevler)          │
│ Progress ring + 3 görev + toplam ödül   │
└──────────────────────────────────────────┘
```

---

## 5. Onboarding/Başlangıç Ekranları İçin Güçlü Yeni Kompozisyon

### Profile Name Gate Ekranı

**Yeni:**
```
┌──────────────────────────────────────┐
│  [Üst %45 — gradient hero alanı]    │
│  Logo büyük + Roj motifi overlay    │
│  "ZanKurd'a Xweş Hatî" başlığı     │
│  Kısa tagline                        │
├──────────────────────────────────────┤
│  [Alt %55 — form alanı]             │
│  "Navê te di lîstikê de çi be?"    │
│  3 değer maddesi (ikon + kısa metin)│
│  Input field                         │
│  Geniş CTA butonu                   │
└──────────────────────────────────────┘
```

### Onboarding Slides

**Slide 1 — Hîn bibe:** Büyük kitap ikonu + "Kurmancî hîn bibe" (28px, w900) + 3 madde: Pirs → Xal → Zincîr

**Slide 2 — Pêşbikeve:** İki figür + VS rozeti + "Bi hevalan re pêşbikeve" + 3 madde

**Slide 3 — Keşfet:** Kategori mozaiği + "8 kategorî, bêhejmar pirs" + 3 madde + "Zankurd'ê Veke"

---

## 6. Kategori Ekranı İçin Premium Mobil Grid Önerisi

**Mevcut:** 5-sütunlu horizontal scroll + flat kart. Sadece görsel + isim + "5 ast · pêşbaz".

**Yeni — 2 sütun grid:**

```
┌──────────────────────────────────────┐
│ COMPACT HEADER + arama ikonu         │
├──────────────────────────────────────┤
│ FEATURED CATEGORY (tam genişlik)    │
│ Haftanın öne çıkan kategorisi       │
├──────────────────────────────────────┤
│ [Ziman]      [Dîrok]               │
│ [Siyaset]    [Muzîk]               │  ← 2 sütun
│ [Paradigma]  [Edebiyat]            │
│ [Cografya]   [Çand]                │
└──────────────────────────────────────┘
```

**Her kart:** Görsel %60 + isim + soru sayısı + progress bar + lock badge

---

## 7. Profil Ekranı — Overflow Çözümü ve Dashboard Kalitesi

### 7.1 Overflow Fix (Acil)

**Sorun:** `_StatTile` GridView `mainAxisExtent` değeri küçük → 3 satır içerik sığmıyor.

**Çözüm A** (en güvenli): `mainAxisExtent: 88` (veya benzeri yeterli değer)  
**Çözüm B**: `crossAxisCount: 4` tek satır + daha kompakt tile layout

### 7.2 Yeni Dashboard Düzeni

```
┌──────────────────────────────────────────┐
│ HERO SECTION (gradient, 200px+)          │
│ [Büyük avatar 72px] [İsim 22px bold]     │
│ [Seviye badge] [XP progress ring]        │
│ [Streak chip] [Rozet sayısı chip]        │
├──────────────────────────────────────────┤
│ 4 STAT TILE — tek satır, 4 sütun        │
│ [Sıra] [Puan] [Seri] [Oyun]            │
├──────────────────────────────────────────┤
│ ACHIEVEMENTS (horizontal scroll)         │
│ [Rozet 1] [Rozet 2] [Rozet 3] [Hemu →] │
├──────────────────────────────────────────┤
│ HAFTALIK PERFORMANS GRAFİĞİ             │
├──────────────────────────────────────────┤
│ QUICK LINKS listesi                      │
└──────────────────────────────────────────┘
```

---

## 8. Shop, Liderlik ve Quiz Sonuç İçin Görsel Yön

### Shop
- Üstte büyük amber coin bakiyesi hero chip
- Ürünler: 2 sütun grid veya büyük liste kartları
- Satın al CTA: tam genişlik, min 48px, "Bikire — X Coin"
- Sahip olunan: yeşil "Hatiye Kirin" badge

### Liderlik (Pêşbaz)
- Podium section: 1. altın, 2. gümüş, 3. bronz — büyük platform tasarımı
- Kullanıcı kendi satırı: vurgulu/sticky
- Filtre: Günlük / Haftalık / Tüm Zamanlar

### Quiz Sonuç
- Büyük dairesel progress ring (doğru oran) ortada
- Coin + XP animasyonlu sayaç
- Yeni rozet: büyük gösterim
- CTA: "Dîsa Lîst" (yeşil) + "Malê" (outline)

---

## 9. Yüksek Etki + Düşük Risk Ekranlar

| Ekran | Neden Düşük Risk | Etki |
|---|---|---|
| `profile_name_gate_screen.dart` | Saf UI, sıfır logic, 199 satır | Çok yüksek — ilk izlenim |
| `onboarding_screen.dart` | UI-only, onComplete callback koruluyor | Çok yüksek — ilk izlenim |
| `app_shell.dart` (bottom nav) | NavigationBar parametreleri, logic yok | Yüksek — her ekranda görünür |
| Profil StatTile overflow fix | `mainAxisExtent` tek değer değişikliği | Yüksek — crash hissi kaldırır |

---

## 10. Yüksek Etki + Orta/Yüksek Risk Ekranlar

| Ekran | Risk Nedeni | Etki |
|---|---|---|
| `home_screen.dart` | 31KB, provider bağlantısı | Çok yüksek |
| `categories_tab.dart` | CategoryVisuals kompleks | Yüksek |
| `profile_screen.dart` | 67KB, stats/achievements/chart | Yüksek |
| `quiz_screen.dart` | Logic ile iç içe geçmiş | Çok yüksek |
| `quiz_result_screen.dart` | Animasyon + sayfa akışı | Yüksek |
| `shop_screen.dart` | Coin transaction mantığı | Orta |

---

## 11. Önce Hangi 3 Ekran Dönüştürülmeli?

### Paket — "İlk İzlenim" Dönüşümü

**1️⃣ Onboarding + Profile Name Gate (En Yüksek Öncelik)**
- Sıfır logic riski
- Kullanıcının ilk gördüğü ekranlar
- Boş beyaz zemin → güçlü hero kompozisyonu
- Dosyalar: `onboarding_screen.dart` + `profile_name_gate_screen.dart`

**2️⃣ Bottom Navigation (AppShell)**
- Tüm ekranlarda sürekli görünür
- NavigationBar parametreleri — saf UI
- Dosya: `app_shell.dart` NavigationBar bloğu

**3️⃣ Profil StatTile Overflow Fix + Hero Güçlendirme**
- Overflow bug kaldırılır
- Hero avatar/seviye/XP güçlendirilir
- Dosya: `profile_screen.dart` — 2-3 bölge

---

## 12. Hangi Değişiklikler Sadece UI?

| Değişiklik | Dosya | Logic Riski |
|---|---|---|
| Onboarding slide layout ve hero | `onboarding_screen.dart` | **Sıfır** |
| Profile name gate hero alanı | `profile_name_gate_screen.dart` | **Sıfır** |
| Bottom nav seçili durum stil | `app_shell.dart` | **Sıfır** |
| `_StatTile` mainAxisExtent fix | `profile_screen.dart` | **Sıfır** |
| Profil hero avatar/seviye düzeni | `profile_screen.dart` | Çok Düşük |
| Home header avatar+streak ekleme | `home_screen.dart` | Düşük |
| Kategori kart 2-sütun grid | `categories_tab.dart` | Düşük |
| Quick play kart görsel güçlendirme | `home/quick_play_grid.dart` | Düşük |

---

## 13. Hangi Değişikliklerde Logic Riski Var?

| Değişiklik | Neden Riskli | Öneri |
|---|---|---|
| Quiz option kartları | State + provider ile iç içe | **Dokunma — Aşama 3** |
| Quiz result coin animasyonu | AnimationController chain | Ayrı analiz gerekir |
| Kategori kilit/unlock sistemi | Backend veri bağlantısı | Ayrı analiz |
| Liderlik podium | Realtime sıralama verisi | Dikkatli |
| Shop satın alma CTA | Coin transaction trigger | Sadece button size, mantık dokunma |

---

## 14. Kod Uygulamasına Geçmeden Önce Net Plan

### Aşama 2A — İlk İzlenim Paketi (Onay Bekleniyor)

| # | Dosya | Değişiklik | Risk |
|---|---|---|---|
| 1 | `onboarding_screen.dart` | Her slide'a güçlü hero blok | Sıfır |
| 2 | `profile_name_gate_screen.dart` | Üst %45 gradient hero + form | Sıfır |
| 3 | `app_shell.dart` | Bottom nav premium pill indicator | Sıfır |
| 4 | `profile_screen.dart` | `_StatTile` overflow fix | Sıfır |

**Kesinlikle dokunulmayacaklar:**
- `app_theme.dart`
- Quiz logic dosyaları
- Supabase / repository / auth
- Route / provider yapısı
- Yeni dependency eklenmez

---

## Ekran Bazlı Özel Yorumlar

### 🟥 Başlangıç / İsim Giriş (`after_guest.png`)
Açık krem zemin üzerinde izole form. Uygulamanın "Kürt kültürü + modern eğitim" hissi tamamen yok. Kullanıcı uygulamayı anlayamıyor. **Düzeltme:** Üst yarı gradient hero (koyu yeşil → deep slate), logo, tagline "Hîn bibe, pêş bike" + altta form. Pure UI, sıfır risk.

### 🟥 Onboarding / "Hîn bibe" (`phase1-desktop-current.png`)
Küçük pembe kitap ikonu + metin + altta buton. Ekranın %65'i boş. Duolingo ve Brilliant bu kadar boş değil. Her slide büyük ikon/sahne bloğu içermeli. **En az risk, en yüksek görsel etki** değişikliği budur.

### 🟨 Ana Sayfa / Quick Play (`home_quickplay_dark_clean.png`)
Dark modda daha iyi. Oda hero kartı güçlü ama sağdaki 2x2 grid küçük ikon + küçük başlıkla vitrin hissi vermiyor. Coin köşede izole, streak/seviye/avatar eksik. **Orta öncelik, orta risk.**

### 🟨 Kategori Ekranı (`categories_dark.png`)
AI görselleri güçlü ama sadece isim + "5 ast · pêşbaz". İlerleme yok, kişiselleştirme yok. 2 sütun grid + progress bar eklenmesi çok iyileştirici olur.

### 🟥 Profil Ekranı (`profile_for_navigation.png`)
**Kritik:** Her tile'da "BOTTOM OVERFLOWED BY 3.3 PIXELS" hatası. Bu hem görsel hem algısal olarak kötü. Overflow fix en öncelikli adım. Avatar mevcut ama hero alanı güçsüz.

### 🟥 Boş Beyaz Görünen Ekran
`after_guest.png` tam olarak bu. Saf krem zemin, küçük ortalanmış içerik. Bu pattern tüm uygulamada sıfırlanmalı — her ekranda hero veya güçlü arka plan olmalı.

### Shop / Liderlik / Quiz Sonuç
- **Shop:** Küçük satın al CTA (P0 touch target), ürün görsel eksikliği
- **Liderlik:** Standart liste, podium yok, altın/gümüş/bronz hiyerarşisi yok
- **Quiz Sonuç:** Güçlü ama navy renk light modda kontrast sorunu; coin/XP tile kod tekrarı

---

## Özet Tablo

| Alan | Mevcut Durum | Hedef | Öncelik |
|---|---|---|---|
| Onboarding | Boş, zayıf | Hero + 3 madde + CTA | P0 |
| Name Gate | İzole form | Gradient hero + form | P0 |
| Bottom Nav | Material default | Premium pill indicator | P0 |
| Profile Overflow | Visible crash | Düzeltildi | P0 |
| Profile Hero | Küçük avatar | Büyük kimlik hero | P1 |
| Quick Play | Küçük kartlar | Type B vitrin kartlar | P1 |
| Kategori Grid | 5-sütun flat | 2-sütun + progress | P1 |
| Home Header | Coin köşede | Avatar+streak kimlik şeridi | P1 |
| Tipografi | 21 farklı size | 5 seviye sistem | P2 |
| Token kullanımı | %10 token | %80 token | P2 |

---

> **Bu planı onaylarsan, önce sadece onboarding + ana sayfa + profil overflow için yüksek etkili ama kontrollü görsel dönüşüm paketini uygulayacağım. Aşama 2'ye geçmek için onay bekliyorum.**
