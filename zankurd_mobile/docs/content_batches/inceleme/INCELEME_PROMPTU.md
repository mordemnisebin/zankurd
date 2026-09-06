# ZanKurd soru bankası — dış inceleme briefi

Sana ekli belgede bir mobil uygulamanın soru bankasından bir kategori
veriliyor. Uygulama Kurmancî (Kuzey Kürtçesi) öğreten iki dilli bir bilgi
yarışması; sorular Kurmancî yazılır, Türkçe karşılıkları da bulunur.
Uygulama App Store'da yayına giriyor, yani yanlış soru gerçek kullanıcıya
gidiyor.

Senden **acımasız ve somut** bir inceleme istiyorum. Övgü istemiyorum.

## Neyi ara

Öncelik sırasıyla:

1. **Olgusal yanlış.** Cevap anahtarı yanlış ya da soru gerçek dışı bir şey
   iddia ediyor. Özellikle Kürt tarihi, coğrafyası, edebiyatı ve müziğinde
   dikkatli ol — bu alanlarda dil modelleri kendinden emin ve yanlış yazar.
2. **Birden fazla doğru cevap.** İki şık da savunulabiliyorsa soru bozuktur.
3. **Cevabı ele veren soru.** Soru metni cevabı içeriyor ya da doğru şık
   diğerlerinden bariz uzun/detaylı.
4. **Muğlak soru kökü.** "En çok hangisiyle ilgilidir", "neye yakındır"
   gibi tek doğru cevabı olmayan kalıplar.
5. **Tembel çeldirici.** Yanlış şıklar açıkça saçma, konu dışı ya da hepsi
   aynı boş kalıpta.
6. **Kurmancî dil hatası.** Yazım (ı, ğ, ö, ü Kurmancî'de YOKTUR), ergatif,
   izafe (veqetandek), oblik hâl hataları. Kurmancî bilmiyorsan bu maddeyi
   atla ve atladığını söyle — uydurma.
7. **Türkçe çeviri hatası.** Anlam kayması ya da şık sırasının bozulması.
8. **Kültürel yanlışlık.** Bir geleneği yanlış anlatan, karıştıran ya da
   rencide edici ifade.

## Neyi arama (zaten denetlendi)

Bunlara vakit harcama, otomatik olarak ölçüldü:

- Şık sayısı, boş şık, birbirinin aynısı şık
- Doğru cevabın şıklar arasında bulunması
- Doğru cevabın A/B/C/D dağılımı (dengeli)
- Kaynak adresinin HTTP olarak açılıyor olması
- Açıklama uzunluğu ve tekrar
- Tipografi (tırnak biçimi)
- Aynı sorunun birebir kopyası

**Kaynak adresinin İÇERİĞİ doğrulanmadı** — yani adres açılıyor ama o
sayfanın iddiayı desteklediği kontrol edilmedi. Şüphelendiğin yerde
kaynağa bakabiliyorsan bak.

## Bilinen zayıflıklar (teyit ya da yalanla)

- Zorluk dağılımı kolaya kaçık; "zor" kademe zayıf.
- Bazı kategorilerde soru kökleri birbirine benziyor.
- Otomatik ölçümle tahmin edilen olgusal hata payı **%3-8** ve az kaynaklı
  alanlarda kümeleniyor.

Bu tahminleri doğruluyorsan söyle, yanlışsa düzelt.

## Çıktı biçimi (buna uy, serbest metin yazma)

Önce iki cümlelik genel değerlendirme. Sonra yalnız SORUNLU kayıtlar için
şu tabloyu ver:

| id | sorun tipi | ciddiyet | açıklama | önerin |
|---|---|---|---|---|
| ds_dirok_0122 | olgusal yanlış | yüksek | Bedirxan Cizre doğumludur, Amed değil | çıkar |

- `sorun tipi`: olgusal / iki doğru cevap / cevabı ele veriyor / muğlak kök /
  tembel çeldirici / dil hatası / çeviri hatası / kültürel
- `ciddiyet`: yüksek (kullanıcıya yanlış öğretir) · orta (kafa karıştırır) ·
  düşük (estetik)
- `önerin`: çıkar · düzelt (nasıl olacağını yaz) · olduğu gibi kalsın

Sorunsuz soruları listeleme. En sonda: kaç soru inceledin, kaçında sorun
buldun, kategorinin genel kalitesi hakkında bir cümle.

## Son not

Emin olmadığın bir iddiayı "yanlış" diye işaretleme; "şüpheli" de ve niçin
şüphelendiğini yaz. Yanlış alarm da gerçek hata kadar maliyetlidir — biz
buna göre soru sileceğiz.

## 2026-08-18 eki: ÖNCÜLÜ yalan olan soru

Altı kategorinin incelemesi, ne mekanik kapının ne de çapraz kontrolün
görebildiği bir kusur sınıfını ortaya çıkardı: **soru kendi içinde
kusursuz, önermesi uydurma.**

Üç örnek — üçü de bankadan çıkarıldı ya da düzeltildi:

* "Dengbêjlik 2018'de UNESCO tarafından tanındı" — tanınmadı. 2018'de
  Türkiye'nin yazdırdığı miras Dede Korkut'tu. Banka bunun üstüne ikinci
  bir soru daha kurmuştu.
* "2021 Nobel Edebiyat Ödülü'nü hangi **Nijeryalı** yazar kazandı?" —
  hiçbiri. 2021 Gurnah'ındır (Tanzanya) ve banka bunu başka bir soruda
  doğru soruyordu.
* "Nobel alan ilk kadın Gabriela Mistral" — ilk kadın 1909'da Selma
  Lagerlöf'tür; Lagerlöf sorunun kendi çeldiricisiydi.

Çapraz kontrol üçünü de onayladı, onaylaması da beklenirdi: modele "şu
dört addan hangisi" diye sorulur, "bu soru anlamlı mı" diye sorulmaz.

**Bu yüzden incelemeden özellikle şu isteniyor:** bir soruyu okurken önce
şıklara değil KÖKE bak. Kökün varsaydığı şey gerçekten oldu mu? Verilen
kurum, ödül, tarih ya da unvan gerçekten var mı? Doğru şık listedeki en
iyi seçenek olabilir ve soru yine de yalan olabilir.

Emin olamadığında "yanlış" değil **"şüpheli"** yaz — hangi iddianın
doğrulanması gerektiğini belirtmen yeter.
