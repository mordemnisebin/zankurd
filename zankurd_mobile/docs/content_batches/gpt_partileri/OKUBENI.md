# Soru kalitesi denetimi — sohbet partileri

33 parti, her biri ~26.000 karakter. Her partinin başında talimat var;
dosyanın tamamını olduğu gibi yapıştır, ayrıca bir şey yazmana gerek yok.

## Sıra önemli

Partiler **riske göre** sıralı. İlk 21 parti, çapraz kontrolden hiç
geçmemiş 2059 kaydı kapsıyor — bankanın %64'ü ve bilinen hataların
yoğunlaştığı yer. İçlerinde de en eski bankalar önde.

Yarıda bırakırsan iş boşa gitmez: sekizinci partide durursan en riskli
~1100 kayıt denetlenmiş olur.

## Dönüşü nereye koyacaksın

Her partinin cevabı bir JSON dizisi olacak. Olduğu gibi şuraya kaydet:

    docs/content_batches/gpt_bulgular/parti_01.json
    docs/content_batches/gpt_bulgular/parti_02.json
    ...

Dosya adı partiyle aynı numarayı taşısın. Ben o klasörü denetleyip
bulguları elden geçireceğim.

## Yapıştırma kutusu dosyaya çeviriyorsa

Bazı sohbet kutuları uzun yapıştırmayı dosya ekine dönüştürür. Bu iş
için kötüdür: model dosyayı okumak yerine bir sanal ortamda Python'la
işler — sayar, örnekler, grepler. 3214 sorunun her birinin OKUNMASI
gerekiyor.

Öyle oluyorsa partileri küçült:

    python3 tool/content_authoring/gpt_partileri_uret.py 12000

Sayı, parti başına karakter bütçesidir. Küçültürsen parti sayısı artar.

## Bilinmesi gereken

Türkçe ikizler bilerek dışarıda bırakıldı. Payı iki katına çıkarıp
parti sayısını 33'ten 60'a taşıyordu. Sorulan şey şıkların kalitesi ve
o Kurmancî kayıttan görülür; Türkçe çeviri kayması ayrı ve daha düşük
öncelikli bir denetim.

Doğru cevap ✓ ile işaretli. Bu bilerek: bu bir sınav değil, eleştiri
görevi. Anahtarın kendisinin yanlış olduğu durumlar da (`yanlis_anahtar`)
aranan kusurlar arasında.
