# ZanKurd Play Store Internal Test Hazırlığı

Bu belge Play Console iç test turunun kısa operasyon notudur. Yayın komutları,
yapılandırma kontrolleri ve Supabase üretim sırası için tek kanonik kaynak
`docs/YAYIN_ADIMLARI.md` dosyasıdır. Bu belge onun yerine geçmez.

## Yerel artifact sözleşmesi

Aşağıdaki dosyalar **önceden hazır kabul edilmez**. Güncel kaynak ve gerçek
production yapılandırmasıyla release derlemesi başarıyla tamamlandıktan sonra
oluşmaları gerekir:

- `build/app/outputs/bundle/release/app-release.aab`: Play Console'a yüklenecek
  Android App Bundle.
- `build/app/outputs/flutter-apk/app-release.apk`: gerektiğinde doğrudan fiziksel
  Android cihaz smoke testi için release APK.
- `web/privacy.html`: yayımlanacak gizlilik politikası kaynağı.

`release_packages/` altında eski bir kopya bulunması güncel artifact kanıtı
sayılmaz. Yükleme öncesi AAB'nin sürümü `pubspec.yaml` ile, imzası ise
`docs/YAYIN_ADIMLARI.md` ve `docs/android_signing_setup.md` içindeki doğrulanmış
upload-key parmak iziyle eşleştirilmelidir.

## Play Console tarafında kullanılacak bilgiler

- Uygulama adı: `ZanKurd`
- Paket adı: `com.zankurd.app`
- Kategori: `Education` veya `Trivia`
- Hedef kitle: dil/quiz uygulaması; çocuklara yönelik uygulama olarak
  işaretlenmemeli.
- Gizlilik politikası: `web/privacy.html` herkese açık HTTPS adresinde
  yayımlanmalı ve Play Console'daki Privacy Policy alanına aynı URL girilmeli.
- Hesap silme URL'si ve Data Safety cevapları, gönderilen binary ve güncel
  `docs/play_console_submission_checklist.md` ile birebir uyuşmalı.

## Internal testing sırası

1. Önce `docs/YAYIN_ADIMLARI.md` içindeki release ön koşullarını tamamla.
2. Güncel `build/app/outputs/bundle/release/app-release.aab` dosyasını Internal
   testing kanalına yükle.
3. Release notes alanına `docs/release_notes_internal.md` içeriğini koy.
4. Play Console'un target API, version code ve signing kontrollerinin hatasız
   geçtiğini doğrula.
5. Test kullanıcılarını ekle ve mağaza bağlantısıyla en az bir gerçek Android
   cihaza kur.
6. Temiz kurulumda şu akışları kontrol et:
   - onboarding ve 13+ yaş kapısı,
   - misafir girişi ve oyuncu adı kapısı,
   - ilk 5 soruluk öğrenme turu ve sonuç ekranı,
   - kategori → alt kategori → seviye → quiz akışı,
   - hızlı eşleşme ve sonuç,
   - oda kurma / kodla katılma / oda sohbeti,
   - mağaza ve geri yükleme davranışı,
   - profil, liderlik, dil ve tema değişimi,
   - hesap silme,
   - kullanıcı içeriği için Report/Block erişimi.
7. Crash, ANR veya kritik işlev kaybı varsa production kanalına yükseltme.

## Supabase üretim güvenlik kapısı

Play Store iç test hazırlığı **eski SQL dosyalarını SQL Editor'de yeniden
çalıştırma talimatı değildir**. Üretim backend değişiklikleri yalnız
`docs/YAYIN_ADIMLARI.md` içindeki koordineli kesim sırasıyla yapılmalıdır.

Önce salt-okunur history kontrolü:

```bash
supabase migration list --linked
```

`20260819000000_gamification_and_custom_rooms.sql` için local/remote migration
history ayrışması çözülmüş değilse:

- `supabase db push` çalıştırma,
- eski 19 Ağustos SQL dosyasını yeniden uygulama,
- migration history'yi hesap sahibinin açık onayı olmadan değiştirme.

Gerekli kontrollü history onarımı ve sonrasındaki doğrulama adımları
`docs/YAYIN_ADIMLARI.md` ile `supabase/applied.md` içinde kayıtlıdır.
