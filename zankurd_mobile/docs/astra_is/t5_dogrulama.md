# T5 — Doğrulama ve teslim durumu

30 Ekim 2026. **Tamamlandı / birleştirmeye hazır değildir.** Kod ve uygulanmamış
göç hazır; widget davranışları, canlı SQL ve bağımsız Opus onayı açık.

## Çalışan kontroller

- `flutter --suppress-analytics --no-version-check analyze --no-pub`:
  **No issues found! (ran in 320.8s)**. Aynı Flutter 3.44.7 SDK'sının geçici,
  yazılabilir kopyası kullanıldı; bağımlılıklar mevcut önbellekten çözüldü.
- `dart --suppress-analytics format --set-exit-if-changed lib test`:
  **Formatted 1202 files (0 changed)**, çıkış 0.
- `git diff --check`: temiz; `git diff --diff-filter=D --stat`: boş.
- Gerçek Dart VM'sinde üretim `ServerRevealClock` sınıfı ile altı bağımsız
  duman kontrolü geçti: geç cihaz, deadline öncesi, iki saatin aynı anda
  sıfırlanması, arka plan gecikmesi, mod süreleri, yanlış cevabın 3 sn okunması.
  Bu kontroller Flutter testlerinin yerine sayılmaz.
- SQL metin sözleşmesi için altı kontrol geçti: işlem sınırı, canlı gövde
  çıpaları, dar süre değişikliği, ortak zaman alanı, ACL/RLS, son do-bloğu
  ve geri alma açıklaması. SQL PostgreSQL üzerinde çalıştırılmadı.
- İlk kırmızı test denemesinde henüz var olmayan reveal_timing.dart ithalatı
  derlenmedi. Widget testlerinde RED/GREEN davranış kanıtı alınamadı.

## Çalıştırıldı fakat ortam tarafından engellendi

`flutter test --no-pub` ile aşağıdaki 12 dosya denendi. Hepsi test gövdesinden
ÖNCE aynı hata ile yüklenemedi: `Failed to create server socket (OS Error:
Operation not permitted, errno = 1), address = 127.0.0.1, port = 0`.

- test/t5_reveal_timing_test.dart
- test/t5_gecis_sql_test.dart
- test/quiz_room_resume_test.dart
- test/async_duel_screens_test.dart
- test/supabase_repository_test.dart
- test/soru_sigma_test.dart
- test/soru_sigma_ek_test.dart
- test/soru_sigma_ek2_test.dart
- test/tur3_bulgu_test.dart
- test/turnuva_sunucu_puani_istemci_test.dart
- test/duello_sirasi_istemci_test.dart
- test/room_question_advance_test.dart

Aynı kısıt doğrudan Python yerel socket bind denemesinde de doğrulandı.
**Sigma/tur3 yeşil denemez.** Gerçek Flutter web/Playwright veya simülatör
kare kontrolü yapılmadı. Yerleşim/dock/metin dosyaları değiştirilmedi.

`bash tool/ci_yerel.sh --tam` başlatıldı; format adımı geçti, analiz adımında
tekrarlı uzun çalışma durduruldu (ayrı flutter analyze temiz tamamlandı).
Tam CI'nin kalan kapıları tamamlanmadı; zaten ekran turu/testler aynı yerel
socket iznini gerektiriyor. Push yapılmadı.

Dart MCP roots çağrısı: `MCP tool call requires approval, but approval policy
is never`. Yerel CLI'ye geçildi. İlk SDK/pub/telemetri yazma engelleri yalnız
geçici SDK/cache ve analytics kapatma ile aşıldı; global ayarlar değiştirilmedi.

## İnceleme, commit ve belge yolu

- Claude Opus 5.5 (`agy --model claude-opus-5-5-high`) salt metin incelemesi
  boş geçici klasörde denendi. CLI, günlük dizinine yazamadı ve localhost
  portu açamadı: `listen tcp 127.0.0.1:0: bind: operation not permitted`.
  **Opus cevabı/onayı yok.** Kod dış modele ulaşmış veya incelenmiş sayılmaz.
- `git add` başarısız: `/Users/kocer/Projects/zankurd/.git/worktrees/
  zk-astra-gecis/index.lock: Operation not permitted`. Commit oluşturulamadı;
  bütün değişiklikler worktree'de duruyor. Hazır mesaj: `t5_commit_mesaji.txt`.
- İstenen `/Users/kocer/Projects/zankurd_kapisma/astra_is/t5_karar.md` yoluna
  kopyalama `Operation not permitted` ile reddedildi. Asıl teslim belgesi
  bu klasördeki `t5_karar.md`; yetkili oturumda istenen yola kopyalanmalı.

## Değişen dosyalar

Üretim:
- lib/src/game/reveal_timing.dart — mod süreleri ve monoton sunucu saati.
- lib/src/models/room.dart — opsiyonel revealClock (eski sunucu uyumu).
- lib/src/data/supabase_zankurd_repository.dart — ortak bitiş zamanı, RTT/2
  tahmini; saat oda/profil yüklemesinden önce yakalanır.
- lib/src/screens/quiz_screen.dart — mevcut sayaç ve advance CAS akışına
  saat bağlandı; sıfır süreli tekrarlama döngüsü önlendi.
- lib/src/screens/async_duel/async_duel_play_screen.dart — yanlış/TIMEOUT
  3 sn, doğru 1,2 sn; aynı ekranı kullanan sunucu puanlı turnuvaya da uygulanır.
- supabase/2026-10-30_gecis_ritmi.sql — idempotent, çıpalı dar yama; uygulanmadı.
- supabase/applied.md — ⏳ YAZILDI, UYGULANMADI kaydı.

Bekçiler: t5_reveal_timing_test, t5_gecis_sql_test yeni; quiz_room_resume_test,
supabase_repository_test, async_duel_screens_test, duello_sirasi_istemci_test,
turnuva_sunucu_puani_istemci_test genişletildi. Eski doğrulamalar kaldırılmadı;
TIMEOUT/yanlış cevap bekleyen helper süreleri yeni 3 sn'ye uyarlandı.

## Açık riskler / sonraki yetkili oturum

1. Yukarıdaki 12 dosyayı, ardından `tool/ci_yerel.sh --tam` çalıştır; gerçek
   ekranda geri sayım, dock sabitliği ve final geçişini gör.
2. Opus bağımsız incelemesini tamamla; testler çalışmadığı için yeni widget
   bekçilerinin çalışma zamanı doğruluğu da henüz kanıtlanmış değil.
3. Göç uygulamasından önce gerçek `pg_get_functiondef` diff'i ve
   begin/rollback testleri: iki eşzamanlı ilerletme, herkes/eksik cevap,
   TIMEOUT, ayrılan üye, son soru, tekrar uygulama, anon yetkisizliği.
   Bilinmeyen çıpa göçü güvenle durdurur; bu durumda eski gövdeyi kopyalama.
4. Ağ asimetrisinde RTT/2 yalnız tahmindir. Cihazların fiziksel çizim anı
   birebir garanti değil; son tarih ve ilerletme yetkisi sunucuda ortaktır.
5. Göç uygulanana kadar canlı odalar 5 sn yedek davranışını sürdürür.
6. Test/inceleme sonrası istenen Türkçe mesajla commit; push yok.

## TR / KU tablosu

| Anahtar | TR | KU | Durum |
|---|---|---|---|
| Yeni dize yok | Mevcut geri sayım korundu | Mevcut KU korundu | strings.dart değişmedi; yeni çeviri/jüri gerekmiyor |
