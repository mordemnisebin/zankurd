# ZanKurd — Denetim Errata (2026-08-02)

Bu dosya, **2026-08-01 tarihli Aşama 1 denetim raporlarındaki** iç çelişkileri
ve hatalı sayıları düzeltir.

- Düzeltmeyi yapan aşama: Aşama 2 (2026-08-02)
- Düzeltilen raporlar: `ZANKURD_RELEASE_READINESS_AUDIT.md`,
  `ZANKURD_PRIVACY_DATA_MAP.md`, `ZANKURD_FINDINGS.json`
- **Uygulama kodu bu errata nedeniyle DEĞİŞTİRİLMEMİŞTİR.** Buradaki
  düzeltmelerin tamamı rapor metnine yöneliktir.
- Aşama 1 raporları tarihsel kanıt olarak korunur; stil amaçlı yeniden yazım
  yapılmamış, yalnız kanıtlanmış yanlışlar düzeltilmiştir.

---

## E-01 — Secret taraması: "temiz" ifadesi ile P0-001 çelişiyordu

**Eski ifade** (ana rapor §6.1):

> "### 6.1 Secret taraması — temiz"
> "**Sonuç: P0 secret bulgusu yok.**"

Aynı raporun §8'i ise `ZKR-REL-20260801-P0-001`'i doğrulanmış P0 olarak
listeliyordu. İki ifade doğrudan çelişiyordu.

**Neden oluştu:** §6.1, taramanın yapıldığı sırada geçerliydi — o tarama
**dosya adına** dayanıyordu (`*.env*`, `key.properties`, `*.jks`, `*.p8`,
`*serviceAccount*`). Sır ise bir kabuk betiğinin (`deploy_ftp.sh`) içindeydi
ve ad tabanlı taramaya yakalanmadı. P0 daha sonra içerik tabanlı arama
(`git log -S`) ile bulundu, fakat §6.1 başlığı güncellenmedi.

**Yeni doğrulanmış ifade** — üç zaman dilimi ayrılmalıdır:

| Kapsam | Durum |
|---|---|
| Güncel HEAD ve takip edilen güncel dosyalar | **TEMİZ** — doğrulanmış sır yok |
| Git geçmişi | **KİRLİ** — `deploy_ftp.sh:3-5` (commit `e8e358a^`) doğrulanmış üretim FTP kimlik bilgisi taşıyor |
| Aktif kimlik bilgisi riski | **GİDERİLDİ** — parola sahibi tarafından 2026-08-02'de Hostinger panelinden değiştirildi (owner-confirmed) |
| Geçmiş kalıntısı | **AÇIK** — history scrub ayrı ve yedekli bir aşamaya ertelendi |

**Kanıt:**
- `git show e8e358a^:zankurd_mobile/deploy_ftp.sh` satır 3-5 (değer maskeli)
- Commit `e8e358a` gövdesi: *"Not: Sızan FTP şifresi git GEÇMİŞİNDE hâlâ
  mevcut — Hostinger'dan şifre değiştirilmeli."*
- 2026-08-02 doğrulaması: `.env.deploy` içinde **hiçbir parola alanı yok**;
  dağıtım SSH anahtarına (`SFTP_IDENTITY_FILE`) geçmiş. Eski kimlik bilgisi
  ne `.env.deploy`da ne de takip edilen herhangi bir dosyada bulunuyor
  (SHA-256 karşılaştırması; sonuç **DIFFERENT/superseded**).

**Bulgu sayısına etkisi:** Yok. P0-001 zaten §8'de sayılıydı; yalnız §6.1
başlığı ve sonuç cümlesi yanlıştı.

---

## E-02 — Analytics rızası: tek bir "VERIFIED PASS" satırı yanıltıcıydı

**Eski ifade** (gizlilik haritası §8 özet tablosu):

> "| Analytics rızası | `VERIFIED PASS` — varsayılan **kapalı** (opt-in) |"

Bu tek satır, iki farklı mekanizmayı tek bir sonuca indirgiyordu.

**Yeni doğrulanmış sınıflandırma — iki ayrı satır:**

| Mekanizma | Durum | Kanıt |
|---|---|---|
| Firebase Analytics **özel/custom olayları** | **VERIFIED PASS** | `lib/main.dart:207` → `if (analyticsConsentProvider.enabled) { … AnalyticsService.instance.initialize() … }`. Rıza yoksa servis hiç başlatılmaz; `logEvent` yolundan olay gitmez. Varsayılan `false` (`analytics_consent_provider.dart:9,22`). |
| Firebase **native automatic collection** | **VERIFIED FAIL → P2-008 AÇIK** | `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` anahtarı ne `ios/Runner/Info.plist`te ne `android/app/src/main/AndroidManifest.xml`te var. Yerel SDK `Firebase.initializeApp()` ile varsayılan olarak açıktır ve `first_open` / `session_start` / `app_open` toplar. `AnalyticsService.disable()` (`analytics_service.dart:31-40`) yalnız rıza **geri çekildiğinde** çağrılır; hiç verilmemişken çağrılmaz. |

**Bulgu sayısına etkisi:** Yok. P2-008 Aşama 1'de zaten kaydedilmişti; düzeltme
yalnız özet tablosundaki tek satırlık indirgemeyi ikiye ayırıyor.

**Kod değişikliği:** Yapılmadı. P2-008 Aşama 2 kapsamı dışındadır ve **AÇIK**
kalmaktadır.

---

## E-03 — Gerçek cihaz ekran görüntüsü sayısı tutarsızdı

**Eski ifadeler:**

- Ana rapor §4.1 tablosu: Android **9** + iOS **5** + iPad **2** = **16**
- Ana rapor §4.2 metni: *"Gerçek cihazda görüntülenen toplam: 16 ekran görüntüsü"*
- Ekran matrisi (`SCREEN_MATRIX.md`): *"Gerçek cihazda görüntülenen ekran görüntüsü: 16"*
- Terminal özeti: **18**

**Yeniden sayım (dosya sisteminden, 2026-08-02):**

```
audit_artifacts/release_audit_2026-08-01/screenshots/android/*.png   13
audit_artifacts/release_audit_2026-08-01/screenshots/ios/*.png        5
audit_artifacts/release_audit_2026-08-01/screenshots/tour_render/*.png 77
web_fallback/                                                          0
```

İçerik hash'i (SHA-256) ile kontrol: **18 benzersiz görüntü, 0 kopya grubu**,
20 KB altında (boş/başarısız olabilecek) **0 dosya**.

**Yeni doğrulanmış sayılar:**

| Ortam | Cihaz | Sayı |
|---|---|---|
| Android gerçek emülatör | Pixel 7 AVD · Android 16 / API 36 | **13** |
| iOS gerçek simülatör | iPhone 17 · iOS 26.5 | **3** |
| iPadOS gerçek simülatör | iPad Pro 13" (M5) · iOS 26.5 | **2** |
| **Gerçek cihaz toplamı** | | **18** |
| Test-renderer (tamamlayıcı) | Flutter test harness | **77** |
| **Genel toplam** | | **95** |

**Hata neredeydi:** Terminal özetindeki **18 doğruydu**. Ana rapordaki
**16 yanlıştı** — Android sayısı 13 yerine 9 yazılmıştı (`10_firstrun_t10`,
`10_firstrun_t20`, `20_offline_home`, `22_after_onboarding` dosyaları
sayılmamıştı). iOS için "5" değeri iPhone+iPad toplamıydı ama tabloda
yalnız iPhone satırına yazılmış, iPad ayrıca 2 olarak eklenince iOS iki kez
sayılmış gibi görünmüştü; doğru ayrım iPhone 3 + iPad 2'dir.

**Bulgu sayısına etkisi:** Yok. Hiçbir bulgu ekran sayısına dayanmıyor.

---

## E-04 — "Ek A doğrulanmadı" etiketinin kapsamı netleştirildi

**Eski ifade:** Ana raporun yönetici özeti *"~110 ek aday bulgu"* diyor, Ek A
başlığı ise *"BAĞIMSIZ DOĞRULANMADI"*.

**Netleştirme:** Ek A'daki adaylardan **üçü** Aşama 1 içinde bağımsız olarak
doğrulanmış ve §8'e gerçek bulgu olarak yükseltilmiştir (P0-001, P2-008,
P2-009). Ek A tablosu bunu §A.1'de zaten listeliyor, fakat yönetici özetindeki
"~110 aday" ifadesi bu ayrımı içermiyordu.

**Doğru ifade:** Paralel analiz ~110 aday üretti; 3'ü doğrulanıp bulguya
dönüştürüldü, kalanlar **doğrulama kuyruğu** olarak Ek A'da durmaktadır ve
**düzeltme gerekçesi değildir**.

**Bulgu sayısına etkisi:** Yok.

---

## E-05 — Aşama 1'de "supabase-backend" boyutu eksik kaldı

**Kayıt:** Aşama 1'de çalıştırılan 12 paralel analiz ajanından biri
(`audit:supabase-backend`) API hatasıyla düştü (`11 done / 1 error`). O boyut
Aşama 1 ana raporunda **elle** incelenmiştir (§6.2: 105 dosyalık `supabase/`
envanteri, `applied.md` analizi, RLS/SECURITY DEFINER sayımı, istemci–sunucu
çapraz doğrulaması).

**Sonuç:** Supabase boyutu için paralel ajan kapsamı **YOK**; elle inceleme
**VAR**. Uzak şema ↔ migration drift zaten `P2-002 / INCONCLUSIVE` olarak
kayıtlıdır. Bu errata yalnız kapsam boşluğunu açıkça kayda geçirir.

**Bulgu sayısına etkisi:** Yok.

---

## Bulgu sayıları — errata sonrası (değişmedi)

| Seviye | Sayı |
|---|---|
| P0 | 1 |
| P1 | 4 |
| P2 | 9 |
| P3 | 5 |

Bu errata **hiçbir bulguyu eklemedi, kaldırmadı veya seviyesini değiştirmedi.**
Yalnız ifade doğruluğu ve sayım hataları düzeltildi.

Bulgu **durumlarındaki** (status) Aşama 2 güncellemeleri ayrı dosyadadır:
`docs/release_audit/2026-08-02/ZANKURD_PHASE2_RELEASE_BLOCKERS_REMEDIATION.md`
