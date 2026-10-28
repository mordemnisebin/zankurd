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

## Bu sürümde yenilikler — 2.1.1 (App Store "What's New" / Play "Sürüm notları")

Yayındaki 2.1.0 (35)'ten beri değişenler. Türkçe metin ana dildir; Kurmancî
metin Kurmancî kurulundan geçti (çeviri GPT-6 Sol; denetim Gemini 3.8 Flash
ve Claude Opus 5.5; uyuşan düzeltmeler uygulandı, 2026-10-28).

### Türkçe

```text
ZanKurd 2.1.1 ile gelenler:
• Turnuva: Gerçek oyuncularla dört kişilik eleme kupası. Maçlar sunucuda puanlanır; şampiyon 200 jeton kazanır.
• Telaffuz atölyesi: Kelimeyi dinle, kendi sesini kaydet, karşılaştır. Ücretsiz.
• Pratik merkezi, alfabe ve sesler, 8 yeni hikâye ve 4 yeni dil bilgisi dersi.
• Kelimelerim: aralıklı tekrarla kelime kutuları ve çift yönlü sözlük.
• Sırayla düello: 24 saat süre, rakibi dürtme, soru soru karşılaştırma ve rövanş.
• Oda: sohbet ve tepkiler en üstte, "Tekrar oyna" ve oyuncu sayısı seçimi.
• Mağaza: joker paketi, seri koruması ve yeni çerçeveler.
• Ana sayfada tek "Bugün" paneli ve "Günün turu".
• Onlarca düzeltme ve iyileştirme.
```

### Kurmancî

```text
Nûbûnên ZanKurd 2.1.1:
• Kûpa: Kûpayeke palawtinê ya çar kesî bi lîstikvanên rastîn. Pûanên pêşbirkan li ser pêşkêşkar tên hesabkirin; şampiyon 200 zêr qezenc dike.
• Atolyeya bilêvkirinê: Guh bide peyvê, dengê xwe tomar bike û berawird bike. Belaş e.
• Navenda pratîkê, elîfbê û deng, 8 çîrokên nû û 4 dersên nû yên rêzimanê.
• Peyvên min: Qutiyên peyvan bi dubarekirina bi navber û ferhengeke dualî.
• Pêşbirka bi dorê: Dema 24 saetan, bîrxistina hevrik, berawirdkirina pirs bi pirs û pêşbirka vegerê.
• Ode: Sohbet û bertek li jor in, "Dîsa bilîze" û hilbijartina hejmara lîstikvanan.
• Firotgeh: Pakêta jokeran, parastina rêzeyê û çarçoveyên nû.
• Li rûpela sereke panela yekane ya "Îro" û "Gera rojê".
• Bi dehan sererastkirin û çêtirkirin.
```

## Mağaza ekran görüntüleri

Mağaza önce **Kürtçe bilgi yarışması** olarak okunur (düello, oda, rastgele
rakip); öğrenme (ders, sözlük) ikinci sıradadır. Sıra buna göre.

App Store en az bir 6,9" (1320×2868) ekran görüntüsü ister; Play için
telefon görüntüsü 1080 px genişlikten büyük olmalı ve en çok 8 tane
yüklenir — aynı sekiz dosya ikisine de yeter. 2026-10-13'te Şahnê
tasarımıyla (2.0.x) yeniden alındı; eski altı görüntü (Şahnê öncesi) atıldı.

Dosyalar `docs/screenshots/store/tr/` altında, hepsi 1320×2868:

| Dosya | Başlık | Ekran |
|---|---|---|
| `01_yaris.png` | Arkadaşına meydan oku | Yarış sekmesi: hızlı düello, sırayla düello, oda kur / kodla katıl |
| `02_fotografli_soru.png` | Kürt kültürünü sınayan sorular | Fotoğraflı soru (Newroz), süre ve ilerleme |
| `03_duello_puan.png` | Canlı puanla düello | Düello ortası: Sen / rakip puanı, dört şık, jokerler |
| `04_sonuc.png` | Sonucunu paylaş | Sonuç: yıldız, puan, doğru/yanlış, XP, Paylaş |
| `05_oda.png` | Oda kur, kodla davet et | Özel oda lobisi (oda kodu, hazırım) |
| `06_ana_ekran.png` | Günlük hedef, seri ve seviye | Öğren sekmesi: günlük hedef, seviye, konular |
| `07_ders_yolu.png` | Alfabeden başla | Kurmancî öğren: sıradaki ders ve ders listesi |
| `08_sozluk.png` | 1.119 kelime ve ifade | Sözlük (uygulama "1119 kelime ve ifade" yazar) |

Ayrıca `docs/screenshots/store/` altında:

- `play_feature_graphic.png` — Play öne çıkan görsel, 1024×500 (logo,
  "ZanKurd", "Kürtçe bilgi yarışması", iki ekran).
- `play_icon_512.png` — Play yüksek çözünürlüklü simge, 512×512, 32 bit PNG;
  `tool/generate_app_icons.py`'deki aynı çizimden (uygulama simgesiyle birebir).

`docs/screenshots/` sürüm denetiminde tutulmuyor (kökteki `.gitignore`);
üretilmiş görsellerin kaynak gibi davranmaması için konmuş bir kural.
Kaynak, ham görüntülerden bu görselleri üreten betiktir (zankurd_mobile/ içinde):

```
python3 tool/magaza_gorselleri.py   # Pillow gerekir
```

Betik zemini ve renkleri `lib/src/theme/sahne.dart` gece belirteçlerinden okur,
başlıkta Bricolage Grotesque ExtraBold kullanır, durum çubuğu saatini 9:41'e
sabitler (ham görüntüler farklı saatlerde alındı) ve her çıktının boyutunu
8 MB sınırına karşı denetler. Başlıklar en çok 32 karakterdir ve yalnız
ekranın gösterdiğini söyler; ham görüntü değişirse başlığı da gözle kontrol et.

Ham görüntüleri yeniden almak için (`docs/screenshots/store/tr/raw/`, yukarıdaki
ad eşlemesi betikteki `SHOTS` listesindedir):

1. Yalnız "Claude Store" (iPhone 17 Pro Max, 1320×2868) benzeri bir 6,9"
   cihaz: `xcrun simctl boot <udid>` — başka cihaz yanlış boyut verir.
2. `flutter run -d <udid> --dart-define-from-file=.env.mobile.release.json`
   (hata ayıklama derlemesi yeterli; köşede şerit çıkmaz). Yapılandırmasız
   derleme çevrimiçi ekranları (düello, oda) açmaz.
3. Misafir girişi → dil TR → görünen ad "Zana" gibi nötr bir ad.
4. Düelloda "Rakip bul" → 20 sn sonra "Botla oyna" (ikinci kişi gerekmez).
   Soru süresi 20 sn: ekranı süre dolmadan almak için `xcrun simctl io`
   ile her saniye kare alıp sonradan seç.
5. `xcrun simctl io <udid> screenshot <dosya>.png`

Sıralama ekranı bilerek setten çıkarıldı: başka kullanıcıların görünen adlarını
gösteriyor ve az kişiyle seyrek duruyor. Kelime dokununca çıkan anlam kartı
(`lesson3`) ham olarak çekildi ama sekizinci sıra için sözlük seçildi.

Kurmancî liste eklenirse aynı yol dil KU'yken tekrarlanır ve görüntüler
`docs/screenshots/store/ku/` altına konur.

---

## Google Play

### Uygulama adı (en fazla 30 karakter)

```
ZanKurd Kürtçe Bilgi Yarışması
```

(30 karakter. 2026-10-13: ad yarışmayı öne alır; Kürtçe öğrenme araması
Bimus gibi büyük uygulamalarla dolu, Kürtçe bilgi yarışması ise boş.
Pirs 2022'den beri güncellenmiyor.)

### Kısa açıklama (en fazla 80 karakter)

```
Kürtçe bilgi yarışması: arkadaşınla düello, oda kur, oynarken Kurmancî öğren.
```

(77 karakter)

### Tam açıklama (en fazla 4000 karakter)

```
ZanKurd, Kürtçe bilgi yarışmasıdır. Arkadaşına meydan oku, oda kur ya da
rastgele bir rakiple düello yap; Kürt dili, tarihi, edebiyatı, müziği ve
sineması üzerine 2.400'den fazla soruyla kimin daha çok bildiğini gör.
Oynarken Kurmancî de öğrenirsin.

Dil, kültür, tarih, edebiyat, coğrafya, müzik, sinema, siyaset, bilim ve
düşünce, teknoloji ve dünya: on bir kategori.

Soruların çoğu Kürt dili, tarihi ve kültürü üzerinedir. Dünya, Teknoloji
ve Bilim ve Düşünce kategorileri genel bilgi sorularıdır; Kürt
kategorilerinden ayrı durur.

YARIŞ

• Canlı düello: seviyene yakın bir rakiple canlı 1v1.
• Sırayla düello: rakibin aynı anda çevrimiçi olması gerekmez. Sen şimdi
  oynarsın, o sonra; sonuç Düellolarım'da görünür.
• Oda kur: davet bağlantısını paylaş, arkadaşların tek dokunuşla katılsın.
  Grup yarışında 50 kişiye kadar aynı anda yarışın, canlı sıralamayı izleyin.
• Turnuva: gerçek oyuncularla dört kişilik eleme kupası. Maçları sunucu
  puanlar; şampiyon 200 jeton kazanır.
• Liderlik tablosu: gün, hafta, ay ve arkadaşlar arası sıralama.

NASIL İŞLER

• Günün turu: her gün on soru, yaklaşık beş dakika.
• Kategori ve seviye: her kategoride beş seviye, kolaydan zora.
• Açıklamalar: tur bitince her sorunun niçin öyle olduğunu okursun.
• Yanlışların takibi: yanlış yaptığın sorular geri gelir, öğrenene kadar.

ÖĞREN

• Başlangıç yolu: alfabeden geçmiş zamana kısa dersler; ders sonunda
  boşluk doldurma, cümle kurma ve çoktan seçmeli alıştırmalar.
• Alfabe ve sesler: her harf, örnek kelimesi ve sesiyle.
• Telaffuz atölyesi: kelimeyi dinle, kendi sesini kaydet, karşılaştır.
  Kayıt yalnız cihazında kalır.
• Hikâye: Kurmancî bir sahnede seçim yaparak ilerlersin.
• Kelimelerim: aralıklı tekrarla kelime kutuları; zorlandığın kelime
  daha sık gelir.
• Sözlük (Ferheng): 1.100'den fazla kelime, Kurmancî ya da Türkçe ara.
  Derste ya da soruda Kurmancî bir kelimeye dokununca anlamı açılır.

İKİ DİL

Arayüzün tamamı hem Kurmancîdir hem Türkçe. İstediğin an tek dokunuşla
değiştirirsin; sorular, açıklamalar ve dersler iki dilde de yazılıdır.

ÇEVRİMDIŞI

Tek kişilik soruların tamamı cihazda. İnternet olmadan da oynarsın.
Seviye çubuğun ve öğrenme ilerlemen cihazda saklanır; hesabınla girdiysen
hesabına da eşitlenir, telefon değişse de kaybolmaz.
Sıralama puanın hesabına yazılır; çevrimiçi yarışlar, coin işlemleri ve
hesap özellikleri internet gerektirir.

ERİŞİLEBİLİRLİK

Metin/zemin kontrastları WCAG AA eşiğine göre ölçülür. Yazı boyutunu
sistemden büyüttüğünde ekranlar taşmaz. Ekran okuyucu için düğmelerin
adı vardır.

ZanKurd ücretsizdir ve reklam içermez. Bütün dersler, yarışlar ve
alıştırmalar ücretsizdir; jetonlar oyun içinde kazanılır.
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
Kürtçe bilgi yarışması, düello
```

(30 karakter; alt başlık yalnız yeni sürümle değişir, 2.0.2 ile gönderilir)

### Tanıtım metni (en fazla 170 karakter — güncellemesi incelemesizdir)

```
Arkadaşına meydan oku: Kürt dili, tarihi ve kültürü üzerine 2.400'den fazla soruyla düello. Yeni: alfabeden başlayan 18 ders ve 1.119 kelimelik sözlük.
```

(151 karakter)

### Açıklama (en fazla 4000 karakter)

Play metni, bölüm başlıkları normal yazıma çevrilerek ve sonuna yasal
bağlantılar eklenerek kullanılır. Yasal bağlantılar App Store için
zorunludur: abonelik sunan uygulamada Kullanım Koşulları (EULA)
bağlantısı App Description'da bulunmalı (1.9.2 öncesi 3.1.2(c) reddi,
bkz. `docs/app_review_packet_1.9.2_build20.md`).

```
ZanKurd, Kürtçe bilgi yarışmasıdır. Arkadaşına meydan oku, oda kur ya da
rastgele bir rakiple düello yap; Kürt dili, tarihi, edebiyatı, müziği ve
sineması üzerine 2.400'den fazla soruyla kimin daha çok bildiğini gör.
Oynarken Kurmancî de öğrenirsin.

Dil, kültür, tarih, edebiyat, coğrafya, müzik, sinema, siyaset, bilim ve
düşünce, teknoloji ve dünya: on bir kategori.

Soruların çoğu Kürt dili, tarihi ve kültürü üzerinedir. Dünya, Teknoloji
ve Bilim ve Düşünce kategorileri genel bilgi sorularıdır; Kürt
kategorilerinden ayrı durur.

Yarış

• Canlı düello: seviyene yakın bir rakiple canlı 1v1.
• Sırayla düello: rakibin aynı anda çevrimiçi olması gerekmez. Sen şimdi
  oynarsın, o sonra; sonuç Düellolarım'da görünür.
• Oda kur: davet bağlantısını paylaş, arkadaşların tek dokunuşla katılsın.
  Grup yarışında 50 kişiye kadar aynı anda yarışın, canlı sıralamayı izleyin.
• Turnuva: gerçek oyuncularla dört kişilik eleme kupası. Maçları sunucu
  puanlar; şampiyon 200 jeton kazanır.
• Liderlik tablosu: gün, hafta, ay ve arkadaşlar arası sıralama.

Nasıl işler

• Günün turu: her gün on soru, yaklaşık beş dakika.
• Kategori ve seviye: her kategoride beş seviye, kolaydan zora.
• Açıklamalar: tur bitince her sorunun niçin öyle olduğunu okursun.
• Yanlışların takibi: yanlış yaptığın sorular geri gelir, öğrenene kadar.

Öğren

• Başlangıç yolu: alfabeden geçmiş zamana kısa dersler; ders sonunda
  boşluk doldurma, cümle kurma ve çoktan seçmeli alıştırmalar.
• Alfabe ve sesler: her harf, örnek kelimesi ve sesiyle.
• Telaffuz atölyesi: kelimeyi dinle, kendi sesini kaydet, karşılaştır.
  Kayıt yalnız cihazında kalır.
• Hikâye: Kurmancî bir sahnede seçim yaparak ilerlersin.
• Kelimelerim: aralıklı tekrarla kelime kutuları; zorlandığın kelime
  daha sık gelir.
• Sözlük (Ferheng): 1.100'den fazla kelime, Kurmancî ya da Türkçe ara.
  Derste ya da soruda Kurmancî bir kelimeye dokununca anlamı açılır.

İki dil

Arayüzün tamamı hem Kurmancîdir hem Türkçe. İstediğin an tek dokunuşla
değiştirirsin; sorular, açıklamalar ve dersler iki dilde de yazılıdır.

Çevrimdışı

Tek kişilik soruların tamamı cihazda. İnternet olmadan da oynarsın.
Seviye çubuğun ve öğrenme ilerlemen cihazda saklanır; hesabınla girdiysen
hesabına da eşitlenir, telefon değişse de kaybolmaz.
Sıralama puanın hesabına yazılır; çevrimiçi yarışlar, coin işlemleri ve
hesap özellikleri internet gerektirir.

Erişilebilirlik

Metin/zemin kontrastları WCAG AA eşiğine göre ölçülür. Yazı boyutunu
sistemden büyüttüğünde ekranlar taşmaz. Ekran okuyucu için düğmelerin
adı vardır.

ZanKurd ücretsizdir ve reklam içermez. Bütün dersler, yarışlar ve
alıştırmalar ücretsizdir; jetonlar oyun içinde kazanılır.

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

Piraniya pirsan li ser ziman, dîrok û çanda kurdî ne. Pirsên Cîhan,
Teknolojî û Zanist û Raman zanîna giştî ne û ji kategoriyên kurdî cuda ne.

ÇAWA DIXEBITE

• Gera rojê: her roj deh pirs, nêzîkî pênc deqe.
• Kategorî û ast: di her kategoriyê de pênc ast, ji hêsan ber bi dijwar.
• Ravekirin: gava tur diqede, tu dixwînî ka her bersiv çima wisa ye.
• Şaşiyên te: pirsên ku te şaş kirine vedigerin, heta tu fêr bibî.

PÊŞBIRK

• Pêşbirka zindî: bi hevrikekî rasthatî re 1v1 rasterast.
• Pêşbirka bi dorê: ne pêwist e hevrikê te di heman demê de serhêl be.
  Tu niha dilîzî, ew paşê; encam di "Pêşbirkên min" de xuya dibe.
• Ode ava bike: girêdana vexwendinê parve bike, bila hevalên te bi yek
  tikandinê tevlî bibin.
• Kûpa: kûpaya palawtinê ya çar kesî bi lîstikvanên rastîn. Pûanên
  pêşbirkan li ser pêşkêşkar tên hesabkirin; şampiyon 200 zêr qezenc dike.
• Tabloya pêşderiyan: roj, hefte, meh û di nav hevalan de.

HÎN BIBE

• Rêyên fêrbûnê: dersên kurt ên ku mijar bi mijar diçin.
• Elîfbê û deng: her tîp bi peyva xwe ya mînak û bi dengê wê.
• Atolyeya bilêvkirinê: guh bide peyvê, dengê xwe tomar bike û berawird
  bike. Tomar tenê li ser amûra te dimîne.
• Çîrok: di dîmeneke kurmancî de bi hilbijartinê pêş dikevî.
• Peyvên min: qutiyên peyvan bi dubarekirina bi navber; peyva ku tu pê
  zehmetiyê dikişînî pirtir tê.
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

ZanKurd belaş e û reklam tê de tune. Hemû ders, pêşbirk û rahênan belaş
in; zêr di nava lîstikê de tên qezenckirin.
```

(1797 karakter. App Store'da aynı metin kullanılır: başlıklar normal
yazıma çevrilir ve Türkçe App Store açıklamasındaki üç yasal bağlantı
satırı sona eklenir.)

### Peyvên lêgerînê / Anahtar kelimeler (yalnız App Store, 100)

```
kurmanci,kurdi,hinbun,pirs,pesbirk,quiz,ziman,dirok,cand,weje,ferheng,dengbej,erdnigari
```

(87 karakter — ASCII, aynı gerekçeyle.)
