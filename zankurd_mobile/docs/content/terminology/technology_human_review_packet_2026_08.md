# Teknoloji terminolojisi — insan/proje editörü inceleme paketi (2026-08-06)

Bu paket bir **insan kararı** içindir. `reviewerDecision` alanlarının hepsi
bilerek boştur. Opus bu terimlerin hiçbirini kendi başına açmadı.

Hiçbir kayıt insan tarafından incelenmedi; `NATIVE_SPEAKER_APPROVED`,
`HUMAN_APPROVED`, `LINGUIST_APPROVED` ifadeleri kullanılmadı.

Editör bir terimi kabul ederse statü **`PROJECT_EDITOR_APPROVED_RESTRICTED_SENSE`**
olur. Bu, "Kurmancîde evrensel dilbilimsel standarttır" anlamına gelmez;
yalnız "ZanKurd içeriklerinde belirtilen anlam sınırları içinde
kullanılabilir" demektir.

## Niçin bu paket gerekti

Teknoloji alanı kaynak yokluğundan değil **terim yokluğundan** durdu. MDN,
W3C ve NIST sayfaları açık ve zengin; ama dokuz kavramın Kurmancî karşılığı
doğrulanamadı ve bunlar MDN'nin en öğretici olgularını kilitliyor
(server/client rolleri, tarayıcının istek göndermesi).

Dört izinli terim (`malper`, `pergal`, `komputer`, `elektrîk`) sekiz ayrı
olguya yetmedi; pilot dört soruda kaldı.

## Karar bekleyen dokuz kavram

| Kavram | Aday | Corpus | Temel soru |
|---|---|---|---|
| server | — | yok | network/web/software/device anlamları ayrışmalı |
| client | — | yok | ticari "müşteri" anlamı ağ bağlamına taşınmamalı |
| browser | — | yok | web browser / browsing fiili / file browser |
| internet | `înternet` | 17 | Wiktionary 404; Internet/web/network ayrımı |
| data | `dane` | 34 | Wiktionary'de Kurmancî bölümü yok; data/datum/information |
| software | `nermalav` | 14 | Wiktionary 404 |
| application | `sepan` | 9 | isim/fiil ve implementation ayrımı |
| password | `şîfre` | 35 | password/cipher/encryption/code ayrışmalı |
| computer network | `tor` | 18 | genel "ağ" + İngilizce "Tor" özel adıyla karışma |

Dört terimin corpus kullanımı yüksek (`şîfre` 35, `dane` 34, `înternet` 17,
`tor` 18) — yani proje bunları zaten kullanıyor. Sözlük kanıtı olmadığı için
YENİ içerikte kullanılmıyorlar; bu, mevcut soruların yanlış olduğu anlamına
gelmez, yalnız yeni içerik için kanıt eşiğinin farklı olduğu anlamına gelir.

## Editörden istenen

Her kavram için: bu terim, belirtilen kısıtlı anlamda ZanKurd içeriğinde
kullanıma açılsın mı? Açılırsa hangi anlamla sınırlı? Yazım hangi biçimde
sabitlensin?

Karar `technology_human_review_packet_2026_08.json` içindeki
`reviewerDecision`, `reviewerNotes` ve `decidedAt` alanlarına yazılabilir.
