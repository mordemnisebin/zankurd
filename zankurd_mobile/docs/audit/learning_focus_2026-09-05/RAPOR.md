# ZanKurd öğrenme akışı iyileştirmeleri

Son doğrulama: 6 Eylül 2026.

## Uygulanan değişiklikler

- Tanıtım iki ekrandan tek ekrana indirildi. Kullanıcı doğrudan Başla eylemiyle devam ediyor; tek ekran için gereksiz sayfa göstergesi kaldırıldı.
- İlk oyun tamamlanana kadar ana sayfada günlük ders ve öğrenme yolu öne çıkıyor. Hedef seçimi, rekabet, günlük görevler ve Premium tanıtımı ilk oturumun önüne geçmiyor. İlk oyun tamamlanınca destek kartları yeniden görünüyor.
- Daha önce başlanmış kategoriler varsa Kaldığın yer bölümü görünmeye devam ediyor.
- Sonuç ekranında cevaplanan, doğru ve yanlış soru sayıları gösteriliyor. Cevapsız sorular ayrı sayılıyor; kategorisi boş kayıtlar genel toplamdan düşmüyor.
- Tek doğru cevap veren kullanıcı artık yanlış cevapları varmış gibi yönlendirilmiyor. Konu değerlendirmesi için yeterli kanıt arayan mevcut eşikler korunuyor.
- Yeni özet metinleri Kurmancî ve Türkçe hazırlandı. Kurmancî metin bağımsız kod incelemesindeki dil önerisiyle düzeltildi.

## Doğrulama

- `dart analyze`: sorun yok.
- `flutter test --exclude-tags preview`: 2.572 test geçti.
- Web debug derlemesi başarılı.
- Playwright: tek ekran tanıtım, ilk beş sorunun tamamlanması, sonuç özeti ve ana sayfaya dönüş doğrulandı. İlk oturumdan sonra destek kartlarının yeniden görünmesi kontrol edildi.
- Kurmancî/Türkçe, açık/koyu tema ve 320–1280 piksel genişliklerde ekran görüntüleri kaydedildi. Kontrol sırasında tarayıcı çalışma zamanı veya Flutter taşma hatası kaydedilmedi.
- Yeni sonuç özeti ayrıca 320 piksel genişlikte, yüzde 200 yazı ölçeğinde, iki dil ve iki temada widget testlerinden geçti.
- Nihai yeniden çalıştırma kaydı `validation/final-verification-2026-09-06.md` içinde; tam paket 2.572 test ve Playwright akışı hatasız geçti.

Kontroller yerel debug derlemesi ve çevrimdışı veri deposuyla yapıldı. Bu çalışma mağaza sürümü, canlı ödeme veya gerçek sunucu akışlarının onayı değildir.

## Soru kalitesi ve kalan editoryal işler

12 kaynakta 3.000 benzersiz soru kaydı tarandı. Engelleyici ve kritik hata sayıları sıfır. Mevcut 1.846 uyarı korunuyor:

- 1.378 kaynak bilgisi eksikliği.
- 468 benzer soru adayı.

Bu uyarılar otomatik olarak düzeltilmedi veya silinmedi. Kaynak uydurulmadı; benzerlik adayları doğrulanmış kopya olarak kabul edilmedi. Soru bazındaki inceleme listeleri `content/metadata_gaps.csv`, `content/near_duplicate_candidates.csv` ve `content/warnings.csv` içinde.

Kalite referansındaki iki kaynak parmak izi güncellendi. Öncesi ve sonrası engelleyici/kritik hata sayıları 0→0, uyarı sayısı 1.846→1.846; uyarı kimlikleri değişmedi. Yenilenen referansa göre kalite kapısı geçti. Bu sonuç tüm soruların dil ve bilgi doğruluğunun insan tarafından tek tek onaylandığı anlamına gelmez.

## Kayıtlar

Bu klasörde önce/sonra ekran görüntüleri, `content/` altında içerik raporları, `validation/` altında analiz, test, derleme ve tarayıcı günlükleri bulunur. Tekrarlanabilir tarayıcı kontrolü `tools/playwright/learning-focus.mjs` dosyasındadır.

Üretim değişiklikleri: `onboarding_screen.dart`, `home_screen.dart`, `learning_outcome_card.dart`, `strings.dart`, günlük soru seçici, cevap kanıtı, öğrenme sonucu, analitik rıza, eşleşme metriği ve TTS ayar yüzeyi. Ayrıntılı ürün denetimi uygulama kaydı `PRODUCT_HARDENING.md` dosyasındadır. İlgili regresyon testleri ve kalite referansı güncellendi.
