# Kör çapraz kontrol — parti durumu

Her satır bir koşudur. Cevap veren taraf anahtarı görmez; karşılaştırmayı
`tool/content_authoring/kor_cevap_karsilastir.py` yapar. Buradaki "çelişki
oranı" o partiye ait sorulardan hesaplanır (araç ekrana kümülatif oran
basar; ikisini karıştırma).

Çelişki "yanlış" demek değil, "insan denetimi gerekiyor" demektir.

| Tarih | Parti | Cevaplanan | "?" | Hükümlü | Çelişki | Oran |
|---|---|---|---|---|---|---|
| 2026-08-25 | kor_01 | 245 | 13 | 232 | 1 | %0,4 |

## 2026-08-25 — kor_01

Tek çelişki `comm_muz_0001` ("Koma rockê ya kurdî ya yekem kîjan e?").
Kör okumada Agirê Jiyan seçildi; anahtar başka şıkta. Soru gerçekten
tartışmalı — "ilk Kürt rock grubu" unvanı kaynaklara göre Agirê Jiyan ile
Siya Şevê arasında değişiyor. İnsan denetimi için tam da beklenen türden
bir kayıt; düzeltilmedi.

"?" verilenlerin 13'ü de dar bir kümede toplandı: film künyeleri
(`comm_sin_0001`, `0004`, `0005`, `0007`, `0009`), Rojava rap sahnesi
(`comm_muz_0004`, `0005`) ve şehit biyografileri (`comm_dir_0001`,
`0002`, `0007`, `0009`, `comm_siy_0001`). Bunlar doğrulanabilir kaynağı
zayıf, güncel ve yerel olgular; kör okumayla tahmin etmek ölçümü
kirletirdi. Kalan konularda (dil, tarih, coğrafya, edebiyat, paradigma)
belirsizlik çıkmadı.

Not: cevaplar harf olarak seçilip parti dosyasındaki şıkkın tam metnine
program aracılığıyla çevrildi — 245 cevabın hiçbiri "şıkka oturmayan"
sayılmadı.
