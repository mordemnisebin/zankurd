# Zankurd — Profesyonel & Modern Uygulama Yol Planı

**Tarih:** 2026-06-19  
**Mevcut Sürüm:** v1.4.0+5  
**Hedef:** Müthiş modern, profesyonel, yüksek retansiyon Kurmanci quiz uygulaması

---

## Mevcut Durum Analizi

### Güçlü Yönler
- Repository pattern (Mock/Supabase) — temiz ve test edilebilir
- 2250+ soru, 8 kategori, 5 zorluk seviyesi
- Online çok oyuncu (Supabase realtime)
- Bot yarışması (3 simüle rakip)
- Günlük quiz (tarih tohumlu, herkese aynı)
- 4 coin'li joker sistemi (50/50, Seyirci, Çift Cevap, Soru Değiştir)
- Mastery sistemi (Xwendekar/Pispor/Mamoste per kategori)
- Streak sistemi, Achievement store, MistakeStore
- Dark/Light mode, Kurmanci/Türkçe ikidillilik
- 135+ geçen test

### Eksikler & Fırsatlar
- Push bildirimi yok (kullanıcı geri dönmüyor)
- Sosyal özellik yok (organik büyüme yok)
- Günlük görev yok (her gün açma nedeni sınırlı)
- XP/seviye yok (uzun vadeli ilerleme hissi eksik)
- Ses efekti / gelişmiş animasyon yok
- Cevap açıklaması yok (eğitim değeri düşük)
- Profil kişiselleştirme yok (aidiyet hissi eksik)
- Haftalık turnuva yok (rekabetçi döngü yok)

---

## Strateji: Paralel İterasyon Modeli

Her 2 haftalık sprint'te:
- 1 teknik paket/iyileştirme
- 1-2 kullanıcı değeri özelliği
- 1 içerik/soru bankası iyileştirmesi

Provider → Riverpod veya Navigator → go_router geçişi **yapılmaz** — mevcut mimari sağlam, kırıcı değişiklik risk/fayda oranı olumsuz.

---

## Eksen 1 — Teknik Zemin Paketleri

### Eklenecek Paketler (pubspec.yaml)

```yaml
# Görsel
cached_network_image: ^3.4.1
shimmer: ^3.0.0
lottie: ^3.1.2

# Paylaşım & Mağaza
share_plus: ^10.0.3
in_app_review: ^2.0.9

# Bildirimler
flutter_local_notifications: ^18.0.1
firebase_messaging: ^15.2.4

# Ses
audioplayers: ^6.1.0

# Bağlantı
connectivity_plus: ^6.1.0
```

### Teknik Mimari Notlar

**Ses Yönetimi (`SoundProvider`):**
- `ChangeNotifier` tabanlı, mevcut provider pattern ile uyumlu
- Ayarlardan aç/kapat (`SharedPreferences` ile persist)
- Dosyalar: `assets/sounds/correct.mp3`, `wrong.mp3`, `win.mp3`, `coin.mp3`

**Bildirim Altyapısı:**
- FCM token → `profiles.fcm_token` kolonu (Supabase migration)
- Yerel zamanlama: saat 09:00 günlük quiz, saat 20:00 streak hatırlatıcısı
- Kullanıcı ayarlardan kapatabilir

**Bağlantı Durumu:**
- `ConnectivityProvider` — çevrimdışıyken home'da banner göster
- MockRepository'ye otomatik fallback (mevcut)

---

## Eksen 2 — Engagement & Retention

### 2a. Günlük Görev Sistemi

**Veri katmanı:** `DailyMissionStore` (SharedPreferences singleton, mevcut store pattern)

```dart
// Görev tipleri
enum MissionType {
  answerCorrect,      // N soru doğru cevapla
  completeQuiz,       // N quiz bitir
  useWildcard,        // Joker kullan
  keepStreak,         // Streakini koru
  playCategory,       // Belirli kategori oyna
}

class DailyMission {
  final MissionType type;
  final int target;
  final int coinReward;
  int progress;
  bool completed;
}
```

**Görev seçimi:** Gün tohumlu rastgele — `DateTime.now().day` ile seed, herkese aynı 3 görev.

**UI:** Home screen'de yeni `DailyMissionsCard` widget — mevcut kart stilinde, her görev progress bar ile.

**Ödül:** Görev tamamlandığında coin + `in-app bildirim` (snackbar değil, özel toast).

### 2b. XP & Seviye Sistemi

**Model:**
```dart
class XPSystem {
  static int levelForXP(int xp) => (xp / 1000).floor() + 1; // 1-100
  static int xpForNextLevel(int xp) => 1000 - (xp % 1000);
  static int xpForCorrect(int streak) => 10 + (streak * 2).clamp(0, 20);
}
```

**XP Kaynakları:**
| Aksiyon | XP |
|---|---|
| Doğru cevap | +10 |
| Streak bonusu (x cevap serisi) | +2 per seri adımı (max +20) |
| Quiz bitirme | +50 |
| Günlük görev | +100 |
| Mastery tier-up | +500 |
| Turnuva top 3 | +300 |

**Depolama:** `XPStore` (SharedPreferences singleton)

**UI:** Profil ekranında coin'in yanında XP bar + seviye rozeti. Ana sayfa header'da seviye badge.

### 2c. Haftalık Turnuva

**Akış:**
- Pazartesi 00:00 → Pazar 23:59 açık
- Her gün aynı turnuva soruları (Supabase `tournaments` tablosu, `week_start` kolonu)
- Turnuva skoru quiz skorundan ayrı birikir
- Pazar akşamı: top 3 oyuncuya özel rozet + coin ödülü

**Supabase Şema:**
```sql
create table tournaments (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  question_ids uuid[] not null
);

create table tournament_scores (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid references tournaments(id),
  user_id uuid references profiles(id),
  score int default 0,
  updated_at timestamptz default now()
);
```

**UI:** Home'da `TournamentCard` widget — kalan süre countdown, kendi sıralaması, top 3.

### 2d. Streak Koruma Kalkanı

`StreakStore`'a eklenir:
```dart
Future<bool> buyStreakShield(int coinCost) async { ... }
bool get hasShield => _shieldActive;
```

Kullanıcı 50 coin harcayarak 1 günlük kalkan alır. O gün quiz yapmazsa streak korunur, kalkan tükenir.

**UI:** Streak badge'in yanında kalkan ikonu. Quiz yapılmadı akşam hatırlatıcısı: "Streakini kaybetmeden önce oyna veya kalkan kullan!"

### 2e. Adaptif Zorluk

Mevcut `loadLevelQuestions` → `loadAdaptiveQuestions` eklenir (mevcut imzayı bozmaz):

```dart
Future<List<QuizQuestion>> loadAdaptiveQuestions({
  required String category,
  required int masteryCorrectCount,
  int limit = 10,
})
```

Mastery count'a göre difficulty ağırlığı:
- 0-19 doğru → ağırlıklı difficulty 1-2
- 20-99 → ağırlıklı difficulty 2-3
- 100-399 → ağırlıklı difficulty 3-4
- 400+ → ağırlıklı difficulty 4-5

---

## Eksen 3 — Sosyal & Büyüme

### 3a. Sonuç Paylaşımı

`QuizResultScreen`'e "Paylaş" butonu eklenir.

**Teknik:** `RenderRepaintBoundary` ile sonuç kartını PNG'ye render et → `share_plus` ile paylaş.

**Kart içeriği:**
- ZanKurd logosu + marka renkleri
- Skor, doğru/yanlış sayısı, en iyi seri
- "Sen de oyna: [Play Store linki]"
- Kategori ve zorluk bilgisi

### 3b. Meydan Okuma (Challenge Modu)

**Akış:**
1. Quiz bitiş ekranında "Arkadaşına Meydan Oku" butonu
2. Aynı soru ID listesi + kullanıcı skoru Supabase'e yazılır (`challenges` tablosu)
3. Deep link oluşturulur: `zankurd://challenge/{id}`
4. Arkadaş linki açar → aynı sorularla quiz → karşılaştırmalı sonuç

**Supabase Şema:**
```sql
create table challenges (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references profiles(id),
  creator_score int not null,
  question_ids uuid[] not null,
  expires_at timestamptz default (now() + interval '24 hours'),
  created_at timestamptz default now()
);
```

**Deep Link:** Firebase Dynamic Links veya App Links (Android) ile.

### 3c. Push Bildirimleri

**FCM Entegrasyonu:**
- `firebase_messaging` paketi (zaten `firebase_core` mevcut)
- Token `profiles.fcm_token` kolonuna yazılır
- Supabase Edge Function veya cron job bildirimleri tetikler

**Bildirim Tipleri:**
| Bildirim | Tetikleyici | Saat |
|---|---|---|
| Günlük quiz | Her gün | 09:00 |
| Streak uyarısı | O gün quiz yoksa | 20:00 |
| Görev hatırlatıcı | Görev yarıda kaldıysa | 18:00 |
| Meydan okuma | Arkadaş challenge gönderdi | Anlık |
| Turnuva bitiyor | Pazar 20:00 | Haftalık |

**Yerel bildirim fallback:** `flutter_local_notifications` ile cihaz içi zamanlama (FCM yoksa).

### 3d. In-App Review

`in_app_review` paketi ile:
- Tetikleyici: 10. quiz bitiş + skor ≥ %70 + daha önce istenmediyse
- `SharedPreferences` flag: `zankurd.review.requested`
- Sadece bir kez tetiklenir

---

## Eksen 4 — UX/UI Polish

### 4a. Quiz Ekranı İyileştirmeleri

**Circular Timer:**
- Mevcut liner progress bar → `CustomPainter` tabanlı dairesel geri sayım
- Renk: yeşil (>50%) → sarı (20-50%) → kırmızı (<20%)
- Pulse animasyonu son 5 saniyede

**Cevap Açıklaması:**
- Doğru/yanlış seçiminden 0.8sn sonra açıklama kutusu slide-in
- Supabase: `questions.explanation_ku` ve `questions.explanation_tr` kolonları
- `QuizQuestion` modeline `explanationKu`/`explanationTr` alanları
- Offline bank'te bu alanlar boş bırakılabilir (null-safe)

**Confetti:**
- 5+ soru serisi yakalandığında confetti patlar
- `CustomPainter` + `AnimationController` ile (harici paket yok)
- Renkler: AppTheme accent renkleri

**Haptic Feedback (zaten Flutter built-in):**
```dart
// Doğru cevap
HapticFeedback.lightImpact();
// Yanlış cevap
HapticFeedback.heavyImpact();
// Joker kullanımı
HapticFeedback.mediumImpact();
```

**Ses Efektleri:**
```
assets/sounds/
  correct.mp3    — tatlı tını
  wrong.mp3      — hafif hata sesi
  win.mp3        — quiz bitiş fanfar
  coin.mp3       — coin kazanma
  wildcard.mp3   — joker aktivasyon
```

### 4b. Profil Ekranı İyileştirmeleri

**Grafik İstatistikler:**
- Kategori bazlı doğruluk oranı → `CustomPainter` ile yatay bar chart
- Renk: her kategorinin kendi gradient rengi (`AppTheme.categoryGradients`)
- Veri: `AchievementStore.categoryStats` (mevcut `playedCategories` genişletilir)

**Avatar Sistemi:**
- 12 avatar seçeneği: Kürt kültürüne ait semboller (güneş, dağ, anahtar, pomnar, stêr...)
- SVG veya Unicode emoji tabanlı
- `profiles.avatar_id` kolonu (Supabase)
- Profil kurulum ekranında seçilir

**Rozet Galerisi:**
- Tüm başarımlar grid olarak (3 sütun)
- Kilitli rozetler gri + "?" ikonu
- Açık rozetler renkli + kazanma tarihi

**XP Progress Bar:**
- Profil üstünde seviye numarası + XP ilerleme çubuğu
- "Bir sonraki seviyeye X XP"

### 4c. Home Ekranı İyileştirmeleri

**Kişiselleştirilmiş Karşılama:**
```dart
// Şu an: 'Salam, Lîstikvan!'
// Hedef: 'Salam, {profileName}!'
```
ProfileName AppShell'de bir kere yüklenir, HomeScreen'e `displayName` parametresi geçilir.

**Yeni Kartlar (mevcut kart stilinde):**
- `DailyMissionsCard` — 3 günlük görev, progress bar'lı
- `TournamentCard` — haftalık turnuva, kalan süre, kendi sırası
- `ChallengeCard` — bekleyen meydan okumalar (varsa)

**Coin Balance Animasyonu:**
- Coin değiştiğinde `AnimatedSwitcher` ile +N animasyonu

**Streak'i Header'da Göster:**
- Mevcut streak hexagon korunur ama kişiselleştirilir: "3 Gün Serisi!"

### 4d. Onboarding İyileştirmesi (4 Adım)

**Adım 1: Dil Seç**
- Kurmanci / Türkçe — büyük butonlar, bayrak ikonu

**Adım 2: İlgi Alanı Seç**
- 8 kategoriden en fazla 3 seç → `onboarding.preferred_categories` SharedPreferences'a yaz
- Home ekranında bu kategoriler öne çıkar

**Adım 3: İlk Mini Quiz (3 Soru)**
- Onboarding tamamlanmadan önce 1 mini quiz
- "Zankurd'u dene!" hissi — uygulamayı hissettir

**Adım 4: Profil Adı Gir**
- Mevcut `ProfileNameGateScreen` mantığı buraya taşınır
- Onboarding akışının parçası olur

### 4e. Genel Animasyon Kalitesi

**Lottie Animasyonları (assets/animations/):**
- `trophy.json` — quiz bitiş, yüksek skor
- `streak.json` — streak uzadı
- `level_up.json` — seviye atlandı

**Geçiş Animasyonları:**
- `AppRoute.to` mevcut — `SlideTransition` veya `FadeTransition` seçenekleri eklenir
- Ekran geçişleri: soldan slide (kategori → level → quiz yönünde)

---

## Eksen 5 — Soru Bankası & İçerik

### 5a. Açıklama Alanı

Her soruya açıklama eklenecek. Kademeli plan:
1. İlk 500 soru (Ziman + Çand kategorileri)
2. Sonraki 750 (Dîrok + Edebiyat)
3. Kalan 1000+ (diğer kategoriler)

Format: kısa, öğretici, 2-3 cümle. Hem Kurmancı hem Türkçe.

### 5b. Soru Bankası Genişletme

- Siyaset kategorisi: +200 soru (şu an zayıf)
- Paradigma kategorisi: +200 soru (şu an zayıf)
- Muzîk: görsel ve ses klip soruları (+50)
- Yeni kategori önerileri: **Spor** (Kürt sporcu/tarihi), **Coğrafya Detay** (dağ/nehir isimleri)

### 5c. Topluluk Soru Önerisi

```sql
create table question_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  question_text text not null,
  options jsonb not null,
  correct_answer text not null,
  category text not null,
  status text default 'pending', -- pending, approved, rejected
  created_at timestamptz default now()
);
```

Uygulama içinde "Soru Öner" butonu (Profil ekranı altında). Admin paneli (ayrı web arayüzü) veya Supabase Studio ile onay.

---

## Sprint Planı (Uzun Vadeli)

### Sprint 1 (Hafta 1-2): Temel Paketler + Haptic + Ses
- [ ] Paketleri pubspec'e ekle
- [ ] `SoundProvider` + ses dosyaları
- [ ] Haptic feedback quiz ekranına
- [ ] `shimmer` ile skeleton loading iyileştirmesi
- [ ] Kişiselleştirilmiş karşılama (profil adı)

### Sprint 2 (Hafta 3-4): Günlük Görevler
- [ ] `DailyMissionStore` + `DailyMission` modeli
- [ ] `DailyMissionsCard` widget
- [ ] Görev ilerleme takibi (quiz/mastery/wildcard hookları)
- [ ] Görev tamamlama coin ödülü

### Sprint 3 (Hafta 5-6): XP & Seviye Sistemi
- [ ] `XPStore` + `XPSystem` utility
- [ ] Quiz/görev/mastery XP entegrasyonu
- [ ] Profil XP bar + seviye badge
- [ ] Level-up animasyonu (Lottie)

### Sprint 4 (Hafta 7-8): Quiz UX Polishing
- [ ] Circular timer (`CustomPainter`)
- [ ] Cevap açıklama kutusu (Supabase schema + model)
- [ ] Confetti animasyonu (seri ödülü)
- [ ] Lottie animasyonları (trophy, streak)

### Sprint 5 (Hafta 9-10): Sosyal — Paylaşım & Review
- [ ] Sonuç kartı render + `share_plus`
- [ ] `in_app_review` entegrasyonu
- [ ] Avatar sistemi (model + UI + Supabase)
- [ ] Rozet galerisi

### Sprint 6 (Hafta 11-12): Push Bildirimleri
- [ ] FCM entegrasyonu (`firebase_messaging`)
- [ ] `profiles.fcm_token` Supabase migration
- [ ] `flutter_local_notifications` yerel zamanlama
- [ ] Bildirim ayarları ekranı

### Sprint 7 (Hafta 13-14): Haftalık Turnuva
- [ ] Supabase `tournaments` + `tournament_scores` tabloları
- [ ] `TournamentCard` widget
- [ ] Turnuva quiz akışı
- [ ] Puan güncelleme + sıralama

### Sprint 8 (Hafta 15-16): Meydan Okuma
- [ ] Supabase `challenges` tablosu
- [ ] Deep link altyapısı
- [ ] Challenge oluşturma/kabul akışı
- [ ] Karşılaştırmalı sonuç ekranı

### Sprint 9 (Hafta 17-18): Onboarding Yenileme
- [ ] 4 adımlı onboarding tasarımı
- [ ] Kategori ilgi seçimi + kişiselleştirme
- [ ] Mini quiz akışı
- [ ] ProfileNameGate entegrasyonu

### Sprint 10 (Hafta 19-20): Streak Kalkanı + Adaptif Zorluk
- [ ] `StreakStore.buyShield()` + UI
- [ ] `loadAdaptiveQuestions()` repository eklentisi
- [ ] Streak kalkan bildirimi

### Sprint 11+ : İçerik & Topluluk
- [ ] Soru açıklamaları (500 → 1000 → 2250)
- [ ] Yeni sorular (Siyaset/Paradigma güçlendirme)
- [ ] Topluluk soru önerisi sistemi
- [ ] Ses soruları (Muzîk kategorisi)

---

## Mimari Kararlar

### Değiştirilmeyecekler
- Provider + ChangeNotifier state management — çalışıyor, kırma
- Repository pattern — temiz, test edilebilir, kalıcı
- SharedPreferences singleton store pattern — tutarlı, devam et
- `dart analyze` (flutter analyze değil — LSP bug)

### Yeni Eklenenler (Kırıcı Değişiklik Yok)
- Her yeni özellik için yeni Store singleton
- Her yeni Provider mevcut `MultiProvider` listesine eklenir
- Her yeni ekran `AppRoute.to` ile açılır

### Supabase Migration Sırası
1. `profiles.fcm_token` kolonu (Sprint 6)
2. `profiles.avatar_id` kolonu (Sprint 5)
3. `profiles.xp` kolonu (Sprint 3, local mirror)
4. `questions.explanation_ku`, `questions.explanation_tr` (Sprint 4)
5. `tournaments` + `tournament_scores` tabloları (Sprint 7)
6. `challenges` tablosu (Sprint 8)
7. `question_suggestions` tablosu (Sprint 11)

---

## Başarı Kriterleri

| Metrik | Mevcut | 6 Ay Hedef |
|---|---|---|
| Günlük aktif kullanıcı | ? | %30 artış |
| D7 retansiyon | ? | %40+ |
| Ortalama oturum süresi | ? | 8+ dakika |
| Play Store puanı | ? | 4.5+ |
| Streak ortalama uzunluğu | ? | 5+ gün |
| Günlük görev tamamlama oranı | N/A | %60+ |

---

## Risk & Azaltma

| Risk | Olasılık | Azaltma |
|---|---|---|
| FCM bildirimleri Play Store politikasını ihlal | Düşük | Opt-in bildirimleri, açık onay al |
| Turnuva sunucu maliyeti | Orta | Supabase free tier sınırlarını izle, row limit ekle |
| Deep link Android fragmantasyonu | Orta | Firebase Dynamic Links (fallback URL) |
| Soru açıklaması içerik kalitesi | Yüksek | İnsan incelemesi, kademeli ekleme |
| Lottie dosya boyutu APK şişirmesi | Düşük | Küçük animasyonlar (<100KB), lazy load |
