# Dış model aday havuzları — intake kararları (2026-08-06)

Branch: `content/overnight-expansion-2026-08-06`

Bu dosya **karar kaydıdır**. Hiçbir dış commit cherry-pick edilmedi, hiçbir
dış aday runtime bankasına alınmadı.

## Havuzların gerçek durumu

| Havuz | Branch | HEAD | Aday | Durum |
|---|---|---|---|---|
| Grok wave 01 | `content/author-grok-wave-01-2026-08-06` | `8f68a50` | 407 | incelendi |
| DeepSeek wave 01 | `content/author-deepseek-wave-01-2026-08-06` | `8fbbb94` | 500 | incelendi |
| Ücretsiz model sürüsü | `content/free-model-swarm-wave-01-2026-08-06` | `be98dc3` | 0 | **SKIPPED — NO COMPLETE HANDOFF** |

Ücretsiz sürü branch'i `be98dc3`'te duruyor; bu, bu çalışmanın da ortak
atasıdır. `main..HEAD` farkı yeni içerik içermiyor — yalnız zaten aktive
edilmiş 218'lik batch'in kendisi. Yeni aday, provenance ya da validation
raporu yok.

## Envanter (907 aday)

    fiziksel toplam                907   (grok 407, deepseek 500)
    benzersiz ID                   907
    şema geçerli                   907
    TR/KU tam                      907
    explanationKu + explanationTr  907
    provenance alanı dolu          907
    GERÇEK (URL) sourceReference     0   <-- §7 kapısı
    exact prompt duplicate           0
    ID çakışması (canlı banka)       0
    semantic duplicate (canlı 2050)  0
    semantic duplicate (aktif 218)   0
    semantic duplicate (grok↔deepseek) 0
    kategori: Teknolojî 225, Cografya 216, Sînema 125, Edebiyat 125,
              Dîrok 91, Muzîk 82, Çand 43
    cevap pozisyonu: 24.9 / 25.8 / 24.4 / 24.9
    en uzun doğru: %34.2   en kısa doğru: %18.5

## Kapıda düşen bulgular

### 1. Kendini yanlış ilan eden çeldiriciler — Grok 296/407 (%72,7)

    ["512 KB (yanlış)", ...]
    ["RAM (ne rast) (ne rastîn)", "RAM (yanlış) (geçersiz)"]

Oyuncu konuyu bilmeden etiketsiz şıkkı seçip kazanır. Mevcut
`answer-leak-*` kuralı bunu görmüyordu (yalnız soru kökünü tarıyordu) ve
sekiz batch'in sekizine de PASS verilmişti. Kural eklendi
(`validate_batch.py::SELF_LABELED`) ve `distractor_integrity_test` ile
üretim bankalarına bağlandı.

Kural sonrası Grok'un kullanılabilir kalıntısı: **111** (407 değil).
DeepSeek bu kuraldan etkilenmedi: 500/500.

### 2. Doğrulanamayan kaynak atfı — bütün havuz

`provenance.method` = `independent-llm-authoring-from-reference-knowledge`.
Yani model kendi belleğinden yazmış. Buna rağmen 80 DeepSeek kaydı belirli
akademik kitaplara atıf taşıyor:

    33  Philip G. Kreyenbroek & Christine Allison, Kurdish Culture and Identity
    32  Mehrdad Izady, The Kurds: A Concise Handbook
    15  Bordwell & Thompson, Film Art: An Introduction

Kitaplar gerçek; ama bu iddiaların o kitaplardan geldiğine dair kanıt yok —
sayfa, baskı, URL yok. `sourceReference` alanlarının tamamı
`internal:...#gate=...` ya da `textbook:...#hash=...` biçiminde, yani
üreten hattı işaret eden iç künyeler; kaynak değil.

Bu, §7'nin "sahte kaynak üretme" kuralının tam hedefi. Atıflar olduğu gibi
bırakılamaz: **gerçek olmayan bir kaynak zincirini gerçekmiş gibi
sunardı.** 65'i (Kreyenbroek + Izady) tam da §7'nin en sıkı fact-check
istediği Kürt tarihi/kültürü alanında — yani en zayıf kaynaklı kayıtlar en
sıkı doğrulama gerektiren kayıtlarla çakışıyor.

Karar: bu atıflar korunmayacak. İki yol var ve kayıt bazında seçilecek:
sabit ve bağımsız doğrulanabilir bilgi ise, aktive edilmiş 218'de olduğu
gibi dürüst iç künye (`internal:...#gate=...`, `reviewedBy: automated`)
yazılır ve kitap atfı **kaldırılır**; doğrulanamıyorsa
`QUARANTINED_UNVERIFIABLE`.

### 3. Kürdistan terminolojisi ve editoryal perspektif

`tool/content_authoring/audit_kurdistan_terminology.py` (raporlar,
değiştirmez):

    aday havuzu (907)          canlı bankalar (2050)
    TERMINOLOGY_OK      375    TERMINOLOGY_OK    1066
    NOT_APPLICABLE      414    NOT_APPLICABLE     818
    ENDONYM_REWRITE      98    ENDONYM_REWRITE     90
    POLITICAL_STATUS     48    POLITICAL_STATUS     9
    REGION_FRAME         19    REGION_FRAME        50
    incelenecek         118    incelenecek        121

Örnek `POLITICAL_STATUS_QUESTION_REJECTED`:

    grok26_geo_nature_0047  "Van Gölü hangi ülkededir?"
    grok26_geo_nature_0050  "Ağrı Dağı esas olarak hangi ülkededir?"

Bunlar §3.4 gereği doğrudan kabul edilmez; Kürdistan'ın hangi parçasında
olduğu, komşu şehirler, akarsular, kültürel bağlam üzerinden yeniden
yazılır ya da karantinaya alınır.

**Canlı bankalardaki 121 kayıt bu turda DEĞİŞTİRİLMEDİ.** "Eski doğru
soruları sessizce değiştirme" kuralı gereği ayrı ve açık bir inceleme
turu gerektirir. Bu turda yalnız görünür kılındılar.

## Aktive edilen

Bu turda **hiçbir dış aday aktive edilmedi.** Loader toplamı değişmedi:
2050 fiziksel, 2050 benzersiz ID, 218 genişletme kaydı.

Sebep: §12 aktivasyon kapısı "provenance %100" ister ve §7 sahte kaynağı
yasaklar. 907 adayın **hiçbirinde** doğrulanabilir kaynak yok. Kaynak
sorunu kayıt bazında çözülmeden batch aktive etmek, kapıyı biçimsel olarak
geçip anlamca çiğnemek olurdu.

## Tur 2 (2026-08-06) — kaynaklandırılmış intake

### Grok 296: kesin red uygulandı

`decisions_grok_rejected.json` — 296 kayıt `REJECTED_LOW_QUALITY`. Toplu
onarım denenmedi: ekonomik değil ve orijinal seçenek kalitesi güvenilmez.
Grok'un kalan 111 adayı inceleme havuzunda bekliyor.

### Kaynak kataloğu

`docs/content/source_catalog_2026_08.json`. Katalog iki doğrulama seviyesi
ayırır ve bu ayrım işin özüdür:

* `fetched` — sayfa bu oturumda açıldı ve okundu;
* `listed` — kurumun kendi alan adında arama sonucunda göründü, içeriği
  okunmadı.

`listed` bir kayıt tek başına bir soruyu doğrulamaz. Şu an yalnız **bir**
kaynak `fetched`: Columbia University Film Language Glossary.

Katalog Sînema dışındaki kategoriler için henüz boş; `pendingCategories`
altında açıkça işaretli. Kürdistan coğrafyası/Kürt tarihi kategorisi en sıkı
doğrulamayı gerektirdiği için kurumsal arşiv kaynağı bulunmadan hiçbir kayıt
aktive edilmeyecek.

### Sînema batch'i (DeepSeek batch_01, 125) — karar dağılımı

    ACCEPTED_VERIFIED             1
    QUARANTINED_DUPLICATE         2
    REJECTED_WRONG_ANSWER         1
    QUARANTINED_UNVERIFIABLE    121

Kayıt bazında kararlar `decisions_cinema.json` içinde.

**Aktive edilen: 0.** Tek doğrulanmış kayıt (ds26_cinema_0001, yakın çekim
tanımı) tek başına bir batch değildir; tek kayıt için banka açmak, ölçüm ve
kapı maliyetini karşılamaz. Doğrulama derinleştiğinde kabul edilenlerle
birlikte aktive edilecek.

### Bulunan somut kusurlar

**Yanlış subcategory etiketi — 28 kayıt.** `subcategory` alanı
`"Yılmaz Güney û Klasîk"` diyor; oysa 125 kaydın **yalnız biri** Yılmaz
Güney'den söz ediyor (o da Cannes sorusu, ilgisiz). 28 kaydın tamamı batı/
dünya sineması klasikleri: Méliès, Lang, Welles, Fellini, Godard. Kürt
yönetmen adı taşıyan bir bölüm vaat edilip içi doldurulmamış. Kürtçe bir
uygulamada bu, ölçülebilir bir içerik boşluğudur.

**Olgu tekrarı — 2 kayıt.** `0082`, `0063` ile aynı olguyu soruyor (1939,
siyah-beyazdan renkliye, Oz Büyücüsü). `0020`, `0002` ile aynı (establishing
shot). Envanterdeki Jaccard eşiği bunları kaçırmıştı; aynı doğru cevabı
paylaşan kayıtları gruplayınca göründüler. `0052`/`0109` de aynı cevabı
("Fransa") paylaşıyor ama farklı olgular — tekrar DEĞİL; bu yüzden eşleşme
otomatik red değil, inceleme sebebi sayıldı.

**Doğrulanamayan Türkçe başlık — 1 kayıt.** `0079` À bout de souffle'ün
Türkçe adını "Sersefil" diye veriyor. Hiçbir kurumsal kaynak (BFI, MoMA,
Britannica) bunu desteklemiyor; yerleşik kullanım "Serseri Âşıklar".
`REJECTED_WRONG_ANSWER`.

## Devam noktası

Sınırlayıcı etken içerik değil, **doğrulama hızıdır**. 121 kaydın her biri
ayrı bir olgu iddiası taşıyor (film adı, yıl, yönetmen, teknik terim) ve her
biri kurumsal kaynakta tek tek aranmayı gerektiriyor. Tur 2'de bir kaynak
`fetched` seviyesine çıkarıldı ve bir kayıt doğrulandı.

Sıradaki iş, sırayla:

1. Sînema kataloğunu genişlet: Columbia sözlüğünün terim dizinini açıp
   sinema-dili sorularının (yaklaşık ilk 52 kayıt) kapsandığını doğrula;
   BFI ve MoMA künye sayfalarını `fetched` seviyesine çıkar.
2. `QUARANTINED_UNVERIFIABLE` 121 kaydı bu kataloga karşı yeniden geçir;
   doğrulananı `ACCEPTED_VERIFIED`, gerçek `sourceReference` ile güncelle.
3. Yalnız doğrulanmış kayıtlarla Sînema batch'ini aktive et.
4. Sonra Edebiyat → Teknolojî → Cografya/doğa → Dîrok → Çand/Muzîk →
   Grok'un kalan 111'i.

28 kaydın yanlış `subcategory` etiketi aktivasyondan önce düzeltilmeli;
"Yılmaz Güney" bölümü ya gerçek Yılmaz Güney içeriğiyle doldurulmalı ya da
etiket dürüst bir ada çekilmelidir.

Girdi dosyaları salt-okunur olarak
`scratchpad/external_authoring/opus_intake_2026_08/raw/` altında;
envanter `inventory.json`, terminoloji manifestleri
`terminology_review.json` ve `terminology_review_live.json`.

## Tur 3 (2026-08-06) — claim matrix ile toplu doğrulama

`docs/content/cinema_claim_matrix_2026_08.json`. 125 kayıt önce iddia türüne
ayrıldı; doğrulama soru başına ayrı arama yerine iddia ailesi başına yapıldı.

    other              50    film_title_year   34
    film_language      17    festival_award    13
    production_tech     5    director_person    4
    country_movement    2    yilmaz_guney       0

### Düzeltme: Yılmaz Güney kaydı sıfır

Tur 2'de "125 kaydın yalnız biri Yılmaz Güney'den söz ediyor" yazmıştım.
Yanlıştı: eşleşme `güney` sözcüğünün "Fransa'nın **güney**indeki Cannes"
içinde geçmesinden geliyordu. Gerçek sayı **sıfır**. `Yılmaz Güney û Klasîk`
etiketli 28 kaydın hiçbiri Yılmaz Güney ile ilgili değil.

### Alt kategori düzeltmesi — 28 kayıt

Gerçek içeriğe göre yeniden sınıflandırıldı; mevcut taksonomi içinde kalındı,
yeni kategori sistemi kurulmadı:

    Klasîkên Sînemaya Cîhanê  22
    Dîroka Sînemayê            2
    Teknîka Hilberînê          2
    Zimanê Fîlmê               1
    Belgefîlm û Festîval       1

### Doğrulanan 9 kayıt

Festival/ödül ailesi resmî kurum arşivlerinden doğrulandı:

    0087 ilk Oscar töreni 1929      oscars.org
    0088 resmî ad Akademi Ödülü     Britannica
    0089 Altın Palmiye / Cannes     festival-cannes.com
    0090 Venedik en eski, 1932      labiennale.org
    0091 Berlinale Almanya          Britannica
    0109 Cannes Fransa              festival-cannes.com
    0111 ilk En İyi Film: Wings     oscars.org
    0113 AMPAS 1927                 Britannica
    0001 yakın çekim tanımı         Columbia University

`0112` (tören şehri) bilerek doğrulanmadı sayıldı: kaynaklarda açıkça
görülmedi, tahminle kabul edilmedi.

Katalog artık üç doğrulama seviyesi ayırır: `fetched`, `search_summary`
(Britannica ve oscars.org doğrudan fetch'e **403** veriyor; alan adıyla
sınırlı arama özeti kullanıldı) ve `listed`.

### Karar dağılımı (125)

    ACCEPTED_VERIFIED             9
    QUARANTINED_DUPLICATE         2
    REJECTED_WRONG_ANSWER         1
    QUARANTINED_UNVERIFIABLE    113

### Aktive edilen: 0 — ve niçin bu turda da değil

9 kayıt aktive edilmeye hazır. Aktivasyon bankanın içeriğini değiştirir,
bu da question-quality baseline kaynak hash'ini değiştirir ve kapı
`--accept-current-debt` gerektirir. O komut bu oturumda izin sınıflandırıcısı
tarafından üç kez engellendi; kullanıcı manuel çalıştırmıştı. Şimdi aktive
etmek kapıyı yeniden kırmızı bırakır ve yine kullanıcı müdahalesi gerektirir.

Bu yüzden 9 kayıt doğrulanmış ve hazır biçimde bekletiliyor; aktivasyon tek
adımda, izin verildiğinde yapılacak.

### Sıradaki iş

1. `film_title_year` (34) ve `director_person` (4) ailelerini BFI/MoMA künye
   sayfalarından toplu doğrula.
2. `film_language` (17) ailesini Columbia sözlüğünün terim sayfalarından
   doğrula (indeks sayfası terimleri listelemiyor; terim URL'leri tek tek).
3. Doğrulananlarla birlikte tek Sînema intake bankası aç ve aktive et.
4. Sonra Edebiyat → Teknolojî → Cografya/doğa → Dîrok → Çand/Muzîk →
   Grok'un kalan 111'i.

## Tur 4 (2026-08-06) — kaynak seviyeleri ve nihai Sînema kararları

Kaynaklar artık dört seviyeye ayrılmış durumda ve seviye olduğundan güçlü
gösterilmiyor:

* `FETCHED_DIRECT` — sayfa açıldı, tanım okundu. Tek başına yeterli.
* `SEARCH_SUMMARY_CORROBORATED` — sayfa doğrudan açılamıyor (403), ama iki
  bağımsız kurumsal kaynak aynı olguyu gösteriyor.
* `SEARCH_SUMMARY_UNCORROBORATED` — tek kaynak. **Yetersiz.**
* `UNVERIFIABLE` — runtime'a alınmaz.

### Columbia sözlüğü: yapı keşfedildi, ama kısmi

`/term/<slug>/` deseni çalışıyor. Beş terim doğrudan açılıp okundu:
close-up, establishing-shot, voice-over, jump-cut, mise-en-scene.

`browse` sayfası ve `flashback` gibi bazı slug'lar **403** veriyor — sözlük
batch'teki her terimi kapsamıyor. Kapsanmayanlar tahminle doldurulmadı.

### İki kayıt bilerek geri alındı

Tur 3'te doğrulanmış saydığım iki kayıt §1'in iki-kaynak kuralına takıldı ve
`QUARANTINED_UNVERIFIABLE` yapıldı:

* `0088` (ödülün resmî adı) — yalnız Britannica; üstelik arama özeti
  sorgudaki resmî adı doğrulamadığını açıkça söylüyordu.
* `0091` (Berlinale Almanya) — tek kurumsal özet; berlinale.de doğrudan
  okunmadı.

Sayıyı korumak için kuralı gevşetmek, kaynak seviyesi icat etmekle aynı şey
olurdu.

### Nihai Sînema kararları (125)

    ACCEPTED_VERIFIED_DIRECT          5
    ACCEPTED_VERIFIED_CORROBORATED    6
    QUARANTINED_DUPLICATE             2
    REJECTED_WRONG_ANSWER             1
    QUARANTINED_UNVERIFIABLE        111

**Toplam doğrulanmış: 11. Aktivasyon eşiği 40. Aktive edilen: 0.**

Eşik karşılanmadığı için batch staged ve karantinada bırakıldı; §7'nin
"doğrulanmamış soruyla eşiği doldurma" kuralı gereği 29 kaydı tamamlamak
için doğrulama seviyesi düşürülmedi. Aktivasyon commit'i oluşturulmadı.

Sınırlayıcı etken yine doğrulama hızı: 111 kaydın çoğu ayrı bir film/yıl/
yönetmen künyesi gerektiriyor ve kurumsal katalog sayfalarının bir kısmı
doğrudan fetch'e kapalı.

### Yılmaz Güney / Kürt sineması

`docs/content/plans/yilmaz_guney_kurdish_cinema_content_plan.md` — yalnız
plan: kaynak aileleri, alt başlıklar, doğrulanacak iddia listesi ve editoryal
sınırlar. Soru içermiyor. Boş `Yılmaz Güney û Klasîk` etiketi, içi kaynaklı
içerikle dolmadan yeniden kullanılmayacak.

### Sıradaki iş

1. `film_title_year` (34) + `director_person` (4): BFI/MoMA künye sayfaları;
   film başına en çok iki arama, sonra karantina.
2. Kalan film dili terimleri: Columbia'da bulunmayanlar için başka üniversite
   veya resmî film enstitüsü sözlüğü.
3. 40 eşiği aşılırsa tek Sînema intake bankası açılıp aktive edilecek.
4. Sonra Edebiyat → Teknolojî → Cografya/doğa → Dîrok → Çand/Muzîk →
   Grok'un kalan 111'i.

## Tur 5 (2026-08-06) — ortak havuz ve Edebiyat

### Ortak doğrulanmış havuz kuruldu

`docs/content/verified_external_pool_2026_08/` — 11 Sînema kaydı
STAGED_VERIFIED. `build_verified_pool.py` havuzu karar manifestlerinden
TÜRETİR (deterministik, idempotent doğrulandı). Kategori başına 40 eşiği
kaldırıldı; toplu eşik 100.

### Edebiyat (DeepSeek batch_02, 125) — kapatıldı, doğrulanan 0

    kurdish_lit 25   work_author 14   concept_term 8
    period_movement 6   other 72

Bu batch Sînema'dan farklı: **25 kayıt doğrudan Kürt edebiyatıyla ilgili**
(Ehmedê Xanî, Melayê Cizîrî, Feqiyê Teyran, Cegerxwîn, Mehmed Uzun,
dengbêj geleneği, Şivanê Kurmanca). Uygulama için en değerli içerik burada.

Encyclopaedia Iranica üç iddiayı destekledi — Mem û Zîn'in masnavi olduğu,
Kurmancî yazıldığı ve Kürt ulusal destanı sayıldığı. Ama §1'in iki-kaynak
kuralı için ikinci **bağımsız** kurumsal kaynak bulunamadı: ikinci arama
British Library ve LoC alan adlarından sonuç döndürdü, fakat özet aynı
iddiayı tekrar ediyordu, ayrı bir kurumsal sayfayı göstermiyordu.

Sînema'da 0088 ve 0091 aynı sebeple geri alınmıştı. Aynı ölçüyü burada
gevşetmek tutarsızlık olurdu; üçü de `SEARCH_SUMMARY_UNCORROBORATED` olarak
karantinada. Tarih iddiaları (Mem û Zîn 1692, Xanî'nin 1651 doğumu) hiçbir
kurumsal kaynakta doğrulanamadı.

**Terminoloji bulgusu:** 8 kayıt `KURDISH_ENDONYM_REWRITE`, 1
`POLITICAL_STATUS_QUESTION_REJECTED`, 1 `REGION_FRAME_REWRITE`. Örnek:
`0003` Ehmedê Xanî'nin doğum yerini "Xankê (Hakkari)" veriyor — sözleşme
gereği Colemêrg. Düzeltmeler kayıt aktive edilmediği için uygulanmadı;
manifestte bekliyor (`terminology_review_literature.json`).

### Ortak havuz durumu

    STAGED_VERIFIED 11 (Sînema)   |   eşik 100   |   aktivasyon: HAYIR

### Sıradaki iş

Sıra: Grok Teknolojî → DeepSeek Cografya → Grok Cografya → Grok Dîrok →
DeepSeek Çand/Muzîk → Grok'un kalanı.

Edebiyat'ın 25 Kürt edebiyatı kaydı, kurumsal Kürt çalışmaları kaynakları
(Iranica dışında: üniversite Kürt çalışmaları merkezleri, ulusal kütüphane
katalogları, British Library Kürtçe koleksiyonu) `FETCHED_DIRECT` seviyesine
çıkarıldığında yeniden değerlendirilmeli — havuzun en yüksek değerli adayları
bunlar.

## Tur 6 (2026-08-06) — risk temelli kaynak politikası, Teknolojî

Risk sınıfları uygulandı: A (yüksek hassasiyet, iki kaynak), B (otoritatif
katalog, tek kaynak), C (sabit teknik/bilimsel, tek doğrudan kaynak),
D (kendi içinde çözülebilir, dış kaynak gerekmez), E (doğrulanamaz).

### Üçüncü kapı deliği: şablon kimliği sızıntısı

Grok'un kalan 111 adayının **19'u** soru metninde iç etiket ve sıfır dolgulu
kayıt numarası taşıyordu:

    "Temel tanım: «ewle (0025)» hangisidir?"
    "Hangi açıklama «sîstem (0036)» ile uyumludur?"

`ewle` iç slug, `(0025)` kayıt numarası. Oyuncuya hiçbir şey ifade etmiyor.
`validate_batch`'in TODO/XXX arayan `placeholder-*` kuralı bu biçimi
görmüyordu ve 19'unu da **kabul etmişti**.

Bu, aynı desenin üçüncü tekrarı: self-labelled distractor, yol deseni
charset'i, şimdi şablon kimliği. Her seferinde kural, kusurun hangi biçimde
geleceğini varsaydığı için varsaymadığı biçimi kaçırdı.

Kural eklendi ve `distractor_integrity_test`'e bağlandı. İlk yazımda desen
`\d{3,4}` idi ve yayımlanmış `cinema_0047`'nin meşru **"(1929)"** yılını
şablon artığı sandı. Kayıt numarası sıfır dolguludur, yıl asla sıfırla
başlamaz — desen `\(\s*0\d{3}\s*\)` olarak daraltıldı. Şimdi 19'u da
yakalıyor, canlı bankalarda yanlış pozitif yok.

### Teknolojî (Grok, 34 kullanılabilir aday)

    risk C 14   risk D 1   risk E 19

    ACCEPTED_PRIMARY_DIRECT      1   (HTTP 404, MDN'den doğrudan okundu)
    ACCEPTED_SELF_CONTAINED      1   (1010(2)=10(10), türetme kayıtlı)
    QUARANTINED_UNVERIFIABLE    13
    REJECTED_INVALID_SCHEMA     19

Risk C'nin 13'ü reddedilmedi, yalnız doğrulanmadı: her biri için doğrudan
açılmış kurumsal tanım kaynağı gerekiyor (W3C/IETF/MDN/NIST/üniversite) ve
bu turda yalnız biri açıldı.

Volatil konu bulunmadı (sürüm, pazar payı, "en yeni" iddiası yok).

### Ortak havuz

    STAGED_VERIFIED 13   |   Sînema 11, Teknolojî 2   |   eşik 100

### Sıradaki iş

Cografya (DeepSeek + Grok, 31 Grok kaydı dâhil) — iki havuz tek potada
karşılaştırılıp semantic duplicate seçimi yapılacak, ardından Dîrok (Grok 46,
risk sınıfı A) ve Çand/Muzîk.

## Tur 7 (2026-08-06) — Cografya (DeepSeek 125 + Grok 31)

### Çapraz duplicate: sıfır

DeepSeek ile Grok arasında yakın çift bulunamadı (Jaccard >= 0.55). İki model
farklı olgu kümeleri üretmiş; seçim yapılacak çift yok.

### Asıl bulgu: batch'in çoğu sözleşmeyle çelişen kalıpta

DeepSeek coğrafya batch'inin omurgası "hangi ülkededir" sorusu:

    "Dêrik hangi ülkededir?"              -> Suriye'de
    "Ağrı Dağı (Ararat) hangi ülkededir?" -> Türkiye'de
    "Urmiye Gölü hangi ülkededir?"        -> İran'da
    "Afrin Çayı hangi ülkede akar?"       -> Suriye'de

Doğru cevabı paylaşan gruplar: Türkiye'de 16, Irak'ta 13, Suriye'de 11,
İran'da 11. Yani Kürt yerlerinin tek ve ana kimliği egemen devlet olarak
kuruluyor — §3.4 ve §5'in doğrudan yasakladığı kalıp.

**62 kayıt** `QUARANTINED_POLITICAL_AMBIGUITY`.

Bunun uydurma bir ölçüt olmadığının kanıtı batch'in kendi içinde: aynı model
doğru kalıbı da üretmiş —

    "Colemêrg li kîjan herêma Kurdistanê ye?" -> Bakurê Kurdistanê
    "Serhed li kîjan herêma Kurdistanê ye?"   -> Bakurê Kurdistanê

21 kayıt bu `Kurdistan_region` çerçevesinde. Yeniden yazım için hedef kalıp
hazır; uydurulması gerekmiyor.

### TR/KU çerçeve tutarsızlığı — 10 kayıt

Türkçe metin exonim, Kurmancî metin endonim kullanıyor; §3.6 ikisinin aynı
coğrafi çerçeveyi taşımasını şart koşar:

    TR "Hakkari Kürdistan'ın hangi bölgesindedir?"
    KU "Colemêrg li kîjan herêma Kurdistanê ye?"

Aynı soru iki dilde iki farklı adlandırma rejimi kullanıyor. Kayıtlar aktive
edilmediği için düzeltme UYGULANMADI; manifestte eski metin, tespit ve
gerekçeyle bekliyor.

### Risk sınıfları ve kararlar

    risk A 77   risk B 25   risk C 54

    QUARANTINED_POLITICAL_AMBIGUITY  62
    QUARANTINED_UNVERIFIABLE         94

Doğrulanan 0: bu turda coğrafya için kurumsal kaynak açılmadı; bağlam
bütçesi çapraz denetim ve terminoloji analizine gitti — ikisi de kaynak
doğrulamasından önce yapılması gereken işlerdi, çünkü 62 kaydın kaynağı
doğrulansaydı bile kalıbı yüzünden aktive edilemezdi.

### Ortak havuz

    STAGED_VERIFIED 13 (Sînema 11, Teknolojî 2)   |   eşik 100

### Sıradaki iş

1. 62 `POLITICAL_AMBIGUITY` kaydını bölge çerçevesine yeniden yaz (hedef kalıp
   batch içinde mevcut), sonra risk A kaynak doğrulaması.
2. 10 TR/KU tutarsızlığını endonime çek.
3. Risk C'nin 54 kaydı için tek kurumsal kaynak yeterli — en ucuz kazanç.
4. Sonra Grok Dîrok (46, risk A) ve DeepSeek Çand/Muzîk.

## Tur 8 (2026-08-06) — Cografya kapanışı

### Kendi risk sınıflandırmamı düzelttim

Tur 7'de 54 kaydı Risk-C ("sabit fizikî coğrafya") saymıştım. İçeriğe
bakınca çoğunun sabit kavram değil **gazetteer/yer bilgisi** olduğu görüldü:

    "Elazığ hangi ilin merkezidir?"     "Barzan hangi bölgededir?"
    "Nusaybin hangi sınırdadır?"        "Küçük Zap hangi bölgeden doğar?"

Bunlar tanım değil kayıt sorusu; üstelik büyük kısmı Kürt yerleri hakkında ve
Türkçe exonim kullanıyor. Risk sınıfı C'den B'ye çekildi. "Ova nedir",
"Mezopotamya ne anlama gelir" gibi gerçek kavram soruları C'de kaldı.

Sonuç: Risk-C'nin "yüksek verimli, tek kaynak yeter" avantajı bu batch'te
sanıldığı kadar geniş değil.

### Dördüncü kapı deliği: döngüsel soru

7 kayıtta doğru cevap, soru kökündeki adı ya da terimi aynen tekrar ediyor:

    "Van hangi gölüyle tanınır?"     -> "Van Gölü'yle"
    "Elazığ hangi ilin merkezidir?"  -> "Elazığ ilinin"
    "Coğrafyada «vadi» nedir?"       -> "iki dağ arasındaki vadi"

Oyuncu konuyu bilmeden, yalnız okuyarak kazanır. Mevcut `answer-leak` kuralı
substring tabanlı ("cevap metni soru metninin içinde mi") ve bunların
**hiçbirini** yakalamıyor — araya kelime girdiği için eşleşme kuruluyor.
7 kayıt `REJECTED_LOW_QUALITY`.

Bu kez kurala dönüştürmedim. İlk denemem token örtüşmesine bakıyordu ve 156
kaydın 36'sını işaretledi; incelenince çoğu yapısal sözcüktü ("metre",
"derdora", "nêzîkî", "sînorê"). Gürültülü bir kapı kuralı, kuralsızlıktan
kötüdür — bir önceki turda kendi `(1929)` yanlış pozitifim bunu gösterdi.
İki dilde güvenilir stopword çalışması gerekiyor; bulgular kayıtlı, kural
sonraki tura bırakıldı.

### Cografya nihai kararlar (156)

    QUARANTINED_POLITICAL_AMBIGUITY  62
    QUARANTINED_UNVERIFIABLE         87
    REJECTED_LOW_QUALITY              7

    risk A 77   risk B 67   risk C 12

Doğrulanan 0, ortak havuz 13'te sabit.

### Niçin bu turda da doğrulama yapılmadı

Aşama 1 "54 Risk-C'yi önce doğrula" diyordu. O 54ün 42si incelendiğinde
Risk-C değildi; kalan 12 gerçek kavram sorusu tek bir kaynak turunu haklı
çıkarmıyor. Yanlış etiketle hızlı doğrulama yapmak, kaynak seviyesini
şişirmenin başka bir biçimi olurdu.

### Sıradaki iş

1. Döngüsel-soru kuralını iki dilli stopword listesiyle sağlam kur.
2. 62 politik belirsizlik kaydını bölge çerçevesine yeniden yaz (hedef kalıp
   batch içinde mevcut: "li kîjan herêma Kurdistanê ye").
3. 10 TR/KU exonim tutarsızlığını endonime çek.
4. Risk-B 70 kayıt için gazetteer/harita kurumu kaynağı aç.
5. Sonra DeepSeek Çand/Muzîk, Grok'un kalan teknik adayları, en son Grok Dîrok.

## Tur 9 (2026-08-06) — dış intake kapandı, kaynak-önce üretime geçiş

Dış aday kurtarma çalışması kapatıldı. Kararlar dondu; bu havuzlarda yeni
arama, toplu yeniden yazım veya kurtarma yapılmayacak.

    doğrulanmış ortak havuz            13  (Sînema 11, Teknolojî 2)
    Grok self-labelled distractor     296  REJECTED_LOW_QUALITY
    Grok iç slug / kayıt numarası      19  REJECTED_INVALID_SCHEMA
    dairesel coğrafya soruları          7  REJECTED_LOW_QUALITY
    devlet-merkezli coğrafya           62  QUARANTINED_POLITICAL_AMBIGUITY
    kaynaksız factual kayıtlar        ...  QUARANTINED_UNVERIFIABLE
    10 endonim + 62 bölge bulgusu           manifestte, runtime dışında

### İki yapısal engel

**1. Kol A'nın kategori evi yok.** Kendi içinde çözülebilir mantık/akıl
yürütme içeriği için runtime'da kategori bulunmuyor. Kategoriler sabit:
Ziman, Cografya, Muzîk, Çand, Dîrok, Edebiyat, Siyaset, Paradigma,
Teknolojî, Sînema. `Paradigma` genel mantık değil; jineolojî, demokratik
konfederalizm ve toplumsal ekoloji içeriği taşıyor. Mantık sorusunu oraya
koymak kategoriyi bozardı; yeni kategori açmak ise UI/kategori sistemi
değişikliği demek ve kapsam dışı.

**2. Kurmancî bilim terminolojisi doğrulanmadı.** USGS su döngüsü paketi
hazır ve kaynaklı, ama 2050 soruluk korpusta su döngüsü sözlüğü YOK:
`hilm` yalnız bir kez ve türbin bağlamında geçiyor ("Hilma bin zextê"),
kalan eşleşmeler alt-dizge yanlış pozitifi. Buharlaşma, yoğuşma, sızma ve
yüzey akışı için Kurmancî karşılıkları uydurmak gerekirdi.

Uydurmadım. Bu, reddettiğim DeepSeek atıf pratiğinin dil tarafındaki
karşılığı olurdu: doğrulanmamış bir şeyi doğrulanmış gibi sunmak. Kurmancî
bir uygulamada uydurulmuş bilimsel terim, yanlış kaynaktan daha zararlıdır —
kullanıcı onu doğru sanıp öğrenir.

### Üretilen

`docs/content/source_first_expansion_2026_08/pack_usgs_water_cycle.json` —
USGS Water Science School sayfası doğrudan açıldı (FETCHED_DIRECT, risk C),
beş açık olgu claim olarak çıkarıldı.

Pakette kayıtlı bir ayrım daha var: sayfa süreçleri anlatıyor ama terimleri
resmî olarak TANIMLAMIYOR. Bu yüzden "buharlaşma nedir" tipi tanım soruları
bu paketten üretilemez; yalnız sayfada açıkça yazan ifadeler claim sayıldı.

Soru üretilmedi: claim'ler `READY_FOR_AUTHORING`, engel `authoringBlocker`
alanında kayıtlı.

### Kesin devam noktası

1. Kurmancî bilim terminolojisini doğrula (proje glossary'si, akademik
   Kurmancî sözlük, anadili konuşur editör). Bu tek adım Kol B'nin tamamını
   açar.
2. Kol A için karar gerekiyor: mantık içeriği ya bir kategoriye gerçekten
   uyacak biçimde çerçevelenmeli (ör. Ziman içinde dil-mantığı) ya da
   kategori sistemi kararı kullanıcıya bırakılmalı.
3. Kol C (Kürdistan coğrafyası) Risk-A: iki bağımsız akademik kaynak
   bulunmadan tek soru üretilmeyecek.
4. Ortak havuz 13; eşik 100. Aktivasyon yok.

## Tur 10 (2026-08-07) — Çand/Muzîk, dengeli kaynak-önce üretim

Branch: `content/source-first-culture-music-2026-08-07`

Tur 9 sırayı "Çand/Muzîk" olarak bırakmıştı. Bu tur o sırayı, dış aday
kurtarmayla değil, doğrudan açılmış kurumsal sayfalardan üretimle kapattı.

    Çand   12 soru   Muzîk  12 soru   hepsi FETCHED_DIRECT
    ortak havuz  25 -> 49   (dış 13, source-first 36)   eşik 100   aktivasyon: HAYIR

"Dengeli" dört ayrı ölçüde tutuldu ve dördü de ölçülüyor: kategori başına
eşit sayı, cevap pozisyonu (Çand 3/3/3/3, Muzîk 2/4/4/2), zorluk dağılımı,
ve bölgesel/dünya içerik karışımı (Muzîk'te 7 bölgesel + 5 bölge dışı).

### Erişilebilen tek kurumsal alan adı

Denenen kaynakların çoğu bu ortamda kapalı çıktı ve hiçbiri arama özetiyle
ikame edilmedi:

    ich.unesco.org            açık    9 eleman sayfası okundu
    folkways.si.edu           403     üç Kürt müziği albümü
    metmuseum.org             429     tanbur / Ehl-i Hak sergisi
    iranicaonline.org         403     "Kurdish music" maddesi
    whc.unesco.org            403     Hewlêr Kalesi künyesi
    loc.gov                   403
    ich.unesco.org/.../00282  301     sonsuz yönlendirme (eski Nowruz kaydı)

Tam liste ve gerekçeler `source_catalog.json` dosyalarının `failedSources`
alanında.

### Kürt içeriği: sıfır — ve niçin

**Bu turda Kürt kültürüne/müziğine özgü tek soru üretilmedi.** Kürt içeriğini
adıyla anan bütün kurumsal kaynaklar yukarıdaki listede: hepsi kapalı. Risk-A
iki bağımsız kaynak ister; sıfır açıldı. Bellekten yazmak, Tur 1'de
reddedilen DeepSeek atıf pratiğinin aynısı olurdu.

Newroz da bu yüzden üretilmedi. UNESCO'nun çok uluslu Nowruz sayfası (02097)
açıldı, ama okunabilen betimleyici cümleler ülke ülke ayrılmış ve dönen bölüm
Moğolistan Kazaklarının Nauryz'ını anlatıyor: *"On 22 March, the Kazakh people
of Mongolia rise early to greet the sunrise of the new year."* O cümleyi Kürt
Newrozuna genellemek kaynağı esnetmek olurdu.

Bu, bu turun en önemli eksiğidir ve kapatılması gereken asıl iştir.

### Beşinci kapı deliği: kanıtsız Kurmancî sözcük

Tur 9 "uydurulmuş bilimsel terim yazma" kararını doğru vermişti ama karar
ÖLÇÜLEBİLİR değildi; bir sözcüğün yerleşik olduğuna göz kararı karar
veriliyordu. `tool/content_authoring/check_kurmanji_attestation.py` kararı
sayıya çevirir: oyuncuya görünen her Kurmancî sözcük 2050 soruluk korpusta
en az bir kez geçmeli.

İlk geçişte 24 sorunun görünür alanlarında **60 kanıtsız sözcük** çıktı.
Hepsi tek tek incelendi ve üç yola ayrıldı:

* özel ad (21) — `daff`, `tshalghi`, `sevdalinka`, `al-naoor`: kaynağın
  yazdığı gibi bırakıldı, `allow_proper_nouns.json` içinde kayıtlı;
* kanıtlı bir biçimin çekimi (19) — `tenûr` <- `tenûrê` x26, `çerx` <-
  `çerxên` x3: her biri lemmasıyla `allow_inflections.json` içinde, ve bir
  test her lemmanın korpusta gerçekten bulunduğunu doğruluyor;
* kanıtsız (20) — `lût`, `firneke`, `qazan`, `nizm`, `erka`, `cenaze`,
  `nimêjan`, `firaqên`, `stûnî`, `eksê`, `televîzyonê`, `endamên`,
  `lêdervanên`, `pireke`, `rêbernameyên`, `xuyakirin`: **soru yeniden
  yazıldı**, sözcük uydurulmadı.

`pireke` ayrı bir ders: "köprü" diye yazılmıştı, ama korpusta `pir` ezici
çoğunlukla *"çok"* demek (*"Hewa îro pir xweş e"*). Kanıt sayısına bakmak
yetmiyor; kanıtın hangi anlamda olduğuna da bakmak gerekiyor.

Kına (hena) kaydı bu yüzden düştü: Kurmancî'de kına «hene»dir ve korpusta
«hene» ezici çoğunlukla *"vardır"* fiilidir (*"Di destê mirov de pênc tilî
hene"*). İkinci bir yazım icat etmek yerine kayıt bekletildi.

### Ölçümle çıkan üç kusur

`tool/content_authoring/measure_source_first_batch.py` ölçümü üretir, insan
yalnız yorumlar — Sînema turunda uzunluk oranı commit gövdesine elle ve
yanlış yazılmıştı.

    cevap pozisyonu   Çand 6/12 üçüncü şıkta, dördüncü şık HİÇ doğru değil
                      (%50 / %0). 3/3/3/3'e çekildi.
    uzunluk sinyali   3 soruda doğru şık tek başına en uzun (%25).
                      Çeldiriciler aynı ayrıntı düzeyine çekildi; şimdi %0.
    kalıp yinelemesi  5 yıl sorusu neredeyse aynı kökü paylaşıyordu; ölçüm
                      bunları turdaş-yineleme olarak gösterdi, kalıp kırıldı.

Dördüncüsü çeldirici uzunluğundaydı ve özel ad olduğu için soruyu
değiştirmek gerekti: `daff` dört harf, diğer üç çalgı adı altı. Aynı kaynak
cümlesinin başka bir olgusu soruldu.

### `build_verified_pool.py`: iki düzeltme

1. Source-first yolu tek kategoriye (`cinema/cinema_questions.json`)
   sabitlenmişti; Çand/Muzîk eklendiğinde araç onları **görmezdi** ve havuz
   sessizce eksik kalırdı. Artık dizin taranıyor.
2. Intake dizini bulunamazsa dış kayıtlar sessizce sıfırlanıyor ve araç yine
   de başarıyla çıkıyordu. Artık havuzda dış kayıt varken intake yoksa hata
   veriyor; düşüş isteniyorsa `--allow-missing-intake` açıkça yazılmalı.

Havuz `--check` ile idempotent doğrulandı: 49 -> 49.

### Aktive edilen: 0

Eşik 100, havuz 49. Aktivasyon yok, banka değişmedi, question-quality
baseline hash'i değişmedi. Bekçi (`test/source_first_culture_music_test.dart`)
staged kayıtların runtime bankasına sızmadığını ayrıca doğruluyor.

### Sıradaki iş

1. **Kürt içeriği için kaynak erişimi.** Bu tek engel Çand/Muzîk'in asıl
   değerini kilitliyor. Kapalı olanların açık alternatifleri aranmalı:
   üniversite Kürt çalışmaları merkezleri, ulusal kütüphane katalogları,
   Kürdistan Bölgesi kurumlarının kendi arşivleri.
2. Kına kaydı için «hene» belirsizliğini çözecek terminoloji kararı.
3. Havuzu 100'e taşımak: kalan UNESCO Çand/Muzîk elemanları aynı hatla
   üretilebilir; sınırlayıcı etken artık doğrulama değil, kaynak çeşitliliği.
