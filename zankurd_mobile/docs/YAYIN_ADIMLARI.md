# Yayın adımları — sıradan şaşma

Bu belge son yayın sırasıdır. Supabase güvenlik göçleri ve Hostinger SSH
bağlantısı hazırdır; mağaza hesabı, imza ve fiziksel cihaz adımları hesap
sahibinde kalır.

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

## 1. Supabase: üç göç çalıştırılacak

2026-07-31 denetiminden sonra **üç yeni göç var ve üçü de canlıda değil.**
Sıra önemli; en kritik güvenlik açığı birincide kapanıyor.

Hepsi için yol aynı: [supabase.com](https://supabase.com) → projen →
**SQL Editor** → **New query** → dosyanın tamamını yapıştır → **Run**.

Üçü de idempotenttir: yanlışlıkla iki kez çalıştırmak bir şey bozmaz.

---

### 1a. Turnuva skor yetkisi — ÖNCE BU

Dosya: `zankurd_mobile/supabase/2026-07-31_tournament_score_authority.sql`

**Niçin acil:** Şu an turnuva maçında oyuncunun bildirdiği skorun üst
sınırı yok. REST üzerinden `p_score = 2147483647` gönderen her maçı
kazanır, şampiyon olur ve turnuva başına 200 coin alır. Coin mağazadan
VIP rozeti dahil her şeyi aldığı için bu, sınırsız coin basma yoludur.
Anonim giriş açık olduğundan sınırsız hesapla tekrarlanabilir.

**Çalıştırdıktan sonra doğrula** (yeni query):

```sql
select
  (select count(*) from information_schema.columns
    where table_name = 'tournaments' and column_name = 'questions_per_match')
    as kolon_eklendi,
  (select bool_or(prosrc ilike '%least(v_score%')
     from pg_proc where proname = 'submit_tournament_match')
    as skor_tavani_var,
  (select bool_or(prosrc ilike '%advance_tournament%')
     from pg_proc where proname = 'resolve_expired_tournament_matches')
    as tur_ilerlemesi_var;
```

**Tamam mı?** Üç sütun da `1` / `true` / `true` ise evet.

---

### 1b. Oda sohbeti moderasyonu

Dosya: `zankurd_mobile/supabase/2026-07-31_chat_moderation.sql`

**Niçin gerekli:** Oda sohbeti bu sürümde geri geldi. Apple App Store
Review 1.2 ve Google Play, kullanıcı içeriği barındıran uygulamalarda
süzme + bildirme + engelleme + iletişim bilgisi ister. Uygulama tarafı
hazır; bu göç sunucu tarafını kuruyor.

Ayrıca iki kusuru daha kapatıyor: gönderen adı ve zaman damgası
istemciden yazılıyordu (kimlik taklidi), ve `room_messages` okuma
politikası `USING (true)` idi — oda kodu olmayan biri **bütün odaların**
mesajlarını okuyabiliyordu.

**Uygulanmazsa ne olur:** Sohbet çalışır ama "Bildir" ve "Engelle"
düğmeleri "işlem yapılamadı" der, okuma politikası herkese açık kalır.

**Çalıştırdıktan sonra doğrula:**

```sql
select
  (select count(*) from pg_tables
    where tablename in ('blocked_users', 'message_reports')) as tablolar,
  (select count(*) from pg_trigger
    where tgname = 'room_messages_moderation') as tetikleyici,
  (select public.chat_message_is_clean('Merheba heval')) as temiz_gecer,
  (select public.chat_message_is_clean('bak https://kotu.com')) as link_gecmez;
```

**Tamam mı?** `2`, `1`, `true`, `false` ise evet.

---

### 1c. Açıkta kalan okuma yüzeyleri — SON VE DİKKATLİ

Dosya: `zankurd_mobile/supabase/2026-07-31_exposure_hardening.sql`

⚠️ **Bu göç iki tablo SİLER ve geri alınamaz.** Önce boş olduklarını —
daha doğrusu artık gerekmediklerini — doğrula.

**Çalıştırmadan ÖNCE bu sorguyu koş** (tablo yoksa da hata vermez):

```sql
select tablename,
       (xpath('/row/c/text()',
              query_to_xml(format('select count(*) as c from public.%I',
                                  tablename), false, true, '')))[1]::text::int
         as satir_sayisi
  from pg_tables
 where schemaname = 'public'
   and tablename like 'questions_editorial_backup%';
```

Bu yedekler 2026-07-16'daki editoryal düzeltmenin geri dönüş kopyalarıydı
ve düzeltme 2026-07-18'de canlı sorguyla doğrulandı — yani geri dönüş
penceresi kapandı. Sorgu hata verip *"relation does not exist"* derse
tablolar zaten yok demektir; sorun değil, göç yine çalışır.

Silinmelerinin sebebi: bu tablolar `questions`ın tam kopyası ve
`correct_option` kolonunu taşıyorlar. 2026-07-22'de `questions`tan
`revoke select` yapıldı ama yedekler o kapatmanın dışında kalmıştı —
yani doğru cevaplar sertleştirmenin yanından dolanılarak okunabilir
durumda.

**Emin değilsen** yedeği önce dışa aktar: tabloya tıkla → sağ üstten
**Export** → CSV. Sonra göçü çalıştır.

**Çalıştırdıktan sonra doğrula:**

```sql
select
  (select count(*) from pg_tables
    where tablename like 'questions_editorial_backup%') as yedek_kalmadi,
  (select bool_or(prosrc ilike '%escape%')
     from pg_proc where proname = 'search_profiles') as arama_kacirmali,
  (select case
     when not exists (select 1 from information_schema.columns
       where table_name = 'profiles' and column_name = 'fcm_token')
     then false
     else has_column_privilege('authenticated', 'public.profiles',
            'fcm_token', 'select')
   end) as jeton_okunabilir;
```

**Tamam mı?** `0`, `true`, `false` ise evet.

---

### 1d. Hepsi bitince kaydı güncelle

`zankurd_mobile/supabase/applied.md` dosyasında üç satırın `❌`
işaretini `✅` yap ve yanına tarihi yaz. Bu dosya deponun **tek**
uygulanma kaydıdır; güncellenmezse bir sonraki sefer hangisinin
çalıştığı bilinmez.

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

## 3. Android imza anahtarı (bir kez, ömür boyu)

> **Bu dosyayı kaybedersen Play Store'da uygulamayı bir daha
> güncelleyemezsin.** Yedekle: parola yöneticisi + harici disk.

Terminalde:

```bash
keytool -genkeypair -v -keystore ~/zankurd-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Soracakları:
- **Keystore parolası** — güçlü seç, kaydet.
- **Key parolası** — aynısını yazabilirsin (Enter'a basınca aynısını alır).
- Ad/kurum/şehir — Play için kritik değil, doldur geç.

Sonra `zankurd_mobile/android/key.properties` diye bir dosya oluştur,
içine (parolaları kendi seçtiklerinle değiştir):

```properties
storePassword=SENIN_KEYSTORE_PAROLAN
keyPassword=SENIN_KEY_PAROLAN
keyAlias=upload
storeFile=/Users/kocer/zankurd-upload.jks
```

Bu dosya git'e girmiyor (`.gitignore`'da), merak etme.

Mobil release yapılandırmasını örnekten oluştur ve dört açık anahtarı gerçek
üretim değerleriyle doldur. `.env.mobile.release.json` yerel kalır; repoya
eklenmez:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
cp .env.mobile.release.example.json .env.mobile.release.json
```

**Tamam mı?**

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter build appbundle --release --dart-define-from-file=.env.mobile.release.json
```

Sonunda `✓ Built build/app/outputs/bundle/release/app-release.aab`
görüyorsan evet. "Release signing is misconfigured" diyorsa
`key.properties` yolunu ya da parolayı yanlış yazmışsındır.

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
cd /Users/kocer/Projects/zankurd/zankurd_mobile && flutter run --release
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
