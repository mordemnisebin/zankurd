# ZanKurd — Aşama 2: Yayın Engellerini Giderme Raporu

**Çalışma tarihi:** 2026-08-02
**Kapsam:** P0-001 aktif risk giderme · P1-004 biçim · P1-003 soru kalitesi kapısı ·
P1-001 imzalı Android release AAB · Aşama 1 rapor tutarlılığı

> Bu aşamada **hiçbir ürün özelliği, tasarım, sürüm numarası veya bağımlılık
> değiştirilmemiştir.** Kapsam dışı bırakılan kalemler (iPad düzeni, Analytics/AD_ID,
> RevenueCat, Supabase migration, git history temizliği, Ek A adayları) bilerek
> ellenmemiştir.

---

## 1. Başlangıç snapshot'ı

| Alan | Değer |
|---|---|
| Depo kökü | `/Users/kocer/Projects/zankurd` |
| Flutter uygulaması | `zankurd_mobile/` |
| Başlangıç branch'i | `main` |
| Başlangıç HEAD | `5c79000513e1148b55588dabe0ed923f833b4cb3` **(beklenen SHA ile eşleşti)** |
| Çalışma branch'i | `fix/release-blockers-2026-08-02` (yeni oluşturuldu; main'e dokunulmadı) |
| Worktree (başlangıç) | Temiz — yalnız `audit_artifacts/` ve `docs/release_audit/` untracked |
| `git diff --check` | Temiz |
| origin | `/Users/kocer/Downloads/zankurd-mac-aktarim.bundle` (yerel bundle; genel remote **değil**) |

### 1.1 Yedekler (kod değiştirilmeden önce alındı)

| Yedek | Yol | Boyut | SHA-256 | Doğrulama |
|---|---|---|---|---|
| Git bundle (`--all`) | `~/Documents/ZanKurd-Backups/zankurd-pre-phase2-20260802-012620.bundle` | 157 641 153 B | `f147cd6454e6196538610faa473113d3a9376197242ce22d45e7c48e1358d330` | `git bundle verify` → *"The bundle records a complete history."* · `HEAD 5c79000…` · `refs/tags/v1.9.1-internal.1` |
| Denetim arşivi | `~/Documents/ZanKurd-Backups/zankurd-audit-pre-phase2-20260802-012620.tar.gz` | 28 093 420 B | `b2885b74c2bf04acc8978aec511400efc1238fc36d130e4ae2e9da97870aae5f` | 137 girdi; yalnız `docs/release_audit/2026-08-01/` + `audit_artifacts/release_audit_2026-08-01/` (`build/`, `.dart_tool/` hariç) |

### 1.2 Toolchain

Flutter 3.44.7 · Dart 3.12.2 · Java (Flutter yapılandırması) OpenJDK **17.0.20**
(`/opt/homebrew/opt/openjdk@17/bin/java`) · keytool ✓ · macOS `security` ✓ ·
Android SDK 36 / build-tools 36.0.0 / NDK 28.2.13676358 · **bundletool 1.18.3**
(bu aşamada kullanıcı onayıyla `brew` ile kuruldu; bağımlılığı olan openjdk 26
de kuruldu fakat **Flutter yapılandırması JDK 17'de kaldı** — `flutter doctor -v`
ile doğrulandı).

---

## 2. P0-001 — Üretim FTP kimlik bilgisi

### 2.1 Sahip beyanı

`OWNER_CONFIRMATION_HOSTINGER_PASSWORD_ROTATED = YES` (2026-08-02).

### 2.2 Yerel doğrulama (değerler hiçbir yerde gösterilmedi)

Karşılaştırma SHA-256 üzerinden yapıldı; eski parola komut satırına literal
olarak yazılmadı, hiçbir değer stdout'a basılmadı.

| Kontrol | Sonuç |
|---|---|
| Eski geçmiş kimlik bilgisi `e8e358a^:deploy_ftp.sh`'te var mı? | **PRESENT** (13 karakter, sha256 `018bd779…`) |
| `.env.deploy` git tarafından yoksayılıyor mu? | **EVET** — `zankurd_mobile/.gitignore:57 (.env.*)` |
| `.env.deploy` takip ediliyor mu? | **HAYIR** — `git ls-files` 0 kayıt; dosya modu `600` |
| `.env.deploy` içinde **parola alanı** var mı? | **HAYIR** — hiç yok |
| `.env.deploy` eski kimlik bilgisini içeriyor mu? | **HAYIR** |
| Eski kimlik bilgisi takip edilen çalışma ağacında var mı? | **HAYIR** — 0 dosya |
| **Sonuç** | **`DIFFERENT` (superseded)** |

`DIFFERENT` sonucunun sebebi yalnız "parola değişti" değildir: dağıtım yolu
**tamamen parolasız** hâle gelmiştir. `.env.deploy` artık şu anahtarları taşır
(değerler gösterilmedi): `SFTP_HOST`, `SFTP_USER`, `SFTP_PORT`, `SFTP_PATH`,
`SFTP_EXPECTED_REALPATH`, `SFTP_BACKUP_PATH`, **`SFTP_IDENTITY_FILE`**,
`SFTP_KNOWN_HOSTS_FILE`, `LIVE_SITE_URL`, `LOCAL_DIR`.

### 2.3 Dağıtım yolu

| Dosya | Durum |
|---|---|
| `deploy_ftp.sh` | Artık yalnız 6 satırlık geriye dönük giriş noktası: `exec "$SCRIPT_DIR/deploy_sftp.sh" "$@"`. Kimlik bilgisi içermiyor. |
| `deploy_sftp.sh` | SSH anahtar tabanlı: `-i "$SFTP_IDENTITY_FILE"`, `BatchMode=yes`, `IdentitiesOnly=yes`, `StrictHostKeyChecking=yes`, sabitlenmiş `UserKnownHostsFile`. **Parola yok.** |
| `.env.deploy.example` | Yalnız şablon anahtar adları |
| `.github/workflows/deploy-web-hostinger.yml` | **Artık mevcut değil** — depoda yalnız `flutter_ci.yml` var. FTP parolası referansı HEAD'de tamamen ortadan kalkmış. |
| Takip edilen dosyalarda düz metin parola | **YOK** (desen taraması temiz) |

`deploy_sftp.sh --dry-run` gerçekten salt okunurdur: uzak `mkdir -p`
**yalnız** dry-run olmayan dalda çalışır (satır 183-186), dry-run dalında
`rsync --dry-run` kullanılır. Buna rağmen **çalıştırılmadı**: üretim
sunucusuna bağlanmak bu aşamanın hedefleri için gerekli değildi ve dışa
dönük bir işlemdir.
→ **`NOT RUN — LIVE PRODUCTION CONNECTION NOT REQUIRED FOR THIS PHASE`**

### 2.4 Sınıflandırma

| Boyut | Durum |
|---|---|
| Aktif kimlik bilgisi riski | **`MITIGATED — PASSWORD ROTATED`** |
| Git geçmişindeki eski kayıt | **`OPEN RESIDUAL — HISTORY SCRUB DEFERRED`** |
| Bütünsel P0 durumu | **`MITIGATED / RESIDUAL OPEN`** — `CLOSED` **değil** |

**History cleanup neden ertelendi:** `git filter-repo` 243 push edilmemiş
commit'i ve tüm SHA'ları yeniden yazar; `audit/2026-07-25-live-findings`
branch'i ile `v1.9.1-internal.1` etiketi de etkilenir. Bu, bu aşamanın dar
kapsamıyla birlikte yapılmamalıdır. Ayrıca depo **hiçbir zaman genel bir
remote'a push edilmemiştir** (origin yerel bir bundle dosyasıdır), dolayısıyla
kalıntının maruziyeti yerel dosya sistemine ve `~/Downloads` altındaki 167 MB'lık
bundle dosyasına erişimi olanlarla sınırlıdır. Parola döndürüldüğü için kalıntı
artık **kullanılamaz bir sırdır**.

**History cleanup planı (uygulanmadı):**
1. Tam yedek al (bu aşamada alınan bundle bu amaca hizmet eder).
2. Depo genel bir remote'a açılmadan **önce** `git filter-repo --replace-text`
   ile eski değeri geçmişten sil.
3. `~/Downloads/zankurd-mac-aktarim.bundle` dosyasını ve eski yedekleri imha et.
4. Yeniden yazımdan sonra etiketleri ve branch'leri doğrula.

---

## 3. P1-004 — `dart format` / CI ilk kapısı

CI'nin gerçek komutu `.github/workflows/flutter_ci.yml` içinden okundu ve
**birebir aynı kapsam ve istisna** kullanıldı
(`-not -path './build/*'`, `-not -path '*/.dart_tool/*'`,
`-not -path './lib/src/data/offline_question_bank.dart'`).

| Aşama | Sonuç |
|---|---|
| Ön durum (salt kontrol) | `Formatted 430 files (23 changed)` → **exit 1** |
| Uygulama (`dart format`) | 23 dosya biçimlendirildi → exit 0 |
| `git diff --check` | Temiz (whitespace hatası yok) |
| **Semantik fark kontrolü** | **0 dosyada anlamsal fark** (aşağıya bakınız) |
| Son durum (salt kontrol) | `Formatted 430 files (0 changed)` → **exit 0** ✅ |
| `offline_question_bank.dart` | **Dokunulmadı** (git'te 0 değişiklik) — CI istisnası korundu |

**Semantik eşdeğerlik kanıtı.** 23 dosyanın her biri için `HEAD:<dosya>` ile
çalışma ağacı sürümü, **tüm boşluklar ve kapatıcıdan önceki sondaki virgüller
normalize edilerek** token düzeyinde karşılaştırıldı:

```
files checked: 23
files with NON-formatting (semantic) difference: 0
RESULT: all 23 diffs are pure formatting (whitespace + trailing commas).
```

Görünür hunk'ların tamamı satır birleştirme/bölme ve sondaki virgüldür
(ör. `_questions = [...]` tek satıra indi, uzun kelime listesi satırlara bölündü).

Değişen 23 dosya: `lib/` altında 7 (`question_bank_loader`, `seen_question_store`,
`models/room`, `screens/learning_screen`, `screens/shop_screen`,
`services/question_language_policy`, `widgets/tournament_bracket_widget`),
`test/` altında 15, `tool/screenshots/` altında 1.

**Durum: `FIXED`.**

---

## 4. P1-003 — Soru kalitesi kapısı (baseline)

### 4.1 Ön durum

| Metrik | Değer |
|---|---|
| `gate` çıkışı | **exit 1** — *"Gate source fingerprint changed; baseline metrics were not accepted."* |
| `report` çıkışı | exit 0 |
| Kaynak sayısı (report / gate) | 50 / 5 |
| Gate physical / canonical | **1832 / 1771** (beklenen değerlerle birebir) |
| Gate severity | **blocker 0 · critical 0** · warning 1856 |
| Baseline (önce) | `createdDate 2026-07-15`, blockers 0, criticals 0, **1856** issueFingerprint |
| Fingerprint'i değişen kaynaklar | `community_questions.json`, `editorial_questions.json`, `offline_questions.json` (3/5) |

### 4.2 Kaynak değişikliklerinin doğrulanması

Baseline'ın en son tazelendiği commit (`c901521`) ile çalışma ağacı arasında
kayıt düzeyinde karşılaştırma yapıldı:

| Kontrol | Sonuç |
|---|---|
| Kayıt sayısı | 1779 → 1779 (**+0**); üç dosyanın hiçbirinde değişiklik yok |
| Eklenen / silinen soru | **0 / 0** — ID kümeleri birebir aynı |
| Değişen kayıt | 1033 |
| Değişen alan | **yalnız `answers`** (başka hiçbir alan değişmemiş) |
| `prompt` metni değişen | **0** |
| `correctAnswer` **metni** değişen | **0** |
| Boş soru / eksik seçenek / boş seçenek | 0 / 0 / 0 |
| Tekrarlanan seçenek | 0 |
| `correctAnswer` seçeneklerde yok (wordOrdering hariç) | 0 |
| Encoding / mojibake | 0 |

**Doğru cevap konumu (yayınlanan banka, n=1211):**
öncesi `A=46.8% B=19.2% C=15.5% D=18.5%` → sonrası `A=23.7% B=24.0% C=24.4% D=27.9%`.
Yani değişiklik gerçekten 2026-08-01 **cevap konumu dengeleme** çalışmasıdır.

**51 kayıtta seçenek içeriği de değişmiş** (saf yeniden sıralama değil). Bunlar
`applied.md`'de belgelenen **çeldirici dil düzeltmesidir**
(`2026-08-01_question_distractor_language_fix.sql`): kelime çevirisi
sorularında doğru cevabın dilinde olmayan çeldiriciler aynı dilden olanlarla
değiştirilmiştir (ör. *"Wateya Tirkî ya peyva «pirtûk» kîjan e?"* → Kurmancî
çeldirici `zarok` yerine Türkçe `türkü`). Güvenlik toplamları:

| Kontrol | Sonuç |
|---|---|
| `correctAnswer` metni değişen | **0 / 51** |
| Doğru cevap hâlâ seçenekler arasında | **51 / 51** |
| Seçenek sayısı korunmuş | **51 / 51** |
| Kaldırılan seçeneğin doğru cevap olduğu vaka | **0** (olması gereken) |

Hiçbir soru bozulmamıştır.

### 4.3 Baseline tazeleme

Araç `baseline` modu önce **usage çıktısından okundu**
(`<report|gate|baseline> [--accept-current-debt]`) ve kaynak kodu incelendi:
yalnız `tool/question_quality/baseline.json` dosyasına yazar, soru kaynaklarına
dokunmaz, `--accept-current-debt` olmadan **hiçbir şey değiştirmez**.

| Adım | Sonuç |
|---|---|
| Bayraksız `baseline` (güvenlik kapısı testi) | *"Baseline was not changed. Re-run with --accept-current-debt…"* — hiçbir şey yazılmadı ✓ |
| `baseline --accept-current-debt` | **`baseline delta: blockers 0->0, criticals 0->0, issues 1856->1856`** |

**Sıfır kötüleşme.** Borç kümesi ne büyüdü ne küçüldü.

`baseline.json` diff'i **3 ekleme / 3 silme** — yalnız üç kaynak fingerprint'i:

| Anahtar | Değişim |
|---|---|
| `sourceFingerprints` | 3 anahtar (community/editorial/offline) |
| `issueFingerprints` | 1856 → 1856, **küme birebir aynı** (`identical_set=True`) |
| `blockerCount` / `criticalCount` | 0 → 0 (değişmedi) |
| `createdDate` / `manifestVersion` / `version` / `metrics` | değişmedi |

Soru kaynakları baseline tazelemesinden **etkilenmedi** (git'te 0 değişiklik).

### 4.4 Son durum

| Kontrol | Sonuç |
|---|---|
| `gate` | **exit 0** — *"Question quality gate passed: no regression from baseline."* ✅ |
| Report metrikleri | Ön durumla aynı (1832 / 1771, blocker 0, critical 0) |

**Durum: `FIXED`.**

---

## 5. P1-001 — Android upload key ve imzalı release AAB

### 5.1 Mevcut anahtar araması → yeni anahtar kararı

Yalnız makul konumlar tarandı (sınırsız ev dizini taraması yapılmadı):
depo içi (yoksayılanlar dahil), `~/.zankurd/`, `~/Documents/ZanKurd*`,
`~/Downloads/`, `~/Library/Application Support/ZanKurd/`.

**Sonuç: hiçbir konumda `*.jks`, `*.keystore` veya `key.properties` bulunamadı.**
Sahip, uygulamanın Play Console'a **hiç yüklenmediğini** doğruladığı için
(`OWNER_CONFIRMATION_ZANKURD_NEVER_UPLOADED_TO_GOOGLE_PLAY = YES`) yeni bir
upload key üretmek güvenlidir; önceden kullanılmış bir anahtarla çakışma riski
yoktur. `~/.android/debug.keystore` mevcuttur fakat **kullanılmamıştır**.

**Karar: YENİ upload key oluşturuldu.**

### 5.2 Anahtar üretimi ve parola yönetimi

| Alan | Değer |
|---|---|
| Birincil yol | `~/.zankurd/signing/zankurd-upload.jks` (repo **dışında**) |
| Yedek yol | `~/Documents/ZanKurd-Signing-Backup/zankurd-upload.jks` |
| Alias | `zankurd-upload` |
| Algoritma | RSA **4096** bit, `SHA384withRSA` |
| Geçerlilik | 10.950 gün (2026-08-02 → 2056-07-25) |
| Keystore biçimi | PKCS12 (keytool varsayılanı; JKS'in tescilli biçim uyarısından kaçınmak için bilinçli seçim, AGP tam uyumlu) |
| Sertifika | `CN=ZanKurd, OU=Mobile, O=ZanKurd, L=Istanbul, ST=Istanbul, C=TR` |
| Dosya izinleri | `600` (keystore, yedek, `key.properties`); yedek dizini `700` |
| Parola | 40 karakter, `/dev/urandom` kaynaklı |

**Sertifika SHA-256 parmak izi (açık bilgi):**

```
80:59:2E:73:81:FE:05:2B:0C:E1:49:F2:09:06:0F:32:CC:7B:53:F3:5B:92:E2:FC:39:58:DD:19:32:E8:98:B3
```

**Keystore dosyası SHA-256:** `79196da64915133aafa96b1420758fba352fbf98def581ba1cfd290eb0127744`
— **birincil ve yedek kopyada aynı** (doğrulandı).

Parola güvenliği:
- Parola hiçbir zaman stdout'a yazılmadı; `keytool`a `-storepass:env` /
  `-keypass:env` ile aktarıldı (argv'de görünmez).
- macOS Keychain'de saklanıyor — service `ZanKurd Android Upload Keystore`,
  account = macOS kullanıcı adı.
- Store ve key parolası **aynıdır**. Gerekçe: Gradle `key.properties` her ikisini
  de aynı dosyadan okur; iki farklı parola ek bir güvenlik sınırı sağlamaz çünkü
  ikisi de aynı 600-modlu dosyada durur, buna karşılık kurtarma karmaşıklığını
  ikiye katlar.

> **Süreç notu (dürüstlük kaydı).** İlk denemede parola Keychain'e `stdin`
> üzerinden yazılmaya çalışıldı; komut başarılı döndü fakat **boş bir değer**
> kaydetti. Bu, keystore'un parolasının o kabuk sonlandığında kaybolması
> demekti. Hata, `keytool -list` "keystore password was incorrect" hatasıyla
> yakalandı. Kullanılamaz keystore **silindi** (hiç imzalamamıştı, hiçbir yere
> yüklenmemişti) ve süreç, **parola önce kalıcılaştırılıp round-trip
> doğrulandıktan sonra** keystore üretilecek şekilde yeniden yapıldı.
> Nihai anahtar bu doğrulanmış akışla üretilmiştir.

### 5.3 `key.properties`

| Kontrol | Sonuç |
|---|---|
| Yol | `zankurd_mobile/android/key.properties` |
| İzin | `600` |
| `storeFile` | Repo **dışındaki** keystore'a mutlak yol |
| `git check-ignore` | **Yoksayılıyor** — `zankurd_mobile/android/.gitignore:13:key.properties` |
| `git ls-files` | **0** kayıt (takip edilmiyor) |
| `git status` | **0** satır (görünmüyor) |
| İçerik | Rapora/loga **yazılmadı** |

### 5.4 Release AAB

Kullanılan komut: README'nin "Play Store Build" bölümündeki
`flutter build appbundle --release`.

> **İlk deneme başarısız oldu ve sebebi denetçi hatasıydı.** Derleme
> `GeneratedPluginRegistrant.java:79: package dev.flutter.plugins.integration_test
> does not exist` ile düştü. Kök neden: aynı proje dizininde **eşzamanlı**
> `flutter analyze` çalıştırılmıştı; iki Flutter aracı üretilmiş registrant
> dosyası üzerinde yarıştı ve dev-dependency olan `integration_test` release
> derlemesine sızdı. `.flutter-plugins-dependencies` incelendiğinde
> `integration_test` girdisinin **doğru şekilde** `"dev_dependency": true`
> taşıdığı görüldü — yani proje yapılandırması sağlamdı. Derleme, başka hiçbir
> Flutter süreci çalışmazken tekrarlandı ve **sorunsuz tamamlandı**.
> Bu bir ürün kusuru **değildir**; denetim yöntemi kusurudur ve kayda geçirilmiştir.

| Alan | Değer |
|---|---|
| Yol | `build/app/outputs/bundle/release/app-release.aab` |
| Boyut | **73 530 129 B (73.5 MB)** |
| SHA-256 | `175147659c5177cc7d2fb611bd27fe87d5427751f1ae2be5f4df01a5c75f07bf` |
| `jarsigner -verify` | **`jar verified.`** |
| İmzalayan | `CN=ZanKurd, OU=Mobile, O=ZanKurd, L=Istanbul, ST=Istanbul, C=TR` |
| İmza sertifikası SHA-256 | `80:59:2E:…:98:B3` — **upload key ile birebir aynı** ✓ |
| İmza algoritması | SHA384withRSA (sertifika) / SHA256withRSA + SHA-256 digest (JAR) |
| Debug sertifikası | **0 kayıt** — `Android Debug` hiç geçmiyor ✓ |
| `bundletool validate` | **Geçti** (hata yok) |
| `package` | `com.zankurd.app` |
| `versionName` / `versionCode` | `1.9.1` / `13` |
| min / target / compile SDK | **24 / 36 / 36** ✓ (31 Ağu 2026 Play şartı karşılanıyor) |
| `android:debuggable` | Manifestte **yok** ✓ |
| ABI'ler | `arm64-v8a`, `armeabi-v7a`, `x86_64` (64-bit mevcut ✓) |
| R8 / minify / shrink | **Çalıştı** — `build/app/outputs/mapping/release/mapping.txt` **295 909 satır** |
| Release izinleri | `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `VIBRATE`, `BIND_GET_INSTALL_REFERRER_SERVICE`, **`com.google.android.gms.permission.AD_ID`**, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION` |

`AD_ID` ve Privacy Sandbox izinleri release ikilisinde de mevcuttur —
**P2-001 açık kalmaya devam ediyor** (bu aşamanın kapsamı dışında).

### 5.5 16 KB doğrulaması — bu kez **release AAB'nin kendisinden**

Aşama 1'de debug APK + Flutter cache kullanılmıştı; bu turda doğrudan üretilen
release AAB'nin `base/lib/**` içeriği çıkarılıp `llvm-readelf -lW` ile ölçüldü.

| ABI | Kütüphane | `PT_LOAD p_align` | Karar |
|---|---|---|---|
| arm64-v8a | `libapp.so` | `0x10000` | **PASS** |
| arm64-v8a | `libflutter.so` | `0x10000` | **PASS** |
| arm64-v8a | `libdartjni.so` | `0x4000` | **PASS** |
| arm64-v8a | `libdatastore_shared_counter.so` | `0x4000` | **PASS** |
| x86_64 | `libapp.so`, `libflutter.so` | `0x10000` | **PASS** |
| x86_64 | `libdartjni.so`, `libdatastore_shared_counter.so` | `0x4000` | **PASS** |
| armeabi-v7a | (4 kütüphane) | `0x4000` / `0x10000` | 32-bit — kapsam dışı |

**64-bit ABI'lerde 16 KB uyumsuz kütüphane yok. Statik sonuç: PASS.**

Çalışma zamanı: emülatör `getconf PAGE_SIZE` → **4096**. 16 KB sayfa boyutlu
sistem imajı hâlâ kurulu değil.
→ **`NOT RUN — 16 KB IMAGE NOT INSTALLED`**. Statik PASS, runtime PASS olarak
sunulmamaktadır.

### 5.6 Release smoke (Android 16 emülatörü)

`bundletool build-apks --connected-device` ile **upload key'le imzalı**,
cihaza hedeflenmiş APK seti üretildi (Play'in bu cihaza göndereceği şeyin
eşdeğeri):

| Split | Boyut |
|---|---|
| `base-master.apk` | 15 122 011 B |
| `base-arm64_v8a.apk` | 21 619 080 B |
| `base-xxhdpi.apk` | 67 023 B |
| `base-en.apk` | 20 627 B |
| **Toplam teslim boyutu** | **~36.8 MB** (73.5 MB'lık AAB'den) |

`bundletool install-apks` ile Android 16 / API 36 emülatörüne kuruldu
(`versionCode=13`, `versionName=1.9.1` doğrulandı) ve başlatıldı.

| Kontrol | Sonuç |
|---|---|
| Kurulum | **Başarılı** (debug sürüm önce kaldırıldı — imza farklı) |
| Açılış | **Çöküş yok** |
| `FATAL` / `AndroidRuntime` / `E/flutter` | **0 satır** |
| `dlopen failed` / `couldn't find DSO` / `UnsatisfiedLink` | **0 satır** — native kütüphaneler release'te sorunsuz yükleniyor |
| Ulaşılan ekran | `_ConfigurationErrorApp` — *"Uygulama yapılandırması eksik — Supabase, RevenueCat ayarları bu üretim derlemesine eklenmemiş."* |
| Kanıt | `audit_artifacts/.../screenshots/android/30_release_smoke_01.png` |

**Yorum.** Bu, kusur değil **tasarlanmış korumadır**: `AppConfig.validateForRelease`
release modda Supabase ve (mobilde) RevenueCat yapılandırması yoksa uygulamayı
demo/eksik hâlde açmak yerine açık bir hata ekranına düşürür. Koruma çalıştığı
için işlevsel smoke (onboarding → ana ekran → sekmeler → çevrimdışı) bu ikili
üzerinde **yapılamadı**.

→ Smoke sonucu: **`PARTIAL PASS`** — ikili kurulur, açılır, çökmez, native
kütüphaneler yüklenir; işlevsel akış `BLOCKED — RELEASE DART-DEFINES MISSING`.

### 5.7 Yeni bulgu — üretilen AAB imzalıdır ama **yayına hazır değildir**

`ZKR-REL-20260802-P1-005` · **P1** · `VERIFIED FAIL`

README'nin "Play Store Build" bölümü şu komutu veriyor:

```
flutter build appbundle --release
```

Bu komut **dart-define içermiyor** ve ürettiği AAB çalışma zamanında
yapılandırma hata ekranına düşüyor (5.6'da kanıtlandı). Doğru komut projenin
**başka** belgelerinde mevcut:

- `docs/YAYIN_ADIMLARI.md:171` →
  `flutter build appbundle --release --dart-define-from-file=.env.mobile.release.json`
- `docs/android_signing_setup.md:70` → aynı bayrak

Yani belgeler kendi içinde çelişiyor ve README'deki (eksik) yol izlenirse
**yayınlanamaz bir AAB** üretiliyor.

Ayrıca `.env.mobile.release.json` bu makinede **yok** (yalnız
`.env.mobile.release.example.json` şablonu var). Gerçek değerler yalnız
sahipte olduğu için bu aşamada üretilemez ve **hard-code edilmemiştir**
(kural 10 / durdurma koşulu 7).

**Düzeltme (sahip tarafında):**
1. `cp .env.mobile.release.example.json .env.mobile.release.json` ve gerçek
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY_ANDROID`,
   `REVENUECAT_API_KEY_IOS` değerlerini gir (dosya `.gitignore` kapsamında).
2. `flutter build appbundle --release --dart-define-from-file=.env.mobile.release.json`
3. README'nin "Play Store Build" bölümünü `YAYIN_ADIMLARI.md` ile hizala.

**Durum:** `OPEN — BLOCKED ON OWNER-SUPPLIED RELEASE CONFIG`

### 5.8 P1-001 sonucu

Bulgunun kendisi *"Android release ikilisi üretilemiyor (imzalama varlığı yok)"*
idi. Bu engel kalktı: güvenli bir upload key mevcut, `key.properties`
yapılandırıldı ve **doğrulanmış imzalı bir release AAB üretildi**.

**Durum: `FIXED`** — yayına gönderim ise yeni `P1-005` ile devam ediyor.

---

## 6. Denetim errata

Ayrıntılar: `docs/release_audit/2026-08-01/AUDIT_ERRATA_2026-08-02.md`

| # | Konu | Özet |
|---|---|---|
| E-01 | Secret çelişkisi | §6.1 "temiz" diyordu, §8 P0-001'i doğruluyordu. Sebep: tarama **dosya adına** dayanıyordu, sır bir kabuk betiğinin içindeydi. Yeni ifade üç zaman dilimini ayırıyor: güncel dosyalar temiz / geçmiş kirli / aktif risk giderildi / kalıntı açık. |
| E-02 | Analytics rızası | Tek "VERIFIED PASS" satırı ikiye ayrıldı: **özel olaylar PASS** (`main.dart:207` rıza kapısı), **native auto-collection FAIL** (P2-008 açık). |
| E-03 | Ekran sayısı | Ana rapor 16, terminal 18 diyordu. Dosya sisteminden yeniden sayım + SHA-256 kopya kontrolü: **18 benzersiz** (Android 13 · iPhone 3 · iPad 2), 0 kopya, 0 boş. **18 doğrudur.** |
| E-04 | Ek A kapsamı | ~110 adayın 3'ü Aşama 1'de doğrulanıp bulguya yükseltilmişti (P0-001, P2-008, P2-009); yönetici özeti bu ayrımı içermiyordu. |
| E-05 | Supabase boyutu | Aşama 1'de paralel ajanlardan `supabase-backend` API hatasıyla düştü; o boyut **elle** incelenmişti. Kapsam boşluğu kayda geçirildi. |

**Bulgu sayıları errata sonrası değişmedi:** P0 1 · P1 4 · P2 9 · P3 5.
Errata nedeniyle **uygulama kodu değiştirilmemiştir**.

---

## 7. Kapı sonuçları

CI sırası taklit edilerek çalıştırıldı.

| # | Kapı | Komut | Sonuç |
|---|---|---|---|
| 1 | Biçim (CI kapsamı birebir) | `dart format --set-exit-if-changed $(find … )` | **exit 0** — `430 files (0 changed)` ✅ |
| 2 | Statik analiz | `flutter analyze` | **exit 0** — *No issues found!* ✅ |
| 3 | Soru kalitesi kapısı | `question_quality_audit.dart gate` | **exit 0** — *"no regression from baseline"* ✅ |
| 4 | Testler | `flutter test` | **exit 0** — **+1302 All tests passed**, **0 fail**, **0 skip** ✅ |
| 5 | Web release | `flutter build web --release` | **exit 0** ✅ |
| 6 | iOS release (imzasız) | `flutter build ios --release --no-codesign` | **exit 0** — `Runner.app` 52.0 MB ✅ |
| 7 | Android release AAB | `flutter build appbundle --release` | **exit 0** — 73.5 MB ✅ |
| 8 | AAB doğrulama | `jarsigner -verify` + `bundletool validate` | **Geçti** ✅ |
| 9 | Android release smoke | `bundletool install-apks` + launch | **PARTIAL PASS** — kurulur/açılır/çökmez; işlevsel akış release dart-define eksikliğiyle bloke |

**Test sayısı değişmedi:** Aşama 1'de 1302, Aşama 2'de 1302. Biçimlendirme
davranışsal değişiklik yaratmadığı için bu beklenen sonuçtur ve §3'teki
token düzeyinde eşdeğerlik kanıtını desteklemektedir.

`dart analyze` (CI'nin kullandığı komut) ayrıca çalıştırıldı fakat eşzamanlı
Gradle derlemesi nedeniyle 10 dakikalık kabuk sınırına takıldı; `flutter analyze`
aynı analiz motorunu kullanır ve **No issues found** verdi.
→ `dart analyze` özel olarak: `INCONCLUSIVE — TIMED OUT UNDER LOAD` (analiz
sonucu `flutter analyze` ile kanıtlanmıştır).

---

## 8. Güncel bulgu durumları

| ID | Başlık | Aşama 1 | **Aşama 2 sonu** |
|---|---|---|---|
| `P0-001` | Üretim FTP kimlik bilgisi git geçmişinde | `VERIFIED FAIL` | **`MITIGATED — PASSWORD ROTATED / RESIDUAL HISTORY OPEN`** |
| `P1-001` | Android release ikilisi üretilemiyor (imzalama) | `BLOCKED` | **`FIXED`** — imzalı, doğrulanmış AAB üretildi |
| `P1-002` | iPad destekleniyor ama düzen bitmemiş | `VERIFIED FAIL` | **`OPEN — DEFERRED`** (bilerek kapsam dışı) |
| `P1-003` | Soru kalitesi kapısı başarısız | `VERIFIED FAIL` | **`FIXED`** — gate exit 0 |
| `P1-004` | `dart format` 23 dosyada başarısız | `VERIFIED FAIL` | **`FIXED`** — format exit 0 |
| `P1-005` | Üretilen AAB imzalı ama yayına hazır değil | *(yeni)* | **`OPEN — BLOCKED ON OWNER-SUPPLIED RELEASE CONFIG`** |
| `P2-001` … `P2-009` | — | — | **Hepsi `OPEN`** — bu aşamada hiçbiri ele alınmadı |
| `P3-001` … `P3-005` | — | — | **Hepsi `OPEN`** |

Ek A'daki ~110 aday **doğrulanmamış** olarak kalmaktadır; hiçbirine dokunulmadı.

---

## 9. Güncel readiness

| Alan | Aşama 1 | **Aşama 2 sonu** | Gerekçe |
|---|---|---|---|
| CODE QUALITY READINESS | `NOT READY` | **`READY`** | Format ✅ · analyze ✅ · soru kalitesi kapısı ✅ · 1302/1302 test ✅. CI'nin beş adımı da yerelde yeşil. Açık P0 kalmadı: P0-001'in **aktif** riski giderildi; kalıntı geçmiş kaydı kod kalitesi kapsamında değil ve ayrı bir işe bağlandı. |
| ANDROID BINARY READINESS | `BLOCKED / NOT FULLY VERIFIED` | **`CONDITIONALLY READY`** | İmzalı AAB üretiliyor ve doğrulanıyor; targetSdk 36, 16 KB statik PASS, R8 çalışıyor, cihazda çöküşsüz açılıyor. **Koşul:** release dart-define'ları (P1-005) olmadan üretilen ikili yayınlanamaz; 16 KB runtime doğrulaması ve native debug symbols (P2-003) hâlâ eksik. |
| IOS BINARY READINESS | `NOT READY` | **`NOT READY`** | `--no-codesign` release derlemesi geçiyor, fakat **P1-002 (iPad düzeni) açık**, `DEVELOPMENT_TEAM` yok ve imzalı arşiv doğrulanmadı. |
| GOOGLE PLAY CONSOLE SUBMISSION READINESS | `NOT READY` | **`NOT READY`** | Data Safety formu, Advertising ID beyanı (P2-001), hesap silme URL alanı, içerik derecelendirme ve kapalı test şartı hâlâ hesap düzeyinde yapılmadı. P1-005 de açık. |
| APP STORE CONNECT SUBMISSION READINESS | `NOT READY` | **`NOT READY`** | iPad düzeni ve iPad ekran görüntüleri (P1-002), App Privacy cevapları, demo hesap, yaş derecelendirme — hiçbiri yapılmadı. |

> iPad P1-002 açık olduğu için iOS ve App Store kararları **bilinçli olarak
> READY yapılmamıştır**. Data Safety / App Privacy / hesap düzeyi işlemler
> yapılmadığı için her iki mağaza gönderim durumu da `NOT READY` kalmıştır.

---

## 10. Kalan en yüksek öncelikli işler

| Sıra | İş | Not |
|---|---|---|
| 1 | **Ek A yüksek risk adaylarının bağımsız doğrulanması** | Özellikle A-01 (satın alınamayan mağaza ürünü), A-02 (quiz şık kontrastı WCAG AA altı), A-10 (çıkışsız liderlik ekranı), A-03/A-05/A-06 (avatar/görünen ad UGC moderasyonu) |
| 2 | Doğrulanan privacy / UGC / ekonomi bulgularının düzeltilmesi | 1. adımın çıktısına göre |
| 3 | **iPad tasarım sprinti** (P1-002) | Ya tablet breakpoint ya da `TARGETED_DEVICE_FAMILY="1"` — ürün kararı |
| 4 | Analytics / Advertising ID ve mağaza beyan uyumu | P2-001 + P2-008; `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` ve Data Safety |
| 5 | Android release sertleştirme | P2-003 (native debug symbols), P2-007 (CI'de release derleme), P2-004 (16 KB imajında runtime test), **P1-005 (release dart-define + README hizalama)** |
| 6 | App Store Connect / Play Console metadata ve sandbox testleri | Hesap düzeyi kontrol listesi (`ZANKURD_STORE_COMPLIANCE_MATRIX.md` §3) |
| 7 | **Ayrı ve yedekli git-history cleanup** | P0-001 kalıntısı; depo herkese açılmadan önce zorunlu |
| 8 | Final release candidate doğrulaması | Tüm kapılar + gerçek cihaz + iki istemcili oda maçı |

---

## 11. Bu aşamada değiştirilen dosyalar

**Takip edilen (24):**
- 23 dosya — **yalnız biçimlendirme** (`lib/` 7, `test/` 15, `tool/screenshots/` 1)
- `tool/question_quality/baseline.json` — yalnız 3 kaynak fingerprint'i

**Yeni rapor dosyaları (takip edilen):**
- `docs/release_audit/2026-08-01/AUDIT_ERRATA_2026-08-02.md`
- `docs/release_audit/2026-08-02/ZANKURD_PHASE2_RELEASE_BLOCKERS_REMEDIATION.md`
- `docs/release_audit/2026-08-01/*` içindeki errata düzeltmeleri

**Repo dışında oluşturulan (asla commit edilmez):**
- `~/.zankurd/signing/zankurd-upload.jks`
- `~/Documents/ZanKurd-Signing-Backup/{zankurd-upload.jks,README.md}`
- `~/Documents/ZanKurd-Backups/*.bundle`, `*.tar.gz`
- `zankurd_mobile/android/key.properties` (repo içinde ama **gitignore**'lu, takip edilmiyor)

**Uygulama davranışını değiştiren hiçbir kaynak değişikliği yapılmamıştır.**
