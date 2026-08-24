# ZanKurd — otonom çalışma listesi

Bu dosya **durumdur, rapor değil.** Her bulut koşusu buradan iş alır,
yapar, sonucu buraya işler. Yeni rapor dosyası üretme.

Son taban ölçümü: **2026-08-23**, dal `fix/quiz-layout-and-release-hygiene`.

## Taban (o gün ölçüldü)

| Ölçüt | Değer |
|---|---|
| Dart dosyası / satır | 191 / 79.149 |
| Test dosyası / test | 366 / 2373 |
| `dart analyze` | temiz |
| Soru bankası | 2920 |
| Çeviri anahtarı | 909 (ku ve tr tam, Hawar temiz) |
| Varlıklar | 9,6 MB (5,1 MB görsel) |

Sağlıklı bulunan ve **yeniden denetlenmesine gerek olmayan** alanlar:
gömülü sır yok (anon key `String.fromEnvironment`), `prefer_const`
uyarısı sıfır, dispose edilmeyen controller yok, 235 `mounted` koruması,
çeviri iki dilde eksiksiz.

---

## İŞ SIRASI

Sıradaki açık maddeyi al. Bitirdiğinde satırı `[x]` yap, altına tek
cümlelik sonuç ve commit kısa kimliğini yaz.

### A1 — [x] ~~Supabase katmanında 60 sessiz hata yutma~~ YANLIŞ BULGU
**Böyle bir kusur yok.** İlk ölçüm dosyadaki `catch` sayısını (61)
`ErrorReporter` kelimesinin geçiş sayısıyla (1) karşılaştırıp aradaki
farkı "sessiz" saymıştı. Gerçekte dosya `_recordError()` sarmalını
kullanıyor ve o sarmal 1981. satırda `ErrorReporter.record`'a gidiyor.

Doğru ölçüm (2026-08-23): projede **294 catch bloğu, 24'ü raporlamıyor**
— ve bakınca çoğu BİLEREK sessiz ve gerekçesi yorumda yazılı: Firebase
yapılandırması olmayan platform, asset bulunamazsa boş listeye düşme,
ya da hatayı `cleanupError`/`lastError` değişkeninde toplayıp sonra
raporlama. Hata yönetimi sağlıklı.

Ders: kelime sayarak kusur ölçülmez. Bu madde neredeyse bir haftalık
otomasyonu var olmayan bir işin peşine düşürüyordu.

### A2 — [x] Ölü kod: `ErrorDialog` silindi
66 satır, hiçbir yerden çağrılmıyordu. Tek "referansı"
`tool/apply_rest_l10n.py` içindeydi; o betik kendi belgesinde "tek
seferlik göç aracı" diyor ve o harita geçmişte ne değiştirdiğinin
kaydı, canlı bağımlılık değil.

Bekçisi `test/dead_widget_guard_test.dart`: `lib/src/widgets/` altında
ne üründe ne testte adı geçen dosya kalamaz. Bekçi SINIF adını arar,
dosya adını değil — dosya adıyla arayan ilk ölçüm dört dosyayı ölü
sanmıştı, üçü yanlıştı.

### A2b — [x] Yalnız kendi testi olan iki widget silindi
`ColorfulActionCard` ve `BadgeCollectionSection` ürün kodunda hiç
kullanılmıyordu, yalnız kendi testlerinde yaşıyorlardı.

**Karar (ürün sahibi, 2026-08-24): silinsin.** Uygulandı. İki widget
dosyası ve onlara ayrılmış iki test dosyası kaldırıldı; üç paylaşılan
testten de ilgili bloklar çıkarıldı.

`kulturel_modern_home_test` içindeki `expect(find.byType(
ColorfulActionCard), findsNothing)` iddiası da kaldırıldı — sınıfın
kendisi yoksa o iddia zaten derlenmez, ve silinmiş olması ekranda
bulunmamaktan daha güçlü bir garanti. Tekrarını `dead_widget_guard_test`
koruyor.

### A3 — [x] ~~Tooltip'siz 4 IconButton~~ YANLIŞ BULGU
**Böyle bir kusur yok.** İlk ölçüm `IconButton(` geçen satır sayısıyla
`tooltip:` geçen satır sayısını karşılaştırmıştı; ikisi farklı satırlarda
olduğu için fark çıkmıştı. Blok gövdesini ayrıştıran doğru ölçüm:
`tooltip` ya da `semanticLabel` taşımayan `IconButton` sayısı **sıfır**.

### A4 — [x] Bağımlılık güncellemesi yapıldı
Güncellenebilir: `firebase_core` 4.12.1→4.13.0, `firebase_analytics`
12.4.5→12.4.6, `firebase_crashlytics` 5.2.6→5.2.7, `supabase_flutter`
2.16.0→2.17.2, `purchases_flutter` 10.6.0→10.9.1,
`flutter_local_notifications` 22.2.0→22.3.0.
**Teker teker** yükselt, her birinden sonra tam test koş. Biri kırarsa
geri al ve maddeye niçin kırdığını yaz. `shimmer` 3→4 ana sürüm
atlaması: kırıcı değişiklik olabilir, ayrı ele al.

**Sonuç (2026-08-23):** `flutter pub upgrade` ile mevcut kısıtlar içinde
24 paket yükseltildi — Supabase yığını (supabase 2.14→2.16.1, gotrue
2.26→2.27.2, postgrest 2.8→2.9.1, realtime 2.11→2.13, storage 2.6→2.8),
Firebase (core 4.12.1→4.13.0, analytics, crashlytics), RevenueCat
(10.6→10.9.1), bildirimler (22.2→22.3). İki paket bağımlılıktan düştü
(`jwt_decode`, `retry`).

Yalnız test değil GERÇEK DERLEME de doğrulandı: bunlar native eklenti
ve testler o tarafı hiç denemiyor. `flutter build ios --simulator`
başarılı. `shimmer` 3→4 ve `code_assets` 1→2 kısıt dışı kaldı, ayrı
madde olarak duruyor (A4b).

### A4b — [x] `shimmer` 3→4 ve `code_assets` 1→2 ana sürüm atlaması
Kısıt dışı kaldılar; ana sürüm atlaması kırıcı değişiklik taşıyabilir.
Yerel oturumda, teker teker, gerçek derlemeyle denenmeli.

**Kapandı (2026-08-24, `5578cb6`).** `shimmer` 4.0.0'a çıkıldı ve gerçek iOS
derlemesiyle doğrulandı; `code_assets` geçişli bağımlılık çıktı, doğrudan
yükseltilemez ve gerek yok. Akşam denetimi `pubspec.yaml`da `^4.0.0` olduğunu
doğruladı.

### A5 — [~] İçerik: çapraz kontrolü olmayan 1782 soru — KİLİT AÇILDI
**DeepSeek artık kullanılamıyor** — anahtar duruyor ama kredi bitti
(HTTP 402 Payment Required, 2026-08-24'te doğrulandı). Yani madde
DeepSeek'le ne bulutta ne yerelde yapılabilir.

**Çözüm: iş sağlayıcıya değil KOŞUYA taşındı.** Bulut koşusunun kendisi
zaten bir dil modeli oturumu; ona soruyu çıplak verip cevabını almak
DeepSeek'e sormakla aynı sinyali üretir. İki yeni araç:

* `tool/content_authoring/kor_parti_uret.py` — hükmü olmayan soruları
  ~40k karakterlik partilere böler ve `correctAnswer` alanını partiye
  HİÇ yazmaz. 1782 soru, 9 parti.
* `tool/content_authoring/kor_cevap_karsilastir.py` — dönen cevapları
  anahtarla karşılaştırır, `capraz_kontrol.json`a işler, çelişkileri
  `celiskiler.json`a çıkarır.

İkisi ayrı olduğu için cevabı veren taraf ile karşılaştıran taraf
birbirini görmüyor — 2026-08-19'da bir çapraz kontrol dosyası tam bu
ayrım olmadığı için bozulmuş, doğru cevabı kaydın kendisinden kopyalayan
bir satır 55 hükmü çöpe atmıştı.

Karşılaştırma aracı dört yolda da sınandı: doğru cevap, çelişki, "emin
değil", ve şıklardan hiçbirine oturmayan uydurma metin (reddediliyor —
yaklaşık eşleşmeyi kabul etmek hükmü uydurmak olurdu).

Kalan iş: `docs/content_batches/kor_partiler/` altındaki 9 partiyi
sırayla cevaplamak. Ayrı bir bulut rutini (`ZanKurd — kör çapraz
kontrol`) bunu yürütüyor.

### A6 — [x] İçerik: makine taramasının 22 sızma bulgusu
`python3 tool/content_authoring/sik_kalite_taramasi.py` çalıştır
(saf Python, Flutter gerektirmez). 16 biçim + 6 uzunluk sızması.
Düzeltirken `docs/KALAN_ISLER_GOREVI.md` bölüm 2'deki bekçi tuzaklarını
oku — orada üç testin birbirini nasıl kırdığı yazılı.

**Sonuç:** 22 bulgunun 22'si kapandı, tarama 0 bulgu veriyor; düzeltme
çeldirici tarafında yapıldı (tek istisna `edit_muzik_0017`) ve betiğe
`FINDING_RATCHET = 0` mandalı eklendi — sızma geri gelirse çıkış kodu 1.

### A7 — [x] Park edilmiş 77 soru bankaya alındı
**Alındı (2026-08-24).** Bekleme sebebi DeepSeek kredisiydi; çapraz
kontrol koşuya taşınınca (A5) engel kalktı. Kayıtlar kör kontrol
kuyruğuna girdi ve 1782 → 1859 oldu.

Yeni banka: `assets/data/expansion_2026_08_19_questions.json`.
Cografya 41, Çand 29, Edebiyat 7; hepsi zorluk 4-5 — tam da o üç
kategorinin zorluk açığının olduğu yer (A4 tablosu).

Alınmadan önce üç Hawar ihlali düzeltildi: `Grönland` → `Gronland`,
`Föhn` → `Foehn`, ve Kurmancî gövdeye sızmış bir Türkçe parantez
(`(toz şeytanı)`) kaldırıldı — Türkçe karşılık zaten `promptTr`de.
Türkçe alanlardaki "Grönland" DOKUNULMADI; orada doğru yazım odur.

**A9 dersi üç yerde birden uygulandı.** Yeni banka aynı commit'te
şuraların hepsine kaydedildi: yükleyici manifesti, kalite bekçilerinin
`banks` haritası, VE `tool/question_quality/source_manifest.json`.
Sonuncusu unutulsaydı denetim onu `unknown` sayıp hiç bakmayacaktı —
deepseek'in altı gün açıkta kalmasının sebebi tam buydu, yalnız üçüncü
yer o zaman fark edilmemişti.

**Kabul edilen borç: 77 `missing_source_metadata` uyarısı.** Kayıtların
hiçbirinde kaynak başlığı ya da adresi yok. Uydurma kaynak YAZILMADI:
olmayan bir kaynağı iddia etmek, hiç kaynak vermemekten kötüdür.
Engelleyici ve kritik sayısı 0'da kaldı; borç `baseline.json`da
1846 → 1923 olarak kayıtlı ve A17 olarak izleniyor.

### A17 — [ ] 77 yeni sorunun kaynak künyesi eksik
`expansion_2026_08_19` bankasındaki 77 kaydın hiçbirinde
`metadata.sourceReference` ya da `sourceTitle` yok; kalite denetimi
her biri için `missing_source_metadata` uyarısı veriyor (uyarı düzeyi,
engelleyici değil).

Bu bir içerik borcudur ve **uydurarak kapatılamaz**. Kayıtları yazan
kaynak bilinince künye eklenir. O zamana kadar borç görünür kalsın —
sessizce kapatmak, kaynaksız içeriği kaynaklı göstermek olur.

### A8 — [~] Dev dosyaların bölünmesi — ilk adım atıldı
`quiz_screen.dart` 3784 satır, `supabase_zankurd_repository.dart` 3023,
`quiz_result_screen.dart` 2655. Bunlar bakım riski ama çalışıyorlar.
**Yalnız Flutter test koşulabiliyorsa** dokun; koşulamıyorsa dokunma.
Küçük adım: tek bir bağımsız bölümü `part` dosyasına taşı, test koş,
commit et. Büyük refactor YAPMA.

**İlk adım atıldı (2026-08-24).** `quiz/quiz_layout_rules.dart` ayrıldı:
iki sabit ve iki SAF işlev (`_useCompactLandscapeLayout`,
`botOpponentDisplayName`). Hiçbiri `_QuizScreenState`e dokunmuyor, hepsi
girdiden çıktı üretiyor — taşınması davranışı değiştiremez. Taşınan 56
satırın 56'sı birebir aynı; tek satır kod değişmedi, yalnız yeri değişti.
3784 → 3723.

Kalan bölünme adımları aynı ölçütle seçilmeli: **önce duruma dokunmayan
bloklar.** Durum okuyan bir bölümü taşımak refactor olur ve proje kuralı
onu yasaklıyor.

### A9 — [x] DeepSeek bankası kalite bekçilerine bağlı değil
`test/all_banks_quality_test.dart` başlığında şu yazılı: "yeni bir kaynak
eklendiğinde buraya da eklenir; listeye eklemeyi unutmak, kalite bekçisini
o kaynak için sessizce kapatmaktır." `deepseek_2026_08_18_questions.json`
(1298 soru) `banks` haritasında YOK — yalnız yükleyici sıra testinde
geçiyor. Yani o bankada sorulan terim şık olabilir, doğru cevap gövdede
yazabilir, şık yinelenebilir; hiçbiri düşmez. A6 koşusunda bulundu.
Bankayı `banks` haritasına ekle ve düşen kuralları tek tek onar.
**Flutter gerektirir** (test koşulmadan eklenmemeli).

**İçerik tarafı ölçüldü (2026-08-23).** Yapısal beş kural Python'da
Dart'a birebir yeniden yazılıp bankaya uygulandı (doğruluk sınavı:
bekçili yedi bankada 0 bulgu). Deepseek bankasında sonuç: doğru cevap
gövdede 0, cevapsız soru 0, yinelenen şık 0, **sorulan terim şık olarak
duruyor: 1** — `ds_sinema_0193`, bu koşuda kapatıldı. Yani A9'un içerik
borcu bitti; kalan iş Dart tarafındadır: haritaya ekleme + Python'da
ölçülemeyen dil politikası kuralları (`offLanguageDistractors`,
`answerIsGivenAwayByLanguage`, açıklama dili). Bankayı haritaya
eklemeden önce **A12 yapılmalı**, yoksa yıl/tür ölçütü 12 yanlış alarm
verir.

**Kapandı (2026-08-24, `5578cb6`).** Banka `banks` haritasına eklendi ve iki
şey buldu: `ds_ziman_1289` gerekçeli muafiyet (dilbilgisi sorusu yanlış biçimi
BİLEREK çeldiricide gösteriyor), ve borç tavanı 8→14 (altı kaydın altısı da tek
tek okunup yanlış alarm olduğu doğrulandı). Akşam denetimi haritadaki girdiyi
(`all_banks_quality_test.dart:72`) ve muafiyeti (satır 535) doğruladı.

### A10 — [x] ~~`ds_sinema_0130` tür uyumsuzluğu~~ YANLIŞ BULGU
**İçerikte kusur yok; yanılan ölçüttür.** Maddenin önerdiği düzeltme
(çeldiricileri dört haneli sayı taşıyan filmlerle değiştirmek) gerçek
içeriği bozardı — A1 ve A3'ün dersi.

Ölçüldü (2026-08-23): kural Python'da Dart'a birebir yeniden yazıldı
(kritik ayrıntı: Dart RegExp'te `\w`/`\b` yalnız ASCII'dir, Python'da
Unicode — bu yüzden `sala 1950î` iki dilde farklı sonuç verir). Doğruluk
sınavı: bekçili yedi bankanın hepsinde 0 bulgu, yani CI'nin yeşiliyle
birebir. Deepseek bankasında kural 12 soruya çarpıyor; **on ikisi de
okundu, hiçbiri kuralın yazıldığı kusur değil.** Üç sızma biçimi:

* sayı+birim şıkları — `0/45/90/180 derece` (yalnız 180 "yıl" sayılıyor)
* çıplak sayı şıkları — `23/57/30/100` senfoni, `64/98/79/117` yılı
* içinde sayı geçen özel ad ve uzun düzyazı — `The 400 Blows`,
  `…sedsala 19an de…`

Aynı ölçüt editoryal bankada 7, expansion'da 3, sourceFirst'te 2 yanlış
alarm daha veriyor; onlar da aynı üç biçimden. Offline'ın temiz olması
kuralın doğruluğunu göstermez — offline 2026-07-24'te tam bu ölçüte
göre elle onarılmıştı.

Kalan iş A12'ye taşındı.

### A12 — [x] Yıl/tür ölçütü keskinleştirilmeli (A9'un önkoşulu)
`question_distractor_quality_test` içindeki `_isYearLike`, "içinde 3-4
haneli sayı geçen" her şeyi tarih sayıyor. Kuralın niyeti ise başka:
**tarih olan bir şık, tarih olmayan şıkların arasında durmasın** (özgün
kusur: bir YER sorusunun şıklarında "16. yüzyıl" ve "20. yüzyıl").

Öneri: ölçüt "içinde sayı var mı" değil "şıkkın KENDİSİ bir tarih
ifadesi mi" olsun — çıplak sayılar tek sınıf sayılsın (hane sayısına
bakılmadan), sayı+birim ve uzun düzyazı tarih sayılmasın, `berî zayînê`
gibi belirteçler listeye eklensin, Kurmancî ek almış sayılar
(`1970yî`, `1962an`, `5em`, `61ê`) ASCII `\b` yüzünden kaçmasın.

Ölçütü GEVŞETME tuzağı: "yalnız doğru şık sayı taşıyorsa işaretle"
biçimindeki teklik koşulu (bkz. `sik_kalite_taramasi.py`'nin
`bicim_sizmasi` kuralı) özgün Urartû kusurunu YAKALAMAZ — orada iki
çeldirici yüzyıldı, üçü değil. Keskinleştirme sınıflandırmada olmalı,
teklikte değil.

Doğrulama: keskinleştirilmiş ölçüt offline'da 0 vermeli (yoksa
2026-07-24'ün 106 onarımı boşa gider) ve yukarıdaki 24 yanlış alarmın
hepsini susturmalı. **Flutter gerektirir.**

**Python tarafı çözüldü ve doğrulandı (2026-08-24).** Ölçüt Python'da,
Dart'a birebir çevrilebilir biçimde (token-bazlı, `\b`/`\d`/`\w`
KULLANMADAN — A10 dersinden: Dart RegExp bunları ASCII sayar ve
`Maddeya 140î` ile `5em`'i farklı sınıflar; token yaklaşımı tuzağı
tümden atlar) yeniden yazıldı. Algoritma —
`is_date_expression(şık)`, şıkkın KENDİSİ tarih ifadesi mi:

1. Şıkı boşluktan token'lara böl, her token'ı sınıfla:
   * **dateword** — `sal/sala/salan/salên/salî`, `sedsal/sedsala/
     sedsalan/sedsalên`, `yüzyıl/yy`, `berî/piştî/zayîn/zayînê`, ve
     dönem kısaltmaları `m.ö/b.z./p.z./y.y.`.
   * **number_suffixed** — Kurmancî tarih/sıra eki (`an yî em yê î ê a
     y`) almış sayı: `1930î`, `1962an`, `19-20em`, `5em`, `61ê`. Eki
     soyunca saf sayı gövdesi kalıyorsa (`^\d+([\d.\-–/]*\d)?$`).
   * **number_bare** — yalın sayı, eksiz: `57`, `100`, `443`, `1918`.
   * **connector** — nötr edat/bağlaç (`û de di ya li ji the of...`),
     yok sayılır.
   * **content** — başka her şey (film adı, `Maddeya`, `derece`, `roj`,
     betimleme sözcükleri).
2. İçerikli tek bir token varsa → **tarih DEĞİL** (film adı, madde no,
   uzun düzyazı böyle elenir).
3. İçerik yoksa: bir dateword ya da number_suffixed varsa → **tarih**;
   yalnız number_bare/connector ise → **tarih DEĞİL** (A12: çıplak sayı
   tek sınıf, hane sayısına bakılmadan — `57`↔`100` uyumlu olur).

Sonuç (`is_date_expression` tür kuralına takılıp, mevcut Dart testinin
uyguladığı 4+ şıklı çok seçmeli sorularda ölçüldü):
* **24 yanlış alarmın 24'ü sustu** (editorial 7, expansion 3,
  sourceFirst 2, deepseek 12 — hepsi). `Maddeya 140î↔5em`, `180
  derece↔0 derece`, `The 400 Blows↔Breathless`, `Salên 1970yî`,
  `Berî zayînê`, `57↔100` dahil.
* **editorial'daki `edit_edebiyat_0018` de tür-tutarlı bulundu** — dört
  şık da zaman (`Di 1930î de`, `Berî 1900î` `number_suffixed` sayesinde
  tarih sayıldı; eski kural `1930î`yi ASCII `\b` yüzünden kaçırıyordu).
* **Özgün Urartû kusuru hâlâ yakalanıyor** (sentetik kayıt: doğru
  `Wanê`↔`sedsala 16an` → offender). Keskinleştirme sınıflandırmada
  yapıldı, teklik/sayım koşuluyla DEĞİL — A12'nin gevşetme uyarısına
  uyuldu.

**Ama offline 0 sağlanmadı: 2 soru KALDI** (`offline_7394`,
`offline_7598`). Bunlar sınıflandırma hatası değil — eski kuralın
körlüğü yüzünden gizli kalmış GERÇEK içerik durumları (bkz. A15). Eski
kural doğru cevaptaki `sala 1921`/`sala 1898`'i `\b\d{4}\b` ile tarih
sayıp `sedsala 16em` ile uyumlu görüyordu; keskin kural doğru cevabı
(içerikli uzun betimleme) tarih-değil, `sedsala 16em`'i tarih sayınca
uyumsuzluk açığa çıktı. **A12'yi Dart'a almadan önce A15 çözülmelidir**,
yoksa keskin ölçüt Dart testinde offline'ı kırar. Kalan Dart işi:
`_isYearLike`'ı bu `is_date_expression`'la değiştir, tür kuralına
`everyBankQuestion`'ı da bağla (şu an yalnız offline), bekçi belgesine
niçini yaz, `flutter test` ile doğrula.

**Kapandı (2026-08-24, `5578cb6`).** Kalan Dart işinin hepsi yapıldı:
`_isDateExpression` token-bazlı olarak yazıldı
(`question_distractor_quality_test.dart:34`) ve kural artık BÜTÜN bankalara
uygulanıyor (`loadEveryBankFromJson`), bekçiye körlük kapısı da kondu
(`everyBank.length > 2000` — banka yüklenemezse ihlal 0 çıkmasın diye).

Akşam denetimi Dart ölçütünü satır satır Python'a taşıyıp bağımsız koştu:
11 bankada 2997 sorunun **0'ı ihlal**. Bekçi boş da değil — ölçüt 60 şıkkı
tarih, 10961'ini tarih-dışı sayıyor, özgün Urartû kusurunu hâlâ yakalıyor
(`Wanê` ↔ `sedsala 16an` uyumsuz), ve `Maddeya 140î` / `The 400 Blows` /
`180 derece` yanlış alarmlarını susturuyor.

### A11 — [x] `question_quality/baseline.json` tam yenilenmeli
A6 koşusunda baseline'ın YALNIZ `sourceFingerprints` alanı elle
güncellendi (sha256, algoritma doğrulandı: dokunulmamış 7 dosyanın
hash'i baseline'la birebir tuttu). `issueFingerprints` listesi 1846'da
bırakıldı, çünkü onu üretmek `dart run tool/question_quality/
question_quality_audit.dart baseline --accept-current-debt` ister ve o
koşuda Dart yoktu.

Sonucu: A6'nın GİDERMİŞ olabileceği uyarılar listede duruyor. Kapıyı
gevşetmez (kapı yalnız yeni fingerprint'e ve sayı artışına bakar), ama
temizlenmiş bir uyarı geri dönerse yakalanmaz. Flutter'lı ilk oturumda
tam yenileme yapılmalı; `createdDate` de o zaman güncellenir (şimdilik
bilerek 2026-08-20'de bırakıldı, çünkü baseline tam yenilenmedi).

### A13 — [x] Şık taraması kendi kapsamını denetlemiyordu
`sik_kalite_taramasi.py` banka listesini manifestodan okur (A9'un elle
sayılmış harita kusurunu tekrarlamamak için). Ama iki sessiz yol
bırakmıştı ve ikisi de ekrana aynı cümleyi yazıyordu — «0 bulgu»:

* `if not path.exists(): continue` — manifestoda anılan bir banka
  yeniden adlandırılsa dosya sessizce ATLANIYORDU;
* desen yalnız tek tırnaklı yol yakalıyor — manifesto çift tırnağa
  geçse `assets` boş kalır, döngü hiç dönmez, tarama 0 soru tarar.

Yani kapsam daraldığı gün bekçi en yüksek sesle "temiz" derdi. İkisi de
artık `main()` başında gürültüyle düşüyor (`KAPSAM EKSİK` / `KAPSAM
YOK`, çıkış kodu 1). Bekçinin bekçisi düşmanca sınandı: banka taşındı →
1, manifesto çift tırnağa çevrildi → 1, ikisi geri alındı → 0.

Ölçüldü (2026-08-23 akşam): kapsam ŞU AN tam — manifestodan 10 yol
çıkıyor, 10'u da diskte, toplam 2920 soru taranıyor (bankasız tek
`assets/data/*.json` dosyası `image_credits.json`, o banka değil).

### A14 — [x] Bot yarışı mantığı hiçbir testin iddiasında yok
Akşam koşusunun test kapsamı taraması (2026-08-23): `lib/src/` altındaki
188 dosyanın 14'ünün adı ne üründe test edilen bir dosyada ne de testte
geçiyor. 14'ün 10'u dolaylı olarak *render edilebilir* (testi olan bir
ekranın içinde duruyorlar), 4'ü koşullu import stub'ı. Geriye kalan
gerçek boşluk bot mantığıdır: `BotOpponent`, `BotRace`, `BotNames`
testlerde **sıfır** kez geçiyor.

Bu boşluk özellikle sırıtıyor, çünkü `bot_opponent.dart:12` yapıcısı
test için `Random?` iğnesi taşıyor — seam bilerek açılmış, kimse
kullanmamış. Tohumlu `Random` ile bunların hepsi kesin olarak
iddia edilebilir:

* `bot_opponent.dart:27` — olasılık `skill - (difficulty-1)*0.07`,
  `[0.15, 0.95]` aralığına kırpılır. skill 0.85 + zorluk 1 → 0.85;
  zorluk 5 → 0.57; zorluk 12 → alt kırpma 0.15'e oturur.
* `bot_opponent.dart:30-32` — seri ÖNCE artar, sonra puan yazılır:
  ilk doğru 110 getirir, 100 değil. Bonus `clamp(0, 50)` ile 5.
  doğrudan sonra sabitlenir (her doğru 150).
* `bot_opponent.dart:34` — yanlış cevap seriyi sıfırlar ama
  `correctCount`'a dokunmaz.
* `bot_opponent.dart:48-53` — `BotRace.standard` havuzu karıp ilk üçü
  alır: **üç adın farklı çıkması havuzda yineleme olmamasına bağlı** ve
  havuz üçten kısalırsa `RangeError`. Bugün havuz 19 ad, yinelemesiz.
* `bot_names.dart:10` — adlar oyuncuya görünen Kurmancî metindir;
  kural 7 (yalnız Hawar) için hiçbir bekçi yok. Bugün 19 adın 19'u
  temiz — yani test yazıldığında YEŞİL başlar, kırmızı değil.

Son iki madde birer kusur DEĞİL; bugün ölçüldü ve tutuyorlar. Eksik
olan, tuttuklarını yarın da söyleyecek bekçidir. **Flutter gerektirir**
(test koşulmadan eklenmemeli).

**Kapandı (2026-08-24, `5578cb6`).** `test/bot_opponent_test.dart` yazıldı;
`Random?` iğnesi on ay sonra ilk kez kullanıldı. Akşam denetimi sekiz
iddianın aritmetiğini kaynak kodla karşılaştırdı ve birebir tuttuğunu gördü:
ilk doğru 110 (seri ÖNCE artıyor — `bot_opponent.dart:30-32`), beş doğru 650,
altıncı yine 150 (`clamp(0, 50)` tavanı), yanlış seriyi sıfırlayıp
`correctCount`a dokunmuyor, olasılık kırpması `[0.15, 0.95]` iki sınırdan da
sınanmış. Havuz 19 ad, yinelemesiz ve Hawar temiz — ikisi de doğrulandı.

### A15 — [x] A12'nin açığa çıkardığı 2 tür-karışık soru (A12'nin önkoşulu)
A12'nin keskinleştirilmiş tür ölçütü Python'da doğrulanınca offline'da
iki soru offender kaldı — eski `\b\d{3,4}\b` kuralı bunları görmüyordu,
çünkü doğru cevaptaki `sala 1921`/`sala 1898`'i de "tarih" sayıp
`sedsala 16em` çeldiricisiyle uyumlu görüyordu. İkisi de bir HAREKET /
YAYIN tanımı soruyor ama şıklarının arasında salt bir yüzyıl duruyor:

* `offline_7394` — «Serhildana Koçgirî»nin tanımı. Doğru = uzun
  betimleme; çeldiricilerin 2/3'ü salt yüzyıl (`sedsala 16em`,
  `sedsala 19em`). Doğru cevap tür-**azınlığında** → özgün Urartû
  kusurunun aynısı, ciddi.
* `offline_7598` — «Rojnameya Kurdistan» ne demek. Doğru + 2 çeldirici
  uzun betimleme, yalnız `sedsala 16em` tür-yabancı. Doğru
  **çoğunlukta** → çeldirici zayıf ama doğruyu ele vermiyor, yumuşak.

Bu bir sınıflandırma sorunu DEĞİL, içerik sorunudur; A12'yi Dart'a
almadan önce çözülmeli, yoksa keskin ölçüt offline testini kırar. İki
yol var, karar Flutter'lı/insan oturumunundur:

1. **İçeriği onar** — `sedsala 16em`/`sedsala 19em` çeldiricilerini aynı
   türden (uzun betimleme) çeldiricilerle değiştir. **DeepSeek çapraz
   kontrolü gerektirir** (bulutta yok); uydurma çeldirici KALAN_ISLER
   0.1'in "sahte iş" tuzağıdır.
2. **Ölçütü genişlet** — "doğru cevap çeldiricilerin tür-çoğunluğunda
   ise affet" incelmesi `offline_7598`'i susturur ama `offline_7394`'ü
   (doğru azınlıkta) yakalamaya devam eder. Bu bir sayım koşuludur;
   A12 sayım-koşuluyla gevşetmeye karşı uyarıyor, o yüzden yalnız
   Urartû regresyonu korunduğu kanıtlanarak eklenmeli.

Bu koşuda ikisi de yapılamadı (Flutter yok, DeepSeek yok); yalnız
keşfedildi ve ölçüldü.

**Kapandı (2026-08-24, `aa470f6`) — 1. yol seçildi, içerik onarıldı.** Çıplak
yüzyıl çeldiricileri (`sedsala 16em`, `sedsala 19em`) aynı türden gerçek
tanımlarla değiştirildi: hareket/yayın + yıl + yer. Ölçüt GEVŞETİLMEDİ, yani
A12'nin sayım-koşulu uyarısına uyuldu.

Akşam denetimi iki kaydı da JSON'dan okudu: dört şıkkın dördü de artık uzun
betimleme, tür-tutarlı. Çeldiriciler uydurma değil gerçek olaylar (1925 Amed,
1908 Stenbol, 1937 Dêrsim / 1932 Şam, 1913 ve 1908 Stenbol) ama soruya yanlış
cevap — çeldiricinin işi bu. `is_date_expression` her iki kayıtta da artık 0
ihlal veriyor.

### A18 — [ ] Dokunma hedefi bekçisi 34 ekranın 3'üne bakıyor

`meetsGuideline` çağrısı bütün depoda tek dosyada
(`accessibility_guideline_test.dart`) ve yalnız üç ekranı geziyor: seviye
sınavı, avatar düzenleyici, hikâye ekranı. `lib/src/screens/` altında 34 ekran
dosyası var.

Dosyanın KENDİ belgesi bunu 2026-07-31'de yazmış: *«Bekçinin kapsamı iki
ekrandan ibaret olduğu sürece aynı kusur başka ekranlarda tekrar eder; liste bu
yüzden büyüyor.»* Liste o gün ikiden üçe çıktı ve orada durdu.

**Niçin sessiz kaldı.** Aynı dosyada dokuz ekran daha kuruluyor ve pump
ediliyor (giriş, ana sayfa, oyun merkezi, kategoriler, öğrenme, profil,
ayarlar, mağaza, premium) — ama yalnız `%200 metin ölçeğinde overflow etmez`
testi için, yani tek iddiası `takeException() == null`. Ekranlar zaten
kurulmuş halde duruyor; üstlerine `meetsGuideline` konmamış. Kapsam dar
olduğu için değil, **var olan kapsamda iddia zayıf olduğu için** sessiz.

**Kaynaktan ölçülen iki somut ihlal adayı** (Flutter yok, `flutter test`
koşulamadı — sayılar sabitlerden hesaplandı, koşarak doğrulanmadı):

* `lib/src/screens/sign_in_screen.dart:1269` — `_LanguageChip`, giriş
  ekranının KU/TR dil düğmesi. `minHeight: 36` + dikey padding 6+6, metin
  `bodyMedium` (fontSize 15 × height 1.5 = 22,5 px) → içerik 34,5 px, kırpma
  **36,0 px**. Android 48 ve iOS 44 eşiğinin ikisinin de altında. Ekranda iki
  kez çiziliyor (satır 346 ve 573).
  Ağırlığı: bu düğme Kurmancî konuşan oyuncunun uygulamayı kendi diline
  aldığı yer, ve giriş ekranında duruyor — yani ilk temas.
* `lib/src/screens/onboarding_screen.dart:210` — «atla» düğmesi.
  `minimumSize: Size.zero` + `tapTargetSize: MaterialTapTargetSize.shrinkWrap`
  Flutter'ın 48 px'lik varsayılan genişletmesini AÇIKÇA kapatıyor; geriye
  `caption` (12 × 1,35 = 16,2) + dikey padding 8+8 = **~32,2 px** kalıyor.
  `OnboardingScreen` hiçbir a11y testinde geçmiyor.

**Sabah koşusuna iş. Flutter gerektirir.**

1. Zaten pump edilen dokuz ekrana `androidTapTargetGuideline`,
   `iOSTapTargetGuideline` ve `labeledTapTargetGuideline` ekle. Bu bir tarama
   değil, mevcut koşum takımına iddia eklemek — maliyeti düşük.
2. Düşenleri tek tek oku. **Hepsini büyütme.** Düşen her hedef kusur değildir;
   önce o boyutun belgelenmiş bir karar olup olmadığına bak (A16'da üç bekçi
   tam böyle bir kararı koruyordu).
3. Gerçek kusurları düzeltirken **görsel tasarımı bozma.** Doğru yol hapı
   büyütmek değil, dokunma alanını büyütmek: `SizedBox`/`ConstrainedBox` ile
   48'e sar ya da `tapTargetSize: MaterialTapTargetSize.padded` kullan. Pil
   36 px görünmeye devam eder, parmak 48 px alan bulur.

Tuzak: `meetsGuideline` yalnız o anda EKRANDA olan hedefleri görür. Sekmenin
arkasında kalan, kaydırma dışındaki ya da koşullu çizilen bir düğme sessizce
denetimin dışında kalır — «geçti» demek «o ekranın tamamı temiz» demek
değildir. Kapsamın nerede bittiğini bekçinin belgesine yaz.

---

## Bulut koşusunun uyacağı kurallar

1. **Flutter var mı, önce bak.** `flutter --version` çalışmıyorsa Dart
   kodunu DEĞİŞTİRME — doğrulayamadığın değişikliği göndermek bu
   depoda iki kez derleme kırdı. O durumda yalnız Python/JSON/belge
   işlerini yap (A6) ya da bir maddeyi analiz edip bulgularını bu
   dosyaya işle.
2. **Testsiz gönderme.** Flutter varsa: `dart analyze` temiz ve
   `flutter test` tam geçmeden commit etme.
3. **Her düzeltmenin bekçisi olsun.** Testin belgesine kusurun ne
   olduğunu ve niçin sessiz kaldığını yaz.
4. **Commit gövdesi niçini anlatsın**, neyi değil.
5. **Yeni rapor dosyası üretme.** Bulgu buraya, teste ve commit
   gövdesine yazılır.
6. **Bitiremediğini yarım bırak ve yarım olduğunu yaz.** Tam sanılan
   yarım iş kabul edilmez.
7. Kurmancî metinlerde yalnız Hawar alfabesi (`ı ğ ö ü İ` yok).
   Çeviri tek kaynaktan: `lib/src/l10n/strings.dart`.
8. **Soru bankası JSON'una dokunduysan `tool/question_quality/
   baseline.json` içindeki `sourceFingerprints` de güncellenmeli.** CI'daki
   `question_quality_audit.dart gate` adımı her kaynak dosyanın sha256'sını
   tutar ve içerik değişince "Gate source fingerprint changed" deyip
   `flutter test`e sıra gelmeden düşer. A6 koşusu tam buna çarptı. Hash
   `sha256(dosyanın ham baytları)`; Dart yoksa Python'da hesaplanabilir,
   ama doğruluğunu önce DOKUNMADIĞIN dosyalarla sınayın — hash'leri
   baseline'la tutmuyorsa varsayımın yanlıştır.

### A16 — [x] Ana sayfada kategorilere İKİ kapı — metinler ayrıldı

İki kart aynı işlevi (`_openCategories`) çağırıyor ve alt yazıları
neredeyse aynı:

| Kart | Başlık | Alt yazı |
|---|---|---|
| `home-topic-picker` | Konu seç | Bir kategori seç ve başla |
| `home-browse-categories-row` | Tüm kategoriler | Bir konu seç ve başla |

Ekranda ~500 px arayla duruyorlar ve ikincisi yalnız İLERLEME YOKKEN
çiziliyor — yani yeni kullanıcıda, kafa karışıklığının en pahalı olduğu
anda (2026-08-24, simülatörde görüldü).

**Bulut koşusu bu maddeye DOKUNMASIN.** Her iki tarafı kaldırma denendi
ve üçü de belgelenmiş bir kararı deviriyor:

* `home_screen_navigation_refresh_test` — keşif daveti ilerleme yokken
  görünmeli (2026-08-14: bölüm sessizce boş kalıyordu).
* `home_play_hierarchy_test` — üç seçenek kartı `secondary` vurguda
  olmalı; `home-topic-picker` adıyla sayılıyor.
* `kulturel_modern_home_test` — öğrenme yolları ve yarış geçişi farklı
  hedeflere gitmeli.

Üç ayrı karar bu düzeni şekillendirmiş. Hangi tarafın kalacağı ürün
sahibinin kararıdır; kararı verilince bekçiler de birlikte güncellenir.

**Karar (ürün sahibi, 2026-08-24): kartlar kalsın, metinler ayrılsın.**
Uygulandı — iki kartın niyeti gerçekten farklı ve artık metinleri de öyle
diyor:

| Kart | Yeni alt yazı | Niyet |
|---|---|---|
| `home-topic-picker` | Tek konuda derinleş | odaklanma |
| `home-browse-categories-row` | Hepsine göz at, birini dene | keşif |

Paylaşılan `categoriesSubtitle` DEĞİŞTİRİLMEDİ: o metin `categories_tab`
ve `matchmaking_screen` tarafından da kullanılıyor ve orada doğru. Ana
sayfaya iki yeni anahtar eklendi.

Bekçi `home_category_entries_distinct_test`: birebir eşitlik yetmiyor
(eski hâlde de metinler farklıydı ama aynı şeyi söylüyorlardı), ortak
kelime oranı %50'nin altında olmalı. Kurmancî tarafın Hawar temizliği de
ayrıca sınanıyor.

## Koşu günlüğü

Her koşu buraya tek satır ekler: tarih, ne yapıldı, commit.

- **2026-08-24 (yerel, kalan işler)** — İnsan kararı bekleyen ve Flutter
  isteyen maddelerin hepsi kapandı. A4b: `shimmer` 4.0.0 (gerçek iOS
  derlemesiyle doğrulandı); `code_assets` geçişli bağımlılık çıktı,
  yükseltilemez ve gerek yok. A9: deepseek bankası kalite bekçilerine
  bağlandı ve hemen iki şey buldu — biri yanlış alarm (`ds_ziman_1289`
  dilbilgisi sorusu, yanlış biçimi BİLEREK çeldiricide gösteriyor,
  gerekçeli muafiyet), biri borç tavanı (8→14, altı kaydın altısı da tek
  tek okunup yanlış alarm olduğu doğrulandı). A12: yıl/tür ölçütü
  token-bazlı olarak Dart'a çevrildi ve kural artık BÜTÜN bankalara
  uygulanıyor (önceden yalnız offline) — sıfır ihlal. A14: bot mantığına
  sekiz bekçi yazıldı; `Random?` iğnesi on ay boyunca açık durup
  kullanılmamıştı. A5'in kilidi de açıldı (kör parti araçları + ayrı
  bulut rutini). 2492 test geçiyor.

- **2026-08-24 (yerel, sıfırdan gözden geçirme)** — Uygulama simülatörde
  gezildi. Sayısal şıkların ekranda karışık sırada geldiği bulundu ve
  düzeltildi (85 sorunun 69'u; bekçi `numeric_option_order_test`).
  Ana sayfada kategorilere iki kapı olduğu bulundu; düzeltme iki kez
  denendi, üç bekçi belgelenmiş kararları koruduğu için geri alındı ve
  A16 olarak insan kararına bırakıldı. Taban ölçümündeki A1 ve A3
  yanlış bulgu çıkmıştı, onlar da düzeltilmişti.

- 2026-08-22 — Flutter YOK (`flutter --version` boş, `dart` yok), bu yüzden
  Dart'a dokunulmadı; A6 yapıldı: 22 sızma bulgusunun 22'si JSON içerik
  tarafında kapatıldı, taramaya mandal eklendi. Doğrulama `flutter test`
  ile değil, dokunulan bekçilerin ölçütleri Python'da yeniden uygulanarak
  yapıldı (HEAD ile karşılaştırma: hiçbiri kötüleşmedi, doğru cevap konum
  dağılımı 160/169/189/184 aynı kaldı, uzunluk stratejilerinin en iyisi
  %26,5 < %28). A5 ve A7 atlandı — DeepSeek anahtarı bulutta yok. A9 ve
  A10 yeni açıldı.
- 2026-08-22 (devamı) — PR #3'te CI o koşuda koşulamayan doğrulamayı yaptı:
  `analyze-and-test` YEŞİL (`dart analyze` temiz, `dart format` 619 dosyada
  0 değişiklik, tüm test paketi geçti, ekran turu 92 görüntü üretti),
  `build-android` yeşil. **A6 artık tam doğrulanmıştır; yeniden
  denetlenmesine gerek yok.** Arada kalite kapısı parmak izinden düşmüştü,
  78ae17d ile onarıldı (bkz. kural 8 ve A11).
- 2026-08-23 — Flutter YOK, Dart'a dokunulmadı. A10 alındı ve **yanlış
  bulgu** çıktı: kuralın 12 çarpmasının 12'si de ölçüt hatası, içerik
  sağlam (kanıt maddede; ölçüt Dart'a birebir yeniden yazıldı ve bekçili
  yedi bankada 0 vererek doğrulandı). Kalan iş A12 olarak açıldı. Ölçüm
  sırasında A9'un içerik borcu da bitti: tek gerçek kusur
  `ds_sinema_0193` (gövdede anılan «Moana» şık olarak da duruyordu),
  düzeltildi ve KU açıklamadaki "xwedawenda volkanê" hatası da
  giderildi (Te Fiti ada tanrıçasıdır). Bekçisi
  `sik_kalite_taramasi.py`'ye `sorulan_terim_sik` sınıfı olarak eklendi
  — kusur geri konunca çıkış kodu 1, kaldırılınca 0 diye sınandı — ve
  tarayıcı ilk kez CI'ya bağlandı. `baseline.json`'daki deepseek parmak
  izi kural 8 gereği yenilendi (yordam önce dokunulmamış 10 dosyayla
  sınandı, 10'u da tuttu). A5/A7 yine atlandı: DeepSeek anahtarı
  bulutta yok. Engel: `flutter test` koşulamadı, doğrulama Python'da
  yeniden uygulanan ölçütlerle yapıldı.
- 2026-08-23 (devamı) — CI o koşuda koşulamayan doğrulamayı yaptı
  (12198e3): `dart analyze` temiz, biçim denetimi temiz, kalite kapısı
  geçti (yani parmak izi yenilemesi doğruydu), **tüm test paketi geçti**,
  ekran turu basıldı. Yeni eklenen "Check option-leak scan (Python)"
  adımı da yeşil — tarayıcı artık gerçekten bir kapı. `ds_sinema_0193`
  düzeltmesi ve `sorulan_terim_sik` bekçisi **tam doğrulanmıştır**;
  yeniden denetlenmesine gerek yok.
- 2026-08-23 (akşam denetimi) — Flutter YOK, Dart'a dokunulmadı. Sabah
  koşusunun işi rapora değil işe bakılarak denetlendi ve **temiz
  çıktı**: `ds_sinema_0193` düzeltmesi JSON'da gerçekten duruyor (KU
  açıklama Hawar temiz, gövdedeki «giravê» ile artık tutarlı),
  `sorulan_terim_sik` bekçisi gerçekten hüküm veriyor (kusur geri
  konunca çıkış 1, kaldırılınca 0 diye bağımsız sınandı), ölçütü Dart
  kardeşiyle (`all_banks_quality_test.dart:111`) birebir aynı,
  `baseline.json`'daki 11 parmak izinin 11'i de yeniden hesaplanınca
  tuttu, CI adımları gerçekten koştu (`flutter test` 8dk52sn — atlanmış
  değil). Geri alınacak madde yok. İçerik taraması 0 bulgu.
  Taranan alan: **test kapsamı boşlukları** (önceki iki koşu içeriğe
  bakmıştı). Bulgular A13 (kapandı) ve A14 (açık) olarak eklendi.
  CI (7ff95dc) koşuyu doğruladı: analiz, biçim, kalite kapısı, kapsam
  kapısı, tüm test paketi (9dk18sn) ve Android derlemesi yeşil. A13
  **tam doğrulanmıştır**; yeniden denetlenmesine gerek yok.
- 2026-08-24 — Flutter YOK, Dart'a dokunulmadı; içerik taraması 0 bulgu
  (regresyon temiz). A12 alındı: Dart parçası (test + `flutter test`)
  bu ortamda yapılamaz ama en riskli parçası — ölçüt tasarımı ve
  doğrulaması — saf Python'da TAM yapıldı. Eski `_isYearLike` tüm
  bankalarda ASCII-sadık taklit edilip 24 yanlış alarm gerçek
  örnekleriyle çıkarıldı (A12'nin dağılımıyla birebir tuttu: editorial
  7, expansion 3, sourceFirst 2, deepseek 12). Keskinleştirilmiş
  `is_date_expression` token-bazlı yazıldı (Dart'a birebir çevrilebilir,
  `\b`/`\d` yok) ve doğrulandı: 24 yanlış alarmın 24'ü sustu,
  `edit_edebiyat_0018` tür-tutarlı bulundu, özgün Urartû kusuru sentetik
  kayıtta hâlâ yakalanıyor — keskinleştirme sınıflandırmada, sayım
  koşuluyla DEĞİL (A12 uyarısına uyuldu). **offline 0 sağlanmadı**:
  keskin ölçüt, eski kuralın körlüğü yüzünden gizli kalmış 2 gerçek
  tür-karışık soru açığa çıkardı (`offline_7394`, `offline_7598`) — A15
  olarak açıldı, A12'nin önkoşulu. Engel: `flutter test` ve DeepSeek
  bulutta yok; A12/A15 tamamlanamadı, yalnız Python'da çözülüp
  belgelendi. Commit yalnız durum dosyasını günceller (kod/içeriğe
  dokunulmadı).
- 2026-08-24 (A6 koşusunun PR gözcüsü) — `41aebd4` sayısal şıkları
  sıralayıp sekiz bankayı değiştirdi ama `question_quality/baseline.json`
  parmak izlerini yenilemedi; CI kapısı "Gate source fingerprint changed"
  ile düştü ve `flutter test`e sıra gelmedi. Bu, aşağıdaki **8. kuralın
  ikinci kez kaçırılması** — kural yazılı olmasına rağmen. Kapının verdiği
  tek sebep buydu (blocker/critical artmamış, yeni issue fingerprint yok),
  yani sıralama değişikliği kalite bakımından temiz. Parmak izleri
  yenilendi; algoritma yine dokunulmamış dosyalarla sınandı (3 dosyanın
  3'ünde hash baseline'la birebir tuttu). İçerik taraması 0 bulgu.
  **Not:** kural bir belge satırı olarak iki kez tutmadı; kalıcı çözüm
  ya baseline yenilemesini betikleştirmek ya da kapı hata mesajına
  "şu komutu koş" satırı eklemektir.
- **2026-08-24 (akşam denetimi)** — Flutter YOK, Dart'a dokunulmadı. Günün
  11 commit'i rapora değil işe bakılarak denetlendi ve **temiz çıktı**; geri
  alınacak madde yok. Doğrulananlar: A4b (`shimmer ^4.0.0` pubspec'te),
  A9 (deepseek `banks` haritasında + gerekçeli muafiyet yerinde),
  A12 (Dart ölçütü satır satır Python'a taşınıp bağımsız koşuldu —
  11 bankada 2997 soruda **0 ihlal**; bekçi boş değil: 60 şık tarih /
  10961 tarih-dışı, Urartû kusuru hâlâ yakalanıyor, 24 yanlış alarm susmuş),
  A14 (sekiz bot iddiasının aritmetiği kaynakla birebir: 110/650/+150,
  kırpma sınırları, havuz 19 ad yinelemesiz + Hawar temiz),
  A15 (iki kayıt JSON'dan okundu, dört şık da tür-tutarlı, çeldiriciler
  uydurma değil), A7 (77 kayıt; Cografya 41 / Çand 29 / Edebiyat 7, zorluk
  4-5; ÜÇ kayıt yerinin üçü de dolu; yeni bankada Hawar ihlali 0),
  A8 (3723 satır; taşınan 62 satırın hepsi birebir aynı — eklenen tek şey
  `part of` ve başlık yorumu), A16 (iki alt yazının ortak kelimesi 0, Hawar
  temiz), A2b (iki widget dosyası gerçekten silinmiş, kalan referans yalnız
  yorum). Kural 8: baseline'daki **12 parmak izinin 12'si** yeniden
  hesaplanınca tuttu; `issueFingerprints` 1923, yani A7'nin 77 borcu doğru
  yansımış; blocker/critical 0. İçerik taraması 0 bulgu.
  Taranan alan: **erişilebilirlik** (önceki koşular içerik ve test kapsamına
  bakmıştı). Bulgu A18 olarak açıldı — `meetsGuideline` 34 ekranın 3'üne
  bakıyor, oysa dokuz ekran daha aynı dosyada zaten pump ediliyor.
  **Engel:** Flutter yok, `dart analyze` ve `flutter test` koşulamadı;
  bu oturumda GitHub MCP araçları da gelmediği için CI'nin günün
  commit'lerini doğrulayıp doğrulamadığı GÖRÜLEMEDİ. Doğrulama Python'da
  yeniden uygulanan ölçütlerle ve kaynak okumasıyla yapıldı. Sabah koşusu
  CI'ya bakmalı. Commit yalnız durum dosyasını günceller.
