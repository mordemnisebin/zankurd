# Karmaşıklık Giderme — Faz 0/4 + Faz 1/2 Denetimi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tasarım kararını (koyu-öncelikli + Bubblegum Arcade palet) tek gerçek
kaynağa sabitle, çakışan/süpersede spec'leri arşivle, gelecekte aynı spec
çakışması döngüsünün oluşmasını engelleyecek bir süreç kuralı ekle, ve
kod-değiştiren fazlar (içerik tekrarı temizliği, metin-yığını güzelleştirme,
dosya bölme) için gereken somut envanteri çıkar.

**Architecture:** Bu plan yalnızca dokümantasyon ve envanter çıkarma
işleridir — hiçbir Dart/UI kodu değişmez, hiçbir davranış etkilenmez. Her
görev bağımsız commit'lenir. Faz 1/2 envanter görevleri (Task 4, 5)
bulgu-üretir; bulunan somut tekrarlar/metin-yığını noktaları, bu görevlerin
çıktısına dayanarak yazılacak **ayrı bir takip planında** (kod değişikliği
içeren) ele alınacak — çünkü hangi widget'ın nereye taşınacağı bu planın
yazıldığı an itibarıyla henüz bilinmiyor (spec'in "Sınırlar" bölümüyle
tutarlı: placeholder/varsayımsal adım yazılmaz).

**Tech Stack:** Flutter/Dart (zankurd_mobile), Markdown dokümantasyon, git.

**Referans spec:** [2026-07-15-karmasiklik-giderme-design.md](../specs/2026-07-15-karmasiklik-giderme-design.md)

---

### Task 1: Tema/palet kararını tek gerçek kaynağa sabitle

**Files:**
- Modify: `zankurd_mobile/docs/superpowers/specs/2026-07-12-bubblegum-arcade-redesign-design.md:4` (Durum satırı)
- Modify: `zankurd_mobile/docs/superpowers/specs/2026-07-12-bubblegum-arcade-redesign-design.md:78` (Light/Dark bölümü, başlıktan sonra not eklenir)

- [ ] **Step 1: `Durum` satırını güncelle**

`zankurd_mobile/docs/superpowers/specs/2026-07-12-bubblegum-arcade-redesign-design.md` dosyasının 4. satırı şu anda:

```
**Durum:** Kullanıcı renk paleti, kültürel taşıyıcı ve yerleşim yönünü onayladı; uygulama planı öncesi son inceleme bekliyor.
```

Bunu şu şekilde değiştir:

```
**Durum:** Palet, kültürel taşıyıcı ve yerleşim kararları uygulandı (`da28ce1`, `c5e9e90`, `43891e0`, `e0dcc2c`, `ce91c1a`). **Not (2026-07-15):** Bu dokümanın "Light/Dark Öncelik Değişikliği" bölümündeki açık-öncelikli karar `fc6d2dd` ile geri alındı — bkz. o bölümdeki güncelleme notu. Palet/bileşen kararları geçerliliğini korur.
```

- [ ] **Step 2: Light/Dark bölümüne güncelleme notu ekle**

`### Light/Dark Öncelik Değişikliği` başlığından (78. satır) hemen sonra, mevcut paragraftan önce şu blockquote'u ekle:

```markdown
> **GÜNCELLEME (2026-07-15, `fc6d2dd`):** Bu bölümdeki açık-öncelikli karar
> geri alındı — varsayılan tema tekrar **koyu** yapıldı ("TRT Bil Bakalım"
> hissi ilk açılışta olsun diye, bkz. `theme_provider.dart`). Aşağıdaki
> açık-mod zemin rengi (`#FAFAFF`) yalnızca kullanıcı elle açık temaya
> geçtiğinde kullanılır; koyu mod zemin (`#15121F`) varsayılandır. Palet
> (indigo/pembe/gökmavi/lime) değişmedi.
```

- [ ] **Step 3: Doğrula**

Dosyayı oku ve iki değişikliğin de doğru yerde, mevcut metni bozmadan
eklendiğini teyit et. `dart analyze` gerekmez (yalnızca Markdown).

- [ ] **Step 4: Commit**

```bash
cd "zankurd_mobile"
git add docs/superpowers/specs/2026-07-12-bubblegum-arcade-redesign-design.md
git commit -m "docs: bubblegum-arcade spec'ini kod gerçeğiyle uyumlu hale getir (koyu-öncelikli)"
```

---

### Task 2: Süpersede edilmiş redesign spec'lerini arşivle

**Files:**
- Move: `zankurd_mobile/docs/superpowers/specs/2026-07-10-pirs-inspired-full-app-redesign-design.md` → `zankurd_mobile/docs/superpowers/specs/_archive/2026-07-10-pirs-inspired-full-app-redesign-design.md`
- Move: `zankurd_mobile/docs/superpowers/specs/2026-07-12-kulturel-modern-2-design.md` → `zankurd_mobile/docs/superpowers/specs/_archive/2026-07-12-kulturel-modern-2-design.md`
- Move: `zankurd_mobile/docs/superpowers/specs/2026-07-12-best-in-class-experience-design.md` → `zankurd_mobile/docs/superpowers/specs/_archive/2026-07-12-best-in-class-experience-design.md`
- Create: `zankurd_mobile/docs/superpowers/specs/_archive/README.md`

- [ ] **Step 1: Arşiv klasörünü ve README'yi oluştur**

`zankurd_mobile/docs/superpowers/specs/_archive/README.md` içeriği:

```markdown
# Arşivlenmiş Tasarım Spec'leri

Bu klasördeki dokümanlar, aktif tasarım yönü tarafından süpersede edildi.
Tarihsel referans için tutuluyor; **güncel kararlar için kullanılmamalı**.
Geçerli tasarım yönü: [`../2026-07-12-bubblegum-arcade-redesign-design.md`](../2026-07-12-bubblegum-arcade-redesign-design.md).

Bkz. [2026-07-15-karmasiklik-giderme-design.md](../2026-07-15-karmasiklik-giderme-design.md)
Faz 0 ve `../../../../CLAUDE.md` içindeki "Design Spec Discipline" kuralı
(Task 3, bu plan).
```

- [ ] **Step 2: Üç dosyayı taşı**

```bash
cd "zankurd_mobile"
git mv docs/superpowers/specs/2026-07-10-pirs-inspired-full-app-redesign-design.md docs/superpowers/specs/_archive/2026-07-10-pirs-inspired-full-app-redesign-design.md
git mv docs/superpowers/specs/2026-07-12-kulturel-modern-2-design.md docs/superpowers/specs/_archive/2026-07-12-kulturel-modern-2-design.md
git mv docs/superpowers/specs/2026-07-12-best-in-class-experience-design.md docs/superpowers/specs/_archive/2026-07-12-best-in-class-experience-design.md
```

- [ ] **Step 3: Doğrula**

```bash
ls docs/superpowers/specs/_archive/
ls docs/superpowers/specs/ | grep -E "kulturel-modern-2|best-in-class-experience|pirs-inspired-full-app-redesign"
```

Expected: `_archive/` içinde 4 dosya (3 taşınan + README); ikinci komut
boş çıktı verir (aktif klasörde artık yok).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/_archive/
git commit -m "docs: süpersede edilmiş redesign spec'lerini arşivle"
```

---

### Task 3: CLAUDE.md'ye "Design Spec Discipline" kuralını ekle

**Files:**
- Modify: `CLAUDE.md:263` (bir "## Design Spec Discipline" bölümü, "## Dart/Flutter Conventions in This Project" başlığından hemen önce eklenir)

- [ ] **Step 1: Yeni bölümü ekle**

`CLAUDE.md` dosyasında şu an 264. satırda başlayan `## Dart/Flutter
Conventions in This Project` başlığından hemen önce (263. satırdaki boş
satırdan sonra), şu bölümü ekle:

```markdown
## Design Spec Discipline

Aynı anda yalnızca **bir** aktif "tam uygulama yeniden tasarımı" (full
app/visual redesign) spec'i olabilir `zankurd_mobile/docs/superpowers/specs/`
altında. Yeni bir tam-uygulama redesign spec'i yazmadan önce:
1. Var olan aktif redesign spec'ini (varsa) süpersede edildiğini belirten
   bir not ekleyerek kapat.
2. Kapatılan spec'i `zankurd_mobile/docs/superpowers/specs/_archive/`
   altına taşı.

Bu kural yalnızca **tüm uygulamayı** kapsayan redesign spec'lerine
uygulanır (ör. "Bubblegum Arcade"); tek bir ekran/paket için yazılan
odaklı spec'ler (ör. "Faz D — Öğrenme Bölgesi") bu kısıtlamaya tabi
değildir. Amaç: 2026-07-10/12 döneminde 48 saat içinde 5 çakışan
tam-uygulama redesign spec'inin yazılmasına yol açan döngüyü önlemek
(bkz. `zankurd_mobile/docs/superpowers/specs/2026-07-15-karmasiklik-giderme-design.md`).
```

- [ ] **Step 2: Doğrula**

`CLAUDE.md` dosyasını oku, yeni bölümün `## Local Data Persistence`
alt bölümünden sonra ve `## Dart/Flutter Conventions in This Project`
başlığından önce, düzgün Markdown başlık hiyerarşisiyle (`##`) eklendiğini
teyit et.

- [ ] **Step 3: Commit**

```bash
cd ..
git add CLAUDE.md
git commit -m "docs: CLAUDE.md'ye tek-aktif-redesign-spec kuralı ekle"
```

(Not: Bu commit repo kökünden atılır, `zankurd_mobile/` alt dizininden değil.)

---

### Task 4: Ekran içeriği tekrarı denetimi (envanter)

**Files:**
- Read: `zankurd_mobile/lib/src/screens/categories_tab.dart`
- Read: `zankurd_mobile/lib/src/screens/subcategory_screen.dart`
- Read: `zankurd_mobile/lib/src/screens/home_screen.dart`
- Read: `zankurd_mobile/lib/src/screens/play_hub_screen.dart`
- Read: `zankurd_mobile/lib/src/screens/learning_screen.dart`
- Read: `zankurd_mobile/lib/src/screens/leaderboard_screen.dart`
- Read: `zankurd_mobile/lib/src/screens/community_screen.dart`
- Create: `zankurd_mobile/docs/superpowers/specs/2026-07-15-duplicate-audit-findings.md`

- [ ] **Step 1: Kategori ekranlarını karşılaştır**

`categories_tab.dart` ve `subcategory_screen.dart` dosyalarını oku. Her
ikisinin de gösterdiği kategori/alt-kategori kartı içeriğini (başlık,
ikon, renk, soru sayısı, mastery rozeti gibi alanları) karşılaştır; aynı
bilgiyi iki farklı widget'ta iki farklı görsel dille mi gösteriyorlar,
yoksa biri diğerinin doğal devamı mı (liste → detay) not et.

- [ ] **Step 2: Ana sayfa/Bilîze/öğrenme kartlarını karşılaştır**

`home_screen.dart`, `play_hub_screen.dart`, `learning_screen.dart`
dosyalarındaki kart/bölüm widget'larını oku. Her ekranın gösterdiği kart
başlıklarının bir listesini çıkar (ör. "Günlük Görev", "Hızlı Oyun",
"1v1", "Ders Yolu" gibi); aynı başlık/işlev iki ekranda da tam kart
olarak mı yoksa biri teaser/diğeri tam mı, işaretle. `fc6d2dd`'nin
Sereke/Bilîze düzeltmesi bu tür bir sorunu çözmüştü — aynı desenin başka
örneği olup olmadığını ara.

- [ ] **Step 3: Liderlik/topluluk ekranlarını karşılaştır**

`leaderboard_screen.dart` ve `community_screen.dart` dosyalarını oku;
her ikisi de sıralama/liderlik satırı gösteriyorsa (rank + avatar + isim
+ skor), aynı satır widget'ının iki yerde ayrı ayrı tanımlanıp
tanımlanmadığını (kopya kod) veya aynı bilginin iki farklı ekranda iki
farklı amaçla mı sunulduğunu not et.

- [ ] **Step 4: Bulguları yaz**

`zankurd_mobile/docs/superpowers/specs/2026-07-15-duplicate-audit-findings.md`
dosyasını oluştur. Her bulgu için şu tabloyu doldur (gerçek dosya:satır
referanslarıyla, Step 1-3'te okunanlara dayanarak):

```markdown
# Ekran İçeriği Tekrarı Denetimi — Bulgular

**Tarih:** 2026-07-15 · Faz 1 envanteri, bkz.
[2026-07-15-karmasiklik-giderme-design.md](2026-07-15-karmasiklik-giderme-design.md)

## Bulgu Tablosu

| # | Ekran çifti | Tekrarlanan içerik | Dosya:satır | Öneri (birleştir / teaser / farklı kalsın) |
|---|---|---|---|---|
| 1 | ... | ... | `path:line` | ... |

## Sonraki Adım

Bu bulgular, ayrı bir takip planında ("Karmaşıklık Giderme — Faz 1/2 Uygulama")
somut kod değişikliklerine dönüştürülecek.
```

Tabloyu Step 1-3'te bulunan gerçek örneklerle doldur; hiçbir satır boş
veya "TBD" kalmayacak — eğer bir ekran çiftinde tekrar bulunmazsa, o
satır "tekrar bulunmadı" olarak açıkça yazılır (satır tamamen atlanmaz).

- [ ] **Step 5: Commit**

```bash
cd "zankurd_mobile"
git add docs/superpowers/specs/2026-07-15-duplicate-audit-findings.md
git commit -m "docs: ekran içeriği tekrarı denetim bulgularını ekle"
```

---

### Task 5: Metin-yığını panel envanteri

**Files:**
- Read: `zankurd_mobile/lib/src/screens/profile_screen.dart:1318-1370` (`_MasterySection`, `_MasteryRow`)
- Read: `zankurd_mobile/lib/src/screens/profile_screen.dart:1498-1600` (`_PedagogicalAnalyticsSection`)
- Read: `zankurd_mobile/lib/src/screens/quiz_result_screen.dart`
- Read: `zankurd_mobile/lib/src/widgets/kilim_progress_bar.dart`
- Read: `zankurd_mobile/lib/src/widgets/kilim_pattern_painter.dart`
- Read (image): `zankurd_mobile/docs/screenshots/phase2b/home_after.png`
- Read (image): `zankurd_mobile/docs/screenshots/phase2c/profile_after.png`
- Read (image): `zankurd_mobile/docs/screenshots/phase2c/result_after.png`
- Create: `zankurd_mobile/docs/superpowers/specs/2026-07-15-text-heavy-panel-inventory.md`

- [ ] **Step 1: Profil ekranındaki yoğun bölümleri oku**

`profile_screen.dart` içindeki `_MasterySection` (1318. satır civarı),
`_MasteryRow` (1370. satır civarı) ve `_PedagogicalAnalyticsSection`
(1498. satır civarı) sınıflarının `build` metotlarını oku. Her birinin
düz `Text`/`Row` yığını mı yoksa zaten `KilimProgressBar` veya
`CustomPaint` tabanlı bir görsel mi kullandığını belirle.

- [ ] **Step 2: Sonuç ekranındaki metrik bloklarını oku**

`quiz_result_screen.dart` içindeki skor/doğru-yanlış/coin/XP metrik
gösterim widget'larını bul; düz metin satırı mı, yoksa ikon+renk+kart
kombinasyonu mu olduğunu not et.

- [ ] **Step 3: Mevcut görsel dili incele**

`kilim_progress_bar.dart` ve `kilim_pattern_painter.dart` dosyalarını
oku — bu ikisi projede zaten var olan, metin-yığını yerine kullanılması
gereken görsel bileşenler. Her birinin genel API'sini (constructor
parametreleri) not al, böylece Task takip planında hangi bölümün hangi
mevcut bileşenle değiştirilebileceği somut olsun.

- [ ] **Step 4: Ekran görüntüleriyle çapraz doğrula**

`home_after.png`, `profile_after.png`, `result_after.png` görsellerini
oku (Read tool görüntü dosyalarını gösterebilir). Kod incelemesinde
bulunan yoğun-metin bölümlerinin ekran görüntüsünde de yoğun/metin-ağırlıklı
göründüğünü teyit et; görüntüde farklı görünüyorsa (ör. kod ile
ekran görüntüsü tarihleri uyuşmuyorsa) bunu bulguya not düş.

- [ ] **Step 5: Bulguları yaz**

`zankurd_mobile/docs/superpowers/specs/2026-07-15-text-heavy-panel-inventory.md`
dosyasını oluştur:

```markdown
# Metin-Yığını Panel Envanteri — Bulgular

**Tarih:** 2026-07-15 · Faz 2 envanteri, bkz.
[2026-07-15-karmasiklik-giderme-design.md](2026-07-15-karmasiklik-giderme-design.md)

## Bulgu Tablosu

| # | Widget | Dosya:satır | Mevcut sunum | Önerilen değişim (mevcut bileşen) |
|---|---|---|---|---|
| 1 | ... | `path:line` | düz metin satırı / kısmen görsel | `KilimProgressBar(...)` / ... |

## Sonraki Adım

Bu bulgular, ayrı bir takip planında ("Karmaşıklık Giderme — Faz 1/2 Uygulama")
somut kod değişikliklerine dönüştürülecek.
```

Tabloyu Step 1-4'teki gerçek bulgularla doldur.

- [ ] **Step 6: Commit**

```bash
cd "zankurd_mobile"
git add docs/superpowers/specs/2026-07-15-text-heavy-panel-inventory.md
git commit -m "docs: metin-yığını panel envanterini ekle"
```

---

## Self-Review Notu

- **Spec kapsama:** Faz 0 → Task 1-2, Faz 4 → Task 3, Faz 1 envanteri →
  Task 4, Faz 2 envanteri → Task 5. Faz 3 (dosya bölme) ve Faz 5 (canlı
  doğrulama) bu planda yer almaz — Faz 3, Task 4/5 bulgularına dayanan
  takip planında somutlaşacak; Faz 5 kullanıcı tarafından yürütülüyor
  (spec'te belirtildiği gibi).
- **Placeholder taraması:** Task 4/5'teki bulgu tabloları şablon olarak
  görünse de, her Step'te "gerçek bulgularla doldur" talimatı açık;
  tablo satırları placeholder değil, görevin **çıktısı**dır (araştırma
  görevinin doğası gereği).
- **Tip/isim tutarlılığı:** Task 1-3'te referans verilen dosya yolları ve
  satır numaraları bu planın yazıldığı an itibarıyla doğrulanmış
  (Read/Grep ile teyit edildi).
