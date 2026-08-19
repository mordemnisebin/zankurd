# Görev: soru bankasının şık kalitesi denetimi

Sen bu depoya dosya erişimi olan bir ajansın. Aşağıdaki işi **yalnız
bulguları yazarak** yapacaksın. Hiçbir soru dosyasını DEĞİŞTİRME.

## Niçin bu iş

Bankada 3214 soru var ve bunların 2059'u hiçbir otomatik denetimden
geçmedi. Var olan denetim (`tool/content_authoring/cross_check.py`) modele
soruyu çıplak sorup anahtarla karşılaştırır; güçlüdür ama yalnız ŞIKKI
denetler, SORUNUN KENDİSİNİ denetlemez. Uydurma bir ödül, uydurma bir
UNESCO kaydı ya da iki şıkkı da doğru olan bir soru, dört şıktan biri
"doğru" işaretlendiği sürece o kontrolden temiz geçer. Senin işin tam
olarak o boşluk.

## Okuyacağın dosyalar

`lib/src/data/question_bank_assets.dart` içinde listelenen bütün
`assets/data/*.json` bankaları. Sırayla, banka banka çalış.

Bir kaydın alanları: `id`, `category`, `prompt` (Kurmancî), `answers`
(şıklar), `correctAnswer`, `explanation`, `type`, `difficulty` ve
Türkçe ikizleri `promptTr` / `answersTr` / `correctAnswerTr`.

## Neye bakacaksın

Her soru için şu kusurları ara. Parantez içindekiler çıktıda
kullanacağın **kod**lardır; başka kod uydurma.

1. `yanlis_anahtar` — işaretli doğru cevap gerçekte yanlış.
2. `birden_fazla_dogru` — birden çok şık savunulabilir biçimde doğru.
3. `mugla` — soru tek bir doğru cevaba işaret etmiyor; kapsam, tarih
   aralığı ya da ölçüt belirsiz.
4. `uydurma_olgu` — sorunun DAYANDIĞI önerme yanlış: olmayan bir ödül,
   olmayan bir yayın, olmayan bir kayıt, yanlış atfedilmiş bir eser.
   Şıklardan bağımsızdır; soru kökünün kendisi yalandır.
5. `celdirici_sacma` — yanlış şıklar ciddiye alınamayacak kadar alakasız;
   soru okunmadan da bilinir.
6. `cevap_sizdiran` — doğru şık biçimiyle kendini ele veriyor: tek başına
   farklı bir kalıpta, tek başına ayrıntılı, ya da soru kökündeki bir
   kelimeyi tekrar ediyor.
7. `kategori_yanlis` — soru bulunduğu kategoriye ait değil.
8. `dil_hatasi` — Kurmancî metinde Hawar alfabesi dışı harf (ı, ğ, ö, ü,
   İ), ergatif/izafe hatası, ya da Türkçe ikizde anlam kayması.
9. `tekrar` — başka bir soruyla aynı olguyu soruyor.

## Nasıl yazacaksın

Her banka için ayrı bir dosya:
`docs/content_batches/spark_bulgular/<banka_adi>.json`

İçerik, **yalnız kusurlu bulduğun** kayıtlardan oluşan bir dizi:

```json
[
  {
    "id": "offline_0123",
    "kusur": ["mugla", "birden_fazla_dogru"],
    "not": "Hem 'Amed' hem 'Riha' 1900 öncesi için doğru; soru tarih vermiyor.",
    "oneri": "Soruya '1514'te' ibaresi eklenmeli."
  }
]
```

Kurallar:

* `kusur` yukarıdaki dokuz koddan en az biri olmalı; başka değer yazma.
* `not` **niçin** kusurlu olduğunu somut yazsın. "Kalitesiz" ya da
  "geliştirilmeli" gibi cümleler işe yaramaz — hangi şıkkın niçin sorunlu
  olduğunu söyle.
* `oneri` düzeltme önerisi; emin değilsen boş bırak.
* Kusursuz bulduğun soruyu dosyaya YAZMA. Liste yalnız bulgulardır.
* Soru dosyalarının kendisine DOKUNMA. Düzeltmeleri sen uygulamayacaksın.

## Uymak zorunda olduğun iki kural

**Emin olmadığında bulgu yazma.** Bu listeyi bir insan tek tek elden
geçirecek; şişirilmiş bir liste, gerçek kusurları görünmez kılarak
işi bozar. Bulamadığın bir bankada boş dizi yazmak geçerli bir sonuçtur.

**Her `id` gerçekten okuduğun bir kayda ait olmalı.** Uydurma kimlik,
var olmayan kusur ya da kaydın içeriğiyle uyuşmayan `not` yazma. Dönüşün
makineyle denetlenecek: kimlikler bankayla, notlar kaydın gerçek
içeriğiyle karşılaştırılacak ve tutmayan bulgular tümden atılacak.

## İlerleme

Küçük bankalarla başla, `offline_questions.json` (1347 kayıt) en sona
kalsın. Her bankayı bitirdiğinde o bankanın dosyasını yaz — hepsini
sona bırakma, yarım kalan iş de değerlidir.
