# Kurmancî bilim terminolojisi — inceleme kaydı (2026-08-06)

Bu kayıt **Opus değerlendirmesidir.** Hiçbir terim `NATIVE_SPEAKER_APPROVED`
değildir ve bu dosya Opus'un kendi kararını insan dil onayı gibi sunmaz.

## Niçin bu kapı var

Tur 9'da USGS su döngüsü kaynak paketi hazırdı ve beş açık olgu içeriyordu,
ama soru yazılamadı: buharlaşma, yoğuşma, sızma ve yüzey akışı için Kurmancî
karşılıklarını uydurmam gerekirdi. Uydurulmuş bilimsel terim, Kurmancî bir
uygulamada yanlış kaynaktan daha zararlıdır — kullanıcı onu doğru sanıp
öğrenir ve düzeltmek daha zordur.

Tur 10'un doğru uyarısı: **aktif corpus'ta bir terimin bulunmaması, o terimin
Kurmancîde bulunmadığını kanıtlamaz.** Corpus Seviye 5'tir — tutarlılık ve
tercih edilen yazım kanıtı, dil otoritesi değil. Bu yüzden Kol B kapatılmadı;
terimler ayrı kapıdan geçiyor.

## Kaynak hiyerarşisi ve şu anki kanıt durumu

| Seviye | Kaynak | Bu turda toplandı mı |
|---|---|---|
| 1 | akademik/lexicographic sözlük (ör. Ferhenga Birûskî) | **hayır** |
| 2 | kurumsal terminoloji (ör. Kurdish Academy of Language) | **hayır** |
| 3 | yayın ve corpus tanıklığı (proje dışı) | **hayır** |
| 4 | topluluk sözlükleri (yalnız aday keşfi) | hayır |
| 5 | aktif ZanKurd corpus'u | **evet** |

Yalnız Seviye 5 toplandı. Bu, hiçbir terimin `APPROVED_*` olamayacağı
anlamına gelir — o sınıflar Seviye 1 veya 2 kanıt ister.

## Sonuç

    ATTESTED_NEEDS_LANGUAGE_REVIEW  10
    TERMINOLOGY_BLOCKED              9

### Corpus'ta yerleşik (10)

`înternet`, `malper`, `tor`, `dane`, `şîfre`, `pergal`, `nermalav`, `sepan`,
`komputer`, `elektrîk`.

Aktif Teknolojî sorularında tutarlı biçimde kullanılıyorlar (`şîfre` 35,
`dane` 34, `pergal` 26, `elektrîk` 25 geçiş). Bu güçlü bir tutarlılık
sinyalidir ve yazımı sabitler — ama teknik standardı belirlemez. Seviye 1-2
kaydı eklendiğinde çoğunun `APPROVED_AUTHORITATIVE_LEXICON` veya
`APPROVED_INSTITUTIONAL_TERMINOLOGY` olması beklenir.

### Bloke (9) — su döngüsü

`water cycle`, `water vapour`, `evaporation`, `condensation`,
`precipitation`, `infiltration`, `surface runoff`, `atmosphere`,
`groundwater`.

Kurmancî alanları **bilerek boş**. Corpus'ta tanıklık yok.

Özellikle kaydedilen ayrım: `hilm` corpus'ta bir kez ve türbin bağlamında
geçiyor ("Hilma bin zextê" = basınç altındaki buhar). `hilm`in "buhar"
anlamı taşıması, `hilmkirin` ya da `hilmbûn` türevlerinin bilimsel
"evaporation" terimi olduğunu **kanıtlamaz**. Her türev ayrı kanıt ister;
bir kökten anlam türetmek tam da bu kapının engellemek için kurulduğu
işlemdir.

## Su döngüsü paketinin durumu

`pack_usgs_water_cycle.json` beş factual claim'i ile korunuyor. Kaynak
tarafı sağlam (USGS, FETCHED_DIRECT); engel dil tarafında.

Durum: `SOURCE_VERIFIED_TERMINOLOGY_BLOCKED`.

## Devam noktası

1. Seviye 1-2 kaynak aç: akademik Kurmancî sözlük ve kurumsal terminoloji
   listesi. Bu tek adım 10 terimi `APPROVED_*`a taşıyabilir ve Kol B'nin
   internet/güvenlik/donanım kolunu açar.
2. Su döngüsü terimleri için ayrı bir hidroloji/coğrafya terminoloji turu
   gerekir; corpus yardım etmiyor.
3. Terim onaylanmadan o terime bağlı soru yazılmayacak. Bir terim bloke ise
   yalnız o soru bekletilir, batch durmaz.
