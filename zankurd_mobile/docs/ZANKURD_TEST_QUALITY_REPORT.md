# ZANKURD TEST & QUALITY HARDENING RAPORU

**Tarih:** 2026-07-10
**Branch:** `zankurd-test-quality-hardening` (`ui-quality-merge` üzerinden)
**Kapsam:** Test kapsamı artırma, regression testleri, minimal bug fix — redesign YOK.

---

## 1. Başlangıç Durumu

- Proje kökü doğrulandı: `zankurd_mobile` (pubspec.yaml, lib/, test/ mevcut).
- Working tree temizdi (3 untracked docs/çıktı dosyası hariç).
- Dart SDK 3.12.1; `flutter pub get` başarılı.
- **Baseline: 351 test, tamamı geçiyor; `dart analyze` temiz (0 issue).**
- Not: `flutter analyze` bu ortamda çöker (yol içindeki Türkçe İ, LSP byte-stream'i bozar) — `dart analyze` kullanıldı.

## 2. Mevcut Test Envanteri (baseline)

47 test dosyası; güçlü kapsam alanları:
- Store'lar (achievement, mastery, streak, mistake, seen-question, xp, daily-mission) — unit
- Soru bankası validasyonu (`question_bank_test.dart`), joker (`wildcard_test.dart`), skor (`quiz_scoring_test.dart`), coin (`coin_calculator_test.dart`)
- `widget_test.dart` (1632 satır): auth kapısı, onboarding viewport'ları, oda lobisi (start-disabled/enabled + player stream), leaderboard loading/empty/error/data, quiz akışı, sonuç ekranı, ayarlar/hesap silme
- Before/after UI regression testleri (home, quiz, profil, kategoriler, sonuç, quickplay)
- Golden testler (`test/golden/`, core widget'lar)

## 3. Tespit Edilen Test Boşlukları

| Alan | Baseline durumu | Bu çalışmada |
|---|---|---|
| SpinWheelScreen davranışı | Sadece "ekran açılıyor" testi | 5 davranış testi eklendi |
| ShopScreen | Hiç test yok | 5 test eklendi |
| MatchmakingScreen | Hiç test yok | 2 test eklendi |
| Oda kodu normalizasyonu | Dolaylı | 4 unit test eklendi |
| Leaderboard refreshSignal sözleşmesi | Yok (yalnız profile'da vardı) | 1 regression test eklendi |
| Çark gün-anahtarı (UTC) | Yok | 4 unit test eklendi |

## 4. Düzeltilen Bug

### 4.1 Günlük çark: lokal/UTC gün sınırı uyumsuzluğu (GERÇEK BUG)

**Dosya:** `lib/src/data/supabase_zankurd_repository.dart`

- Sunucu RPC'leri (`can_spin_today`, `award_spin_coins`) gün sınırını `CURRENT_DATE` (**UTC**) ile çizer; ekrandaki geri sayım da UTC gece yarısını hedefler (`spin_wheel_screen.dart:73-74`).
- İstemcideki SharedPreferences guard'ı ise **lokal** `DateTime.now()` ile `y-m-d` üretiyordu.
- Sonuç (UTC+3'te): lokal gece yarısı → UTC gece yarısı arasında (00:00–03:00) buton **aktif** görünür, çark döner gibi olur, sunucu ödülü reddeder → "Bugün zaten çevirdin" / "çark dönmüyor" şikayeti. Tersi pencerede guard gereksiz kilitler.
- **Fix:** gün anahtarı üretimi `spinDayKey(DateTime)` adlı saf/statik yardımcıya çıkarıldı ve **UTC**'ye normalize edildi; `canSpinToday` + `awardSpinCoins` içindeki iki kullanım da bu yardımcıya bağlandı. Eski kayıtlı lokal değer en kötü ihtimalle guard'ı pas geçirir — sunucu zaten yetkili olduğundan güvenlidir (çift ödül riski yok).
- **Regression testi:** `test/spin_day_key_test.dart` (4 test).

### 4.2 Format sonrası lint düzeltmesi

`lib/src/data/daily_mission_store.dart:101` — `dart format` sonrası tek satırlık `if ... continue;` `curly_braces_in_flow_control_structures` uyarısı verdi; süslü paranteze alındı (davranış değişikliği yok).

## 5. Eklenen Testler (21 yeni test, 6 yeni dosya)

**Unit:**
- `test/spin_day_key_test.dart` (4): UTC gün anahtarı — saat dilimi bağımsızlığı, UTC gece yarısı sınırı, lokal→UTC eşdeğerliği, idempotentlik.
- `test/room_code_test.dart` (4): oda kodu trim+uppercase normalizasyonu (`joinRoom`, `joinOnlineRoom`), ZK- önekli kod üretimi.

**Widget / Regression:**
- `test/spin_wheel_screen_test.dart` (5):
  - Hak varken "Çevir!" aktif.
  - Hak yokken buton pasif + geri sayım görünür.
  - Çevirince ödül **tam bir kez** verilir (hızlı çift dokunuş çift ödül üretmez), hak kapanır.
  - Sunucu 0 dönerse (UTC sınırı reddi) crash yok, "Bugün zaten çevirdin." + hak kapanır.
  - `canSpinToday` hata fırlatırsa crash yok, kullanıcıya uyarı.
- `test/shop_screen_test.dart` (5):
  - Bakiye + 4 ürün listelenir.
  - Bakiye yetersiz → "Bakiye yetersiz!", `spendCoins` HİÇ çağrılmaz.
  - Satın alma coini düşürür, doğru gerekçeyle (`purchase_extra_lifeline`) harcar, bakiye UI'da güncellenir.
  - Alınmış ürün "Alındı" + buton pasif (tekrar alınamaz).
  - `spendCoins` false dönerse hata mesajı gösterilir.
- `test/matchmaking_screen_test.dart` (2):
  - Seçim menüsü 1vs1 girişini ve rastgele eşleşmeyi gösterir.
  - Ekrandan çıkınca `cancelMatchmaking` çağrılır (kuyrukta hayalet oyuncu kalmaz).
- `test/leaderboard_refresh_test.dart` (1):
  - `refreshSignal` tetiklenince liderlik tablosu yeniden yüklenir (IndexedStack stale-tab regression'ı).

## 6. Kod İncelemesi Bulguları (değişiklik gerektirmeyen — doğrulandı)

- **Oda kur/katıl (Aşama 7.1):** `room_screen.dart` realtime + 3 sn'lik polling fallback'e sahip; host, realtime sussa bile misafiri görür. Tüm subscription/timer'lar dispose ediliyor. Buton koşulu `ready && !starting && players.length >= 2` doğru.
- **1v1 soru senkronu (7.2):** Sorular `room_questions` tablosundan `question_index` sırasıyla okunur (`loadRoomQuestions`) — iki oyuncu aynı seti aynı sırada görür; istemci başına rastgele tohum yok.
- **Takım oyunu (7.3):** Kod tabanında ayrı bir "takım" modu YOK; çok oyunculu oda akışı (2+ oyuncu) bunu karşılıyor. Test edilecek ayrı bir takım-state makinesi bulunmadı — yeni özellik isteği olarak değerlendirilmelidir.
- **Kodla giriş input görünürlüğü (7.6):** `home_screen.dart` join sheet'i theme-aware renkler, açık hintStyle, focus border ve validator ile zaten düzeltilmiş; repo tarafı `trim().toUpperCase()` normalize ediyor (artık testli).
- **Liderlik bayatlaması (7.5):** `LeaderboardScreen` hem oto-refresh timer'ı hem `refreshSignal` dinleyicisi taşıyor; sinyal AppShell'den bağlı (artık testli).
- **Dispose denetimi (Aşama 6):** `quiz_screen` (7 timer/sub + 2 controller), `matchmaking_screen` (2 controller, sub, timer + kuyruk iptali), `spin_wheel` (controller + countdown), `room_screen` (2 sub + polling) — tümü eksiksiz dispose ediyor; async callback'lerde `mounted`/`_isCancelled` guard'ları tutarlı.
- **Shop `context.read<SoundProvider>()`** (`shop_screen.dart`): try bloğu içindeydi; provider/ses hatası başarılı satın almayı "Bir hata oluştu" mesajına dönüştürebiliyordu. **Düzeltildi (890065f):** ses çağrısı çark ekranındaki desenle aynı şekilde kendi try-catch'ine alındı.

## 7. Formatlama

`dart format lib test` çalıştırıldı: 85 dosya biçimlendirildi (Dart 3.12 formatter). Davranış değişikliği yok; `dart analyze` + tam test paketiyle doğrulandı. Test koşusunun yeniden ürettiği `docs/screenshots/*.png` artefaktları geri alındı (görsel değişiklik yok).

## 8. Çalıştırılan Komutlar ve Sonuçları

| Komut | Sonuç |
|---|---|
| `flutter pub get` | Başarılı |
| `dart analyze` (baseline) | 0 issue |
| `flutter test` (baseline) | 351/351 geçti |
| `dart format lib test` | 85 dosya biçimlendi |
| `dart analyze` (final) | 0 issue |
| `flutter test` (final) | **372/372 geçti** (351 baseline + 21 yeni) |
| `flutter build web --release` | Başarılı (97 sn, ikon tree-shaking aktif) |

## 9. Manuel Test Gerektirenler

- Gerçek iki cihazla 1v1 (realtime gecikme/yeniden bağlanma).
- 3+ oyunculu gerçek oda (çoklu katılımcı senaryosu).
- Gerçek Supabase realtime altında lobby güncellemesi ve leaderboard tazeliği.
- Günlük çarkın **gerçek UTC gece yarısı geçişinde** davranışı (fix bu sınırı hedefliyor).
- Android küçük ekran + textScale 1.3+ görsel kontrolü.

## 10. Kalan Riskler

- ~~Sunucu saat dilimi UTC varsayımı~~ **KAPANDI (2026-07-10):** canlı DB'ye salt-okunur sorguyla doğrulandı — `timezone = UTC`. Sorgu anında lokal tarih 10 Temmuz iken sunucu 9 Temmuz 23:21 UTC'deydi; yani tam uyumsuzluk penceresi canlıda gözlendi ve fix'in hedeflediği durum birebir teyit edildi.
- `join_matchmaking` canlı durumu hafıza notlarında "uygulandı (2026-07-03)" görünüyor; 1v1 online akışın canlı doğrulaması yine de iki cihaz ister.
- Takım oyunu ayrı mod olarak yok; ürün beklentisiyse ayrı bir geliştirme kalemi.
- Format diff'i geniş (85 dosya) ama tamamen mekanik; istenirse `style:` ve `test:` olarak iki commit'e bölünebilir.

## 11. Commit Önerisi

```
test: harden zankurd core flows and regression coverage
```

İstenirse bölünmüş:
1. `style: apply dart format across lib and test`
2. `fix: align daily spin day-key with server UTC boundary`
3. `test: add spin wheel, shop, matchmaking and room code coverage`
