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
