# ZanKurd AI Handoff — Session 4
**Tarih**: 10 Haziran 2026
**Handoff**: Claude Code (Fable 5) → Codex
**Aktif branch**: `feature/polish-v1.3` (master'dan dallandı)
**Durum**: Release adayı korundu, Sprint 1 cila çalışması 4/6 tamamlandı

---

## 🎯 Bu Oturumda Yapılanlar (kronolojik)

### 1. Güvenlik temizliği + commit düzeni (master)
- `Pirs_apk_extracted/` (4.103 dosya, 47 MB, üçüncü taraf APK dökümü) git takibinden
  çıkarıldı, kök `.gitignore` eklendi → commit `08b7c59`
  - ⚠️ Dosyalar **git geçmişinde hâlâ var**; GitHub'a push öncesi `git filter-repo`
    ile geçmişten temizleme kararı verilecek (kullanıcıyla konuşuldu, ertelendi).
- Bekleyen tüm değişiklikler 4 mantıksal commit'e bölündü:
  - `392841a` — auth Firebase→Supabase migrasyonu + Crashlytics (google-services.json
    dahil; repo private kalacağı için bilinçli commit edildi)
  - `b254565` — günlük çark + quiz ödülleri (RPC SQL'leri dahil)
  - `9291208` — Play Store internal test hazırlığı, sürüm **1.2.0+3**
  - `zankurd/package-lock.json` ilgisizdi → revert edildi

### 2. 🔴 Coin güvenlik açığı kapatıldı (release bloker'ıydı) — `dbbfb87`
- **Açık**: `coin_transactions` RLS insert politikası `daily_spin:`/`quiz_complete:`
  dışındaki her reason ile **istenen miktarda** istemci insert'ine izin veriyordu
  (anonim kullanıcı dahil sınırsız coin yazılabilirdi).
- **Çözüm (3 katman)**:
  1. RLS: insert politikası tamamen kaldırıldı (`supabase/coin_policies.sql`
     güncellendi, kullanıcı prod'da çalıştırdı ve doğruladı — tek politika SELECT)
  2. İstemci: `_insertQuizCoinsFallback` silindi; `awardQuizCoins` RPC başarısızsa
     **0 döner** + Crashlytics'e `recordError` (sahte "+coin" gösterimi bitti)
  3. RPC'ler prod'da doğrulandı: `claim_quiz_reward` + `claim_daily_spin`, ikisi de
     `security definer = true`. **Not**: `claim_quiz_reward` prod'da eksikti,
     kullanıcı SQL Editor'dan oluşturdu.
- **Kural**: Coin yazmanın tek yolu security definer RPC'lerdir. İstemciden
  `coin_transactions`'a insert KESİNLİKLE eklenmemeli.

### 3. Release adayı dondu
- İmzalı AAB: `C:\src\zankurd_mobile\build\app\outputs\bundle\release\app-release.aab`
  (51,5 MB; v1.2.0, versionCode 3, com.zankurd.app, jarsigner verified)
- Tag: **`v1.2.0-internal.1`** (= `dbbfb87`, master). Play Console kimlik doğrulaması
  beklemede; doğrulama bitince bu AAB internal test'e yüklenecek (yeniden build
  GEREKMEZ — sonraki backend değişiklikleri sunucu tarafıydı).
- Gizlilik politikası host edilecek: `docs/privacy_policy.html` (Netlify Drop veya
  GitHub Pages önerildi). Play Console checklist'i `docs/play_store_internal_test.md`.

### 4. Sprint 1 cila çalışması (feature/polish-v1.3)
Etki/risk matrisiyle önceliklendirildi. Durum:

| # | Madde | Durum | Commit |
|---|---|---|---|
| 1 | Rubik tipografi sistemi | ✅ | `b7766f6` |
| 2 | AAB boyut optimizasyonu | ✅ kapatıldı — **aksiyon gereksizdi** (aşağıya bak) | — |
| 3 | M3 NavigationBar | ✅ | `ce21cd2` |
| 4 | Quiz mikro-animasyonları + haptics | ✅ | `5c5ef64` |
| 5 | Hata/boş durum standardı | ⬜ sıradaki | — |
| 6 | Uygulama içi hesap silme akışı | ⬜ (Supabase `delete_my_account` RPC gerekir; SQL önce kullanıcıya gösterilecek, prod'a KULLANICI uygular) | — |

**Madde detayları:**
- **Rubik (b7766f6)**: `assets/fonts/` altında 4 statik ağırlık (400/500/700/900,
  fonts.gstatic.com v31'den) + OFL.txt. `google_fonts` paketi BİLİNÇLİ kullanılmadı.
  Tema: `fontFamily: 'Rubik'`, başlıklarda negatif letterSpacing, gövdede height.
  î û ê ş ç İ ı karakterleri Windows'ta görsel doğrulandı (3 ekran).
- **Boyut analizi**: 51,5 MB AAB yanıltıcı — 26,5 MB hiç inmeyen debug symbols +
  3 ABI'lik native lib (cihaza tek ABI iner). **Gerçek indirme ~9-10 MB.** 72 soru
  görseli toplam 0,7 MB; WebP dönüşümü gereksiz görüldü (YAGNI).
- **M3 NavigationBar (ce21cd2)**: `app_shell.dart` + `app_theme.dart`. Mercan hap
  göstergesi (accent %18), height 68, eski bottomNavigationBarTheme silindi.
- **Quiz animasyonları (5c5ef64)**: SIFIR yeni dependency — yalnızca implicit
  animation'lar (testler `pumpAndSettle` ile uyumlu kalsın diye sonlu animasyonlar).
  - Cevap: `AnimatedScale`(0.98) + `AnimatedContainer` renk geçişi (220ms)
  - Haptics: seçim `lightImpact`, doğru `mediumImpact`, yanlış `heavyImpact`,
    50/50 `selectionClick` (`flutter/services` import edildi)
  - Soru geçişi: `AnimatedSwitcher` + slide/fade, `KeyedSubtree(ValueKey(index))`;
    soru paneli `_buildQuestionPanel()` metoduna çıkarıldı
  - 50/50: elenen şıklar artık kaybolmuyor → `AnimatedOpacity` 0.25 + `IgnorePointer`
  - Skor/seri: `TweenAnimationBuilder<int>` count-up; ilerleme çubuğu tween'li
  - Sonuç ekranı: coin paneli scale-in + coin sayısı 0→N count-up (800ms)

---

## ⚠️ Bilinen Sorunlar / Backlog

1. **Windows debug donması (font'la İLGİSİZ, önceden var)**: Profil sekmesindeki
   satırlara (Mîheng/Ayarlar, Pirsên Tomarkirî/Favoriler) tıklayınca uygulama
   "Yanıt Vermiyor" oluyor. Dart hatası YOK → platform (C++) tarafı. Font öncesi
   build ile aynen tekrar üretildi (kanıtlı). Home'dan quiz push'u çalışıyor;
   yalnızca Profil ekranından push donuyor. Android etkilenmiyor. Şüpheli:
   Firebase C++ desktop SDK / plugin method channel. Kullanıcı istemeden inceleme.
2. **Pirs_apk_extracted git geçmişinde** — push öncesi filter-repo kararı.
3. **Settings ekranındaki `appVersion = '1.1.0'` sabiti eski** (pubspec 1.2.0+3) —
   küçük tutarsızlık, ilk uygun commit'te güncellenebilir.
4. **Remote yok** — repo yalnızca bu diskte. Kullanıcı private GitHub push istiyor
   ama önce cila bitsin dedi. Keystore yedeği repo DIŞINDA tutulmalı.

---

## 🔧 Ortam Notları (kritik)

- **Git deposu**: `C:\Users\AMARGİ\Desktop\pirs kurmanci` (Türkçe karakterli yol!).
  Commit'ler SADECE burada atılır.
- **Build/test çalışma kopyası**: `C:\src\zankurd_mobile` (git deposu DEĞİL).
  Değişen dosyalar Desktop→C:\src manuel kopyalanır, sonra analyze/test/build.
- **Gradle/build için zorunlu**: `TMP/TEMP=C:\src\tmp` (yoksa loopback IOException).
- Release build dart-define'ları (anahtarlar `AI_HANDOFF_SESSION_3.md`'de):
  `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- dart-define VERİLMEZSE uygulama mock moduna düşer (görsel test için güvenli).
- Kalite çıtası: `flutter analyze` 0 uyarı, `flutter test` **19/19**.
- Kullanıcı çalışma şekli: her adım önce plan → onay → uygulama → rapor.
  Commit'ler kullanıcı onayıyla, mantıksal/küçük. Push ASLA kendiliğinden yapılmaz.

---

## ▶️ Sonraki Adımlar (öncelik sırasıyla)

1. **Sprint 1 madde 5**: Hata/boş durum standardı — ortak `EmptyState`/`ErrorState`
   widget'ı + "tekrar dene"; sessiz `catch (_)` noktalarına Crashlytics kaydı
   (home/leaderboard/favoriler).
2. **Sprint 1 madde 6**: Uygulama içi hesap silme — Ayarlar'a onaylı akış +
   Supabase `delete_my_account` security definer RPC (SQL'i kullanıcıya göster,
   prod'a o uygular). Play production politika gereksinimi.
3. Play Console doğrulaması bitince: privacy URL host et → Console formları →
   `v1.2.0-internal.1` AAB'sini internal test'e yükle.
4. Sonra: private GitHub remote + push (öncesinde filter-repo kararı).
5. Sprint 2 adayları: onboarding, FCM günlük hatırlatma, ekran dosyası bölme,
   i18n/ARB (büyük iş, ayrı sprint), bot rakip, öğrenme modu.
