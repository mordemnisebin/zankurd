# ZanKurd Referans Esintili Açık Tema Yenilemesi

**Tarih:** 2026-07-15  
**Durum:** Kullanıcı tarafından sözlü olarak onaylandı; uygulama planı bekleniyor.  
**Referans:** `C:\Users\AMARGİ\Desktop\zankurd (1)`  
**Öncelik kararı:** Bu belge, önceki tasarım belgelerindeki koyu-varsayılan ve
turuncuyu tamamen dışlayan kararları süpersede eder. Varsayılan tema açık,
koyu tema ise ayarlardan seçilebilir olacaktır.

## Amaç

React tabanlı alternatif ZanKurd sürümündeki güçlü bilgi hiyerarşisini,
kompakt oyun kartlarını, kullanıcı/ödül göstergelerini ve navigasyon dilini
mevcut Flutter uygulamasına uyarlamak. Referansın koyu görünümü birebir
kopyalanmayacak; aynı oyun enerjisi daha açık, ferah ve profesyonel bir ZanKurd
kimliğiyle kurulacaktır.

## Korunacak Sözleşmeler

- Supabase, repository, provider, auth ve veri modeli değişmeyecek.
- Quiz skoru, zamanlayıcı, joker, coin, XP, seri, oda ve matchmaking mantığı
  değişmeyecek.
- Mevcut route ve buton davranışları korunacak.
- Kurmancî/Türkçe seçimi, Kurmancî karakterler ve mevcut test key'leri
  korunacak.
- Rubik font ailesi ve mevcut uygulama varlıkları kullanılacak; yeni paket veya
  font eklenmeyecek.
- Kullanıcıya ait `macos/Flutter/GeneratedPluginRegistrant.swift` değişikliği
  korunacak ve bu çalışma kapsamında düzenlenmeyecek.

## Görsel Yön — "Ronahî Arcade"

Referansın turuncu, kompakt ve oyun odaklı karakteri; soğuk beyaz yüzeyler,
lacivert metin ve kontrollü renk vurgularıyla yeniden yorumlanır.

| Rol | Renk | Kullanım |
|---|---|---|
| Açık zemin | `#F5F7FC` | Varsayılan sayfa zemini |
| Ana yüzey | `#FFFFFF` | Kartlar, bottom sheet, navigation |
| Yüksek yüzey | `#EEF2FA` | İç paneller ve seçili olmayan alanlar |
| Ana metin | `#171B2E` | Başlıklar ve birincil metin |
| Ana vurgu | `#E57832` | Birincil eylem, aktif sekme, günlük içerik |
| İkincil vurgu | `#5147C7` | İlerleme, profil ve şans ekranları |
| Ödül | `#E9B949` | Yalnızca coin, seri ve ödül |
| Bilgi | `#2D8BD8` | Oda, bağlantı ve yardımcı eylemler |

Doğru/yanlış renklerinin anlamı değiştirilmeyecek. Koyu tema, aynı renk
hiyerarşisinin `#101217` zemin ve `#171C29` yüzey üzerindeki karşılığı olacak;
ikinci sınıf veya eksik bir tema olmayacaktır.

## Tipografi, Yoğunluk ve Şekil

- Rubik korunur; başlıklarda `800/900`, gövde metninde `500/600`, veri ve
  rozetlerde `700` ağırlık kullanılır.
- Kart yarıçapı 16 px, iç kontrol yarıçapı 12 px, pill rozet 99 px olur.
- Sayfa yatay boşluğu 16-20 px; kart aralığı 12-14 px olur.
- Mevcut çok büyük gradyan bloklar azaltılır. Renk, birincil eylem ve ekran
  kimliğinde yoğunlaşır.
- Gölgeler açık temada kısa ve yumuşak, koyu temada çoğunlukla ince kenarlık
  şeklinde uygulanır.

## İmza Unsuru

ZanKurd'a özgü imza, kartların üst veya alt kenarında yalnızca önemli
bölümlerde kullanılan ince bir **kilim ilerleme çizgisi** olacaktır. Bu çizgi
dekor değil; seviye, görev veya tur ilerlemesini gösterir. Zana/Roj maskotu
korunur ve ana sayfadaki günlük içerikte odak olarak kullanılır.

## Ekran Dönüşümleri

### 1. Tema ve Ortak Bileşenler

`AppTheme` açık-varsayılan Ronahî Arcade tokenlarına geçirilir. `AppPanel`,
`PressableCard`, `StyledButton`, `ScreenIdentityHeader` ve navigation görünümü
aynı yüzey, radius, kenarlık ve durum dilini kullanır.

### 2. Ana Sayfa

- Referanstaki kullanıcı/coin/seri hiyerarşisi, mevcut başlığa daha kompakt bir
  bilgi şeridi olarak uyarlanır.
- Büyük ve yoğun hero alanı sadeleştirilir; birincil oyun eylemi netleşir.
- Günlük içerik, görev, şans çarkı ve oda eylemleri aynı kart ailesinde fakat
  farklı vurgu renkleriyle sunulur.
- Sereke ve Bilîze arasında aynı içeriğin tekrarlanmasına izin verilmez.

### 3. Bilîze ve Kategoriler

- Referanstaki tam genişlik mod kartları kullanılır: ikon, başlık, kısa
  açıklama, ilerleme ve yön oku.
- Kategori görselleri korunur; üstlerindeki metin ve ilerleme bilgisi daha
  okunaklı, tutarlı bir overlay yapısına alınır.
- Oda kurma/katılma eylemleri tek bir net panel içinde gruplanır.

### 4. Quiz ve Sonuç

- Soru kartında dikkat dağıtan süsler azaltılır; süre ve ilerleme aynı üst
  şeritte toplanır.
- Şıklar açık yüzey, güçlü seçili durum ve erişilebilir doğru/yanlış geri
  bildirimi kullanır.
- Sonuç ekranında skor kahramanı, kazanılan XP/coin ve sonraki eylemler açık
  bir hiyerarşiyle gösterilir.

### 5. Liderlik ve Profil

- Liderlik satırları referanstaki kompakt rank/avatar/isim/skor düzenine
  yaklaşır; ilk üç sıra görsel olarak ayrılır.
- Profil üst alanı avatar, ad, seviye ve XP'yi tek odakta toplar.
- İstatistik, mastery ve haftalık performans panelleri aynı metrik kart dilini
  kullanır; düz metin yığınları azaltılır.

### 6. Çark, Giriş ve Sistem Ekranları

- Çark ekranı referanstaki merkezlenmiş odak ve güçlü tek eylem düzenini alır;
  mevcut ödül mantığı değişmez.
- Onboarding, giriş, ayarlar, loading, empty/error, dialog ve bottom sheet
  yüzeyleri ortak tokenlara geçirilir.

## Hareket ve Erişilebilirlik

- Yalnızca ekran girişinde hafif sıralı kart görünümü ve basma geri bildirimi
  kullanılır; sürekli pulse ve gereksiz animasyon azaltılır.
- `reduceMotion` davranışı korunur.
- 360 px mobil ve 768 px tablet genişliğinde taşma olmayacak.
- Metin kontrastı, odak görünürlüğü ve en az 44 px dokunma alanı korunacak.

## Uygulama Stratejisi

Çalışma küçük ve test edilebilir paketlere ayrılır:

1. Tema tokenları, açık-varsayılan tercihi ve ortak bileşenler.
2. App shell, alt navigasyon ve ana sayfa.
3. Bilîze, kategoriler ve oda eylemleri.
4. Quiz, sonuç ve çark.
5. Liderlik, profil ve ayarlar.
6. Onboarding, giriş ve kalan sistem yüzeyleri.

Sırf refactor yapmak için büyük dosyalar bölünmeyecek. Bir ekrandaki bağımsız
görsel bölüm zaten değişiyorsa, yalnızca o bölüm küçük bir widget dosyasına
çıkarılabilir.

## Test ve Doğrulama

- Her pakette önce hedef görünüm sözleşmesini doğrulayan widget/theme testi
  yazılıp başarısız olduğu görülür.
- Değişiklikten sonra önce `dart analyze`, sonra ilgili `flutter test`, paket
  sonunda tam `flutter test` çalıştırılır.
- UI değişiklikleri Flutter web üzerinde 360x800 ve 768x1024 boyutlarında
  Playwright ile incelenir.
- Açık ve koyu tema için ana akış ekran görüntüleri karşılaştırılır.
- Navigasyon, backend çağrıları ve quiz hesaplarında davranış farkı olmadığı
  testlerle doğrulanır.

## Kabul Kriterleri

- İlk kurulum açık temayla başlar; koyu tema ayarlardan seçilebilir ve eksiksiz
  çalışır.
- Ana sayfa, Bilîze, kategoriler, quiz, sonuç, liderlik, profil, çark, giriş ve
  ortak sistem yüzeyleri aynı tasarım ailesine ait görünür.
- Referans projenin kart yoğunluğu ve bilgi hiyerarşisi hissedilir; koyu arka
  planı veya React varlıkları birebir kopyalanmaz.
- İş mantığı, Supabase sözleşmeleri, dil seçimi ve test key'leri değişmez.
- 360 px ve 768 px genişlikte taşma oluşmaz.
- `dart analyze` ve ilgili Flutter testleri temiz geçer.

## Kapsam Dışı

- Yeni oyun modu, backend özelliği veya veri tabanı değişikliği.
- React/Firebase kodunun Flutter projesine taşınması.
- Referanstaki logo, metin veya varlıkların doğrudan kopyalanması.
- Navigasyon davranışını veya mevcut ürün bilgi mimarisini baştan kurmak.
