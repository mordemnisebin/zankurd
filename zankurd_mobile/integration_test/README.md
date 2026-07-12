# Entegrasyon & Performans Testleri

Bu klasör uçtan uca akış senaryolarını ve performans ölçüm senaryosunu içerir.
Kurallara uygun olarak **geliştirme makinesine bağlı milisaniye assertion'ları
kullanılmaz**; performans için timeline raporu üretilir ve gözden geçirilir.

## Akış senaryoları (`app_flows_test.dart`)

Auth gerektirmeyen, cihazdan bağımsız uçtan uca yollar (store + servis + ekran):

- Seviye belirleme sınavı → sonuç → kalıcı kayıt
- Akıllı tekrar: yanlış → hazır kuyruk → SM-2 çözüm
- Çocuk modu: sosyal/paylaşım kapıları kilitlenir ve geri gelir
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
