# ZanKurd — Aşama 3: Üretim Yapılandırması + Yüksek Riskli Aday Doğrulaması

**Çalışma tarihi:** 2026-08-02
**Hedef A:** P1-005 (üretim release yapılandırması)
**Hedef B:** Ek A yüksek riskli 7 adayın bağımsız doğrulanması

> Bu turda **uygulama kaynak kodu değiştirilmemiştir.** Değişen tek dosya
> `zankurd_mobile/README.md`'dir (Aşama 4 — belge tutarlılığı). Doğrulanan
> kusurlar **düzeltilmemiştir**; yalnız kanıtlanmış ve seviyelendirilmiştir.

---

## 1. Başlangıç snapshot'ı

| Alan | Değer |
|---|---|
| Depo | `/Users/kocer/Projects/zankurd` |
| Başlangıç branch | `fix/release-blockers-2026-08-02` **(beklenenle aynı)** |
| Başlangıç HEAD | `05e0b6f1ef79ab6d2d3772a822a2f1ce5ed7e24c` **(beklenen `05e0b6f` ile aynı)** |
| Son iki commit | `67c1b59 chore(ci)…`, `05e0b6f docs(audit)…` **(doğrulandı)** |
| `main` | `5c79000` — **değiştirilmemiş** |
| Worktree | Temiz; yalnız `audit_artifacts/` untracked |
| Çalışma branch'i | **`audit/high-risk-verification-2026-08-02`** (yeni) |
| `git diff --check` | Temiz |
| origin | yerel bundle (genel remote değil) |

**Yedek:** `~/Documents/ZanKurd-Backups/zankurd-pre-phase3-20260802-082638.bundle`
· SHA-256 `fdd636a724f25e2913d9f06bd683c9a3a147e71d115b77a4f926d5d035cd2299`
· `git bundle verify` → *"The bundle records a complete history."* (HEAD `05e0b6f`)

**Toolchain:** Flutter 3.44.7 · Dart 3.12.2 · JDK 17.0.20 · Android SDK 36 ·
bundletool 1.18.3 · Xcode 26.6 / iOS 26.5.

---

## 2. Release yapılandırma sözleşmesi

Koddan çıkarıldı (`lib/src/config/app_config.dart`, `lib/main.dart`,
`.env.mobile.release.example.json`).

| Anahtar | Kapsam | Zorunlu mu? | Tür |
|---|---|---|---|
| `SUPABASE_URL` | ortak | **Evet** (release'te her platform) | public client config |
| `SUPABASE_ANON_KEY` | ortak | **Evet** | **publishable/public** client key (`sb_publishable_…`) |
| `REVENUECAT_API_KEY_ANDROID` | Android | **Evet** (mobilde) | public SDK key |
| `REVENUECAT_API_KEY_IOS` | iOS | **Evet** (mobilde) | public SDK key |
| `REVENUECAT_API_KEY_WEB` | web | Hayır | public SDK key |
| `NEXT_PUBLIC_SUPABASE_URL` / `…_PUBLISHABLE_KEY` | ortak | alternatif adlar | public |
| `USE_BUNDLED_SUPABASE_DEFAULTS` | ortak | Hayır (bool) | derleme anahtarı |

**Davranış:** `AppConfig.validateForRelease` yalnız `kReleaseMode`'da çalışır.
Supabase her zaman, RevenueCat `!kIsWeb && (Android || iOS)` iken zorunludur
(`main.dart:109-115`). Eksikse `_ConfigurationErrorApp` gösterilir ve normal
uygulama hiç açılmaz (`main.dart:116-119`). Debug/profile modda validasyon
devre dışıdır (`if (!isReleaseMode) return const []`).

### 2.1 Güvenli yerel keşif — envanter (değer gösterilmedi)

Aranan yerler: repoda gitignore'lu `.env*`; shell ortam değişkeni adları;
`~/.zankurd/`; `~/Documents/ZanKurd*`; `~/Downloads` altındaki ZanKurd
kopyaları (`Asset-Auditorzip/zankurd_mobile`, `zankurd_extracted`) — yalnız
`.env*` ve release config dosyaları; `~/Library/Application Support/ZanKurd/`;
IDE launch config; macOS Keychain servis **adları**.

| Anahtar | Durum | Kaynak | Uzunluk | Maskeli hash | Placeholder? |
|---|---|---|---|---|---|
| `SUPABASE_URL` | **FOUND — CURRENT SECURE SOURCE** | `zankurd_mobile/.env.web.release.json` (gitignore'lu) | 40 | `3e9e6a34…` | Hayır |
| `SUPABASE_ANON_KEY` | **FOUND — CURRENT SECURE SOURCE** | aynı | 46 | `62909d35…` | Hayır |
| `REVENUECAT_API_KEY_ANDROID` | **MISSING** | — | — | — | — |
| `REVENUECAT_API_KEY_IOS` | **MISSING** | — | — | — | — |

Ek doğrulama: `.env.web.release.json`'daki iki Supabase değeri,
`app_config.dart`'taki gömülü varsayılanlarla **birebir aynıdır**
(hash eşleşmesi `3e9e6a34…` / `62909d35…`) — yani aynı üretim projesi ve
istemciye gömülmek üzere tasarlanmış publishable anahtar.

Keychain'de yalnız `Supabase CLI` ve `ZanKurd Android Upload Keystore`
kayıtları var; **RevenueCat kaydı yok**. Eski proje kopyalarında
`.env.mobile.release.json` **yok**.

### 2.2 `.env.mobile.release.json` durumu

**OLUŞTURULMADI.** İki zorunlu anahtar eksik olduğu için dosya sahte/placeholder
değerlerle üretilmedi (Aşama 3 kural 7 ve durdurma koşulu 1).
`git check-ignore` doğrulaması yine de yapıldı: dosya adı `.gitignore:57 (.env.*)`
kuralına giriyor ve `git ls-files` boş — yani oluşturulduğunda commit edilmeyecek.

---

## 3. P1-005 — durum

| Kontrol | Sonuç |
|---|---|
| Üretim config dosyası | **YOK** (2/4 anahtar eksik) |
| Android production AAB | **BLOCKED** — çalıştırılmadı |
| Android production smoke | **BLOCKED** |
| iOS production config build | **BLOCKED** |
| README düzeltmesi | **YAPILDI** (§4) |
| Config değeri Git'e/loga sızdı mı? | **Hayır** |

**P1-005 son durumu: `BLOCKED — OWNER-SUPPLIED RELEASE CONFIG REQUIRED`**

Eksik anahtarlar (yalnız adlar): **`REVENUECAT_API_KEY_ANDROID`**,
**`REVENUECAT_API_KEY_IOS`**.

Bunlar RevenueCat panelindeki **public SDK anahtarlarıdır** (Android için
`goog_…`, iOS için `appl_…` biçiminde). Sunucu sırrı değildirler ve istemci
ikilisine gömülmek üzere tasarlanmışlardır — ancak yalnız hesap sahibinde
bulunurlar ve **uydurulamazlar**.

Aşama 2'de üretilen imzalı AAB'nin çalışma zamanı davranışı bu turda tekrar
gözlendi (release APK seti hâlâ emülatörde kuruluydu): uygulama
`_ConfigurationErrorApp` ekranında açılıyor
(`screenshots/android/A02_00_state.png`). Bu, P1-005'in hâlâ açık olduğunun
bağımsız teyididir.

---

## 4. README düzeltmesi

`zankurd_mobile/README.md` → "Play Store Build" bölümü yeniden yazıldı:

1. Bayraksız `flutter build appbundle --release` kullanımına karşı açık uyarı
   ve nedeni (yapılandırma hata ekranı; 2026-08-02'de cihazda doğrulandı).
2. `cp .env.mobile.release.example.json .env.mobile.release.json` adımı.
3. Dört anahtarın **ne olduğu** (service-role/secret **olmadığı** vurgusuyla).
4. `.gitignore` kapsamında olduğu ve asla commit edilmeyeceği.
5. Doğru komut: `flutter build appbundle --release --dart-define-from-file=.env.mobile.release.json`
6. `jarsigner -verify` imza doğrulaması.
7. **Zorunlu çalışma zamanı doğrulaması**: `bundletool build-apks` +
   `install-apks` ile kurup uygulamanın onboarding/ana ekrana ulaştığını
   gözle görme.

**Tutarlılık doğrulandı** — üç belge de aynı komutu veriyor:
`README.md:214-216`, `docs/YAYIN_ADIMLARI.md:171`,
`docs/android_signing_setup.md:69-70`.

README'ye hiçbir gerçek değer veya örnek anahtar yazılmadı.

---

## 5. Aday doğrulama matrisi

| Aday | İddia | **Verdict** | Severity | Yeni ID | Sonraki işlem |
|---|---|---|---|---|---|
| **A-01** | Mağaza ürünü sunucuda satın alınamıyor | **VERIFIED DEFECT** | **P1** | `ZKR-REL-20260802-P1-006` | `spend_coins` allowlist'e `avatar_frame_neon` eklenmeli |
| **A-02** | Quiz şık kontrastı WCAG AA altında | **VERIFIED DEFECT** | **P2** | `ZKR-REL-20260802-P2-010` | Gradient koyulaştır veya metin/scrim değiştir + kontrast testi ekle |
| **A-10** | Liderlik rotası çıkışsız/bozuk | **VERIFIED DEFECT** | **P1** | `ZKR-REL-20260802-P1-007` | Pushed kullanımda `Scaffold` sar + geri düğmesi |
| **A-03** | Avatar kaldırılınca Storage nesnesi kalıyor | **VERIFIED DEFECT** | **P2** | `ZKR-REL-20260802-P2-011` | Kaldırma/değiştirmede `storage.remove` |
| **A-04** | `analytics_events` rıza dışı veri yazıyor | **NOT A DEFECT** | — | — | Ölü tablo; kaldırma P3 önerisi |
| **A-05** | Avatar denetimsiz görsel UGC | **VERIFIED DEFECT** | **P1** | `ZKR-REL-20260802-P1-008` | Avatar için bildir/engelle + moderasyon |
| **A-06** | Görünen adlar filtreden geçmiyor | **VERIFIED DEFECT** | **P1** | `ZKR-REL-20260802-P1-009` | İstemci + **sunucu** ad doğrulaması |

**Sonuç: 6 doğrulanmış kusur (4×P1, 2×P2), 1 yanlış alarm.**

---

## 6. Ayrıntılı bulgular

### `ZKR-REL-20260802-P1-006` — Neon çerçeve satın alınamıyor (A-01)

| Alan | İçerik |
|---|---|
| **Durum** | `VERIFIED DEFECT` · P1 · Android + iOS · Ekonomi/mağaza |
| **Zincir** | (1) `shop_items` seed'inde ürün var: `('avatar_frame_neon', …, 600, …)` — `supabase/2026-07-23_shop_items_sync.sql:52-55` ve `2026-07-13_shop_chat_suggestions.sql:51`. (2) UI kataloğunda 600 coin ile listeleniyor — `shop_screen.dart:174-183`. (3) `_supportedItemIds` içinde — `shop_screen.dart:141-145`; dosyanın kendi yorumu: *"bu kümeye bir kimlik eklemek, o ürünün gerçekten bir şey yaptığı anlamına gelir."* (4) Satın alma `spendCoins(600, 'purchase_avatar_frame_neon')` çağırıyor — `shop_screen.dart:465-468`. (5) **Sunucu reddediyor:** `spend_coins` allowlist'i yalnız `spin_wheel_extra`, `avatar_frame_gold`, `profile_badge_vip` içeriyor — `supabase/2026-07-29_shop_purchase_integrity_fix.sql:105-116` → `{'success': false, 'error': 'product not available'}`. (6) İstemci hata dizesini atıyor (`spendCoins` yalnız `bool` döndürüyor — `supabase_zankurd_repository.dart:943-959`) ve kullanıcıya genel `K.purchaseFailed` gösteriyor — `shop_screen.dart:487-489`. |
| **Kritik kontrol** | `avatar_frame_neon`'u allowlist'e ekleyen **daha yeni bir migration yok** (tüm `supabase/` tarandı; `product not available` guard'ı yalnız bu tek dosyada). |
| **İronі** | İstemci tarafı 2026-07-31'de **düzeltilmiş**: `AvatarFrame.neon` enum'a eklenmiş, rengi ve etiketi var, `avatar_editor_screen.dart:69-70,98` `hasPurchased('avatar_frame_neon')` ile kilidi açıyor. `avatar_frames.dart:10-14` yorumu eski kusuru anlatıyor. Ama **sunucu allowlist'i güncellenmemiş**, dolayısıyla `hasPurchased` hiçbir zaman true olamaz. |
| **Kullanıcı etkisi** | 600+ coin biriktiren kullanıcı ürünü görüyor, satın almaya basıyor, gerekçesiz "satın alma başarısız" alıyor. Coin kesilmiyor (iyi), ama ürün **hiçbir zaman** alınamıyor. |
| **Store etkisi** | Kazanılmış sanal para ile reklamı yapılan ürünün alınamaması; mağaza kalite/yanıltıcı içerik riski. |
| **Düzeltme** | `spend_coins` allowlist dizisine `'avatar_frame_neon'` ekleyen ileri-dönük migration. Ek olarak `spendCoins`'in sunucu `error` dizesini taşıyıp kullanıcıya anlamlı mesaj göstermesi. |
| **Doğrulama** | Migration sonrası: mock/lokal RPC sözleşme testi + gerçek hesapla 600 coin ile satın alma → çerçeve avatar editöründe seçilebilir olmalı. |
| **Güven** | **Yüksek** (tam zincir dosya:satır ile izlendi) |

### `ZKR-REL-20260802-P2-010` — Quiz şık kontrastı WCAG AA altında (A-02)

| Alan | İçerik |
|---|---|
| **Durum** | `VERIFIED DEFECT` · P2 · Her iki platform · Erişilebilirlik |
| **Renkler** | `AppTheme.correct = #3DA968` → `#2D8250` (`app_theme.dart:486,672-676`); `AppTheme.wrong = #E5533D` → `#C53F2B` (`:487,678-682`). Metin `Colors.white` (`quiz_option_tile.dart:114-116`). |
| **Ölçülen oranlar** | doğru gradient **başlangıç 2.97:1** · orta 3.75:1 · bitiş 4.75:1 — yanlış gradient **başlangıç 3.73:1** · orta 4.35:1 · bitiş 5.10:1 |
| **Uygulanan eşik** | Metin `fontSize: isCompact ? 15 : 17`, `FontWeight.w800` (`quiz_option_tile.dart:241-244`). WCAG "büyük metin" eşiği kalın için **14pt = 18.67px**; 17px < 18.67px olduğundan **normal metin eşiği 4.5:1 geçerlidir**. |
| **Sonuç** | Doğru durumda gradyanın büyük kısmı 4.5:1'in **altında** ve başlangıç noktası 3:1'in bile altında; yanlış durumda da başlangıç ve orta bölge 4.5:1'in altında. |
| **Tema bağımsız** | Her iki gradient `static const`, metin rengi de duruma bağlı sabit `Colors.white` — **oran light ve dark temada aynıdır**. Cihazda da doğrulandı. |
| **Test kapsamı boşluğu** | `contrast_policy_test.dart` yalnız marka turuncusu, `heroScrim` ve altın bandı ölçüyor. `quiz_accent_test.dart` gradyanlara dokunuyor ama **yalnız renk kimliğini** doğruluyor (`:109-115`), kontrastı değil. `contrastRatio` ile doğru/yanlış yüzeyini ölçen **hiçbir test yok**. |
| **Gerçek cihaz kanıtı** | Android 16 emülatörü, aynı soruda hem doğru (B) hem yanlış (D) durum: light `screenshots/android/A02_06_LIGHT_answered.png`, dark `A02_11_DARK_answered.png` |
| **Hafifletici** | Durum yalnız renkle anlatılmıyor: kalıcı ikon (`circleCheck`/`circleXmark`), yanlışta sarsıntı animasyonu ve Semantics metni var. Bu, *ayırt edilebilirliği* kurtarır ama **metnin okunabilirliğini** kurtarmaz — WCAG kontrastı metnin kendisiyle ilgilidir. |
| **Düzeltme seçenekleri** | (a) Gradient'i koyulaştırıp her iki ucu ≥4.5:1'e çekmek (marka rengi korunur, en düşük riskli); (b) metnin arkasına scrim eklemek; (c) metin boyutunu ≥18.67px'e çıkarıp 3:1 eşiğine geçmek (düzeni etkiler). **Önerilen: (a)** |
| **Doğrulama** | `contrast_policy_test.dart`'a doğru/yanlış gradyanın **her iki ucu** için `contrastRatio(Colors.white, …) >= 4.5` assertion'ı eklemek. |
| **Güven** | **Yüksek** |

### `ZKR-REL-20260802-P1-007` — Quiz sonucundan açılan liderlik ekranı bozuk (A-10)

| Alan | İçerik |
|---|---|
| **Durum** | `VERIFIED DEFECT` · P1 · Her iki platform · Navigasyon/render |
| **Rota** | `quiz_result_screen.dart:1127-1131` → `Navigator.of(context).push(AppRoute.to(LeaderboardScreen(repository: repository)))` |
| **Yapı** | `LeaderboardScreen` içinde **`Scaffold` yok, `AppBar` yok, `PopScope` yok** — yalnız `SafeArea` (`leaderboard_screen.dart:255,466`). Sekme 2 olarak kullanıldığında Scaffold'u `AppShell` sağlıyor (`app_shell.dart:287`); tam rota olarak push edildiğinde **hiçbir Material atası yok**. |
| **Gerçek cihaz kanıtı** | Android 16, tam akış (quiz → sonuç → "Rêzbendî"): ekranın **bütün metni** Flutter'ın `DefaultTextStyle.fallback()` biçimiyle çiziliyor — **sarı çift alt çizgi** ve yanlış tipografi. Başlık, sekmeler ve boş-durum metni okunaksız. Kanıt: `screenshots/android/A10_04_leaderboard_pushed.png` (karşılaştırma: aynı ekran sekme 2'den normal görünüyor). |
| **Önemli** | `DefaultTextStyle.fallback()` **debug'a özel değildir**; release derlemede de aynı şekilde çizilir. |
| **Çıkış yolu — Android** | Sistem geri tuşu **çalışıyor** (cihazda denendi, sonuç ekranına dönüldü — `A10_05_after_system_back.png`). Yani Android'de kullanıcı mahsur kalmıyor. |
| **Çıkış yolu — iOS** | Görünür geri kontrolü **yok** (AppBar yok) **ve** kenar kaydırma **yok**: `AppRoute` düz bir `PageRouteBuilder` (`app_route.dart:4`) ve depoda `pageTransitionsTheme`, `CupertinoPageTransitionsBuilder`, `CupertinoPageRoute` **hiç geçmiyor** (grep: 0 sonuç). Bu iki olgu birlikte iOS'ta çıkışsız ekran anlamına gelir. **Bu alt iddia kaynak düzeyinde doğrulanmıştır; cihazda çalıştırılmamıştır** (bkz. §8). |
| **Neden P1** | Render kusuru tek başına "beklenmedik şekilde ana akıştan kopma" ölçütünü karşılıyor ve gerçek cihazda kanıtlandı; iOS'ta ayrıca çıkışsızlık riski var. |
| **Kök neden** | Aynı widget hem sekme gövdesi hem tam rota olarak kullanılıyor; ikinci kullanım için Material/Scaffold sarmalayıcı eklenmemiş. Depo bu kalıbı başka yerlerde çözmüş (`categories_tab.dart`, `paywall_screen.dart`) ama burada atlanmış. |
| **Düzeltme** | Push edilen kullanımı `Scaffold(appBar: …, body: LeaderboardScreen(...))` ile sarmak; veya `LeaderboardScreen`e `isEmbedded` bayrağı ekleyip tam rota hâlinde kendi Scaffold'unu kurmak. Ayrıca iOS için `pageTransitionsTheme` ile Cupertino geçişi eklemek uygulama genelinde swipe-back kazandırır. |
| **Doğrulama** | Cihazda quiz → sonuç → liderlik: normal tipografi, görünür geri düğmesi, iOS'ta kenar kaydırma. |
| **Güven** | **Yüksek** (render), **Orta-Yüksek** (iOS çıkışsızlık — kaynak kanıtı kesin, cihaz testi yapılmadı) |

### `ZKR-REL-20260802-P2-011` — "Fotoğrafı kaldır" Storage nesnesini silmiyor (A-03)

| Alan | İçerik |
|---|---|
| **Durum** | `VERIFIED DEFECT` · P2 · Gizlilik/veri yaşam döngüsü |
| **Yükleme** | `uploadAvatarPhoto` sabit yola yazıyor: `'${user.id}/avatar.$ext'`, `upsert: true`, `avatars` bucket'ı — `supabase_zankurd_repository.dart:284-301` |
| **Bucket** | **`public = true`** ve politika *"Avatar photos are publicly readable" `using (bucket_id = 'avatars')`* — yani **anon dahil herkes** okuyabilir (`2026-07-05_avatar_showcase.sql:27-46`) |
| **Kaldırma aksiyonu** | Var: `ValueKey('avatar-remove-photo')` → `clearPhoto: true` (`avatar_editor_screen.dart:239-246`) → yalnız `profiles.avatar_url` null'lanıyor |
| **Kritik olgu** | `lib/` içinde **hiçbir yerde** `storage…remove/delete` çağrısı yok (grep: 0 sonuç). Nesne silinmiyor. |
| **Sonuç** | Kullanıcı "kaldır" dedikten sonra dosya `…/storage/v1/object/public/avatars/{uid}/avatar.jpg` adresinde **kalıcı ve herkese açık** kalmaya devam ediyor. Yol deterministik olduğu için kullanıcı kimliğini bilen biri erişebilir. Ek olarak uzantı değişimi (png → jpg) eski nesneyi yetim bırakıyor. |
| **Önemli hafifletici** | **Hesap silme Storage'ı temizliyor**: `delete from storage.objects where bucket_id = 'avatars' and (storage.foldername(name))[1] = v_user_id::text` (`2026-07-05_avatar_showcase.sql:169-171`). Yani Apple/Play'in **zorunlu** hesap silme şartı karşılanıyor; kusur yalnız "fotoğrafı kaldır" yolunda. |
| **Neden P2 (P1 değil)** | Mağaza zorunluluğu olan silme yolu doğru çalışıyor; kalan risk kullanıcı beklentisi ihlali ve yetim genel nesne. |
| **Düzeltme** | Kaldırma ve uzantı değiştiren yeniden yüklemede `client.storage.from('avatars').remove([path])`; profil URL'si yalnız silme başarılıysa temizlenmeli; başarısızlıkta kullanıcıya bildirilmeli. |
| **Güven** | **Yüksek** |

### `ZKR-REL-20260802-P1-008` — Avatar denetimsiz görsel UGC yüzeyi (A-05)

| Alan | İçerik |
|---|---|
| **Durum** | `VERIFIED DEFECT` · P1 · Store politikası (Apple 1.2 / Play UGC) |
| **Yabancılara görünürlük** | Liderlik (`leaderboard_screen.dart:938,1168` → `entry.avatarUrl`), eşleştirme/rakip (`matchmaking_screen.dart:415,515,1168`), oda sohbeti (`room_chat.dart`), turnuva tablosu (`tournament_bracket_widget.dart`). `avatar_url` başka oyuncular için sorgulanıp döndürülüyor (`supabase_zankurd_repository.dart:731,1176,1236,1260`). |
| **Süzme** | **Yok.** Bucket yalnız MIME (`jpeg/png/webp`) ve 2 MB sınırı uyguluyor; içerik/NSFW taraması yok. `ChatModerationPolicy` **yalnız metin** içindir. |
| **Bildirme** | **Yok.** `report_room_message` yalnız sohbet mesajı bildirir; avatarı bildirmenin hiçbir yolu yok. |
| **Engelleme** | **Kısmi/etkisiz.** `block_player` sohbeti süzüyor; liderlik ve eşleştirme sorgularında engellenen kullanıcı filtresi yok, dolayısıyla engellenen kişinin avatarı görünmeye devam ediyor. |
| **İletişim** | Var (`nisebinbawer47@gmail.com`) ✓ |
| **Apple 1.2 karşılaştırması** | süz ✗ · bildir ✗ · engelle ✗(avatar için) · iletişim ✓ → **4 şarttan 3'ü avatar yüzeyi için karşılanmıyor** |
| **Düzeltme** | (a) avatarı bildirme akışı (mevcut `message_reports` deseni genişletilebilir); (b) engellenen kullanıcının avatarının istemciye hiç gelmemesi veya yerel olarak gizlenmesi; (c) yükleme sonrası moderasyon kuyruğu veya otomatik NSFW taraması; (d) admin tarafından avatarı devre dışı bırakma alanı. |
| **Güven** | **Yüksek** |

### `ZKR-REL-20260802-P1-009` — Görünen adlar hiçbir filtreden geçmiyor (A-06)

| Alan | İçerik |
|---|---|
| **Durum** | `VERIFIED DEFECT` · P1 · Store politikası (Apple 1.2 / Play UGC) |
| **Yazma yolları** | İsim kapısı (`profile_name_gate_screen.dart`), kayıt (`sign_up_screen.dart` → `display_name` metadata), profil düzenleme; hepsi `updateProfileName` → `profiles.display_name` (`supabase_zankurd_repository.dart:219`, `:149`) |
| **İstemci doğrulaması** | **Yalnız uzunluk**: `name.length < 2` ve `name.length > 24` (`profile_name_gate_screen.dart:323,326`). Küfür, Unicode/görünmez karakter, kimlik taklidi, korunan ad kontrolü **yok**. |
| **Küfür filtresi kapsamı** | `ChatModerationPolicy` deponun tamamında **tek bir yerde** çağrılıyor: `room_chat.dart:148`. Adlara **hiç uygulanmıyor**. |
| **Sunucu doğrulaması** | **Yok** — `display_name` için CHECK constraint, trigger veya doğrulayan RPC bulunamadı (tüm `supabase/*.sql` tarandı). |
| **Sonuç** | Kullanıcı adını herhangi bir küfür/hakaret/kimlik taklidi dizesine ("ZanKurd Destek", "Admin", vb.) ayarlayabilir; ad liderlikte, odalarda, eşleştirmede ve sohbette yabancılara gösterilir. Adı bildirmenin yolu da yok. |
| **Düzeltme** | (a) `ChatModerationPolicy.review`'i (veya ad'a özel bir sürümünü) üç istemci yoluna da uygulamak; (b) **sunucu tarafında** `display_name` üzerinde trigger/constraint — istemci filtresi tek başına bypass edilebilir; (c) korunan ad listesi; (d) adı bildirme yolu. |
| **Güven** | **Yüksek** |

---

## 7. Yanlış alarmlar (`NOT A DEFECT`)

### A-04 — `analytics_events` ikinci analitik hattı

**İddia:** Supabase'de `analytics_events` tablosu var ve uygulama Firebase
rızasından bağımsız olarak buraya kullanıcı davranışı yazıyor.

**Neden yanlış:**

| Kontrol | Sonuç |
|---|---|
| `lib/` içinde `analytics_events` referansı | **0** |
| `lib/` içinde `log_event` / `track_event` / `telemetry` | **0** |
| Migration'larda `insert into … analytics_events` | **0** |
| Tablo var mı? | Evet — `2026-07-06_persistence.sql`, RLS açık, yalnız "Users can view own analytics" SELECT politikası |

Tablo **ölü şemadır**: oluşturulmuş, RLS'i açık, ama ne istemci ne de herhangi
bir RPC ona yazıyor. Görev tanımındaki taksonomiye göre bu **durum 1**
("Tablo yalnız migration'da var ama hiç kullanılmıyor"). Bir tablonun varlığı
veri toplandığını kanıtlamaz.

**Yeniden açılma koşulu:** `lib/` veya bir edge function `analytics_events`e
insert etmeye başlarsa; ya da canlı tabloda satır bulunursa (bu turda canlı
veritabanı sorgulanmadı).

**Öneri (P3, bu turda bulgu sayılmadı):** kullanılmayan tablo kaldırılmalı ya
da amacı belgelenmeli.

---

## 8. Bloke / sonuçsuz kontroller

| Kontrol | Durum | Sebep |
|---|---|---|
| Üretim config ile Android AAB | `BLOCKED` | `REVENUECAT_API_KEY_ANDROID/IOS` yok; uydurulmadı |
| Üretim config ile Android smoke | `BLOCKED` | aynı |
| Üretim config ile iOS build/smoke | `BLOCKED` | aynı |
| **A-10 iOS çıkışsızlık — cihaz testi** | `NOT RUN` | Kaynak kanıtı kesin (Scaffold/AppBar yok + `PageRouteBuilder`, Cupertino geçişi hiç yok). iOS'ta quiz'i uçtan uca sürmek çok sayıda etkileşim gerektirdiği için bu turda çalıştırılmadı. **Bir sonraki turda cihazda doğrulanmalı.** |
| A-01 gerçek satın alma | `NOT RUN` | Üretimde coin harcamak mutasyondur |
| A-03 gerçek avatar yükleme/silme | `NOT RUN` | Üretim Storage'ında mutasyon yapılmadı |
| A-05/A-06 gerçek uygunsuz içerik testi | `NOT RUN` | Üretimde uygunsuz ad/avatar oluşturulmadı |
| Canlı Supabase şeması ↔ migration drift | `INCONCLUSIVE` | P2-002 (Aşama 1) — canlı veritabanı sorgulanmadı |

---

## 9. Güncel açık P0 / P1 listesi

| ID | Başlık | Durum |
|---|---|---|
| `P0-001` | Üretim FTP kimlik bilgisi git geçmişinde | `MITIGATED — ROTATED / RESIDUAL HISTORY OPEN` |
| `P1-002` | iPad destekleniyor ama düzen bitmemiş | `OPEN — DEFERRED` |
| `P1-005` | Üretim AAB yapılandırma ekranında açılıyor | **`BLOCKED — OWNER-SUPPLIED RELEASE CONFIG REQUIRED`** |
| **`P1-006`** | Neon çerçeve satın alınamıyor | **`OPEN` (yeni)** |
| **`P1-007`** | Quiz sonucundan liderlik ekranı bozuk | **`OPEN` (yeni)** |
| **`P1-008`** | Avatar denetimsiz görsel UGC | **`OPEN` (yeni)** |
| **`P1-009`** | Görünen adlar filtresiz | **`OPEN` (yeni)** |

`P1-001`, `P1-003`, `P1-004` Aşama 2'de `FIXED`.

---

## 10. Güncel readiness

| Alan | Karar | Gerekçe |
|---|---|---|
| CODE QUALITY READINESS | **`READY`** | Format ✅ · analyze ✅ · soru kalitesi kapısı ✅ · 1302/1302 test ✅ (Aşama 3 sonunda yeniden koşuldu) |
| ANDROID BINARY READINESS | **`NOT READY`** | P1-005 kapanmadı — üretim yapılandırmasıyla çalışan bir AAB henüz üretilemedi. Ayrıca P1-006 (mağaza ürünü) ve P1-007 (liderlik) açık. |
| IOS BINARY READINESS | **`NOT READY`** | P1-002 (iPad) açık; P1-005 iOS'ta da geçerli; P1-007'nin iOS'ta çıkışsızlık riski var |
| GOOGLE PLAY CONSOLE SUBMISSION READINESS | **`NOT READY`** | Data Safety / Advertising ID beyanı yapılmadı; **P1-008 ve P1-009 UGC şartlarını karşılamıyor**; P1-005 açık |
| APP STORE CONNECT SUBMISSION READINESS | **`NOT READY`** | Apple 1.2 dört şartından avatar ve ad yüzeyleri için üçü eksik (P1-008, P1-009); iPad (P1-002); App Privacy formu yapılmadı |

---

## 11. Sonraki düzeltme paketi (önerilen — 4 iş)

Yalnız bu turda **gerçekten doğrulanan** bulgulara dayanır.

| # | İş | Bulgular | Büyüklük | Gerekçe |
|---|---|---|---|---|
| 1 | **UGC moderasyon paketi** | `P1-008`, `P1-009` | **L** | İkisi de aynı kök nedeni paylaşıyor (metin dışı UGC yüzeyleri moderasyon kapsamı dışında) ve ikisi de **mağaza reddi** riskidir. Birlikte yapılmalı: ad filtresi (istemci+sunucu), avatar bildir/engelle, engellenen kullanıcının liderlik/eşleştirmede süzülmesi. |
| 2 | **Mağaza ürün bütünlüğü** | `P1-006` | **S** | Tek satırlık allowlist migration'ı + `spendCoins`'in sunucu hata dizesini taşıması. Düşük risk, yüksek kullanıcı etkisi. |
| 3 | **Liderlik rotası + iOS geçişleri** | `P1-007` | **M** | Push edilen kullanımı Scaffold'a sarmak; ayrıca `pageTransitionsTheme` ile iOS swipe-back kazandırmak uygulama genelinde fayda sağlar. |
| 4 | **Kontrast + avatar temizliği** | `P2-010`, `P2-011` | **S** | İkisi de küçük ve bağımsız; kontrast düzeltmesi yanına kalıcı test eklenmeli. |

**Pakete dahil edilmeyenler:** `P1-005` (sahip tarafından anahtar gerekiyor),
`P1-002` (ayrı tasarım sprinti), `P0-001` kalıntısı (ayrı ve yedekli history
cleanup), Ek A'nın kalan orta/düşük öncelikli adayları (henüz doğrulanmadı).
