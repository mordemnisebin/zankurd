# Faz C: Etkinlikler & Contest Sistemi
**Tarih:** 2026-07-05 | **Versiyon:** 1.0

---

## 1. Vizyonu

ZanKurd'a **zamana sınırlandırılmış yarışma heyecanı** ekle: günlük özel tema contest'leri, kazanan puanları, katılım bonusları ve **temalı rozet ödülleri**.

Kullanıcılar:
- **Hergün saat 00:00 UTC**'de yeni contest başlar
- Her contest'in **tema** vardır (ör. "Coğrafya Eksperi", "Ziman Kökenler", "Dîrok Efsaneleri")
- **Top 3 katılımcı** ödül kazanır: altın coin + özel badge
- Katılmaktan bile ödül: 10 coin + XP

---

## 2. Database Schema

### `contests` Tablosu
```sql
CREATE TABLE IF NOT EXISTS contests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_key DATE NOT NULL UNIQUE, -- 2026-07-05
  theme_name_ku TEXT NOT NULL, -- "Coğrafya Eksperi"
  theme_description_ku TEXT,
  category TEXT NOT NULL, -- Ziman, Çand, Cografya, ...
  difficulty_min INT, -- 1-5
  difficulty_max INT,
  participation_reward INT DEFAULT 10, -- coin
  rank1_reward INT DEFAULT 500, -- altın
  rank2_reward INT DEFAULT 300,
  rank3_reward INT DEFAULT 100,
  question_count INT DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ
);
```

### `contest_entries` Tablosu
```sql
CREATE TABLE IF NOT EXISTS contest_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score INT DEFAULT 0,
  correct_count INT DEFAULT 0,
  finished_at TIMESTAMPTZ,
  rank INT, -- 1, 2, 3, NULL
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(contest_id, user_id)
);
```

### `contest_badges` Tablosu
```sql
CREATE TABLE IF NOT EXISTS contest_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL, -- "contest_001_champion", "contest_001_finalist"
  name_ku TEXT NOT NULL,
  description_ku TEXT,
  icon_name TEXT, -- Material icon
  color_hex TEXT, -- #FFD700 (altın)
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### `user_contest_badges` Tablosu (Rozet Ödülleri)
```sql
CREATE TABLE IF NOT EXISTS user_contest_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id UUID NOT NULL REFERENCES contest_badges(id) ON DELETE CASCADE,
  contest_id UUID NOT NULL REFERENCES contests(id),
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, badge_id, contest_id)
);
```

---

## 3. Functionalite Breakdown

### 3.1 Contest Yönetimi
**Backend (Supabase):**
- `contests` tablosu INSERT/UPDATE RPC (admin tarafı, şimdi skip)
- `get_today_contest()` RPC — bugünün contest'ini döner
- `submit_contest_entry()` RPC — skor kaydeder, katılım reward'ı verir
- `get_contest_leaderboard(contest_id)` RPC — top 10 + user's rank

**Client:**
- `ContestScreen` widget
  - Contest tema/başlık/kategori
  - Quiz başlatma butonu
  - Real-time leaderboard (live 5s auto-refresh)
  - Katılım durumu: ✓ bitti, ⏳ etkinlik-devam, ✗ sona erdi
  
### 3.2 Ödül Mekanizması
**Backend:**
- `claim_contest_reward()` RPC (güvenli)
  - Katılım reward'ı (10 coin, her zaman)
  - Rank reward'ı (1–3. yer ise altını bonus)
  - Rozet vermek (contest_badges tablosuna INSERT)
  - Guard: user zaten ödül aldı mı?

**Client:**
- Quiz sonuç ekranından otomatik trigger
- Snackbar: "🏆 +500 Altın! 🥇 Birinci oldun!"
- Rozet preview (badge icon, text)

### 3.3 Rozet/Badge Sistemi
**Türler:**
- **🥇 Birinci:** contest_001_champion (Altın renkli, tac simgesi)
- **🥈 İkinci:** contest_001_finalist
- **🥉 Üçüncü:** contest_001_participant
- **Katılımcı:** (her katılımda basit badge — şartlı tutulabilir)

**Görünüm:**
- ProfileScreen'de "Etkinlik Rozetleri" tab'ı
- Her rozet: ikon + ad + tarih + contest tema
- Showcase profile açısından özel stat

---

## 4. User Experience Flow

### 4.1 Contest Başladığında (00:00 UTC)
1. Push notification: "Bugün kontesti: Coğrafya Eksperi 🌍 | Katıl!"
2. Home tab'da Contest card:
   - Başlık: "Coğrafya Eksperi"
   - Kategori badge
   - "Katıl" butonu (quiz başlatır)
   - Leaderboard preview (top 3)

### 4.2 Quiz Sırasında
- AppBar'da: "⏱️ Contest Quiz — 10 soru"
- Sorular o gün kontestinin kategori/zorluk aralığından
- Answer tracking (correct_count accumulate)

### 4.3 Quiz Sonrası
1. Result Screen:
   - Puan + rank (canlı)
   - Reward banner: "🏆 +500 Altın — 1. Oldun! 🥇"
   - Badge teaser: "Yeni rozet kazandın!"
   
2. Otomatik işlemler:
   - `claim_contest_reward()` trigger
   - coin_transactions INSERT (contest reward)
   - user_contest_badges INSERT (rank ≤ 3 ise)

### 4.4 Profil Sayfası — Rozetler Tab'ı
- Etkinlik rozetleri grid
- Düşey scroll
- Her badge: ikon (Material icon) + name + tarih
- Tıklayınca: description + contest tema

---

## 5. Implementation Plan

### Task 1: Backend RPC'ler
- `get_today_contest()` — bugün kontestini dön
- `submit_contest_entry()` — quiz bitişi, skor kaydı, rank hesaplayıp katılım reward ver
- `claim_contest_reward()` — sırasıyla katılım + rank reward dağıt, rozet ver
- `get_contest_leaderboard(contest_id)` — top 10
- Guard trigger: contest deadline check

### Task 2: Models & Repository API
- `ContestDay`, `ContestEntry`, `ContestBadge` model'leri
- `loadTodayContest()`, `submitContestEntry()`, `claimContestReward()`, `getContestLeaderboard()` interface
- Mock + Supabase impl (coin guard, badge tracking)

### Task 3: UI — ContestScreen
- AppBar + Card widget
- Real-time leaderboard ListTile
- "Katıl" button → QuizScreen
- State: loading, active, finished

### Task 4: UI — Result Screen Integration
- Ödül banner (con­ditional)
- Badge preview
- Claim button (auto-claim ya da tap)

### Task 5: UI — Profile Badges Tab
- Badge grid view
- Icon + name + date
- TapHandler → detail sheet

### Task 6: Tests & Validation
- Contest logic: reward calc, rank assign
- Badge uniqueness
- Guard trigger: 404 when no contest today

---

## 6. Test Data & Mock

### Contest Daily Generation
**Offline:** Static mock contest (bugün), kategori = Ziman
**Online:** Supabase `contests` tablosu — admin yararlı kontrol

### Badge Seeding
Supabase'e 3 badge INSERT (champion/finalist/participant)

---

## 7. Timeline & Phasing

- **Task 1–2:** Backend RPC + Model (1–2 saat)
- **Task 3–5:** UI Implementation (2–3 saat)
- **Task 6:** Testing + Validation (1 saat)
- **Total:** ~4–6 saat (Faz B bitmişse paralel gidilebilir)

---

## 8. Notes

- Contest tema isimleri Kurmancî (isim sadece TitleCase, İngilizce açıklama yok)
- Coin reward'lar production'da fine-tune edilebilir
- Push notification'lar FCM (existing setup)
- Real-time leaderboard Supabase Realtime tabanlı (contests_entries subscribe)
- Rozet açısından unique constraint: user + badge + contest_id (triple key)
