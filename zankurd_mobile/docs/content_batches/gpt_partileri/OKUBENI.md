# Soru kalitesi denetimi — tek dosya

`TUM_SORULAR.txt` — 3214 sorunun tamamı, ~712.000 karakter (~178.000
token). Talimat dosyanın başında; olduğu gibi ver, ayrıca bir şey
yazmana gerek yok.

## Dönüşü nereye

Cevap bir JSON dizisi olacak. Olduğu gibi şuraya kaydet:

    docs/content_batches/gpt_bulgular/tum.json

Denetim:

    python3 tool/content_authoring/spark_denetim.py docs/content_batches/gpt_bulgular

Araç kimlikleri bankayla, iddiaları kayıtların gerçek içeriğiyle
karşılaştırır ve dizinin sonundaki `{"_okunan": N}` beyanını 3214 ile
karşılaştırır. "1200 okudum" diyen bir dönüş yakalanır.

## Tek gerçek risk

Yapıştırma kutusu bu boyutu **dosya ekine** çevirebilir. Öyle olursa
model metni okumak yerine bir sanal ortamda Python'la işler: sayar,
örnekler, greple arar — ve 3214 sorunun hiçbiri okunmamış olur. Dönüşün
kısa ve genel çıkması bunun işaretidir.

Öyle olduğunu düşünüyorsan haber ver; aynı içeriği partilere bölerim:

    python3 tool/content_authoring/gpt_partileri_uret.py 22000

## Bilinmesi gerekenler

**Türkçe ikizler yok.** Eklenseydi dosya ~306.000 token olurdu ve
çıktıya yer kalmazdı. Sorulan şey şıkların kalitesi; o Kurmancî
kayıttan görülür. Çeviri kayması ayrı ve daha düşük öncelikli bir
denetim — istenirse ayrı dosya üretilir.

**Doğru cevap ✓ ile işaretli.** Bu bir sınav değil, eleştiri görevi.
Anahtarın kendisinin yanlış olduğu durum (`yanlis_anahtar`) da aranan
kusurlar arasında. Kör sorma yöntemi `cross_check.py`nin işi ve ayrı
duruyor.

**Sıra riske göre.** Dosyanın başında çapraz kontrolden hiç geçmemiş
2059 kayıt var (bankanın %64'ü), içlerinde en eski bankalar önde. Model
yarıda bırakırsa ya da sona doğru dikkati düşerse, kaybedilen kısım en
az riskli kısım olur.
