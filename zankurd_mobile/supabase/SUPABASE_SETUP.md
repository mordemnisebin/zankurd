# ZanKurd — Supabase Kurulum Rehberi

## 1. Supabase Projesi Oluştur

1. [supabase.com](https://supabase.com) → **New Project**
2. Ad: `zankurd`, Region: en yakın (örn. Frankfurt)
3. Güçlü bir şifre belirle, kaydet

---

## 2. SQL Migration'ları Çalıştır

Supabase Dashboard → **SQL Editor** → aşağıdaki sırayla her dosyayı yapıştırıp çalıştır:

| Sıra | Dosya | İçerik |
|------|-------|--------|
| 1 | `migration_step1_schema.sql` | Tablolar, RLS, Fonksiyonlar, Leaderboard view |
| 2 | `migration_step2a_questions.sql` | Soru bankası 1/5 |
| 3 | `migration_step2b_questions.sql` | Soru bankası 2/5 |
| 4 | `migration_step2c_questions.sql` | Soru bankası 3/5 |
| 5 | `migration_step2d_questions.sql` | Soru bankası 4/5 |
| 6 | `migration_step2e_questions.sql` | Soru bankası 5/5 |

---

## 3. Realtime Aktif Et

Supabase Dashboard → **Database → Replication → Tables**:
- `rooms` ✅
- `room_players` ✅
- `room_questions` ✅
- `player_answers` ✅

---

## 4. Anonymous Auth Aktif Et

**Authentication → Providers → Anonymous** → Enable

---

## 5. Flutter Uygulamasına Bilgileri Ekle

Supabase Dashboard → **Settings → API** → `URL` ve `anon key` al.

### `.env` dosyası oluştur (proje kökünde):
```
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
```

### Uygulamayı bu değerlerle çalıştır:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

### Release APK için:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

---

## 6. Veritabanı Yapısı

```
profiles         → kullanıcı adı, coin, rating
categories       → Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk
questions        → sorular (option_a..d, correct_option, is_approved)
rooms            → oyun odaları (kod, status, mode)
room_players     → oda üyeliği (score, streak)
room_questions   → odaya atanan sorular
player_answers   → verilen cevaplar
leaderboard_entries → VIEW (rank, total_score, best_streak)
favorite_questions  → favorilenen sorular
coin_transactions   → coin geçmişi
```

---

## 7. Soru Bankası Yönetimi

Yeni soru eklemek için `is_approved = true` ile insert et:

```sql
INSERT INTO public.questions (
  category_id, language_code, prompt,
  option_a, option_b, option_c, option_d,
  correct_option, explanation, difficulty, is_approved
)
VALUES (
  (SELECT id FROM public.categories WHERE name = 'Ziman'),
  'ku-kmr',
  'Kurmancî''de "heval" ne demektir?',
  'Arkadaş', 'Düşman', 'Öğretmen', 'Aile',
  'A', '"Heval" dost, arkadaş anlamına gelir.', 2, true
);
```

---

## 8. Android Release Build

```bash
# 1. Keystore oluştur (bir kez)
keytool -genkey -v -keystore android/zankurd-release.jks \
  -alias zankurd -keyalg RSA -keysize 2048 -validity 10000

# 2. android/key.properties dosyasını doldur (template mevcut)
cp android/key.properties.template android/key.properties
# → şifreleri doldur

# 3. Release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# 4. Release App Bundle (Play Store için)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

---

## 9. App Icon Güncelleme

İkon değiştirmek istersen:
1. `assets/icon/icon.png` dosyasını değiştir (1024×1024 PNG)
2. `flutter pub run flutter_launcher_icons` çalıştır

---

## Kontrol Listesi

- [ ] Supabase projesi oluşturuldu
- [ ] `migration_step1_schema.sql` çalıştırıldı
- [ ] Soru bankası migration'ları çalıştırıldı (2a-2e)
- [ ] Realtime tablolar aktif edildi
- [ ] Anonymous Auth açıldı
- [ ] `dart-define` değerleri uygulamaya eklendi
- [ ] `android/key.properties` dolduruldu
- [ ] Release build test edildi
