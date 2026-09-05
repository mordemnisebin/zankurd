# Mağaza listesi metinleri

App Store ve Google Play için doğrulanmış yayın metinleri.

Karakter sınırları başlıklarda yazılı ve metinler o sınırlara göre
yazıldı. Sayılar 2026-09-02 durumudur; sürüm değişince güncelle:

| Ne | Kaç |
|---|---|
| Yayınlanabilir benzersiz soru | 1.890 |
| Kategori | 10 |
| Kategori başına seviye | 5 |
| Arayüz dili | Kurmancî, Türkçe |

Sayı vermek iki ucu keskin: doğruysa güven verir, eskiyince yalan olur.
Bu yüzden metinlerde yalnız "1.800'den fazla soru" gibi aşağı yuvarlanmış
biçimi kullan — banka büyüdükçe doğru kalır, küçülmedikçe yanlış olmaz.

## Mağaza ekran görüntüleri

App Store en az bir 6,9" (1320×2868) ekran görüntüsü ister; Play için
telefon görüntüsü 1080 px genişlikten büyük olmalı — aynı dosyalar ikisine
de yeter.

Altı yayın görüntüsü iPhone 17 Pro Max simülatöründen, Türkçe arayüzle alındı ve
`docs/screenshots/store/tr/` altında duruyor:

| Dosya | Ekran |
|---|---|
| `01_home.png` | Ana ekran: günlük ders, dersler, hızlı düello, görevler |
| `02_categories.png` | Kategoriler ve soru sayıları |
| `03_subcategories.png` | Alt alanlar (illüstrasyonlu başlık) |
| `04_levels.png` | Seviye yolu |
| `06_quiz.png` | Dört şıklı soru |
| `07_photo_question.png` | Fotoğraflı soru |

`05_word_order.png` yalnız taslak arşividir ve güncel mağaza setinde
kullanılmıyor. Yeniden kullanılacaksa mevcut derlemeyle yeniden çekilip
görsel kalite kontrolünden geçirilmelidir.

`docs/screenshots/` sürüm denetiminde tutulmuyor (kökteki `.gitignore`);
üretilmiş görsellerin kaynak gibi davranmaması için konmuş bir kural.
Yükleme öncesi yeniden almak gerekirse tarif şu:

1. `xcrun simctl boot "iPhone 17 Pro Max"` — 1320×2868 tam bu cihazdan
   çıkar, başka bir cihaz yanlış boyut verir.
2. `flutter run -d <udid>` (hata ayıklama derlemesi yeterlidir; uygulama
   `debugShowCheckedModeBanner: false` kullanıyor, köşede şerit çıkmaz).
3. Misafir girişi → dili TR yap → ekranları gez.
4. `xcrun simctl io <udid> screenshot <dosya>.png`

Kurmancî liste eklenirse aynı yol dil KU'yken tekrarlanır ve görüntüler
`docs/screenshots/store/ku/` altına konur.

---

## Google Play

### Uygulama adı (en fazla 30 karakter)

```
ZanKurd — Kurmancî öğren
```

(24 karakter)

### Kısa açıklama (en fazla 80 karakter)

```
Kurmancî öğren, sorularla yarış. 1.800'den fazla soru, 10 kategori.
```

(66 karakter)

### Tam açıklama (en fazla 4000 karakter)

```
ZanKurd, Kurmancî öğrenmeyi bir yarışmaya çeviren bir bilgi
uygulamasıdır. Dil, tarih, edebiyat, müzik, coğrafya, kültür ve daha
fazlası — 1.800'den fazla soru, on kategori.

NASIL İŞLER

• Günlük ders: her gün on soru, yaklaşık beş dakika.
• Kategori ve seviye: her kategoride beş seviye, kolaydan zora.
• Açıklamalar: tur bitince her sorunun niçin öyle olduğunu okursun.
• Yanlışların takibi: yanlış yaptığın sorular geri gelir, öğrenene kadar.

YARIŞ

• 1v1 düello: rastgele bir rakiple ya da arkadaşınla canlı yarış.
• Oda kur: kodu paylaş, arkadaşlarınla aynı soruları çöz.
• Turnuva: gerçek oyuncularla eleme; şampiyon kupayı alır.
• Liderlik tablosu: gün, hafta, ay ve arkadaşlar arası sıralama.

ÖĞREN

• Ders yolları: konu konu ilerleyen kısa dersler.
• Hikâye: Kurmancî bir sahnede seçim yaparak ilerlersin.
• Flaş kartlar: kelime ezberi için.

İKİ DİL

Arayüzün tamamı hem Kurmancîdir hem Türkçe. İstediğin an tek dokunuşla
değiştirirsin; sorular, açıklamalar ve dersler iki dilde de yazılıdır.

ÇEVRİMDIŞI

Soruların tamamı cihazda. İnternet olmadan da oynarsın. Seviye çubuğun
ve öğrenme ilerlemen cihazda saklanır. Sıralama puanın hesabına yazılır;
çevrimiçi yarışlar, coin işlemleri ve hesap özellikleri internet
gerektirir.

ERİŞİLEBİLİRLİK

Metin/zemin kontrastları WCAG AA eşiğine göre ölçülür. Yazı boyutunu
sistemden büyüttüğünde ekranlar taşmaz. Ekran okuyucu için düğmelerin
adı vardır.

ZanKurd ücretsizdir ve reklam içermez. İsteyen için bir abonelik vardır
— otomatik seri koruması ve projeye destek. Oyunun tamamı aboneliksiz
oynanır.
```

### Anahtar kelimeler / etiketler

Play etiket alanı serbest metin değildir (kategori seçilir), ama
listeleme metninde geçmesi iyi olan sözcükler:

```
Kurmancî, Kürtçe, Kurdî, dil öğrenme, bilgi yarışması, quiz, test,
kelime, Kürt kültürü, Kürt tarihi, dengbêj, edebiyat
```

---

## App Store

### Ad (en fazla 30 karakter)

```
ZanKurd
```

### Alt başlık (en fazla 30 karakter)

```
Kurmancî öğren, yarış, ilerle
```

(29 karakter)

### Tanıtım metni (en fazla 170 karakter — güncellemesi incelemesizdir)

```
Yeni: turnuvalar artık gerçek oyuncular arasında. Şampiyon kupayı alır.
```

(71 karakter)

### Açıklama (en fazla 4000 karakter)

App Store açıklamasında Play metni, bölüm başlıkları normal yazıma
çevrilerek kullanılır.

### Anahtar kelimeler (en fazla 100 karakter, virgülle, boşluksuz)

```
kurmanci,kurtce,kurdi,dil,ogrenme,bilgi,yarisma,quiz,kelime,kultur,tarih,dengbej
```

(80 karakter — Türkçe karakterler aranan sözcükte de kullanılmadığı için
ASCII yazıldı; App Store aramasında bu daha geniş eşleşir.)

---

## Kurmancî liste (ikinci dil olarak eklenirse)

Her iki mağaza da liste metnini dile göre çoğaltmaya izin verir.
Uygulamanın kendisi iki dilli olduğu için Kurmancî liste eklemek
tutarlıdır.

### Nav / Ad

```
ZanKurd
```

### Bineşan / Alt başlık (30)

```
Kurmancî hîn bibe, pêş bikeve.
```

(30 karakter)

### Danasîna kurt / Kısa açıklama (80)

```
Kurmancî hîn bibe, bi pirsan pêşbirkê bike. Zêdetir ji 1.800 pirs, 10 kategorî.
```

(78 karakter)

### Danasîn / Tam açıklama

```
ZanKurd sepaneke zanînê ye ku hînbûna kurmancî dike pêşbirk. Ziman,
dîrok, wêje, muzîk, erdnîgarî, çand û bêtir — zêdetir ji 1.800 pirs, deh
kategorî.

ÇAWA DIXEBITE

• Dersê rojane: her roj deh pirs, nêzîkî pênc deqe.
• Kategorî û ast: di her kategoriyê de pênc ast, ji hêsan ber bi dijwar.
• Ravekirin: gava tur diqede, tu dixwînî ka her bersiv çima wisa ye.
• Şaşiyên te: pirsên ku te şaş kirine vedigerin, heta tu fêr bibî.

PÊŞBIRK

• Duelo 1v1: bi hevrikekî rasthatî an bi hevalê xwe re rasterast.
• Ode ava bike: kodê parve bike, bi hevalan re heman pirsan bibersivîne.
• Kûpa: bi lîstikvanên rastî re elemeyî; şampiyon kûpayê digire.
• Tabloya pêşderiyan: roj, hefte, meh û di nav hevalan de.

HÎN BIBE

• Rêyên fêrbûnê: dersên kurt ên ku mijar bi mijar diçin.
• Çîrok: di dîmeneke kurmancî de bi hilbijartinê pêş dikevî.
• Kartên peyvan: ji bo bîrkirina peyvan.

DU ZIMAN

Tevahiya navrûyê hem bi kurmancî ye hem bi tirkî. Kengî bixwazî bi yek
tikandinê diguherî; pirs, ravekirin û ders bi her du zimanan hatine
nivîsandin.

BÊ ÎNTERNET

Hemû pirs li ser amûrê ne. Bêyî înternetê jî tu dikarî bilîzî. Ast û
pêşketina hînbûnê li ser amûrê tên parastin. Xala rêzkirinê li ser
hesabê tê nivîsandin; pêşbirkên serhêl, karên coinan û taybetmendiyên
hesabê înternetê dixwazin.

ZanKurd belaş e û reklam tê de tune. Ji bo yên ku dixwazin abonetiyek
heye — parastina xweber a zincîrê û piştgirî ji projeyê re. Lîstik bi
temamî bêyî abonetiyê tê lîstin.
```
