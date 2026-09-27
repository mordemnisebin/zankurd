# Yayın adımları — sıradan şaşma

Bu belge son yayın sırasıdır. Hostinger SSH bağlantısı ve Android upload
anahtarı hazırdır. Supabase tarafında güncel şema staging/preview ortamında
smoke edilmelidir; production migration-history ayrışması çözülmeden üretim
şeması değiştirilmez. Mağaza hesabı ve fiziksel cihaz adımları hesap sahibinde
kalır.

Sırayla git. Her adımın sonunda **"tamam mı?"** satırı var; orası
tutmuyorsa sonrakine geçme.

Tahmini süre: 1. gün ~2 saat (hesap açma beklemeleri hariç), sonra
inceleme bekleyişi (Apple 1-3 gün, Google 1-7 gün).

---

## 0. Önce şunu bir kez çalıştır

Terminalde proje klasöründe:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
dart run tool/validate_release_toolchain.dart
dart analyze
flutter test
```

**Tamam mı?** `Release toolchain geçerli: Flutter 3.44.7.`,
"All tests passed!" ve "No issues found!" görüyorsan evet. Flutter sürümü
farklıysa bağımlılıkların Built-in Kotlin / Swift Package Manager geçişi
tamamlanana kadar o SDK ile release üretme; önce bu kapıyı bilinçli olarak
güncelle ve tüm release doğrulamalarını yeniden çalıştır.

---

## 1. Supabase: staging ve migration-history ön kontrolü

Önce `zankurd_mobile/supabase/applied.md` dosyasına ve tarihli canonical migration
zincirine bak. `20260802000000_multiplayer_session_hardening.sql` production
history'de 2026-08-05'ten beri uygulanmış durumdadır; eski
`supabase/2026-08-02_multiplayer_session_hardening.sql` dosyasını production'a
**yeniden çalıştırma**.

2026-09-09 salt-okunur denetiminde
`20260819000000_gamification_and_custom_rooms.sql` şemada uygulanmış olmasına
rağmen remote migration history'de görünmüyordu. Hesap sahibi onayıyla yalnız
history metadata'sı onarıldı; SQL yeniden çalıştırılmadı ve onarım sonrası
local/remote eşleşmesi tekrar doğrulandı. Herhangi bir production schema
adımından önce yalnız history'yi oku:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
supabase migration list --linked
```

Bu ayrışma yeniden oluşursa **`supabase db push` çalıştırma**, 19 Ağustos
SQL'ini yeniden uygulama ve hesap sahibinin açık onayı olmadan `migration repair`
çalıştırma. Bu bölümdeki staging smoke production history'yi değiştirmez.

Staging/preview projesi güncel canonical şemayı temsil etmelidir. Staging eskiyse
onu yalnız staging üzerinde `supabase/migrations/` altındaki tarihli canonical
zincirle ileri taşı; eski/undated SQL dosyalarını rastgele tekrar oynatma.
Ardından git tarafından yok sayılan ayrı bir staging yapılandırması hazırla;
üretim dosyasını staging turunda kullanma:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
if [ ! -f .env.mobile.staging.json ]; then
  cp .env.mobile.release.example.json .env.mobile.staging.json
fi
```

Şimdi `.env.mobile.staging.json` içindeki `SUPABASE_URL` ve
`SUPABASE_ANON_KEY` değerlerini staging/preview projesinin açık istemci
değerleriyle, RevenueCat alanlarını da sandbox/Test Store **public SDK**
anahtarlarıyla doldur. Service-role veya başka bir sunucu sırrı kullanma.
Kaydettikten sonra değerleri terminale yazdırmayan yapısal doğrulamayı çalıştır:

```bash
dart run tool/validate_release_config.dart --file=.env.mobile.staging.json --target=mobile --environment=staging
```

Bu kapı HTTPS Supabase proje adresini, yalnız publishable/anon rolünü ve iki
RevenueCat platform alanını doğrular. Test Store anahtarı yalnız bu açık
`staging` modunda kabul edilir; production doğrulamasında reddedilir. Kontrol
başarısızsa devam etme. Başarılıysa `flutter devices` ile iki hedefin kimliğini
bul; sonra iki ayrı terminalde şu komutları çalıştır:

```bash
flutter run --release -d <birinci-cihaz-id> --dart-define=APP_ENV=staging --dart-define-from-file=.env.mobile.staging.json
flutter run --release -d <ikinci-cihaz-id> --dart-define=APP_ENV=staging --dart-define-from-file=.env.mobile.staging.json
```

İki ayrı istemciyi iki cihazda çalıştır ve iki ayrı hesap aç. Oda kurma → koda
katılma → iki tarafın hazır olması → oyunun başlaması → cevap/ilerleme →
sonuç/makbuz → uygulamayı kapatıp oturumu geri alma akışını tamamla. Bir iOS
simülatörü release modunu kabul etmezse fiziksel iPhone veya Android hedef
kullan; staging yerine üretim backend'ine dönme. Bu tur bitmeden üretime geçme.

Staging/preview turundan sonra ayrı bir yeni sorguda şu salt-okunur doğrulamayı
çalıştır:

```sql
select
  to_regprocedure('public.create_online_room(text,integer,integer,integer)') is not null
    as oda_olusturma_hazir,
  to_regprocedure('public.get_my_resumable_room()') is not null
    as oturum_kurtarma_hazir,
  to_regprocedure('public.get_my_pending_room_result()') is not null
    as bekleyen_sonuc_hazir,
  to_regprocedure('public.acknowledge_room_result(uuid)') is not null
    as sonuc_onayi_hazir,
  to_regclass('public.room_result_snapshots') is not null
    as sonuc_anlik_goruntusu_hazir,
  to_regclass('public.room_result_receipts') is not null
    as sonuc_makbuzu_hazir;
```

**Tamam mı?** Staging/preview iki istemci turu geçti, altı değerin altısı da
`true` ve `supabase migration list --linked` sonucu ayrıca kaydedildiyse evet.
Bu aşamada production SQL Editor'ünü açma, `supabase/applied.md` dosyasını
değiştirme veya history gap'i otomatik onarmaya çalışma. Herhangi bir doğrulama
beklenenden farklıysa yayına devam etme; önce mevcut şema/history ayrışmasını
incele.

---

## 2. Üretim artefaktlarını dağıtmadan hazırla

Staging doğrulaması bitince yeni istemcilerin bütün üretim artefaktlarını
hazırla. Bu adımda web sitesini değiştirme, mağazaya paket yükleme ve üretim
Supabase göçünü uygulama. Kesim sırasında yeniden derleme yapılmayacak.

### 2a. Web artefaktı

Üç yasal sayfa web derlemesinin **içinde** geliyor (`web/privacy.html`,
`web/terms.html`, `web/delete-account.html` → `build/web/`). Daha önce gerçek
üretim açık istemci değerleriyle doğrulanmış `.env.web.release.json` dosyasını
kullanarak yerel paketi hazırla:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
dart run tool/validate_release_config.dart --file=.env.web.release.json --target=web --environment=production
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env.web.release.json
cmp -s web/privacy.html build/web/privacy.html
cmp -s web/terms.html build/web/terms.html
cmp -s web/delete-account.html build/web/delete-account.html
```

`build/web/` klasörünü bu kesim için sabit tut. Göç uygulanana kadar
`release_web.sh` veya gerçek `deploy_sftp.sh` aktarımını çalıştırma; salt-okunur
`--dry-run` ön kontrolü 2d adımında zorunludur.

### 2b. Android imza anahtarı ve AAB

> **Bu dosyayı kaybedersen Play Store'da uygulamayı bir daha
> güncelleyemezsin.** Var olan anahtarı yeniden üretme veya değiştirme.

Doğrulanmış upload keystore bu makinede
`/Users/kocer/.zankurd/signing/zankurd-upload.jks` yolundadır; alias
`zankurd-upload`, parolaları macOS Keychain'dedir. `android/key.properties`
zaten bu dosyayı gösterir ve git tarafından yok sayılır. Parolaları terminale
yazdırmadan yol ile alias değerini denetle:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
test -f /Users/kocer/.zankurd/signing/zankurd-upload.jks
awk -F= '$1 == "storeFile" || $1 == "keyAlias" { print }' android/key.properties
```

Beklenen iki satır:

```text
storeFile=/Users/kocer/.zankurd/signing/zankurd-upload.jks
keyAlias=zankurd-upload
```

Sertifikayı da Keychain'deki parola istendiğinde girerek doğrula:

```bash
keytool -list -v -keystore /Users/kocer/.zankurd/signing/zankurd-upload.jks -alias zankurd-upload
```

Çıktıdaki sertifika SHA-256 parmak izi şu doğrulanmış değerle **birebir** aynı
olmalı:

```text
80:59:2E:73:81:FE:05:2B:0C:E1:49:F2:09:06:0F:32:CC:7B:53:F3:5B:92:E2:FC:39:58:DD:19:32:E8:98:B3
```

Play Console upload sertifikası kaydı oluştuğunda oradaki SHA-256 da aynı
olmalıdır. Dosya yoksa, değerler veya parmak izi farklıysa yeni anahtar üretme;
yayını durdur ve doğrulanmış anahtarı yedeğinden geri getir.

Mobil release yapılandırmasını örnekten oluştur ve dört açık anahtarı gerçek
üretim değerleriyle doldur. `.env.mobile.release.json` yerel kalır; repoya
eklenmez:

RevenueCat anahtarları release derlemesinde zorunludur. Supabase veya RevenueCat
değeri eksik, şablon, secret, Test Store veya yanlış platform anahtarıysa
production doğrulaması durur; böyle bir AAB mağazaya yüklenebilir bir paket
sayılmaz.

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
if [ ! -f .env.mobile.release.json ]; then
  cp .env.mobile.release.example.json .env.mobile.release.json
fi
```

Dosyayı gerçek üretim istemci değerleriyle doldurup kaydettikten sonra değerleri
yazdırmadan doğrula:

```bash
dart run tool/validate_release_config.dart --file=.env.mobile.release.json --target=mobile --environment=production
```

Doğrulama geçerse AAB'yi üret, imzasını ve bundle yapısını doğrula:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter build appbundle --release --dart-define-from-file=.env.mobile.release.json
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
bundletool validate --bundle=build/app/outputs/bundle/release/app-release.aab
```

Sonunda AAB için `✓ Built`, imza denetiminde `jar verified` ve bundletool
doğrulamasında hata olmayan bir çıktı görmelisin. Ardından `flutter devices` ile
production smoke için ayrılmış Android cihaz kimliğini bul ve mağazaya gidecek
aynı AAB'den cihaza özel APK setini kur:

```bash
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=build/app/outputs/bundle/release/app-release-smoke.apks --connected-device --device-id=<android-smoke-cihaz-id> --ks=/Users/kocer/.zankurd/signing/zankurd-upload.jks --ks-key-alias=zankurd-upload --overwrite
bundletool install-apks --apks=build/app/outputs/bundle/release/app-release-smoke.apks --device-id=<android-smoke-cihaz-id>
```

Bundletool parolaları etkileşimli ister; parolayı komut satırı argümanına veya
loga yazma. Kurulan uygulamayı aç, onboarding/ana ekranın geldiğini ve
"Uygulama yapılandırması eksik" ekranının görünmediğini doğrula. Uygulamayı
cihazda kurulu bırak; production 1v1 turu kesimden sonra aynı kurulumla yapılır.

### 2c. iOS production-config smoke ve App Store arşivi

Fiziksel iPhone kimliğini `flutter devices` ile bul. Önce aynı kaynak ve üretim
yapılandırmasını development imzasıyla release modunda kur:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter run --release -d <iphone-smoke-cihaz-id> --dart-define-from-file=.env.mobile.release.json
```

Onboarding/ana ekranı ve paywall teklif durumunu doğrula; gerçek satın alma
yapma. Flutter oturumunu kapattıktan sonra uygulamayı telefonda kurulu bırak.
Ardından Apple Developer hesabı Xcode'da ekliyken mağaza arşivini açıkça App
Store dağıtım yöntemiyle hazırla; henüz App Store Connect'e yükleme:

```bash
flutter build ipa --release --export-method=app-store --dart-define-from-file=.env.mobile.release.json
```

**App Store IPA doğrudan cihaza kurulmaz.** Production smoke için kullanılan
paket yukarıdaki `flutter run --release` kurulumudur; App Store IPA yalnız
Organizer/Transporter yüklemesi içindir.

### 2d. Geriye uyumsuz göçten önce dağıtım ön kontrolü

Bütün artefaktlar hazırken gerçek aktarım yapmadan SSH, sabit host key, uzak web
kökü, uzak yedek kökü ve rsync erişimini doğrula:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
./deploy_sftp.sh --dry-run
```

Bu komut başarısızsa production migration'ını uygulama. Özellikle uzak yedek
kökü önceden var, yazılabilir ve gerçek yolu web kökünün dışında olmalıdır;
kesim sırasında ilk kez oluşturulmaya veya symlink yönlendirmesine güvenilmez.

**Tamam mı?** `build/web/`, imzası/bundle yapısı doğrulanmış ve Android'e
kurulmuş AAB, fiziksel iPhone'a kurulmuş production-config release, imzalı App
Store arşivi ve başarılı SFTP dry-run aynı kaynak kodundan geldiyse evet.
Bunlardan biri eksikse üretim göçüne geçme.

### 2e. Fiziksel cihaz test kanıtı

CI koşucusu fiziksel cihaz varmış gibi davranmaz. Aday kaynakla aşağıdaki dört
integration testi gerçek hedeflerde tamamla; ayrıntılı host/guest ısıtma sırası
`integration_test/README.md` içindedir:

```bash
flutter test integration_test/local_backend_1v1_test.dart -d <host-cihaz-id> --dart-define-from-file=.env.mobile.local.json --dart-define=ZK_ROLE=host
flutter test integration_test/local_backend_1v1_test.dart -d <guest-cihaz-id> --dart-define-from-file=.env.mobile.local.json --dart-define=ZK_ROLE=guest --dart-define=ZK_ROOM_CODE=<host-logundaki-kod>
flutter test integration_test/revenuecat_roundtrip_test.dart -d <ios-cihaz-id> --dart-define-from-file=.env.mobile.local.json
flutter test integration_test/notification_real_schedule_test.dart -d <ios-cihaz-id>
flutter test integration_test/os_level_resilience_test.dart -d <android-cihaz-id> --dart-define-from-file=.env.mobile.local.json --dart-define=ZK_PHASE=setup
adb shell am force-stop com.zankurd.app
flutter test integration_test/os_level_resilience_test.dart -d <android-cihaz-id> --dart-define-from-file=.env.mobile.local.json --dart-define=ZK_PHASE=resume
```

1v1 host ve guest koşuları eşzamanlıdır; host logundaki `ZK_ROOM_CODE` guest
komutuna verilir. `os_level_resilience_test.dart` için setup/resume arasında
gerçek `force-stop` zorunludur. RevenueCat turunda sandbox/Test Store dışında
gerçek ücret çekme; mağaza satın alma ekranı ayrıca manuel smoke kapsamında
kontrol edilir.

Kanıt şablonunu yerel dosyaya kopyala. Cihaz testlerine başlamadan hemen önce
aday kaynağın parmak izini üretip `source_fingerprint` alanına yaz. `version`
alanını `pubspec.yaml` ile birebir eşleştir, yalnız gerçekten geçen testleri
`passed: true` yap ve her testte kullanılan cihazı yaz:

```bash
cp .release-device-evidence.example.json .release-device-evidence.json
dart run tool/validate_device_release_evidence.dart --print-source-fingerprint
dart run tool/validate_device_release_evidence.dart --file=.release-device-evidence.json
```

`.release-device-evidence.json` git tarafından yok sayılır. Validator dört
testin tamamını, ISO tarihini, aday sürümü ve release girdilerinin SHA-256
parmak izini doğrulamadan sıfır çıkış kodu vermez. Cihaz testlerinden sonra
`lib`, `assets`, `android`, `ios`, `pubspec.yaml`, `pubspec.lock` veya mobil
release yapılandırması değişirse eski kanıt bilinçli olarak geçersiz olur.

**Tamam mı?** Validator `4/4` geçti ve Android/iPhone production-config smoke
kurulumları da aynı aday kaynaktan geldiyse evet. Bu kapı eksikse mağaza
yüklemesine geçme.

---

## 3. Koordineli üretim kesimi

Bu göç yeni `ready` protokolü ile RPC imzalarını birlikte değiştirir. Herhangi bir
legacy istemci — eski web dağıtımı, mağaza/test paketi veya doğrudan
kurulmuş mobil sürüm — üretime erişebiliyorsa **migration'ı uygulama**. Önce
bakım modu ile erişimi kesen ve minimum sürüm/zorunlu güncelleme uygulayan bir
geçiş planı gerekir. Planı yalnızca yazmak yetmez: legacy erişimin gerçekten
kesildiğini üretimde doğrulamadan migration'ı uygulama. Yalnızca gerçekten ilk
yayın yapılıyorsa ve
**public legacy istemci yok** ise aşağıdaki koordineli kesime devam et.

2026-08-05 production rollout kaydı tamamlandı: aşağıdaki iki migration
production history’de birer kez uygulanmış ve `supabase/applied.md` içinde
kanıt notuyla kayıtlıdır. Bu rollout için aynı SQL’i production’a yeniden
çalıştırma; yalnız repo dışı local clone replay’i doğrulama amacıyla kullan.

İlerletme yetki sözleşmesi özellikle host-only değildir: `start_room_game`
host-only kalır; `advance_room_question(uuid, integer)` ise oda üyeliği ve
`p_expected_question_index` CAS’i ile korunur. Host bağlantısı koparsa guest’in
aynı güvenli retry yolunu kullanması beklenen davranıştır.

Kesim penceresinde sırayı değiştirme:

1. Önce migration history'yi yalnızca oku:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
supabase migration list --linked
```

   `20260801000000`–`20260811000000` satırları local/remote eşleşmelidir.
   2026-09-09 denetiminde `20260819000000_gamification_and_custom_rooms.sql`
   önce yalnız local tarafta görünüyordu; hesap sahibi onayıyla yalnız
   migration-history kaydı eşitlendi ve onarım sonrası local/remote eşleşti.
   Aynı SQL'in kaynak dosyası `supabase/2026-08-19_gamification_and_custom_rooms.sql`
   canlıda uygulanmış ve `supabase/applied.md` içinde postflight kanıtıyla kayıtlıdır.

2. Bu history gap çözülmeden **`supabase db push` çalıştırma** ve
   `2026-08-19_gamification_and_custom_rooms.sql` dosyasını yeniden uygulama.
   Eski fonksiyon tanımları daha yeni production sözleşmelerini geri yazabilir.
   Önce canlı şema ile canonical SQL'in beklenen durumunu yeniden doğrula;
   ardından hesap sahibi açıkça onaylarsa yalnız migration-history kaydını
   eşitlemek için şu işlem kontrollü olarak değerlendirilir:

```bash
supabase migration repair --status applied 20260819000000
```

   Bu komut production migration history'yi değiştirir; salt-okunur denetimin
   parçası değildir ve açık onay olmadan çalıştırılmaz.

3. `2026-08-02_multiplayer_session_hardening.sql`,
   `2026-08-03_streak_freeze_idempotency.sql` ve üç adet 2026-08-06 göçü
   production'da uygulanmış ve `supabase/applied.md` içinde doğrulanmıştır.
   Bunları yeniden çalıştırma. Aşağıdaki salt-okunur postflight sorgularıyla
   mevcut production sözleşmesini doğrula; bir sonuç beklenenden farklıysa
   yayın kesimini durdur ve kök nedeni incele.

4. Yukarıdaki altı alanlı salt-okunur sorguyu yeni bir sorguda üretimde
   çalıştır. Altı değerden biri bile `false` ise istemci dağıtma ve sorunu
   incele. Dondurma göçünü ve 2026-08-06 göçlerini ayrıca doğrula:

```sql
select count(*) = 1 as spend_streak_freeze_var
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'spend_streak_freeze';

-- 2026-08-06 denetimi: dördü de true olmalı
select
  (select pg_get_functiondef(oid) like '%''neon''%'
     from pg_proc where proname = 'protect_paid_profile_cosmetics')
    as neon_frame_allowed,
  (select pg_get_functiondef(oid) not like '%''Player''%'
     from pg_proc where proname = 'add_friend')
    as friend_identity_real,
  (select count(*) = 1 from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_client_insert_authority_trg')
    as profile_insert_guarded,
  (select array_to_string(proacl, ' | ') not like '%authenticated=X%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'finalize_weekly_league')
    as league_finalize_locked;
```

5. Daha önce hazırlanmış `build/web/` çıktısını yeniden derlemeden güvenli
   ön kontrol ve aktarım ile yayınla:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
./deploy_sftp.sh --dry-run
./deploy_sftp.sh
```

5. 2b ve 2c adımlarında Android ile fiziksel iPhone'a kurulmuş release
   uygulamalarını yeniden aç; App Store IPA'yı cihaza kurmaya çalışma. İki ayrı
   hesapla **Üretim iki istemci smoke** turunda oda kurma → koda katılma → iki
   tarafın hazır olması → oyun → sonuç/makbuz → uygulamayı kapatıp oturumu geri
   alma akışını tamamla. Android host/iOS guest ve iOS host/Android guest
   yönlerini ayrı ayrı dene.
5. Salt-okunur üretim sorgusu ve iki yönlü smoke geçtikten sonra göçü
   `supabase/applied.md` dosyasına tarih/kanıt notuyla `✅` olarak kaydet.

Web aktarımı parola kullanmaz, hedefin gerçek yolunu doğrulamadan başlamaz,
değişen uzak dosyaları web kökü dışındaki tarihli yedeğe alır ve uzak dosyaları
topluca silmez. Smoke sırasında canlı sayfaların içeriğini de doğrula:

- `https://www.zankurd.com/terms.html` → başlıkta **"Kullanım Koşulları ·
  Mercên Bikaranînê"** yazmalı.
- `https://www.zankurd.com/privacy.html` → 4. maddede **"Ayarlar → Hesap
  → Hesabımı Sil"** yazmalı.
- `https://www.zankurd.com/delete-account.html` → **"Hesap Silme ·
  Jêbirina Hesabê"** başlığı ve talep düğmesi görünmeli.

**Tamam mı?** Üretim RPC kontrolü, web içeriği ve iki yönlü 1v1 smoke geçti;
`applied.md` kaydı da yalnız bu kanıtlardan sonra yazıldıysa evet. Aksi halde
mağaza yüklemelerine geçme.

---

## 4. Google Play

### 4a. Uygulamayı oluştur
[play.google.com/console](https://play.google.com/console) → **Uygulama
oluştur** → ad `ZanKurd`, dil Türkçe, **Uygulama**, **Ücretsiz**.

### 4b. AAB yükle
**Test ve yayınla → Test → Dahili test → Yeni sürüm oluştur** →
`app-release.aab` dosyasını sürükle.

Sürüm notlarına `docs/release_notes_internal.md` içeriğini koy.

### 4c. Formlar
Sol menüde **Politika → Uygulama içeriği**. Cevapların madde madde
`docs/play_console_submission_checklist.md` içinde. Kısaca:

- **Reklam:** Hayır, reklam yok.
- **İçerik derecelendirmesi:** Anket → kategori "Eğitim/Bilgi yarışması".
  Şiddet/cinsellik/kumar sorularına hayır.
- **Hedef kitle:** Çocuklara yönelik **değil** işaretle (Families
  politikası ayrı bir yük, şu an hazır değiliz).
- **Veri güvenliği:** Uzun form. Ne toplandığı listesi checklist'te var;
  hepsi "şifreli aktarılıyor" ve "kullanıcı silebiliyor" işaretlenmeli.
- **Gizlilik politikası:** `https://www.zankurd.com/privacy.html`

### 4d. Mağaza listesi
**Büyüme → Mağaza listesi**. Metinler `docs/store_listing.md` içinde
hazır — kopyala yapıştır.

Ekran görüntüleri: `docs/screenshots/store/tr/` klasöründeki 6 yayın dosyası.
`05_word_order.png` editör onayı bekleyen özelliği gösterdiği için yüklenmez;
diğer altı dosyayı kullan. Play en az 2 tane ister.

Play için gereken iki ek görsel de hazır:
- **Uygulama simgesi** 512×512 PNG →
  `zankurd_mobile/web/icons/Icon-512.png` dosyasını kullan.
- **Öne çıkan grafik** 1024×500 →
  `zankurd_mobile/docs/store-assets/play-feature-graphic.png` dosyasını kullan.

**Tamam mı?** Play Console'da hiçbir yerde kırmızı ünlem kalmadıysa evet.

---

## 5. App Store

### 5a. Uygulama oluştur
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Uygulamalarım
→ +** → Platform iOS, ad `ZanKurd`, birincil dil Türkçe, paket kimliği
`com.zankurd.app`.

### 5b. Abonelik ürününü tanımla
**Özellikler → Abonelikler**. Uygulamadaki abonelik RevenueCat üzerinden
çalışıyor; App Store Connect'te ürün tanımlı değilse paywall boş görünür.

### 5c. Yükle
2c adımında hazırlanmış imzalı iOS arşivini aç:

```bash
open build/ios/archive/Runner.xcarchive
```

Xcode Organizer'da **Distribute App → App Store Connect** yolunu izle.
Alternatif olarak `build/ios/ipa/` altındaki `.ipa` dosyasını Transporter ile
yükleyebilirsin.

Apple Developer hesabın Xcode'da ekli olmalı (Xcode → Settings →
Accounts).

### 5d. Formlar
- **Uygulama Gizliliği:** `ios/Runner/PrivacyInfo.xcprivacy` dosyasında
  ne beyan ettiysek aynısını işaretle (hesap kimliği, e-posta, ad, avatar,
  oda mesajları, soru önerileri, oyun/eşleştirme içeriği, ürün etkileşimi,
  uygulama kurulum tanımlayıcısı, çökme, satın alma).
  Satın alma için **Uygulama İşlevselliği + Analiz** seç; hiçbiri "izleme" değil.
- **Gizlilik politikası URL'si:** `https://www.zankurd.com/privacy.html`
- **Kullanım koşulları (EULA):** `https://www.zankurd.com/terms.html`
- **Yaş derecelendirmesi:** anket, hepsine "yok/hiç".
- **İhracat uyumluluğu:** sormayacak — kodda beyan ettik.
- **İnceleme notu:** iOS sürümünde giriş **Apple, Google, e-posta/şifre ve
  misafir** seçenekleriyle yapılır. Reviewer paketi ve App Store Connect notu
  gönderilen binary'de gerçekten görünen bu dört yolu aynı biçimde anlatmalı.

### 5e. Metin ve görseller
`docs/store_listing.md` içindeki App Store bölümü. Ekran görüntüleri
`docs/screenshots/store/tr/` (6,9" boyutu, doğru ölçüde; `05_word_order.png`
hariç).

**Tamam mı?** "İncelemeye gönder" düğmesi aktifse evet.

---

## 6. Göndermeden önce: gerçek cihazda bir tur

Bunu ben yapamam; simülatörde görünmeyen donanım ve mağaza davranışları var.
2c adımında fiziksel iPhone'a kurulmuş production-config release uygulamasını
yeniden aç. App Store IPA'yı sideload etmeye çalışma.

Bak:

1. **Bildirim ikonu.** Ayarlar'dan günlük hatırlatmayı aç, saatini birkaç
   dakika sonrası yap, uygulamayı kapat, bildirimi bekle. İkon turuncu
   ZanKurd amblemi olmalı — **beyaz kare değil**. (Bunu düzelttim ama
   yalnız cihazda doğrulanabilir.)
2. **Abonelik.** Paywall'ı aç, sandbox hesabıyla satın al. Fiyat
   görünüyor mu, satın alma bitiyor mu, "Satın alımları geri yükle"
   çalışıyor mu.
3. Bir tur oyna, sonuç ekranına kadar git.

**Tamam mı?** Üçü de düzgünse gönder.

---

## Sonra ne olur

- Play dahili testte birkaç saatte, üretimde 1-7 günde çıkar.
- Apple incelemesi genelde 1-3 gün. Reddederlerse gerekçeyi bana
  yolla — çoğu ret metin/form kaynaklıdır, kod değişmeden çözülür.

## Bir dahaki sürümde

Önce **Play Console** içindeki en yüksek `versionCode` ve **App Store Connect**
içindeki son yayımlanmış sürüm/build kimliğini kontrol et. `pubspec.yaml`
içindeki `version: x.y.z+N` satırında **+N build numarası**, iki mağazaya daha
önce yüklenmiş bütün build numaralarından büyük olmalı; yalnız yerelde üretilen
bir artifact'ın numarasına bakarak karar verme.

App Store'da `x.y.z` Marketing Version zaten yayındaysa, yeni bir App Store
sürümü oluştururken yalnız `+N` artırmak yetmez: ürün değişikliğinin kapsamına
uygun biçimde `x.y.z` Marketing Version değerini de ileri taşı ve ardından yeni
build numarasını kullan. Henüz yayımlanmamış aynı App Store sürümünün yeni bir
aday build'i hazırlanıyorsa marketing sürümü sabit kalabilir, ama build numarası
yine daha önce yüklenmiş olanların üstünde olmalıdır.

Sürüm veya build değişince `docs/app_review_packet_<version>_build<build>.md`
paketini yeni binary ile eşleştir ve sürüm notlarını
`docs/release_notes_internal.md` en üstüne yeni başlıkla ekle; eski kaydı silme.
