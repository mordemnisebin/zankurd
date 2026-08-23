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

### A2b — [ ] Yalnız kendi testi olan iki widget — İNSAN KARARI
`ColorfulActionCard` ve `BadgeCollectionSection` ürün kodunda hiç
kullanılmıyor, yalnız üçer test dosyasında yaşıyorlar. Silmek testleri
de götürür; ileride kullanılmak üzere bekliyor olabilirler. Bulut koşusu
bu maddeye DOKUNMASIN — silme kararı ürün sahibinindir.

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

### A4b — [ ] `shimmer` 3→4 ve `code_assets` 1→2 ana sürüm atlaması
Kısıt dışı kaldılar; ana sürüm atlaması kırıcı değişiklik taşıyabilir.
Yerel oturumda, teker teker, gerçek derlemeyle denenmeli.

### A5 — [ ] İçerik: çapraz kontrolü olmayan 1810 soru
Ayrıntı `docs/KALAN_ISLER_GOREVI.md` bölüm 1. **DeepSeek API anahtarı
gerekiyor ve bulutta yok** — bu madde bulut koşusunda YAPILAMAZ.
Yerel oturum için bırakıldı.

### A6 — [x] İçerik: makine taramasının 22 sızma bulgusu
`python3 tool/content_authoring/sik_kalite_taramasi.py` çalıştır
(saf Python, Flutter gerektirmez). 16 biçim + 6 uzunluk sızması.
Düzeltirken `docs/KALAN_ISLER_GOREVI.md` bölüm 2'deki bekçi tuzaklarını
oku — orada üç testin birbirini nasıl kırdığı yazılı.

**Sonuç:** 22 bulgunun 22'si kapandı, tarama 0 bulgu veriyor; düzeltme
çeldirici tarafında yapıldı (tek istisna `edit_muzik_0017`) ve betiğe
`FINDING_RATCHET = 0` mandalı eklendi — sızma geri gelirse çıkış kodu 1.

### A7 — [ ] Park edilmiş 77 soru
`docs/content_batches/bekleyen_2026_08_19_cografya_cand_edebiyat.json`.
A5'e bağlı (çapraz kontrol gerekiyor). Bulutta yapılamaz.

### A8 — [ ] Dev dosyaların bölünmesi
`quiz_screen.dart` 3784 satır, `supabase_zankurd_repository.dart` 3023,
`quiz_result_screen.dart` 2655. Bunlar bakım riski ama çalışıyorlar.
**Yalnız Flutter test koşulabiliyorsa** dokun; koşulamıyorsa dokunma.
Küçük adım: tek bir bağımsız bölümü `part` dosyasına taşı, test koş,
commit et. Büyük refactor YAPMA.

### A9 — [ ] DeepSeek bankası kalite bekçilerine bağlı değil
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

### A12 — [ ] Yıl/tür ölçütü keskinleştirilmeli (A9'un önkoşulu)
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

### A11 — [ ] `question_quality/baseline.json` tam yenilenmeli
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

## Koşu günlüğü

Her koşu buraya tek satır ekler: tarih, ne yapıldı, commit.

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
