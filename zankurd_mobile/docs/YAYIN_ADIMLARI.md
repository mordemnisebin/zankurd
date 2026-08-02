# Yayın adımları — sıradan şaşma

Bu belge son yayın sırasıdır. Hostinger SSH bağlantısı ve Android upload
anahtarı hazırdır. Yeni 1v1 Supabase göçü ise önce staging/preview ortamında
doğrulanmalıdır; mağaza hesabı ve fiziksel cihaz adımları hesap sahibinde kalır.

Sırayla git. Her adımın sonunda **"tamam mı?"** satırı var; orası
tutmuyorsa sonrakine geçme.

Tahmini süre: 1. gün ~2 saat (hesap açma beklemeleri hariç), sonra
inceleme bekleyişi (Apple 1-3 gün, Google 1-7 gün).

---

## 0. Önce şunu bir kez çalıştır

Terminalde proje klasöründe:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile && dart analyze && flutter test
```

**Tamam mı?** "All tests passed!" ve "No issues found!" görüyorsan evet.
Görmüyorsan bana yaz, yayına başlama.

---

## 1. Supabase: yeni 1v1 göçünü uygula ve doğrula

Önce `zankurd_mobile/supabase/applied.md` dosyasına bak. `✅` kaydı olan
göçleri **yeniden çalıştırma**. Bu sürüm için ayrıca
`supabase/2026-08-02_multiplayer_session_hardening.sql` gerekir. 2026-08-02
salt-okunur canlı kontrolde bu dosyanın yeni RPC'leri bulunamadı; dosyanın
`applied.md` kaydı hâlâ yoksa dosyayı doğrudan üretime gönderme.

Önce staging/preview Supabase projesinde dosyanın tamamını tek işlem olarak
uygula. Ardından git tarafından yok sayılan ayrı bir staging yapılandırması
hazırla; üretim dosyasını staging turunda kullanma:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
if [ ! -f .env.mobile.staging.json ]; then
  cp .env.mobile.release.example.json .env.mobile.staging.json
fi
```

Şimdi `.env.mobile.staging.json` içindeki `SUPABASE_URL` ve
`SUPABASE_ANON_KEY` değerlerini staging/preview projesinin açık istemci
değerleriyle, RevenueCat alanlarını da sandbox/test **public SDK** anahtarlarıyla
doldur. Service-role veya başka bir sunucu sırrı kullanma. Kaydettikten sonra
ayrı bir komut olarak şablon kalıntısı kontrolünü çalıştır:

```bash
if grep -Eq 'your-project|your-public-|your_public_|replace[-_]?me|changeme|placeholder' .env.mobile.staging.json; then
  echo "Staging yapılandırmasında şablon değeri kaldı; düzeltmeden devam etme."
  false
else
  echo "Staging yapılandırmasında şablon kalıntısı yok."
fi
```

Kontrol başarısızsa devam etme. Başarılıysa `flutter devices` ile iki hedefin
kimliğini bul; sonra iki ayrı terminalde şu komutları çalıştır:

```bash
flutter run --release -d <birinci-cihaz-id> --dart-define-from-file=.env.mobile.staging.json
flutter run --release -d <ikinci-cihaz-id> --dart-define-from-file=.env.mobile.staging.json
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
  to_regprocedure('public.create_online_room(text,integer)') is not null
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

**Tamam mı?** Staging/preview iki istemci turu geçti ve altı değerin altısı da
`true` ise aynı dosyayı üretim SQL Editor'ünde bir kez uygula, doğrulama
sorgusunu üretimde tekrarla ve ancak ondan sonra göçü `supabase/applied.md`
dosyasına tarih/kanıt notuyla `✅` olarak kaydet. Herhangi biri `false` ise
yayına devam etme ve göçü körlemesine ikinci kez çalıştırma; önce ilk
çalıştırmanın hatasını incele.

---

## 2. Siteyi güncelle (uygulama + yasal sayfalar birlikte)

Üç yasal sayfa web derlemesinin **içinde** geliyor (`web/privacy.html`,
`web/terms.html`, `web/delete-account.html` → `build/web/`), yani siteyi güncellediğinde onlar da
güncellenir. Ayrı yükleme yok.

Tek komut analiz → bütün testler → açık Supabase ayarlı release derleme →
Hostinger hedef/anahtar ön kontrolü → şifreli aktarım → dört canlı sayfa
doğrulaması sırasını uygular:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
./release_web.sh
```

Aktarım parola kullanmaz, hedefin gerçek yolunu doğrulamadan başlamaz,
değişen uzak dosyaları web kökü dışındaki tarihli yedeğe alır ve uzak
dosyaları topluca silmez.

**Tamam mı?** "Sayfa açılıyor" yetmez: sunucu olmayan her adrese
uygulamanın kendi sayfasını döndürüyor, yani 404 bile 200 görünüyor.
İçeriğe bak:

- `https://www.zankurd.com/terms.html` → başlıkta **"Kullanım Koşulları ·
  Mercên Bikaranînê"** yazmalı. "ZanKurd" yazan boş sayfa görüyorsan
  yükleme olmamıştır.
- `https://www.zankurd.com/privacy.html` → 4. maddede **"Ayarlar → Hesap
  → Hesabımı Sil"** yazmalı. Hâlâ "e-posta gönder" diyorsa eski dosya
  duruyordur.
- `https://www.zankurd.com/delete-account.html` → **"Hesap Silme ·
  Jêbirina Hesabê"** başlığı ve talep düğmesi görünmeli.

Üçü de krem zeminli, yeşil başlıklı. Eskisi lacivert/kırmızıydı; renk
değiştiyse yeni sürüm yüklenmiş demektir.

---

## 3. Android imza anahtarını doğrula

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
değeri eksik/şablonsa uygulamanın release açılış kapısı güvenli hata ekranında
durur; böyle bir AAB mağazaya yüklenebilir bir paket sayılmaz.

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
if [ ! -f .env.mobile.release.json ]; then
  cp .env.mobile.release.example.json .env.mobile.release.json
fi
```

Dosyayı gerçek üretim istemci değerleriyle doldurup kaydettikten sonra ayrı bir
komut olarak doğrula:

```bash
if grep -Eq 'your-project|your-public-|your_public_|replace[-_]?me|changeme|placeholder' .env.mobile.release.json; then
  echo "Üretim yapılandırmasında şablon değeri kaldı; düzeltmeden devam etme."
  false
else
  echo "Üretim yapılandırmasında şablon kalıntısı yok."
fi
```

**Tamam mı?** Şablon kalıntısı yoksa derlemeye geç:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter build appbundle --release --dart-define-from-file=.env.mobile.release.json
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Sonunda AAB için `✓ Built` ve imza denetiminde `jar verified` görüyorsan evet.
"Release signing is misconfigured" diyorsa `key.properties` yolunu veya
Keychain'deki parolaları doğrula; yeni keystore üretme.

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
İmzalı iOS arşivini aynı açık üretim yapılandırmasıyla oluştur:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter build ipa --release --dart-define-from-file=.env.mobile.release.json
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
- **İnceleme notu:** iOS sürümünde giriş e-posta/şifre veya misafir hesabıyla
  yapılır. Sosyal giriş seçenekleri bu sürümde bilerek sunulmaz.

### 5e. Metin ve görseller
`docs/store_listing.md` içindeki App Store bölümü. Ekran görüntüleri
`docs/screenshots/store/tr/` (6,9" boyutu, doğru ölçüde; `05_word_order.png`
hariç).

**Tamam mı?** "İncelemeye gönder" düğmesi aktifse evet.

---

## 6. Göndermeden önce: gerçek cihazda bir tur

Bunu ben yapamam, simülatörde görünmeyen iki şey var.

iPhone'unu kabloyla bağla:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter devices
flutter run --release -d <iphone-cihaz-id> --dart-define-from-file=.env.mobile.release.json
```

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

`pubspec.yaml` içindeki `version: 1.9.1+13` satırında **+13**'ü artır
(Play aynı numarayı iki kez kabul etmez). Sürüm notlarını
`docs/release_notes_internal.md` en üstüne yeni başlıkla ekle, eskiyi
silme.
