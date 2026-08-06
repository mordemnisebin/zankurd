# ZanKurd proje glossary'si v1 — inceleme kaydı (2026-08-06)

Bu glossary projenin **bağlayıcı terminoloji karar kaydıdır**. Glossary'de
yer almak dilbilimsel kesinlik anlamına gelmez; her kayıt kendi kanıt
seviyesini ve onay durumunu taşır. Otomatik kelime değiştirme aracı değildir.

**Hiçbir kayıt insan dil editörü tarafından incelenmedi.**
`NATIVE_SPEAKER_APPROVED`, `HUMAN_APPROVED`, `LINGUIST_APPROVED` etiketleri
kullanılmadı ve `glossary_contract_test` bunları yasaklıyor.

## Sonuç

    ATTESTED_NEEDS_LANGUAGE_REVIEW   8
    MULTIPLE_SENSES_NEEDS_SPLIT      4
    approvedForQuestionAuthoring     0

**Onaylanan terim sıfır olduğu için source-first Teknolojî batch'i
üretilmedi** (eşik: en az 4 onaylı terim).

## Kaynak durumu — asıl darboğaz

| Kaynak | Seviye | Durum |
|---|---|---|
| Ferhenga Birûskî | 1 | `LISTED_NOT_READ` |
| Institut kurde de Paris | 2 | `LISTED_NOT_READ` |
| Kurdish Academy of Language | 2 | `LISTED_NOT_READ` |
| Wiktionary (en) | 4 | **READ** |

Seviye 1 ve 2 kaynaklarının hiçbirinin **girdisi** açılamadı. Arama sonuçları
kurumların ve yayınların var olduğunu gösteriyor; bu, terimin o kaynakta
kayıtlı olduğunun kanıtı değildir. Kitabın adını kaynak gösterip terim
onaylamak, dış aday turunda reddettiğim DeepSeek atıf pratiğinin aynısı
olurdu.

`APPROVED_AUTHORITATIVE_LEXICON` ve `APPROVED_MULTI_SOURCE` sınıfları Seviye
1-2 girdi okumasını şart koşuyor. Bu yüzden hiçbir terim onaylanmadı.

## Okunan tek gerçek sözlük girdisi

**`malper`** — Wiktionary (en), doğrudan açıldı:

> Northern Kurdish, feminine: "(Internet) homepage", "website".
> Bileşik: *mal* (ev) + *per* (sayfa). Eşanlamlı: *serrûpel*.

Lehçe etiketi açıkça Northern Kurdish (Kurmancî) — otomatik lehçe varsayımı
yapılmadı. Corpus yazımı (`malper`, 17 geçiş) sözlük girdisiyle uyuşuyor.

Yine de Seviye 4 tek başına teknik standardı belirlemez; kayıt
`ATTESTED_NEEDS_LANGUAGE_REVIEW`. Ayrıca "homepage" ile "website" anlam
ayrımı soru yazılmadan netleştirilmeli.

## Anlam ayrımı gerektiren dört kayıt

Talimatın uyarısı doğru çıktı; tek toplu onay verilemez:

* **`şîfre`** — corpus'ta hem "parola" hem şifreleme bağlamında geçiyor.
  password / cipher / encryption / code ayrı kavramlar; iki ayrı conceptId
  açıldı (`ku_tech_sifre_password`, `ku_tech_sifre_encryption`).
* **`tor`** — Kurmancîde genel "ağ/file". general network / computer network
  / internet ayrımı yapılmadan onay verilemez; ayrıca İngilizce "Tor"
  (anonimlik ağı) ile karışma riski soru yazarken değerlendirilmeli. İki
  conceptId açıldı.

## Sözleşme testi

`test/glossary_contract_test.dart` yedi kuralı bağlıyor: yinelenen
conceptId yok; kaynaksız kayıt APPROVED olamaz; **okunmamış kaynak
(`LISTED_NOT_READ`) onay kanıtı sayılamaz**; onaylanmamış terim soru
yazımına açılamaz; insan onayı iddiası yasak; recordHash deterministik;
corpus sayısı ile tanıklık listesi tutarlı.

## Devam noktası

Tek darboğaz: **Seviye 1-2 sözlük girdisine erişim.** Ferhenga Birûskî'nin
ilgili maddeleri ya da Kurdish Academy terminoloji listesinin gerçek
girdileri okunabilirse, sekiz terim tek turda `APPROVED_*`a taşınabilir ve
Teknolojî batch'i açılır — factual claim tarafı zaten ucuz (MDN, W3C, IETF,
NIST, CISA).

Bu erişim basılı kaynak veya abonelik gerektiriyorsa, karar kullanıcıya
aittir: ya kaynak sağlanır ya da proje `ATTESTED_NEEDS_LANGUAGE_REVIEW`
seviyesindeki terimlerle soru yazmayı bilinçli olarak kabul eder. Opus bu
kararı kendi başına veremez; verirse kanıt seviyesini şişirmiş olur.
