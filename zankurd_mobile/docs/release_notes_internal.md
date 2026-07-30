# Sürüm notları — iç test

`play_console_submission_checklist.md` ve `play_store_internal_test.md`
bu dosyaya işaret ediyordu ama dosya yoktu (2026-07-27'de yazıldı). İki
kontrol listesi de "release notes alanına bu dosyanın içeriğini koy"
diyor; o alan boş bırakılamaz.

Buradaki metin **iç test** içindir: ne yaptığımızı ekibe anlatır. Mağaza
listesinde görünecek kullanıcıya dönük metin ayrı bir dosyadadır
(`store_listing.md`).

Yeni sürüm hazırlarken: en üste yeni bir başlık aç, eskiyi silme.

---

## 1.9.1+13 — 2026-07-27

Bu tur bir denetim turudur: yeni özellik yok, 112 düzeltme var. Ağırlık
okunabilirlik ve içerik doğruluğunda.

### Okunabilirlik (17 düzeltme)

Bütün ekranlarda metin/zemin kontrastı ölçüldü ve WCAG AA eşiğinin
(4.5:1) altında kalan her yer düzeltildi. En ciddileri:

- Açık temada **bütün** sönük metinler 3.54:1'di — tek bir renk sabiti
  ekranların yarısını etkiliyordu.
- Podyum sıra numaraları 1.36:1; okunabilirliğini yalnız altındaki
  gölgeye borçluydu.
- Turnuvanın ne zaman başlayacağını söyleyen satır 1.78:1.
- Soru öner ekranında B, C, D harfleri karoda kayboluyordu (1.93:1).

Renk kararları artık ölçüte bağlı: `onAccentTint` ve `onSolid`
yardımcıları zemini hesaplayıp yazı rengini seçiyor, kontrast zaten
yeterliyse rengi değiştirmiyor.

### İçerik (16 düzeltme)

- **Aynı soru bankada üç kez duruyordu.** 479 soru anlamsız bir ders
  çerçevesi cümlesiyle başlıyordu; o cümle silinince 240 grubun 239'unun
  üçlü kopya olduğu görüldü. Kopyalar atıldı: 2387 → 1908 soru, gerçek
  içerik azalmadan.
- Doğru cevabın biçimle ele verdiği sorular kapatıldı (en uzun
  çeldiricinin 1,5 katından uzun doğru cevap: sıfır).
- Sorunun istediği türden olmayan şıklar düzeltildi ("hangi dilde?"
  sorusuna kitap adı, "hangi şehir?" sorusuna siyasi parti).

### Dil (10 düzeltme)

- Türkçe başlıklarda büyük İ noktasını kaybediyordu ("GÜVENLIK").
- Türkçe günlük görev kategoriyi Kurmancî yazıyordu ("Muzîk", "Dîrok").
- Kurmancî metinlere Türkçe kelime ve harf sızmıştı; iki soruda Kurmancî
  açıklama Türkçenin birebir kopyasıydı.
- Yüzde biçimi üç yerde Kurmancîde Türkçe önekle yazılıyordu.

### Veri

- Yeni oyuncuya sıralamada "1. sıradasın, 5000 puanın var" deniyordu:
  çevrimdışı depo demo tablosunun birincisini "senin satırın" diye
  döndürüyordu.

### Marka

- Uygulama simgesi ürünün logosu değildi; simge, açılış ekranı ve
  uygulama içi logo tek kaynaktan yeniden üretildi.
- Android'e uyarlanabilir simge eklendi (`monochrome` katmanı dahil).

### Test

987 test geçiyor. Her düzeltmenin yanında onu koruyan bir bekçi var;
bekçilerin çoğu ölçüt tabanlı (kontrast oranı, alfabe, kopya gövde), yani
yarın eklenecek içerikte de çalışır.

### Bu sürümde olmayan

- Fotoğraf kapsamı %9,9'da duruyor (lisans kararı bekliyor).
- İki şıklı sorularda soru kartı ekranı tam doldurmuyor; dolgu bir kademe
  açıldı ama kartın kalan alana uzaması ayrı bir iş.
