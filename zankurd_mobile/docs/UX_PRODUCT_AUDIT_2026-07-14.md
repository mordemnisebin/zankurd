# ZanKurd Derin Ürün ve UX Denetimi

Tarih: 14 Temmuz 2026

Bu belge, son üç sekmeli UX düzenlemesi, yerel proje yapısı, mevcut test paketi,
önceki UI denetimleri, canlı web doğrulaması ve rakip araştırması birlikte
incelenerek hazırlanmıştır.

## 1. Kısa karar

ZanKurd artık temel navigasyon ve rekabet odağı açısından önceki hâlinden daha
anlaşılır. Ana sayfada yarış, ayrı Yarış sekmesi ve görünür Profil/ayarlar
erişimi doğru yönde.

Ancak ürün henüz “kullanıcı kesinlikle karışmaz” seviyesinin kanıtlanmış son
noktası değildir. Bunun nedeni ana menü değil; ikincil ekranların hâlâ yoğun
olması, bazı görsel/erişilebilirlik borçları, içerik güveninin kullanıcıya
gösterilmemesi ve gerçek kullanıcı davranış verisinin bulunmamasıdır.

Benim ürün kararıma göre durum:

- Teknik kalite: güçlü aday.
- Ana navigasyon: kabul edilebilir ve sade.
- İlk kullanım: iyi, fakat gerçek kullanıcı testi gerekir.
- Yarış deneyimi: güçlü temel, günlük rekabet döngüsü henüz yeterince keskin değil.
- Öğrenme deneyimi: kapsamlı, fakat hâlâ fazla bilgi yoğun.
- İçerik güveni: içeride metadata ve denetim var; kullanıcıya görünür güven sinyali zayıf.
- Sonraki yatırım: yeni özellik eklemek değil, mevcut akışları kısaltmak ve ölçmek.

## 2. Şu anda iyi olanlar

### Ürün yönü

- Ana alt menü üç hedefe indirildi: Ana Sayfa, Yarış, Profil.
- Öğrenme alanı yarışın önüne geçmiyor; ana sayfada ikincil ama görünür.
- Yarış ekranında doğrudan modlar oda kurma akışından önce geliyor.
- Profil ayarları ilk görünür alanda.
- Topluluk, mağaza, arkadaşlar ve gelişmiş özellikler silinmeden ikincil seviyeye taşındı.

### Teknik güven

- Tam Flutter test paketi son doğrulamada 553/553 başarılı.
- Dart analiz temiz.
- Web release build üretildi.
- Hostinger yüklemesi sonrası yerel/canlı `main.dart.js` hash eşleşmesi yapıldı.
- Supabase migration ve test fixture kopyaları eşitlendi.
- 360 px ve farklı ekran senaryoları için mevcut widget testleri var.

### Ürün varlıkları

Uygulama yalnızca quiz ekranından ibaret değil: oda, eşleşme, turnuva,
contest, liderlik, mağaza, çark, arkadaşlar, favoriler, raporlama, yanlış
sorular, öğrenme yolu ve profil istatistikleri mevcut. Sorun özellik eksikliği
değil; bu genişliğin kullanıcıya ne zaman ve hangi sırayla gösterildiği.

## 3. En önemli kalan sorunlar

### P0 — Güven ve okunabilirlik

1. Quiz sonuç ekranı farklı tema ve uzun Kurmancî metinlerle tekrar denetlenmeli.
   Önceki denetimde sabit renkli sonuç başlığı, metrik satırları ve dar ekran
   başlıkları riskli bulunmuştu. Sonuç ekranı yarışın en duygusal anıdır; burada
   kontrast veya taşma görülmesi uygulamanın kalitesini doğrudan düşürür.

2. Alt kategori ekranındaki şeffaf AppBar beyaz geri oku ile açık zemin
   kombinasyonu hâlâ riskli görünüyor. Geri düğmesi her temada görünür olmalı.

3. Ana sayfa ve ayarlardaki küçük dil/tema kontrolleri, mağaza satın alma
   düğmeleri ve bazı profil aksiyonları 44 px dokunma hedefi standardına göre
   yeniden ölçülmeli.

4. İçerik kalitesi kullanıcıya yeterince anlatılmıyor. Soruların kaynak,
   doğrulama veya “soru bildir” güvencesi içeride var; fakat oyuncu çoğunlukla
   yalnızca doğru/yanlış sonucunu görüyor. Güvenilir bir kültür uygulaması için
   açıklama, kaynak ve bildirim mekanizması görünür olmalı.

### P1 — Kullanıcı akışı

1. Ana sayfa yarışa yönlendiriyor; fakat “Günün Yarışması” ana ekranda tek
   dokunuşlu bir günlük hedef olarak yeterince görünür değil. Günlük ritüel,
   Yarış sekmesinin içine gömülürse kullanıcı her gün aynı değeri keşfetmeyebilir.

2. Yarış sonrası ekranında sonuçtan sonra kullanıcıya “şimdi ne yapmalıyım?”
   cevabı daha net verilmelidir. Öğrenme alanına otomatik itmek doğru değil;
   bunun yerine “Tekrar yarış”, “Günün sıralamasını gör”, “Ana sayfa” üçlüsü
   bağlama göre önceliklenmelidir.

3. Kategori girişi şu an öğrenme/kategori ekranına götürüyor. Kullanıcı
   “Kategori ve konular” kartından yarış başlatacağını düşünürse beklenti
   kırılabilir. Kartın açıklaması ve sonraki ekranın başlığı aynı amacı
   söylemeli: öğrenme mi, kategoriye göre yarış mı?

4. Profil hâlâ çok büyük bir ekran. Ayarlar erişimi düzeldi, fakat istatistik,
   rozet, performans, güç haritası, mastery ve menülerin tamamı aynı yüzeyde
   yarışıyor. Profilin ilk ekranı kimlik + seviye + üç temel aksiyonla sınırlı
   kalmalı; analizler ayrı “İlerlemen” ekranına taşınabilir.

5. Öğrenme ekranı özellik açısından zengin, fakat ilk ziyaretçi için “bugün ne
   yapmalıyım?” sorusuna tek cevap vermiyor. Birincil öğrenme hedefi, devam et
   kartı ve kategori keşfi arasında net bir öncelik gerekir.

### P2 — Tutarlılık ve bakım maliyeti

- Ekranlarda çok sayıda sabit radius, fontSize ve renk kullanımı var.
- `profile_screen.dart`, `quiz_screen.dart` ve `quiz_result_screen.dart` çok
  büyük dosyalar; küçük bir UI değişikliği bile regresyon riski taşıyor.
- Aynı kart, metrik, chip, dil değiştirici ve liste satırı desenleri farklı
  şekillerde tekrar ediyor.
- Kurmancî ve Türkçe metinler bazı yerlerde aynı ürün kavramını farklı tonda
  anlatıyor; tek bir ürün sözlüğü gerekiyor.
- Eski belgelerdeki bazı durumlar güncel kodla örtüşmüyor. Denetim belgeleri
  “tamamlandı” işareti ve doğrulama tarihiyle güncellenmeli.

## 4. Senaryo bazlı değerlendirme

### Senaryo A — İlk kez gelen kullanıcı

Beklenen yol:

`Onboarding → misafir devam → ad → Ana Sayfa → Hemen yarış`

Durum: Akış çalışıyor ve testli. Risk, onboarding sonrası kullanıcının
öğrenme/kategori/yarış ayrımını ilk anda tam kavrayamaması. İlk yarışa giden
tek ana CTA korunmalı; diğer kartlar daha sessiz kalmalı.

### Senaryo B — Her gün giren yarış oyuncusu

Beklenen yol:

`Ana Sayfa → Hemen yarış veya Günün Yarışması → sonuç → sıralama/tekrar`

Durum: Hemen yarış güçlü. Günlük yarışma ve sıralama döngüsü daha görünür
olmalı. Kullanıcının ertesi gün geri gelmesi için tek cümlelik hedef ve kalan
ödül ilerlemesi görünmeli.

### Senaryo C — Arkadaşla oynayan kullanıcı

Beklenen yol:

`Yarış → Oda kur/Kodla katıl → oda → sonuç`

Durum: Fonksiyon mevcut. Oda kurma panelinin doğrudan yarışların altında
olması doğru. Oda kodu paylaşma, arkadaş daveti ve rakibin hazır olma durumu
tek bakışta anlaşılmalı.

### Senaryo D — Öğrenmek isteyen kullanıcı

Beklenen yol:

`Ana Sayfa → Öğrenme yolu → konu → seviye → tekrar`

Durum: Motor güçlü. İlk hedef, ilerleme ve devam et eylemi sadeleştirilmeli.
Yarış sonrası otomatik öğrenme yönlendirmesi olmaması doğru karardır.

### Senaryo E — Yanlış yapan kullanıcı

Beklenen yol:

`Sonuç → yanlışlarım/inceleme → açıklama → tekrar`

Durum: Bu ürünün eğitim farkını yaratabilecek akış burada. Yanlış soru
inceleme, açıklama ve aralıklı tekrar tek bir açık “Yanlışlarımı çalış”
aksiyonunda birleşmeli.

### Senaryo F — İçeriğe güvenmeyen kullanıcı

Beklenen yol:

`Soru → açıklama/kaynak → bildir → düzeltme güveni`

Durum: Raporlama ve metadata altyapısı var. Kullanıcıya “kaynak” ve “hata
bildir” seçenekleri daha görünür verilirse ZanKurd, rastgele quiz uygulaması
olmaktan ayrılır.

## 5. Rakip karşılaştırması

### Pirs

Google Play açıklamasında Pirs; grup odası, öğrenme alanı, geçmiş ve planlı
yarışmalar, özel kodla arkadaş daveti, puan/coin, liderlik, kişisel istatistik,
soru bildirme, favoriler, bildirimler ve dört joker hakkını birlikte sunuyor.
Bu, Pirs'in gücünün tek bir ekranda değil, geniş ve anlaşılır bir oyun döngüsünde
olduğunu gösteriyor.

ZanKurd'un Pirs'i kopyalaması gerekmiyor. Fark yaratması gereken noktalar:

- daha güncel ve güvenilir soru editoryali,
- daha temiz ilk kullanım,
- Kurmancî dil kalitesi,
- doğru cevabın açıklaması ve kaynak güveni,
- daha iyi yanlış tekrar sistemi,
- daha hızlı ve daha az yorucu rekabet akışı.

Pirs'in Google Play sayfası 10 B+ indirme gösteriyor ve listelenen son güncelleme
18 Ekim 2022. Bu, ZanKurd için güncel içerik ve düzenli ürün iletişimi açısından
fırsat yaratıyor; ancak Pirs'in mevcut kurulu kullanıcı alışkanlığını küçümsemek
yanlış olur.

### Kahoot

Kahoot'un güçlü tarafı, canlı katılımı ve kendi kendine çalışma modlarını ayrı
ama anlaşılır hedefler olarak sunmasıdır. Resmî yardım sayfasında hesapsız
katılım, canlı oyuna PIN ile girme, flashcard/learn/test modları, arkadaşlarla
çalışma ve kendi oyununu oluşturma akışları ayrı ayrı tanımlanıyor.

ZanKurd için ders: “oyna”, “öğren”, “oda kur” ve “kendi içeriğini öner” aynı
seviyede gösterilmemeli; her birinin ilk aksiyonu tek cümleyle anlaşılmalı.

### Quizlet

Quizlet'in güçlü tarafı aynı içeriği flashcard, Learn, Test, Match ve Live gibi
farklı çalışma biçimlerine dönüştürmesidir. ZanKurd'un öğrenme yolu bunun
Kurmancî ve kültürel karşılığını yaratabilir; fakat önce mevcut tek akışı
kusursuzlaştırmak, sonra yeni mod eklemek gerekir.

## 6. Önceliklendirilmiş öneri paketi

### Paket 1 — Güvenli ilk kullanım ve rekabet döngüsü

Öncelik: P0, önce yapılmalı.

1. Sonuç ekranının light/dark, 360 px ve uzun Kurmancî metin denetimini tamamla.
2. Alt kategori AppBar geri düğmesini tema güvenli hâle getir.
3. Tüm ana CTA ve dil/tema kontrollerini minimum 44–48 px yap.
4. Sonuç ekranına üç bağlama duyarlı aksiyon koy:
   - Tekrar yarış
   - Sıralamayı gör
   - Ana sayfaya dön
5. Günün Yarışması için Ana Sayfa’da tek, küçük ama görünür bir günlük hedef
   kartı ekle.

### Paket 2 — Öğrenme farkı

Öncelik: P1.

1. Öğrenme yolunda yalnızca bir “Devam et” kartı birincil olsun.
2. “Yanlışlarımı çalış” aksiyonunu sonuç ve profil arasında aynı isimle kullan.
3. Kategori ekranında her kategori için ilerleme, son oynama ve önerilen sonraki
   adım göster.
4. Soru açıklamasında kaynak başlığı ve “sorun varsa bildir” eylemini sade
   biçimde göster.

### Paket 3 — Sosyal rekabet

Öncelik: P1.

1. Oda kurma ve kodla katılma akışında paylaşılabilir kod/bağlantı eylemini
   birincil yap.
2. Yarış sonrası “arkadaşını rövanşa çağır” eylemi ekle.
3. Liderlikte kullanıcının kendi satırını sabit ve görünür tut.
4. Günlük/haftalık yarışmanın kalan süresi ve ödülü tek kartta göster.

### Paket 4 — Görsel sistem borcu

Öncelik: P2.

1. `AppRadius`, `AppTypography` ve tema renk token'larını gerçek kullanımın
   çoğunluğuna yay.
2. Kart, buton, metrik, chip ve liste satırı bileşenlerini küçük güvenli
   adımlarla ortaklaştır.
3. `profile_screen.dart`, `quiz_result_screen.dart` ve `quiz_screen.dart` için
   ekran bazlı alt widget'lara ayırma planı yap; büyük refactor'ı tek seferde
   uygulama.

## 7. Ölçülmeden “iyi UX” denmemeli

En az şu olaylar anonim olarak ölçülmeli:

- onboarding tamamlandı,
- ilk yarış başlatıldı,
- ilk yarış tamamlandı,
- sonuçtan tekrar yarış seçildi,
- günlük yarışma açıldı,
- öğrenme kartı açıldı,
- kategori ekranında çıkış yapıldı,
- oda kuruldu/koda katılındı,
- soru raporlandı,
- yanlışlarım çalıştırıldı.

İlk hedefler:

- onboarding → ilk yarış başlatma: %70+,
- ilk yarış → sonuç: %85+,
- sonuç → tekrar veya ana sayfa: %60+,
- kategori ekranında ilk 30 saniyede çıkış: %35'in altında,
- oda kurup kod paylaşma başarısı: %80+.

## 8. Son karar kriterleri

ZanKurd'u “kullanıcı kesinlikle karışmaz” seviyesinde kabul etmek için:

- 5 yeni kullanıcıdan en az 4'ü ilk 10 saniyede yarışa girebilmeli.
- 5 kullanıcıdan en az 4'ü öğrenme girişinin yarıştan farklı olduğunu
  açıklayabilmeli.
- Hiçbir kullanıcı ayarları bulmak için profilin sonuna kadar kaydırmamalı.
- 360 px, 390 px, tablet ve web genişliğinde overflow olmamalı.
- Light/dark temada sonuç, kategori ve mağaza ekranlarında kontrast sorunu
  görülmemeli.
- Kullanıcı yanlış yaptığında bir sonraki adımı düşünmeden bulabilmeli.
- Günlük yarışmanın ne olduğu ve ne kazandırdığı tek bakışta anlaşılmalı.

## 9. Benim net önerim

Yeni özellik ekleme hızını düşürüp iki kısa döngüye odaklanmak:

1. P0 güven/erişilebilirlik ve sonuç akışını bitir.
2. Beş gerçek kullanıcıyla 10 dakikalık görev testi yap.
3. Kullanıcıların takıldığı noktaya göre tek tek düzelt.
4. Ancak bundan sonra yeni sosyal veya öğrenme özellikleri ekle.

ZanKurd'un rekabet avantajı özellik sayısı değil; Kurmancî içerik kalitesi,
güvenilir açıklamalar ve kullanıcının her ekranda ne yapacağını bilmesidir.

