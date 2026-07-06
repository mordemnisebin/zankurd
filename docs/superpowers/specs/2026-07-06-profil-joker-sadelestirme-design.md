# Profil + Joker Sadeleştirme — Tasarım Spec'i

**Tarih:** 2026-07-06
**Durum:** Kullanıcı onayladı (görsel mockup'lar üzerinden Profil "A — Oyuncu Kartı"
ve Joker "A — Kimlikli Şerit" seçildi)
**Kapsam:** Profil ekranı yeniden tasarımı + quiz joker görünürlüğü + tutarlılık rötuşları

## Problem

Kullanıcı geri bildirimi (telefonda kullanım):

1. **Profil karışık ve görsel yönü zayıf.** Ekranın çoğu çıplak metin; bölümler
   iç içe/tekrarlı hissettiriyor.
2. **Jokerler quiz ekranında hiç belirgin değil.** Aktifken bile "kilitli/devre
   dışı" görünüyorlar.

Kod incelemesinde doğrulanan kök nedenler:

- `profile_screen.dart` (~2070 satır) **aynı ekranı iki kez içeriyor**:
  geniş düzen (`leftColumn`/`rightColumn`, satır ~197-771) ve mobil düzen
  (satır ~836-1327) ayrı ayrı elle yazılmış. Mobil kopya eskimiş durumda:
  - Mor gradyan başlık kartı (`Color(0xFF7C3AED) → Color(0xFF4F1EB8)`) —
    uygulamanın yeşil/mercan/altın paletinin tamamen dışında.
  - `PlayerAvatar` yerine düz `CircleAvatar`; avatar düzenleyiciye erişim yok;
    showcase title (ünvan çipi) gösterilmiyor.
  - Menü panelinde Dukan ve Hevalên Min öğeleri eksik (geniş düzende 6 öğe,
    mobilde 4).
- **Rozetler iki ayrı kart:** `_AchievementShowcase` (AchievementStore, x/8) +
  `BadgeCollectionSection` (ayrı 5'li koleksiyon). Üst üste iki "rozet" bölümü,
  tutarsız sayaçlarla.
- **Kuru boş durumlar:** `Statîstîkên Min` veri yokken iki satır düz metin;
  `Performansa Heftane` grafiği veri olmasa da hep çiziliyor (boş eksenler).
- **Ustalık bölümü** 8 tekdüze satır (aynı gri "Destpêkirin" çipi + ince çubuk) —
  duvar etkisi.
- `_WildcardButton` (quiz_widgets.dart ~899-1012): 52px yükseklik, %12 alfa
  soluk arka plan, 15px ikon, "20c" 10px metin. Aktif durum bile disabled gibi
  okunuyor.

## Tasarım

### 1. Profil — "Oyuncu Kartı" (tek akış, tek düzen)

**Kod yapısı:** Mobil/geniş kopyalar silinir. Bölümler yeniden kullanılabilir
private widget'lara çıkarılır (`_PlayerHeaderCard`, `_BadgeSection`,
`_StatsSection`, `_MasteryGrid`, `_MenuPanel`, mevcut `_LangToggle`). Geniş
ekran aynı widget'ları iki sütuna dağıtır; mobil tek sütunda alt alta dizer.
Davranış farkı yalnızca yerleşimdir, içerik farkı kalmaz.

**Sayfa sırası (mobil):**

1. **`_PlayerHeaderCard`** — koyu yeşil gradyan (mevcut geniş düzendeki
   `[Color(0xFF1E5F47), Color(0xFF123427)]` korunur):
   - `PlayerAvatar` + kalem düzenleme rozeti (`profile-avatar-edit` key'i
     korunur — mevcut widget testi buna bağlı) → `AvatarEditorScreen`.
   - Ad + unvan çipi (varsa `showcaseTitle`, altın renk).
   - Ast/XP satırı + altın ilerleme çubuğu (mevcut davranış).
   - **Üç istatistik çipi** (yarı saydam beyaz zemin): coin
     (`repository.loadCoinBalance()`, `_load()`'a eklenir; hata olursa çip
     gizlenir), günlük seri (`StreakStore.effectiveStreak()`), oyun sayısı
     (`_stats?.roomsPlayed`, stats null ise çip gizlenir).
2. **Dil satırı** — mevcut `_LangToggle` paneli aynen.
3. **Tek Rozet kartı (`_BadgeSection`)** — `_AchievementShowcase` +
   `BadgeCollectionSection` birleşir:
   - Tek başlık "Rozet", sayaç iki kaynağın birleşik toplamı
     (örn. `3/13` = açılan başarım + açılan koleksiyon rozeti).
   - Tek yatay şerit: açılanlar renkli çip/daire, kilitliler gri + kilit ikonu.
   - "Hemû ›" mevcut bottom sheet'i açar; sheet iki kaynağı tek grid'de
     listeler (başarımlar + koleksiyon rozetleri, bölüm etiketleriyle).
   - `BadgeCollectionSection` profilden ayrı kart olarak kaldırılır;
     `_BadgeSection` onun veri kaynağını (koleksiyon rozeti tanımları ve
     kilit durumu) doğrudan okuyarak tek şeritte gösterir.
4. **İstatistik kartı (`_StatsSection`)** — mevcut `_StatTile` grid'i korunur;
   değişenler:
   - `_stats == null` boş durumu: düz iki satır metin yerine ikonlu kompakt
     boş durum (mevcut `AppEmptyState` görsel dilinde, küçük boy).
   - `Performansa Heftane` grafiği yalnızca `getLast7DaysHistory()` içinde en
     az bir gün sıfırdan büyük veri varsa gösterilir; yoksa tek satır sakin
     not ("İlk quizden sonra grafik burada" / KU karşılığı).
5. **Analîza Performansê** — mevcut `_PedagogicalAnalyticsSection` aynen
   (zaten veri yokken kendini gizliyor).
6. **Ustalık (`_MasteryGrid`)** — 8 satır → 2 sütunlu ızgara. Hücre: kategori
   ikonu (renkli mini kare, `AppTheme.categoryGradients` indeksinden) +
   kategori adı + seviye çipi (mevcut renk mantığı) + `count/threshold`.
   `_MasteryRow` yerine `_MasteryCell`; ilerleme çubuğu hücre altında ince
   çizgi olarak kalabilir.
7. **Menü paneli (`_MenuPanel`)** — 6 öğenin tamamı mobilde de: Pirsên
   Tomarkirî, Şaşiyên Min (alt metniyle), Dukan, Hevalên Min, Mîheng, Derkeve.
   Mevcut InkWell/Divider yapısı korunur.

**Görsel dil:** Kart yüzeyleri `AppPanel` üzerinden; yeni renk tanımı
gerekmiyor. Mor palet tamamen kalkıyor.

### 2. Joker — kimlikli şerit

`_WildcardButton` görsel katmanı yeniden yazılır; `quiz_screen.dart`'taki
`_buildWildcardRow`/`_onWildcardTap`/`spendCoins` akışı ve onay diyaloğu
**değişmez**.

- **Biçim:** 46-48px dolu renkli daire + altında 11px etiket + dairenin
  sağ-alt köşesinde altın (`AppTheme.gold`) fiyat rozeti. Rozet yalnızca
  sayıyı gösterir ("20"); tam fiyat ("20 coin") uzun basış balonunda yer alır.
  Rozet içi metin koyu tondadır.
- **Kimlik renkleri** (`WildcardType.themeColor` güncellenir):
  - 50/50 → mercan `Color(0xFFE76F51)`
  - Seyîrvan (audience) → kobalt `Color(0xFF2B5C8F)`
  - 2 Bersiv (doubleAnswer) → derin yeşil `Color(0xFF1E5F47)`
  - Biguherîne (changeQuestion) → turkuaz `Color(0xFF26A69A)` (AppTheme.cyan)
- **Durumlar:**
  - Kullanılabilir: dolu renk, beyaz ikon, altın fiyat rozeti.
  - Coin yetersiz: gri dolgu (`surfaceHi`), gri ikon, gri fiyat rozeti —
    kilit ikonu yerine jokerin kendi ikonu kalır (ne olduğu hep görünsün).
  - Kullanıldı: %40 opaklık + ikon üzerinde çapraz çizgi ya da onay işareti.
  - Çift Cevap aktif: pembe (`AppTheme.accent`) halka/glow.
- **Uzun basış:** jokerin adı + tek cümle açıklaması balon/tooltip olarak
  (KU/TR). Mevcut `WildcardType` üzerine `description(bool ku)` eklenir.
- Etiketler: 50/50, Seyîrvan, 2 Bersiv, Biguherîne (KU); TR modunda 50/50,
  Seyirci, Çift Cevap, Değiştir.

### 3. Tutarlılık rötuşları

- **Hero kartı gradyanı** (`hero_card.dart`): yeşil→kahve/mercan geçişi tek
  renk ailesine sakinleştirilir (koyu yeşil aile); mercan yalnızca birincil
  CTA butonunda kalır.
- **Quiz solo modunda "Skora zindî" kartı gizlenir** (tek satır "Tu"
  gösteriyordu); canlı/çok oyunculu odalarda aynen kalır. Solo tespiti quiz
  ekranındaki mevcut `_isSoloMode` mantığıyla aynı.

## Kapsam Dışı

- Repository/Supabase davranışı, coin RPC akışları (dokunulmaz).
- Kategoriler, Ana Sayfa yerleşimi, Liderlik, onboarding (kullanıcı bu
  ekranlardan rahatsız değil).
- `AppTheme.violet` adlandırma temizliği (yalnızca not: isim yeşil renk
  taşıyor; ayrı bir teknik borç maddesi).
- Turnuva skor takibi, offline_question_bank bölme vb. backlog maddeleri.

## Hata Yönetimi

- Coin çipi: `loadCoinBalance()` hata verirse çip render edilmez (ekran
  bloklanmaz); mevcut `ErrorReporter.record` düzeni izlenir.
- Profil `_loadFailed` yolu (AppErrorState + yeniden dene) aynen korunur.

## Test Stratejisi

Her adımdan sonra: `dart analyze` (0 sorun) + `flutter test` (mevcut 322 test
yeşil kalmalı; `flutter analyze` bu ortamda çökük — kullanma).

Yeni ve güncellenen testler:

1. **Profil tek düzen:** dar genişlikte (ör. 400px) pompalanan ProfileScreen'de
   `PlayerAvatar` bulunur, `profile-avatar-edit` key'i bulunur, 6 menü öğesi
   metni bulunur; mor renk (`0xFF7C3AED`) hiçbir widget'ta kalmaz (kaynak
   taraması da yeterli).
2. **Rozet birleşimi:** tek "Rozet" başlığı render edilir (iki ayrı kart yok);
   sayaç birleşik toplamı gösterir.
3. **Joker durumları:** `_WildcardButton` — yeterli coin'de dolu renk,
   yetersizde gri, kullanılmışta soluk; fiyat rozeti metni görünür.
4. **Solo skorboard:** solo modda "Skora zindî" bulunmaz, `botRace`/online
   modda bulunur.
5. Mevcut quiz/profil widget testleri kırılmadan geçer (key'ler ve görünür
   metinler korunduğu için beklenti: değişiklik gerekmez ya da minimal metin
   güncellemesi).

## Uygulama Sırası (özet — detay uygulama planında)

1. Profil bölüm widget'larını çıkar + tek düzene geçir (mor kart silinir).
2. Rozet birleşimi.
3. Boş durumlar + ustalık ızgarası.
4. Joker butonu yeniden tasarımı + uzun basış açıklaması.
5. Tutarlılık rötuşları (hero gradyan, solo skorboard).
6. Her adımda analyze + test; sonda web'de manuel ekran kontrolü (Playwright).
