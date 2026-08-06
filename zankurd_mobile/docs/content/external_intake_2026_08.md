# Dış model aday havuzları — intake kararları (2026-08-06)

Branch: `content/overnight-expansion-2026-08-06`

Bu dosya **karar kaydıdır**. Hiçbir dış commit cherry-pick edilmedi, hiçbir
dış aday runtime bankasına alınmadı.

## Havuzların gerçek durumu

| Havuz | Branch | HEAD | Aday | Durum |
|---|---|---|---|---|
| Grok wave 01 | `content/author-grok-wave-01-2026-08-06` | `8f68a50` | 407 | incelendi |
| DeepSeek wave 01 | `content/author-deepseek-wave-01-2026-08-06` | `8fbbb94` | 500 | incelendi |
| Ücretsiz model sürüsü | `content/free-model-swarm-wave-01-2026-08-06` | `be98dc3` | 0 | **SKIPPED — NO COMPLETE HANDOFF** |

Ücretsiz sürü branch'i `be98dc3`'te duruyor; bu, bu çalışmanın da ortak
atasıdır. `main..HEAD` farkı yeni içerik içermiyor — yalnız zaten aktive
edilmiş 218'lik batch'in kendisi. Yeni aday, provenance ya da validation
raporu yok.

## Envanter (907 aday)

    fiziksel toplam                907   (grok 407, deepseek 500)
    benzersiz ID                   907
    şema geçerli                   907
    TR/KU tam                      907
    explanationKu + explanationTr  907
    provenance alanı dolu          907
    GERÇEK (URL) sourceReference     0   <-- §7 kapısı
    exact prompt duplicate           0
    ID çakışması (canlı banka)       0
    semantic duplicate (canlı 2050)  0
    semantic duplicate (aktif 218)   0
    semantic duplicate (grok↔deepseek) 0
    kategori: Teknolojî 225, Cografya 216, Sînema 125, Edebiyat 125,
              Dîrok 91, Muzîk 82, Çand 43
    cevap pozisyonu: 24.9 / 25.8 / 24.4 / 24.9
    en uzun doğru: %34.2   en kısa doğru: %18.5

## Kapıda düşen bulgular

### 1. Kendini yanlış ilan eden çeldiriciler — Grok 296/407 (%72,7)

    ["512 KB (yanlış)", ...]
    ["RAM (ne rast) (ne rastîn)", "RAM (yanlış) (geçersiz)"]

Oyuncu konuyu bilmeden etiketsiz şıkkı seçip kazanır. Mevcut
`answer-leak-*` kuralı bunu görmüyordu (yalnız soru kökünü tarıyordu) ve
sekiz batch'in sekizine de PASS verilmişti. Kural eklendi
(`validate_batch.py::SELF_LABELED`) ve `distractor_integrity_test` ile
üretim bankalarına bağlandı.

Kural sonrası Grok'un kullanılabilir kalıntısı: **111** (407 değil).
DeepSeek bu kuraldan etkilenmedi: 500/500.

### 2. Doğrulanamayan kaynak atfı — bütün havuz

`provenance.method` = `independent-llm-authoring-from-reference-knowledge`.
Yani model kendi belleğinden yazmış. Buna rağmen 80 DeepSeek kaydı belirli
akademik kitaplara atıf taşıyor:

    33  Philip G. Kreyenbroek & Christine Allison, Kurdish Culture and Identity
    32  Mehrdad Izady, The Kurds: A Concise Handbook
    15  Bordwell & Thompson, Film Art: An Introduction

Kitaplar gerçek; ama bu iddiaların o kitaplardan geldiğine dair kanıt yok —
sayfa, baskı, URL yok. `sourceReference` alanlarının tamamı
`internal:...#gate=...` ya da `textbook:...#hash=...` biçiminde, yani
üreten hattı işaret eden iç künyeler; kaynak değil.

Bu, §7'nin "sahte kaynak üretme" kuralının tam hedefi. Atıflar olduğu gibi
bırakılamaz: **gerçek olmayan bir kaynak zincirini gerçekmiş gibi
sunardı.** 65'i (Kreyenbroek + Izady) tam da §7'nin en sıkı fact-check
istediği Kürt tarihi/kültürü alanında — yani en zayıf kaynaklı kayıtlar en
sıkı doğrulama gerektiren kayıtlarla çakışıyor.

Karar: bu atıflar korunmayacak. İki yol var ve kayıt bazında seçilecek:
sabit ve bağımsız doğrulanabilir bilgi ise, aktive edilmiş 218'de olduğu
gibi dürüst iç künye (`internal:...#gate=...`, `reviewedBy: automated`)
yazılır ve kitap atfı **kaldırılır**; doğrulanamıyorsa
`QUARANTINED_UNVERIFIABLE`.

### 3. Kürdistan terminolojisi ve editoryal perspektif

`tool/content_authoring/audit_kurdistan_terminology.py` (raporlar,
değiştirmez):

    aday havuzu (907)          canlı bankalar (2050)
    TERMINOLOGY_OK      375    TERMINOLOGY_OK    1066
    NOT_APPLICABLE      414    NOT_APPLICABLE     818
    ENDONYM_REWRITE      98    ENDONYM_REWRITE     90
    POLITICAL_STATUS     48    POLITICAL_STATUS     9
    REGION_FRAME         19    REGION_FRAME        50
    incelenecek         118    incelenecek        121

Örnek `POLITICAL_STATUS_QUESTION_REJECTED`:

    grok26_geo_nature_0047  "Van Gölü hangi ülkededir?"
    grok26_geo_nature_0050  "Ağrı Dağı esas olarak hangi ülkededir?"

Bunlar §3.4 gereği doğrudan kabul edilmez; Kürdistan'ın hangi parçasında
olduğu, komşu şehirler, akarsular, kültürel bağlam üzerinden yeniden
yazılır ya da karantinaya alınır.

**Canlı bankalardaki 121 kayıt bu turda DEĞİŞTİRİLMEDİ.** "Eski doğru
soruları sessizce değiştirme" kuralı gereği ayrı ve açık bir inceleme
turu gerektirir. Bu turda yalnız görünür kılındılar.

## Aktive edilen

Bu turda **hiçbir dış aday aktive edilmedi.** Loader toplamı değişmedi:
2050 fiziksel, 2050 benzersiz ID, 218 genişletme kaydı.

Sebep: §12 aktivasyon kapısı "provenance %100" ister ve §7 sahte kaynağı
yasaklar. 907 adayın **hiçbirinde** doğrulanabilir kaynak yok. Kaynak
sorunu kayıt bazında çözülmeden batch aktive etmek, kapıyı biçimsel olarak
geçip anlamca çiğnemek olurdu.

## Devam noktası

Sıradaki iş, §11 sırasına göre **Sînema (DeepSeek batch_01, 125 kayıt)**:

1. 125 kaydın her birinin olgusunu bağımsız doğrula (sinema dilbilgisi
   ağırlıklı; çoğu sabit ve doğrulanabilir).
2. `Bordwell & Thompson` atfını kaldır; dürüst iç künye yaz.
3. Doğrulanamayanı `QUARANTINED_UNVERIFIABLE` yap.
4. `validate_batch` → terminoloji → tipografi → semantic duplicate →
   question-quality → runtime loader → hedefli quiz testi.
5. `content(intake): review external cinema candidates` olarak commit et.

Grok havuzu için sıradaki iş: 296 kaydı `REJECTED_LOW_QUALITY`
(distractor-self-labeled) olarak işaretlemek ve kalan 111'i aynı hattan
geçirmek.

Girdi dosyaları salt-okunur olarak
`scratchpad/external_authoring/opus_intake_2026_08/raw/` altında;
envanter `inventory.json`, terminoloji manifestleri
`terminology_review.json` ve `terminology_review_live.json`.
