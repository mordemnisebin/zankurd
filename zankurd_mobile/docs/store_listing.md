# Mağaza listesi metinleri

App Store ve Google Play için doğrulanmış yayın metinleri.

Karakter sınırları başlıklarda yazılı ve metinler o sınırlara göre
yazıldı. Sayılar 2026-10-01 durumudur (sürüm 2.0.0, build 21); sürüm
değişince güncelle:

| Ne | Kaç |
|---|---|
| Uygulamada oynanabilir benzersiz soru | 2.486 |
| Sunucuda onaylı soru (çevrimiçi düello ve odalar) | 4.718 |
| Kategori | 11 |
| Kategori başına seviye | 5 |
| Arayüz dili | Kurmancî, Türkçe |

Soruların yaklaşık yüzde 70'i Kürt dili, tarihi ve kültürü; yaklaşık yüzde
30'u Dünya, Teknoloji ve Bilim ve Düşünce kategorilerindeki genel bilgidir.

Sayı vermek iki ucu keskin: doğruysa güven verir, eskiyince yalan olur.
Bu yüzden metinlerde yalnız "2.400'den fazla soru" gibi aşağı yuvarlanmış
biçimi kullan — banka büyüdükçe doğru kalır, küçülmedikçe yanlış olmaz.
Sunucudaki 4.718 sayısı metinlerde geçmez: istemcide oynanan sayı 2.486'dır
ve mağaza metni onu aşmamalı.

> 2026-09-27'de gizlenen Paradigma, Siyaset ve Teknolojî 2026-09-30'da
> yeniden açıldı (gizli kategori yok; bkz.
> `lib/src/config/category_visibility.dart`). Tek bir siyasi görüşü doğru
> cevap diye sunan sorular kategori yerine tek tek emekliye ayrıldı
> (`lib/src/config/retired_question_ids.dart`). Paradigma oyuncuya "Bilim ve
> Düşünce" (Kurmancî "Zanist û Raman") adıyla görünür; Cîhan (Dünya) yeni
> kategoridir. Mağazadaki canlı metin hâlâ "1.800'den fazla soru, 10
> kategori" ya da "7 kategori" diyorsa bu dosyadaki metinle değiştirilmeli.
> Turnuva ve haftalık lig bayrakla kapalı (`kTournamentEnabled`,
> `kWeeklyLeagueEnabled`); metinlerde geçmez.

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

Bu altı görüntü Şahnê tasarımından (2.0.0) ÖNCE alındı; yeni görünümü
göstermiyor. 2.0.0 için mağazaya yüklemeden önce aşağıdaki tarifle yeniden
alınmalı (görüntü seçimi ve sırası aynı kalabilir).

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
Kurmancî öğren, sorularla yarış. 2.400'den fazla soru, 11 kategori.
```

(67 karakter)

### Tam açıklama (en fazla 4000 karakter)

```
ZanKurd, Kurmancî öğrenmeyi bir yarışmaya çeviren bir bilgi
uygulamasıdır. Dil, kültür, tarih, edebiyat, coğrafya, müzik, sinema,
siyaset, bilim ve düşünce, teknoloji ve dünya — 2.400'den fazla soru,
on bir kategori.

Soruların çoğu Kürt dili, tarihi ve kültürü üzerinedir. Dünya, Teknoloji
ve Bilim ve Düşünce kategorileri genel bilgi sorularıdır; Kürt
kategorilerinden ayrı durur.

NASIL İŞLER

• Günün dersi: her gün on soru, yaklaşık beş dakika.
• Kategori ve seviye: her kategoride beş seviye, kolaydan zora.
• Açıklamalar: tur bitince her sorunun niçin öyle olduğunu okursun.
• Yanlışların takibi: yanlış yaptığın sorular geri gelir, öğrenene kadar.

YARIŞ

• Hızlı düello: rastgele bir rakiple canlı 1v1.
• Sırayla düello: rakibin aynı anda çevrimiçi olması gerekmez. Sen şimdi
  oynarsın, o sonra; sonuç Düellolarım'da görünür.
• Oda kur: davet bağlantısını paylaş, arkadaşların tek dokunuşla katılsın.
• Liderlik tablosu: gün, hafta, ay ve arkadaşlar arası sıralama.

ÖĞREN

• Ders yolları: konu konu ilerleyen kısa dersler.
• Hikâye: Kurmancî bir sahnede seçim yaparak ilerlersin.
• Kelime kartları: kelime ezberi için.
• Sözlük (Ferheng): Kurmancî ya da Türkçe ara.

İKİ DİL

Arayüzün tamamı hem Kurmancîdir hem Türkçe. İstediğin an tek dokunuşla
değiştirirsin; sorular, açıklamalar ve dersler iki dilde de yazılıdır.

ÇEVRİMDIŞI

Tek kişilik soruların tamamı cihazda. İnternet olmadan da oynarsın.
Seviye çubuğun ve öğrenme ilerlemen cihazda saklanır.
Sıralama puanın hesabına yazılır; çevrimiçi yarışlar, coin işlemleri ve
hesap özellikleri internet gerektirir.

ERİŞİLEBİLİRLİK

Metin/zemin kontrastları WCAG AA eşiğine göre ölçülür. Yazı boyutunu
sistemden büyüttüğünde ekranlar taşmaz. Ekran okuyucu için düğmelerin
adı vardır.

ZanKurd ücretsizdir ve reklam içermez. İsteyen için bir abonelik vardır
— otomatik seri koruması ve projeye destek. Oyunun tamamı aboneliksiz
oynanır.
```

(1895 karakter)

### Anahtar kelimeler / etiketler

Play etiket alanı serbest metin değildir (kategori seçilir), ama
listeleme metninde geçmesi iyi olan sözcükler:

```
Kurmancî, Kürtçe, Kurdî, dil öğrenme, bilgi yarışması, quiz, test,
kelime, sözlük, Kürt kültürü, Kürt tarihi, dengbêj, edebiyat, düello
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
Yeni: baştan tasarlandı. 2.400'den fazla soru, on bir kategori ve rakibin çevrimiçi olmasını beklemeden oynadığın sırayla düello.
```

(129 karakter)

### Açıklama (en fazla 4000 karakter)

Play metni, bölüm başlıkları normal yazıma çevrilerek ve sonuna yasal
bağlantılar eklenerek kullanılır. Yasal bağlantılar App Store için
zorunludur: abonelik sunan uygulamada Kullanım Koşulları (EULA)
bağlantısı App Description'da bulunmalı (1.9.2 öncesi 3.1.2(c) reddi,
bkz. `docs/app_review_packet_1.9.2_build20.md`).

```
ZanKurd, Kurmancî öğrenmeyi bir yarışmaya çeviren bir bilgi
uygulamasıdır. Dil, kültür, tarih, edebiyat, coğrafya, müzik, sinema,
siyaset, bilim ve düşünce, teknoloji ve dünya — 2.400'den fazla soru,
on bir kategori.

Soruların çoğu Kürt dili, tarihi ve kültürü üzerinedir. Dünya, Teknoloji
ve Bilim ve Düşünce kategorileri genel bilgi sorularıdır; Kürt
kategorilerinden ayrı durur.

Nasıl işler

• Günün dersi: her gün on soru, yaklaşık beş dakika.
• Kategori ve seviye: her kategoride beş seviye, kolaydan zora.
• Açıklamalar: tur bitince her sorunun niçin öyle olduğunu okursun.
• Yanlışların takibi: yanlış yaptığın sorular geri gelir, öğrenene kadar.

Yarış

• Hızlı düello: rastgele bir rakiple canlı 1v1.
• Sırayla düello: rakibin aynı anda çevrimiçi olması gerekmez. Sen şimdi
  oynarsın, o sonra; sonuç Düellolarım'da görünür.
• Oda kur: davet bağlantısını paylaş, arkadaşların tek dokunuşla katılsın.
• Liderlik tablosu: gün, hafta, ay ve arkadaşlar arası sıralama.

Öğren

• Ders yolları: konu konu ilerleyen kısa dersler.
• Hikâye: Kurmancî bir sahnede seçim yaparak ilerlersin.
• Kelime kartları: kelime ezberi için.
• Sözlük (Ferheng): Kurmancî ya da Türkçe ara.

İki dil

Arayüzün tamamı hem Kurmancîdir hem Türkçe. İstediğin an tek dokunuşla
değiştirirsin; sorular, açıklamalar ve dersler iki dilde de yazılıdır.

Çevrimdışı

Tek kişilik soruların tamamı cihazda. İnternet olmadan da oynarsın.
Seviye çubuğun ve öğrenme ilerlemen cihazda saklanır.
Sıralama puanın hesabına yazılır; çevrimiçi yarışlar, coin işlemleri ve
hesap özellikleri internet gerektirir.

Erişilebilirlik

Metin/zemin kontrastları WCAG AA eşiğine göre ölçülür. Yazı boyutunu
sistemden büyüttüğünde ekranlar taşmaz. Ekran okuyucu için düğmelerin
adı vardır.

ZanKurd ücretsizdir ve reklam içermez. İsteyen için bir abonelik vardır
— otomatik seri koruması ve projeye destek. Oyunun tamamı aboneliksiz
oynanır.

Kullanım Koşulları (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Kullanım koşulları: https://www.zankurd.com/terms.html
Gizlilik politikası: https://www.zankurd.com/privacy.html
```

(2102 karakter)

### Anahtar kelimeler (en fazla 100 karakter, virgülle, boşluksuz)

```
kurmanci,kurtce,kurdi,dil,ogrenme,bilgi,yarisma,quiz,kelime,kultur,tarih,dengbej,sozluk,duello
```

(94 karakter — Türkçe karakterler aranan sözcükte de kullanılmadığı için
ASCII yazıldı; App Store aramasında bu daha geniş eşleşir. Ad ve alt
başlıkta geçen sözcükler zaten dizinlendiği için tekrarlanmadı.)

---

## Kurmancî liste

Her iki mağaza da liste metnini dile göre çoğaltmaya izin verir.
Uygulamanın kendisi iki dilli olduğu için Kurmancî liste eklemek
tutarlıdır. Sayılar ve kategori adları uygulamadaki Kurmancî adlarla
yazıldı (Wêje, Erdnîgarî, Zanist û Raman, Cîhan…). Metnin anadil
kontrolü gönderimden önce yapılmalı.

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
Kurmancî hîn bibe, bi pirsan pêşbirkê bike. Zêdetir ji 2.400 pirs, 11 kategorî.
```

(79 karakter)

### Metna pêşvebirinê / Tanıtım metni (yalnız App Store, 170)

```
Nû: ji nû ve hat sêwirandin. Zêdetir ji 2.400 pirs, yanzdeh kategorî û pêşbirka bi dorê — bêyî ku hevrik serhêl be.
```

(115 karakter)

### Danasîn / Tam açıklama (4000)

```
ZanKurd sepaneke zanînê ye ku hînbûna kurmancî dike pêşbirk. Ziman, çand,
dîrok, wêje, erdnîgarî, muzîk, sînema, siyaset, zanist û raman, teknolojî
û cîhan — zêdetir ji 2.400 pirs, yanzdeh kategorî.

Piraniya pirsan li ser zimân, dîrok û çanda kurdî ne. Pirsên Cîhan,
Teknolojî û Zanist û Raman zanîna giştî ne û ji kategoriyên kurdî cuda ne.

ÇAWA DIXEBITE

• Dersa rojê: her roj deh pirs, nêzîkî pênc deqe.
• Kategorî û ast: di her kategoriyê de pênc ast, ji hêsan ber bi dijwar.
• Ravekirin: gava tur diqede, tu dixwînî ka her bersiv çima wisa ye.
• Şaşiyên te: pirsên ku te şaş kirine vedigerin, heta tu fêr bibî.

PÊŞBIRK

• Pêşbirka bilez: bi hevrikekî rasthatî re 1v1 rasterast.
• Pêşbirka bi dorê: ne pêwist e hevrikê te di heman demê de serhêl be.
  Tu niha dilîzî, ew paşê; encam di "Pêşbirkên min" de xuya dibe.
• Ode ava bike: girêdana vexwendinê parve bike, bila hevalên te bi yek
  tikandinê tevlî bibin.
• Tabloya pêşderiyan: roj, hefte, meh û di nav hevalan de.

HÎN BIBE

• Rêyên fêrbûnê: dersên kurt ên ku mijar bi mijar diçin.
• Çîrok: di dîmeneke kurmancî de bi hilbijartinê pêş dikevî.
• Kartên peyvan: ji bo bîrkirina peyvan.
• Ferheng: bi kurmancî an bi tirkî bigere.

DU ZIMAN

Tevahiya navrûyê hem bi kurmancî ye hem bi tirkî. Kengî bixwazî bi yek
tikandinê diguherî; pirs, ravekirin û ders bi her du zimanan hatine
nivîsandin.

BÊ ÎNTERNET

Hemû pirsên ji bo lîstina bi tenê li ser amûrê ne. Bêyî înternetê jî tu
dikarî bilîzî. Ast û pêşketina hînbûnê li ser amûrê tên parastin.
Xala rêzkirinê li ser hesabê tê nivîsandin; pêşbirkên serhêl, karên
coinan û taybetmendiyên hesabê înternetê dixwazin.

ZanKurd belaş e û reklam tê de tune. Ji bo yên ku dixwazin abonetiyek
heye — parastina xweber a zincîrê û piştgirî ji projeyê re. Lîstik bi
temamî bêyî abonetiyê tê lîstin.
```

(1797 karakter. App Store'da aynı metin kullanılır: başlıklar normal
yazıma çevrilir ve Türkçe App Store açıklamasındaki üç yasal bağlantı
satırı sona eklenir.)

### Peyvên lêgerînê / Anahtar kelimeler (yalnız App Store, 100)

```
kurmanci,kurdi,hinbun,pirs,pesbirk,quiz,ziman,dirok,cand,weje,ferheng,dengbej,erdnigari
```

(87 karakter — ASCII, aynı gerekçeyle.)
