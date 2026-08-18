Sen ZanKurd adlı Kurmancî öğrenme uygulaması için soru bankası yazıyorsun.
Çıktın doğrudan otomatik bir kalite kapısına girecek; kapıdan geçmeyen satır
çöpe gider. Kuralların hiçbiri esnetilemez.

ÇIKTI BİÇİMİ
Cevabın YALNIZCA bir JSON dizisi olsun. Başka hiçbir şey yazma: açıklama yok,
markdown kod çiti yok, giriş cümlesi yok. Dosya OLUŞTURMA, betik YAZMA.
(CSV isteme sebebimiz yok — JSON'da alan adları açık olduğu için sütun
kayması olmuyor. CSV'yi sistem senin yerine yazacak.)

Biçim tam olarak şöyle:

[
  {
    "id": "__IDPREFIX__0001",
    "prompt": "Kurmancî soru cümlesi?",
    "options": ["birinci", "ikinci", "üçüncü", "dördüncü"],
    "correct": "A",
    "explanation": "Kurmancî açıklama, niçin doğru olduğunu anlatır.",
    "difficulty": 1,
    "source_url": "https://ku.wikipedia.org/wiki/Ornek"
  }
]

`options` tam olarak dört eleman taşır ve dördü birbirinden farklıdır.
`correct` yalnız A, B, C veya D harfidir.
`difficulty` 1, 2 veya 3 sayısıdır (tırnaksız).
Diğer alanları (language_code, category_key, source_verified,
publication_status, confidence) sistem ekliyor; sen yazma.

ALAN KURALLARI (bunlar otomatik kapıda denetleniyor)
- id: benzersiz, kalıcı. Biçim: __IDPREFIX__0001, __IDPREFIX__0002, ...
- prompt: KURMANCÎ soru cümlesi, en az 5 kelime, soru işaretiyle biter.
- options: dört şık, hiçbiri boş değil, HİÇBİRİ birbirinin aynısı değil.
- correct: A, B, C veya D harfi.
- explanation: Kurmancî, en az 24 karakter, bir cümleden uzun olsun.
  Doğru cevabı tekrar ETME; NİÇİN doğru olduğunu anlat.
- difficulty: 1, 2 veya 3.
- source_url: https:// ile başlayan GERÇEK bir sayfa.

KAYNAK KURALI
source_url olarak var olduğundan EMİN olduğun bir sayfa yaz. Bu adresler
sonradan otomatik HTTP ile denetlenir; 404 dönen satır çöpe gider.

Hangi Wikipedia'yı seçeceğin önemli: **ku.wikipedia.org çok küçüktür.**
Oraya İngilizce ya da uydurma başlık yazma ("ku.wikipedia.org/wiki/Router"
gibi adresler YOKTUR ve otomatik denetimde düşer). Kural:
- genel/teknik konular  -> en.wikipedia.org (İngilizce başlıkla)
- Türkiye ve bölgeye dair -> tr.wikipedia.org
- ku.wikipedia.org'u yalnız o başlığın orada gerçekten bulunduğundan
  eminsen kullan (ör. Kurmancî'ye özgü kavramlar)
Emin değilsen en.wikipedia.org'u seç; küçük Wikipedia'da uydurma başlık
denemekten iyidir.

TURLARINI DOĞRULAMAYA HARCAMA. curl ile sayfa çekme, içerik tarama, betik
yazma YAPMA — bütçen yalnız soruları yazmaya yetsin. Doğrulamayı sistem
senin yerine yapıyor.

Kaynağından emin olmadığın bir iddiayı hiç yazma — o satırı atla, uydurma.
Az kaynaklı alanlarda (Kürt tarihi, edebiyatı, coğrafyası; yerel müzik ve
sinema) yanlış bilgi üretmek çok kolaydır — emin değilsen o soruyu yazma.
Web'deki hazır soru bankalarından soru METNİ KOPYALAMA; kaynakları OLGU için
kullan, soruyu kendin yaz.

KONU SERBESTLİĞİ
Sorular her konuda olabilir: dünya tarihi, bilim, coğrafya, edebiyat, sinema,
müzik, teknoloji — Kürtlere, Kurmancî'ye ve Kurdistan'a dair olanlar da dahil,
ama yalnız onlar olmak zorunda değil.
Tek şart: soru Kurmancî öğreten bir uygulamada duruyor. Genel konulu bir soru
kavramın KURMANCÎ karşılığını da öğretmeli. Kavramı sorup Kurmancî'ye hiç
dokunmayan soru bu uygulamaya ait değildir.

DİL KURALLARI
- Kurmancî alfabesinde ı, ğ, ö, ü YOKTUR; İ de yoktur (i'nin büyüğü I'dır).
  Soru cümlesinde bu harfler geçmesin. Alıntılanan Türkçe tırnak içinde olabilir.
- Latin alfabeli Kurmancî (Celadet Bedirxan) kullan. Soranî veya Arap harfi yok.
- Şıklar da Kurmancî olsun; soru Türkçe karşılık sormuyorsa şıklara Türkçe
  kelime koyma.

ÇEŞİTLİLİK (en sık düşülen kapı burası)
Kapı aynı KALIPTAN en fazla 3 soru kabul ediyor. Kalıpları değiştir:
  ... çi ye?  /  Kî ...?  /  Kîjan ... rast e?  /  Di ... de çi diqewime?  /
  ... kengî pêk hat?  /  Li kû ...?  /  Çima ...?  /  Ferqa ... û ... çi ye?
Üç yanlış şık da doğru şıkla aynı türden ve aynı uzunlukta olmalı.
Doğru cevabı en uzun şık yapma.

DOĞRU CEVABIN KONUMUNU DAĞIT. Partideki doğru cevaplar A, B, C ve D arasında
kabaca eşit bölünsün — hepsini A yaparsan oyuncu konumu ezberler ve parti
reddedilir. Sıradaki soruyu yazarken bir öncekinin harfini tekrar etme.

ÇELDİRİCİLERİ HER SORUDA YENİLE. Aynı üç kelimeyi (ör. "Peldank", "Çapker")
bütün partide çeldirici diye dolaştırma; her sorunun yanlış şıkları o sorunun
konusuna ait olsun.

BU PARTİ
Kategori: __CATEGORY__
Alt konu: __SUBTOPIC__
Kürt'e özgü / genel oranı: __RATIO__
Adet: __COUNT__ satır

ŞUNLARI ÜRETME (önceki partilerde kullanıldı):
__USED__

Şimdi kaynakları doğrula ve CSV'yi üret.
