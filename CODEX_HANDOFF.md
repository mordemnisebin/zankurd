# ZanKurd — Oturum Devir Dosyası (Claude → Codex)

> Bu dosya, önceki asistanın (Claude) bu projede yaptığı tüm işleri, mimariyi ve
> deploy altyapısını özetler. Codex bu dosyayı okuyarak sıfırdan bağlam kurmadan
> devam edebilir.

## Proje Nedir

**ZanKurd** — Kurmancî (Kürtçe) dil öğrenme + bilgi yarışması uygulaması.
- **zankurd_mobile/**: Flutter app (Android/iOS/Web) — asıl ürün, aktif geliştirilen
- **zankurd/**: React+Vite prototip web paneli — ikincil, düşük öncelik

Canlı: **https://zankurd.com** (Flutter Web build, Hostinger'da barındırılıyor)
Supabase project ref: `hupivnxgjtsfafulzspo`

## Mimari (özet — detay için zankurd_mobile/CLAUDE.md'ye bak)

- Repository pattern: `ZanKurdRepository` (abstract) → `SupabaseZanKurdRepository`
  (composition ile içinde `MockZanKurdRepository _offline` tutar, hata durumunda
  ona düşer) ve `MockZanKurdRepository` (offline/test).
- State: Provider 6.1.0
- Coin bakiyesi **sunucu-otoriter**: `coin_transactions` toplamı, client-side
  keyfi coin ekleme yolu YOK, tekrar eklenmemeli.
- 5 sekmeli AppShell: Sereke / Kategorî / Xwendin / Pêşbaz / Profîl.
  Turnuva ve Hevalên artık ayrı tab değil — Ana Sayfa kartından ve Profil
  menüsünden erişiliyor (bilinçli tasarım kararı, bkz. Faz G1).

## Bu Oturumda Yapılanlar (kronolojik)

### Faz E — Persistence, Tournament, Social, Analytics altyapısı
- `models/`: `lesson.dart`, `friend.dart`, `tournament.dart` (immutable + JSON)
- `utils/analytics_tracker.dart`: event logging yardımcıları
- Repository'ye 11+ yeni metod (ders, arkadaş, turnuva, analytics, mission sync)
- SQL: `2026-07-06_persistence.sql` (mission_completions, analytics_events,
  tournament_progress tabloları + RPC'ler)
- `TournamentScreen`, `FriendsScreen` ilk versiyonları, AppShell'e eklendi

### Faz F/G1 — Stabilizasyon
- **AppShell 7→5 sekme**: NavigationBar taşma bug'ı vardı, testler kırılıyordu.
  Turnuva/Hevalên erişimi ana ekran kartı + Profil menüsüne taşındı.
- **TournamentScreen komple yeniden yazıldı**: lobi ekranı ("ZanKurd Kupası" /
  "Turnuvaya Başla") → 16 kişilik şema (Son 16→Final) → "Maçı Başlat" gerçek
  bot-yarışı quiz'i açıyor → tur ilerleme + şampiyon banner'ı.
- **Kritik bug bulundu ve düzeltildi**: Supabase `RETURNS TABLE` tipi RPC'ler
  PostgREST'te **liste** döndürür, kod `rpc<Map>` cast'i yapıyordu — bu runtime'da
  patlayıp sessizce offline fallback'e düşüyordu (çark ödülü, arkadaş ekleme,
  analytics hep bozuktu). Çözüm: `supabase_zankurd_repository.dart` içinde
  `_firstRow(dynamic response)` helper — ilk satırı Map'e çevirir.
- Kurmancî çeviri düzeltmeleri: Pêş/Paş buton karışıklığı, "Hûwander"→"Hejmar",
  bozuk TR-KU karışık mesajlar.
- SQL: `2026-07-06_friends_system.sql`, `2026-07-06_learning_zone.sql`,
  `2026-07-06_spin_wheel_backend.sql` — hepsi `DROP ... CASCADE` + yeniden
  `CREATE` pattern'iyle idempotent hale getirildi (Supabase SQL Editor'de
  tekrar tekrar "already exists" hatası alınıyordu, artık alınmıyor).

### Faz G2 — Sosyal tamamlama
- `search_profiles` ve `reject_friend_request` RPC'leri (`2026-07-07_friends_v2.sql`)
- `FriendsScreen`e gerçek oyuncu arama + ekleme UI, istek reddetme butonu
- "Oyna" butonu artık gerçek özel oda açıp `RoomScreen`'e yönlendiriyor
  (önceden sahte "yakında" snackbar'ıydı)
- `PlayerSearchResult` modeli eklendi

### Faz G3 — Parlatma
- Ders tamamlama rozetleri (yeşil ✓ işareti, liste + slayt ilerleme çubuğu)
- 4 yeni analytics olayı bağlandı (lesson_completed, tournament_started,
  tournament_champion, friend_request_sent)
- Ders içeriği seed: `2026-07-06_lesson_seed.sql` — **15 ders, 62 slayt**,
  8 kategorinin tamamı (Roj-beroj, Gramer, Çand, Xwarin, Ajal, Cografya,
  Hest, Dem) — Kurmancî + Türkçe çeviri + örnek cümle içeriyor.

### Faz H — Görsel tasarım yenileme (kullanıcı isteği: "çok basit görünüyor")
- **QuickPlayGrid** kartlarına dairesel ikon rozeti + arka planda dev "ghost"
  ikon dekor — 4 hızlı-oyun kartı artık aynı düz gradyan kutu gibi görünmüyor.
- **SectionHeader** opsiyonel renkli ikon rozeti desteği.
- **HomeHeader** coin rozetine glow gölgesi + büyütülmüş tipografi.
- **`widgets/coach_mark.dart`** (YENİ, paket bağımlılığı yok): spotlight
  overlay — hedef widget'ı aydınlık bırakıp gerisini karartan CustomPainter +
  yönlendirici balon (İleri/Atla, ku/tr). `AppShell`e entegre: profil adı
  tamamlanan her kullanıcı için (yeni ya da mevcut) bir kez gösterilen
  5 adımlık tur, alt menü sekmelerini tanıtıyor.
  - **Bilinen ve düzeltilen bug**: masaüstü genişliğinde (`ResponsiveWrapper`
    uygulamayı 480px'lik ortalanmış çerçeveye sığdırıyor)
    `RenderBox.localToGlobal()` "gerçek ekran köküne göre" konum veriyordu,
    spotlight yanlış yerde (ekranın sağında) beliriyordu. Çözüm:
    `CoachMarkOverlay`e `ancestorKey` parametresi eklendi, `AppShell`in dış
    `Stack`ine bu key veriliyor, `localToGlobal(ancestor: ...)` ile göreceli
    konum hesaplanıyor. **Canlıda test edilip doğrulandı.**
  - Build sırasında (değil, post-frame callback'te) ölçüm yapılıyor —
    build() içinde RenderBox sorgulamak "hasSize" assertion'ına çarpıyordu.
- `AppEmptyState`/`AppErrorState` ikon rozetine ikinci soluk halka eklendi.

## Kalite Durumu (bu oturum sonunda)

- `dart analyze`: **0 sorun**
- `flutter test`: **321/321 yeşil** (Windows'ta `flutter analyze` LSP hatası
  yüzünden çöküyor — Türkçe İ karakteri path'i bozuyor; **`dart analyze`
  kullan**, o çalışıyor)
- pubspec version: **1.8.0+10**
- Son commit: `655a4ca` — "fix(coach-mark): masaüstü genişliğinde spotlight
  konum kayması düzeltildi"

## Deploy Altyapısı (KALICI — Codex bunu kullanabilir)

### Web (Hostinger)
```bash
# 1. Build al
cd zankurd_mobile
flutter build web --release
cd build
tar -czf web.tar.gz web

# 2. SSH key ile yükle (anahtar zaten sunucuda authorized_keys'e eklenmiş durumda)
scp -P 65002 -i ~/.ssh/zankurd_deploy -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no web.tar.gz \
  u622615894@82.25.102.137:domains/zankurd.com/

# 3. Extract + yerleştir
ssh -p 65002 -i ~/.ssh/zankurd_deploy -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no u622615894@82.25.102.137 \
  "cd domains/zankurd.com && tar -xzf web.tar.gz && cp -rf web/* public_html/ && rm -rf web web.tar.gz"
```
SSH private key: `~/.ssh/zankurd_deploy` (yerel makinede, bu oturumda oluşturuldu).
Public key zaten Hostinger hPanel → SSH Access → SSH Keys altında kayıtlı.

### Supabase (proje: `hupivnxgjtsfafulzspo`)
Migration uygulamak için Management API kullanılabilir:
```powershell
. $PROFILE  # SUPABASE_ACCESS_TOKEN burada tanımlı
$sql = Get-Content "path/to/migration.sql" -Raw -Encoding UTF8
$body = @{ query = $sql } | ConvertTo-Json -Depth 3
$headers = @{ Authorization = "Bearer $env:SUPABASE_ACCESS_TOKEN"; "Content-Type" = "application/json" }
Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/hupivnxgjtsfafulzspo/database/query" `
  -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
```
**Önemli**: Yeni migration dosyaları `DROP ... CASCADE` + yeniden `CREATE`
pattern'i kullanmalı (idempotent olsun diye) — Supabase'de tablo/policy/index
zaten varsa "already exists" hatası fırlatıyor, plain `CREATE TABLE IF NOT
EXISTS` yeterli değil çünkü `CREATE POLICY`/`CREATE INDEX` için `IF NOT EXISTS`
sözdizimi yok.

**Doğrulama (salt okunur, güvenli)**: Bir migration'ın gerçekten uygulanıp
uygulanmadığını kontrol etmek için:
```sql
SELECT routine_name FROM information_schema.routines
  WHERE routine_schema='public' AND routine_name = 'fonksiyon_adi';
SELECT table_name FROM information_schema.tables
  WHERE table_schema='public' AND table_name = 'tablo_adi';
```

### Android
```powershell
$env:TMP = "C:\src\tmp"; $env:TEMP = "C:\src\tmp"  # Gradle loopback fix, ZORUNLU
mkdir C:\src\tmp -Force
cd zankurd_mobile
flutter build apk --release
```
APK çıktısı: `build/app/outputs/flutter-apk/app-release.apk`
**Not**: Home path'te Türkçe İ karakteri (`C:\Users\AMARGİ\...`) bazı build
adımlarında (gen_snapshot, jni) sorun çıkarabiliyor — gerekirse
`C:\src\zk` gibi bir junction (`mklink /J`) üzerinden derle.

## Bilinen Sorunlar / Yapılmadı

- **Play Console yükleme**: Kullanıcı bilinçli olarak erteledi ("şimdi
  yapmayacağız"). APK v1.7.0+9 için hazırdı; v1.8.0+10 için henüz build
  alınmadı (görsel yenileme sonrası).
- **Quiz ekranı** (`quiz_screen.dart`, 1341 satır) Faz H'te dokunulmadı —
  görsel yenileme sadece Ana Sayfa/Kategoriler/Turnuva/boş-durumlara uygulandı.
  İstenirse aynı görsel dil (ghost icon, ikon rozeti) buraya da taşınabilir.
- **offline_question_bank.dart** 20.064 satır — kategori başına dosyaya
  bölünmesi önerildi ama yapılmadı (düşük öncelik, sadece derleme/inceleme
  hızını etkiler).
- `zankurd/` (React web prototip) bu oturumda hiç dokunulmadı.

## Codex İçin Görev Önerisi (opsiyonel başlangıç noktaları)

Eğer devam edilecekse, mantıklı sıradaki adımlar:
1. Quiz ekranına Faz H görsel dilini taşımak (ghost icon, ikon rozetleri)
2. Android APK'yı v1.8.0+10 için yeniden build edip Play Console'a hazırlamak
3. `offline_question_bank.dart`'ı kategori başına dosyalara bölmek
4. Turnuva sistemi için gerçek skor takibi (şu an `_advanceRound()` basitleştirilmiş
   simülasyon yapıyor — bkz. `tournament_screen.dart` içindeki yorum)

Her zaman şunları çalıştır: `dart analyze` (0 sorun bekleniyor) ve
`flutter test` (321/321 bekleniyor) — herhangi bir değişiklik sonrası.
