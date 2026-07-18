# ZanKurd UX, Responsive ve İçerik Sağlamlaştırma Tasarımı

Tarih: 2026-07-18

## Amaç

17 Temmuz'da onaylanan koyu, sıcak ve modern tasarım sistemini değiştirmeden;
güncel yerel sürümde doğrulanan küçük ekran taşmalarını, kullanıcı yolculuğu
sürtünmesini, eylem hiyerarşisini, erişilebilirlik açıklarını, Kurmancî metin
tutarsızlıklarını ve soru kalite aracındaki kök hatayı kapatmak.

## Kapsam sınırı

- Repository, provider, model, servis ve oyun kuralları korunur.
- Yeni paket, yeni tasarım sistemi veya geniş refactor yapılmaz.
- Mevcut ortak buton, loader, empty/error state ve tema bileşenleri kullanılır.
- Canlı Supabase verisine bu paket içinde doğrudan yazılmaz. Yerel kaynaklar ve
  güvenli editoryal araçlar hazırlanır; canlı içerik uygulaması ayrıca
  doğrulanabilir bir dağıtım adımıdır.
- Kullanıcı özelliği doğrudan kaldırılmaz; gereksiz sürtünme oluşturan özellikler
  bağlamsal olarak ertelenir veya ikincil menüye taşınır.

## Değerlendirilen yaklaşımlar

### A. Tüm ekranları yeniden yazmak

Görsel tutarlılık sağlayabilir; fakat mevcut onaylı tasarımı, çalışan akışları ve
geniş test yüzeyini gereksiz riske atar. Reddedildi.

### B. Yalnız görünen taşmaları tek tek yamamak

Hızlıdır; fakat ortak grid, aksiyon hiyerarşisi, terminoloji ve kalite aracı
köklerini çözmez. Reddedildi.

### C. Kök neden odaklı, küçük ve testli paketler

Mevcut tasarım bileşenlerini korur; önce ortak constraint ve semantik nedenleri,
sonra ilgili ekranları düzeltir. En küçük güvenli değişiklik olduğu için seçildi.

## Tasarım kararları

### 1. Responsive ve büyük metin

- Destek kapısı: 320, 360, 390, 430, 768, 1024, 1366 ve 1440 px.
- Profil metrikleri sabit yüksekliğe güvenmeyecek; metin ölçeği ve genişliğe göre
  içerik sığacak ya da uygun kolona geçecek.
- Liderlik podyum puanı tek satır kalacak; isimler semantik içeriği kaybetmeden
  kontrollü kısalacak.
- İlk profil adı ve sonuç ekranı dikey kullanılabilir alana göre kaydırılabilir
  olacak; klavye açıldığında birincil eylem erişilebilir kalacak.
- Masaüstünde içerik mevcut max-width içinde kalacak; kolonlar içerik boyuna göre
  dengelenecek. Alt navigasyonun etkileşim alanı sınırlı içerik genişliğine
  bağlanacak.
- Yüzde 200 yazı ölçeği, landscape ve tablet boyutları regresyon testine girecek.

### 2. İlk kullanım yolculuğu

- Dört sayfalık onboarding korunur; ancak ilk quiz için gerekli olmayan mağaza,
  turnuva, joker ve oda ayrıntıları çıkarılır.
- Profil adı kapısı korunur; metni düzeltilir ve ekran responsive yapılır.
- Navigasyon turu yalnız temel üç hedefi gösterir.
- Beş adımlı quiz turu, ilk soruda gösterilen en fazla iki bağlamsal açıklamaya
  indirgenir.
- Deneyimli kullanıcıların mevcut atlama ve daha sonra tekrar açma davranışları
  korunur.

### 3. Eylem ve bilgi hiyerarşisi

- Quiz sonucunda birincil eylem `Dîsa bilîze`, ikincil eylem yanlışları inceleme,
  ana sayfa sade bağlantı olur.
- Paylaşma, değerlendirme ve liderlik eylemleri tek bir ikincil menüde toplanır.
- `Teknolojî — yakında` oynanabilir kategorilerin sonuna taşınır.
- Seviye ekranının büyük dekoratif başlığı küçültülür; ilk üç seviye 320 px'de
  mümkün olduğunca görünür olur.
- Oyun hub, oda ve sosyal özellikler korunur; ana öğrenme/quiz eylemlerinden daha
  düşük görsel öncelikte kalır.

### 4. Metin ve terminoloji

- Kurmancî arayüzde Türkçe kalan sabit metinler temizlenir.
- Ortak sözlük şu kavramları tekleştirir: çevrimiçi, görev, başlat, devam et,
  doğru/yanlış ve puan.
- Dilbilgisel çekimler (`Ode`, `Odeyek`, `Odeya`) körlemesine değiştirilmez.
- `Amadeyî yanga nû?`, `Pêşbirktî`, `Lîstikê û serlêderên bibike`,
  `15 saniyede bersivê bide`, `Entık` ve `Barekî hilbijêre` editoryal olarak
  doğrulanıp doğal Kurmancî karşılıklarla düzeltilir.
- Demo kullanıcı adları profesyonel ve doğal örneklere çevrilir.
- Quiz promptu cevap dilini açıkça söylemiyorsa kalıp bunu belirtecek.

### 5. Erişilebilirlik ve durum bileşenleri

- Tüm ikon eylemlerine yerelleştirilmiş semantics label ve tooltip eklenir.
- Ham `GestureDetector` ile kullanılan küçük ikonlar en az 44x44 dokunma alanına
  sahip `IconButton`/mevcut ortak bileşene taşınır.
- Geri düğmesi ekran okuyucuda seçili dilde duyulur.
- Doğru/yanlış geri bildirimi renk + ikon + metin taşımaya devam eder.
- Kontrast, dokunma alanı, etiket ve yüzde 200 metin ölçeği testleri tekrar açılır.
- Yerel loading/empty/error uygulamaları mümkün olduğu yerde mevcut ortak
  bileşenlere geçirilir; yeni soyutlama oluşturulmaz.

### 6. Soru kalite süreci

- Kaynak keşfi `build`, `.dart_tool` ve diğer dışlanan dizinlere girmeden önce
  onları filtreler; geçici dosya kaybı gate'i çökertmez.
- Bu hata için geçici klasör silinmesini simüle eden bir regresyon testi yazılır.
- Gate'in baseline borcu kalite onayı sayılmaz.
- Türkçe veya şablon promptlar otomatik toplu çeviriyle değiştirilmez; mevcut
  audit çıktısı üzerinden küçük, gözden geçirilebilir editoryal partilere ayrılır.

## Hata ve boş durum davranışı

- Yeniden denenebilir ağ hataları açık neden + `Dîsa biceribîne` eylemi gösterir.
- Gerçek boş durumlar kullanıcıya bir sonraki anlamlı eylemi sunar.
- Eylemi olmayan salt bilgi durumları yalnızca kısa açıklama gösterir.
- Hata metni teknik exception ayrıntısını kullanıcıya taşımaz; ayrıntı logda kalır.

## Doğrulama

Her paket test-first uygulanır:

1. Mevcut hatayı gösteren test yazılır ve doğru nedenle başarısız olduğu görülür.
2. En küçük üretim değişikliği yapılır.
3. Hedef test, ilgili ekran testleri ve ardından tam test paketi çalıştırılır.
4. `dart analyze` tamamlanıp hatasız çıkmadan paket bitmiş sayılmaz.
5. Değişen kritik ekranlar light/dark temada ve hedef genişliklerde gerçek
   tarayıcıda kontrol edilir; overflow, kesilme, yatay kaydırma ve anlamsız boşluk
   bulunursa teslim durur.

## Başarı ölçütleri

- Hedef genişliklerde görünür Flutter overflow uyarısı yok.
- Atlanan 320 px ve sonuç ekranı testleri etkin ve yeşil.
- İlk tam quize ulaşmak için açıklama katmanı belirgin biçimde kısalmış.
- Sonuç ekranında yalnız bir görsel birincil eylem var.
- Kurmancî modda doğrulanan sabit Türkçe/bozuk metin kalmamış.
- Kritik ikon eylemleri etiketli ve en az 44x44 dokunma alanına sahip.
- Kalite gate'i dışlanan/geçici klasörler nedeniyle çökmüyor.
- Light/dark kalite, 200% metin ölçeği, tablet ve landscape testleri çalışıyor.

