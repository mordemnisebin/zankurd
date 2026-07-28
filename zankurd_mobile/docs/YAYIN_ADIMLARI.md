# Yayın adımları — sıradan şaşma

Kodda yapılacak bir şey kalmadı. Aşağıdakiler yalnız senin
yapabileceklerin: imza anahtarı sende, site senin, mağaza hesapları
senin.

Sırayla git. Her adımın sonunda **"tamam mı?"** satırı var; orası
tutmuyorsa sonrakine geçme.

Tahmini süre: 1. gün ~2 saat (hesap açma beklemeleri hariç), sonra
inceleme bekleyişi (Apple 1-3 gün, Google 1-7 gün).

---

## 0. Önce şunu bir kez çalıştır

Terminalde proje klasöründe:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile && flutter test && flutter analyze
```

**Tamam mı?** "All tests passed!" ve "No issues found!" görüyorsan evet.
Görmüyorsan bana yaz, yayına başlama.

---

## 1. Supabase: oyuncu kodu göçü

Aynı adı taşıyan iki oyuncunun ayırt edilmesi buna bağlı.

1. [supabase.com](https://supabase.com) → projen → sol menüde **SQL Editor**.
2. **New query**.
3. `zankurd_mobile/supabase/2026-07-28_player_tag.sql` dosyasını aç,
   **tamamını** kopyala, editöre yapıştır.
4. **Run**.

Dosya yeniden çalıştırılabilir; yanlışlıkla iki kez basarsan bir şey
bozulmaz.

**Tamam mı?** Aynı editörde şunu çalıştır:

```sql
select display_name, player_tag from public.profiles limit 5;
```

Her satırda dört karakterlik bir kod görüyorsan evet. `null` görüyorsan
göç çalışmamış.

---

## 2. Siteyi güncelle (uygulama + yasal sayfalar birlikte)

İki yasal sayfa web derlemesinin **içinde** geliyor (`web/privacy.html`,
`web/terms.html` → `build/web/`), yani siteyi güncellediğinde onlar da
güncellenir. Ayrı yükleme yok.

1. Derlemeyi yap:

```bash
flutter build web --release
```

2. `build/web` klasörünün **içindeki her şeyi** (klasörün kendisini
   değil) Hostinger'da `public_html` içine yükle, üzerine yazsın.
   Gizli `.htaccess` dosyası da gitmeli — dosya yöneticisinde "gizli
   dosyaları göster" açık olmalı.

**Tamam mı?** "Sayfa açılıyor" yetmez: sunucu olmayan her adrese
uygulamanın kendi sayfasını döndürüyor, yani 404 bile 200 görünüyor.
İçeriğe bak:

- `https://www.zankurd.com/terms.html` → başlıkta **"Kullanım Koşulları ·
  Mercên Bikaranînê"** yazmalı. "ZanKurd" yazan boş sayfa görüyorsan
  yükleme olmamıştır.
- `https://www.zankurd.com/privacy.html` → 4. maddede **"Ayarlar → Hesap
  → Hesabımı Sil"** yazmalı. Hâlâ "e-posta gönder" diyorsa eski dosya
  duruyordur.

İkisi de krem zeminli, yeşil başlıklı. Eskisi lacivert/kırmızıydı; renk
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

**Tamam mı?**

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile && flutter build appbundle --release
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

Ekran görüntüleri: `docs/screenshots/store/tr/` klasöründeki 7 dosya.
Play en az 2 tane ister.

Ayrıca Play iki görsel daha ister, onlar bende yok:
- **Uygulama simgesi** 512×512 PNG →
  `zankurd_mobile/web/icons/Icon-512.png` dosyasını kullan.
- **Öne çıkan grafik** 1024×500 — bunu senin yapman ya da bana
  yaptırman gerek, elimde yok.

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
Xcode ile:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile && open ios/Runner.xcworkspace
```

Xcode'da: üstten cihaz seçiciden **Any iOS Device** → menüden **Product →
Archive** → açılan pencerede **Distribute App → App Store Connect**.

Apple Developer hesabın Xcode'da ekli olmalı (Xcode → Settings →
Accounts).

### 5d. Formlar
- **Uygulama Gizliliği:** `ios/Runner/PrivacyInfo.xcprivacy` dosyasında
  ne beyan ettiysek aynısını işaretle (hesap kimliği, e-posta, ad, avatar,
  ürün etkileşimi, çökme, satın alma). Hiçbiri "izleme" değil.
- **Gizlilik politikası URL'si:** `https://www.zankurd.com/privacy.html`
- **Kullanım koşulları (EULA):** `https://www.zankurd.com/terms.html`
- **Yaş derecelendirmesi:** anket, hepsine "yok/hiç".
- **İhracat uyumluluğu:** sormayacak — kodda beyan ettik.

### 5e. Metin ve görseller
`docs/store_listing.md` içindeki App Store bölümü. Ekran görüntüleri
`docs/screenshots/store/tr/` (6,9" boyutu, doğru ölçüde).

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
