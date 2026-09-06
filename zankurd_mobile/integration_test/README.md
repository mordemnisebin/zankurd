# Entegrasyon & Performans Testleri

Bu klasör uçtan uca akış senaryolarını ve performans ölçüm senaryosunu içerir.
Kurallara uygun olarak **geliştirme makinesine bağlı milisaniye assertion'ları
kullanılmaz**; performans için timeline raporu üretilir ve gözden geçirilir.

## Akış senaryoları (`app_flows_test.dart`)

Auth gerektirmeyen, cihazdan bağımsız uçtan uca yollar (store + servis + ekran):

- Seviye belirleme sınavı → sonuç → kalıcı kayıt
- Akıllı tekrar: yanlış → hazır kuyruk → SM-2 çözüm
- Hareket azaltma tercihi kalıcı
- Çevrimdışı temel öğrenme: soru havuzu erişilir

Çalıştırma:

```bash
# CI / masaüstü (headless)
flutter test integration_test/app_flows_test.dart

# Gerçek cihaz / emülatör
flutter test integration_test/app_flows_test.dart -d <device_id>
```

### Gerçek cihaz smoke testi (tam onboarding→auth akışı)

Tam `onboarding → profil adı → seviye tespiti → öğrenme yolu` akışı canlı auth
gerektirir; manuel smoke test olarak bağlı cihazda profile modunda doğrulanır:

```bash
$env:TMP = "C:\src\tmp"; $env:TEMP = "C:\src\tmp"
flutter run --profile -d <device_id>
```

## Performans (`performance_test.dart` + `test_driver/perf_driver.dart`)

Profile modunda (debug ölçümü yanıltıcıdır) gerçek cihazda kaydırma profili:

```bash
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/performance_test.dart \
  --profile -d <device_id>
```

Çıktı `output/performance/` altına yazılır:
- `scroll_timeline.timeline.json` — ham Chrome trace
- `scroll_timeline.timeline_summary.json` — özet (ortalama/worst frame, jank)

Ölçülen temsili yollar: ana ekran kaydırma, öğrenme yolu kaydırma, quiz soru
geçişleri, civak ekranı. Gerçekçi bir bakış için `average_frame_build_time_millis`
ve `worst_frame_build_time_millis` değerleri incelenir; sabit bir eşik
dayatılmaz (cihaz donanımına göre değişir).

## İki rollü yerel backend testleri: derlemeyi önce ısıtın

`local_backend_1v1_test.dart` ve `local_backend_durability_test.dart` iki
EŞZAMANLI koşum ister: `host` odayı kurup kodu basar, `guest` o kodla
katılır. Host guest'i **300 saniye** bekler.

İlk denemede ikisi de kırılır ve ikisi de ürün kusuru gibi görünür:

- host: `Expected: <2>  Actual: <1>` — "guest odaya katilmadi"
- guest: `Expected: RoomStatus.active  Actual: RoomStatus.lobby`

Sebep ürün değil, harness: guest cihazında ilk `flutter test` bir Xcode
derlemesi yapar (~160 sn) ve host'un penceresi buna yetişmez. Guest aslında
odaya KATILIR; yalnız host çoktan pes etmiştir.

Doğru sıra (2026-08-17'de bu yolla doğrulandı):

1. Her iki cihazda testi bir kez tek başına koşturup derlemeyi ısıtın.
2. Sonra host'u başlatın, log'dan `ZK_ROOM_CODE=` satırını bekleyin.
3. Kodu alıp guest'i ikinci cihazda hemen başlatın.

Isıtılmış derlemeyle guest ~30 sn'de bağlanır ve ikisi de geçer. Geçtiğinde
host ile guest'in `ZK_*_Q0` değerleri AYNI olmalıdır: iki ayrı anonim
kullanıcının gerçek PostgreSQL'den aynı soru setini aynı sırada alması,
çok oyunculu adaletin sözleşmesidir.
