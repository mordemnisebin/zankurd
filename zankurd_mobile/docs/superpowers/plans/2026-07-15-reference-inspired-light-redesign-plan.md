# ZanKurd Referans Esintili Açık Tema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Google AI Studio üretimi `zankurd (1)` referansındaki güçlü oyun hiyerarşisini, varsayılanı açık ve koyu seçeneği eksiksiz olan Ronahî Arcade görsel sistemiyle Flutter ZanKurd uygulamasına uyarlamak.

**Architecture:** Mevcut provider/repository/route sözleşmeleri korunur. Görsel dönüşüm önce `AppTheme` ve ortak widget katmanında yapılır; ardından ekran aileleri bu token ve bileşenlere geçirilir. Büyük refactor yapılmaz, yalnızca değişen ekrandaki bağımsız görsel bloklar çıkarılır.

**Tech Stack:** Flutter, Dart, Provider, SharedPreferences, flutter_test, Playwright ile Flutter web görsel doğrulama.

## Global Constraints

- İlk kurulum `ThemeMode.light`; kayıtlı koyu tercih aynen korunur.
- Renkler: açık zemin `#F5F7FC`, yüzey `#FFFFFF`, yüksek yüzey `#EEF2FA`, ana metin `#171B2E`, turuncu `#E57832`, indigo `#5147C7`, ödül `#E9B949`, bilgi `#2D8BD8`.
- Koyu zemin `#101217`, koyu yüzey `#171C29`; koyu tema eksiksiz kalır.
- Doğru/yanlış renk semantiği, coin/XP/seri/quiz/oda/matchmaking davranışı değişmez.
- Supabase, repository, provider, auth, veri modeli, route ve mevcut test key'leri değişmez.
- Yeni paket veya font eklenmez; Rubik ve mevcut varlıklar kullanılır.
- Kurmancî metinlerin karakter ve anlam doğruluğu korunur.
- Kullanıcı değişikliği `macos/Flutter/GeneratedPluginRegistrant.swift` dosyasına dokunulmaz.
- Git/commit/push yapılmaz.

---

### Task 1: Ronahî Arcade Tema Sözleşmesi

**Files:**
- Modify: `test/app_theme_bubblegum_test.dart`
- Modify: `test/theme_default_test.dart`
- Modify: `lib/src/theme/app_theme.dart`
- Modify: `lib/src/widgets/app_panel.dart`
- Modify: `lib/src/widgets/styled_button.dart`
- Modify: `lib/src/widgets/screen_identity_header.dart`

**Interfaces:**
- Consumes: `ThemeProvider.load()`, `AppTheme.light()`, `AppTheme.dark()`.
- Produces: yeni token değerleri; `AppTheme.brandOrange`, `brandOrangeWarm`, `playPurple`, `lightBg`, `lightSurfaceHi`, `lightTextPrimary`, `bg`, `surface`, `surfaceHi` aynı public adlarla kalır.

- [ ] **Step 1: Yeni paleti isteyen başarısız tema testi yaz**

```dart
test('Ronahî Arcade açık paleti sabittir', () {
  expect(AppTheme.lightBg, const Color(0xFFF5F7FC));
  expect(AppTheme.lightSurface, const Color(0xFFFFFFFF));
  expect(AppTheme.lightSurfaceHi, const Color(0xFFEEF2FA));
  expect(AppTheme.lightTextPrimary, const Color(0xFF171B2E));
});

test('Ronahî Arcade vurgu paleti sabittir', () {
  expect(AppTheme.brandOrange, const Color(0xFFE57832));
  expect(AppTheme.playPurple, const Color(0xFF5147C7));
  expect(AppTheme.gold, const Color(0xFFE9B949));
  expect(AppTheme.playCyan, const Color(0xFF2D8BD8));
});

test('Ronahî Arcade koyu yüzeyleri sabittir', () {
  expect(AppTheme.bg, const Color(0xFF101217));
  expect(AppTheme.surface, const Color(0xFF171C29));
});
```

- [ ] **Step 2: Testin eski Bubblegum değerleri yüzünden kırıldığını doğrula**

Run: `flutter test test/app_theme_bubblegum_test.dart`
Expected: FAIL; ilk fark `0xFFF5F7FC` yerine `0xFFFAFAFF` veya vurgu tokenında eski indigo değeridir.

- [ ] **Step 3: Tema tokenlarını ve ortak yüzeyleri uygula**

```dart
static const brandOrange = Color(0xFFE57832);
static const brandOrangeWarm = Color(0xFFF09A52);
static const playGreen = Color(0xFF4EA66A);
static const playPink = Color(0xFFD94D72);
static const playCyan = Color(0xFF2D8BD8);
static const playPurple = Color(0xFF5147C7);
static const gold = Color(0xFFE9B949);
static const bg = Color(0xFF101217);
static const bgDeep = Color(0xFF0B0D12);
static const surface = Color(0xFF171C29);
static const surfaceHi = Color(0xFF202739);
static const lightBg = Color(0xFFF5F7FC);
static const lightBgDeep = Color(0xFFEFF3FA);
static const lightSurface = Color(0xFFFFFFFF);
static const lightSurfaceHi = Color(0xFFEEF2FA);
static const lightTextPrimary = Color(0xFF171B2E);
```

`AppPanel`, `GeometricGradientButton` ve `ScreenIdentityHeader` aynı tokenları kullanacak; açık temadaki kimlik başlığı koyu dolgu yerine açık tint yüzey + renkli ikon/başlık kullanacak.

- [ ] **Step 4: Tema ve ortak widget testlerini çalıştır**

Run: `flutter test test/app_theme_bubblegum_test.dart test/theme_default_test.dart test/pressable_card_test.dart`
Expected: PASS, 0 failure.

---

### Task 2: App Shell, Navigasyon ve Ana Sayfa Hiyerarşisi

**Files:**
- Create: `test/ronahi_home_shell_test.dart`
- Modify: `lib/src/screens/app_shell.dart`
- Modify: `lib/src/screens/home_screen.dart`
- Modify: `lib/src/screens/home/home_header.dart`
- Modify: `lib/src/screens/home/hero_card.dart`
- Modify: `lib/src/screens/home/daily_race_card.dart`
- Modify: `lib/src/screens/home/daily_missions_card.dart`
- Modify: `lib/src/widgets/zana_daily_card.dart`

**Interfaces:**
- Consumes: mevcut `HomeScreen` callback'leri ve `NavigationBar` tab indeksleri.
- Produces: `ValueKey('home-player-strip')`, `ValueKey('home-primary-play-card')`; mevcut create/join/quick-match callback'leri aynen çağrılır.

- [ ] **Step 1: Kompakt kullanıcı şeridi ve birincil oyun kartını isteyen widget testi yaz**

```dart
expect(find.byKey(const ValueKey('home-player-strip')), findsOneWidget);
expect(find.byKey(const ValueKey('home-primary-play-card')), findsOneWidget);
expect(find.text('Oda Kur'), findsOneWidget);
expect(find.text('Kodla Katıl'), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Testin eksik key nedeniyle kırıldığını doğrula**

Run: `flutter test test/ronahi_home_shell_test.dart`
Expected: FAIL; `home-player-strip` bulunamaz.

- [ ] **Step 3: Referans hiyerarşisini mevcut akışa uygula**

Ana header içinde avatar/ad/seviye solda, coin/seri rozetleri sağda ve görev ilerleme çizgisi altta yer alır. Hero kart tek birincil oyun eylemine odaklanır; oda kur/katıl mevcut callback'lerle ikincil butonlar olarak kalır. Navigation açık yüzey, üst kenarlık ve turuncu aktif durum kullanır; tab sayısı ve rotalar değişmez.

- [ ] **Step 4: Ana sayfa testlerini çalıştır**

Run: `flutter test test/ronahi_home_shell_test.dart test/kulturel_modern_home_test.dart test/home_before_after_test.dart test/zana_daily_card_test.dart`
Expected: PASS; preview testleri hariç davranış assertionları temizdir.

---

### Task 3: Bilîze, Kategori ve Oda Kartları

**Files:**
- Create: `lib/src/widgets/reference_mode_card.dart`
- Create: `test/reference_mode_card_test.dart`
- Modify: `lib/src/screens/play_hub_screen.dart`
- Modify: `lib/src/screens/categories_tab.dart`
- Modify: `lib/src/screens/home/quick_play_grid.dart`
- Modify: `lib/src/screens/home/room_actions.dart`

**Interfaces:**
- Produces: `ReferenceModeCard({required String title, required String subtitle, required IconData icon, required Color accent, required VoidCallback onTap, double? progress, Key? key})`.
- Consumes: mevcut QuickPlay ve oda callback'leri; kart yalnızca sunum yapar.

- [ ] **Step 1: Tam genişlik mod kartı için başarısız test yaz**

```dart
await tester.pumpWidget(_shell(ReferenceModeCard(
  title: 'Ziman',
  subtitle: 'Rêziman û ferhenga Kurmancî',
  icon: Icons.menu_book_rounded,
  accent: AppTheme.brandOrange,
  progress: .4,
  onTap: () => tapped = true,
)));
expect(find.text('Ziman'), findsOneWidget);
expect(find.byType(LinearProgressIndicator), findsOneWidget);
await tester.tap(find.text('Ziman'));
expect(tapped, isTrue);
```

- [ ] **Step 2: Testin widget eksik olduğu için kırıldığını doğrula**

Run: `flutter test test/reference_mode_card_test.dart`
Expected: FAIL at compile time because `ReferenceModeCard` does not exist.

- [ ] **Step 3: Kartı oluştur ve ekranlara entegre et**

Kart açık temada beyaz yüzey + renkli kare ikon + lacivert metin + yön oku;
koyu temada `surface` + ince border kullanır. `play_hub_screen.dart` içinde ana
oyun yolları bu kart ailesine geçer. Kategori görselleri korunur; başlık/meta
overlay kontrastı tokenlara bağlanır. Oda eylemleri tek panelde gruplanır.

- [ ] **Step 4: Bilîze/kategori testlerini çalıştır**

Run: `flutter test test/reference_mode_card_test.dart test/play_hub_screen_test.dart test/categories_tab_test.dart test/categories_before_after_test.dart test/quick_play_grid_test.dart`
Expected: PASS, 0 overflow/exception.

---

### Task 4: Quiz, Sonuç ve Şans Çarkı

**Files:**
- Create: `test/ronahi_game_surfaces_test.dart`
- Modify: `lib/src/screens/quiz_screen.dart`
- Modify: `lib/src/screens/quiz/quiz_widgets.dart`
- Modify: `lib/src/screens/quiz_result_screen.dart`
- Modify: `lib/src/screens/spin_wheel_screen.dart`

**Interfaces:**
- Consumes: mevcut quiz seçim, zamanlayıcı, joker ve spin repository callback'leri.
- Produces: `ValueKey('quiz-status-strip')`, `ValueKey('quiz-question-surface')`, `ValueKey('spin-primary-action')`; davranış değişmez.

- [ ] **Step 1: Açık oyun yüzeylerini isteyen başarısız testleri yaz**

```dart
expect(find.byKey(const ValueKey('quiz-status-strip')), findsOneWidget);
expect(find.byKey(const ValueKey('quiz-question-surface')), findsOneWidget);
expect(find.byKey(const ValueKey('spin-primary-action')), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Testlerin key'ler eksik olduğu için kırıldığını doğrula**

Run: `flutter test test/ronahi_game_surfaces_test.dart`
Expected: FAIL; yeni surface key'leri bulunamaz.

- [ ] **Step 3: Görsel hiyerarşiyi uygula**

Süre/ilerleme/coin aynı kompakt status stripte; soru beyaz birincil yüzeyde;
şıklar açık yüzey + belirgin seçili border ile gösterilir. Doğru/yanlış renkleri
değişmez. Sonuç ekranında skor, XP ve coin önce; eylemler sonra gelir. Çark
ortalanır ve tek ana buton `spin-primary-action` key'iyle işaretlenir.

- [ ] **Step 4: Oyun testlerini çalıştır**

Run: `flutter test test/ronahi_game_surfaces_test.dart test/quiz_experience_test.dart test/quiz_accent_test.dart test/quiz_result_visual_test.dart test/spin_wheel_screen_test.dart`
Expected: PASS; skor/ödül ve çift-spin testleri değişmeden geçer.

---

### Task 5: Liderlik, Profil ve Ayarlar

**Files:**
- Create: `test/ronahi_profile_leaderboard_test.dart`
- Modify: `lib/src/screens/leaderboard_screen.dart`
- Modify: `lib/src/screens/profile_screen.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Modify: `lib/src/widgets/weekly_performance_chart.dart`
- Modify: `lib/src/widgets/strength_map_section.dart`

**Interfaces:**
- Consumes: mevcut leaderboard yenileme, profil istatistik ve tema toggle callback'leri.
- Produces: `ValueKey('leaderboard-compact-list')`, `ValueKey('profile-identity-card')`; veri akışı değişmez.

- [ ] **Step 1: Kimlik ve kompakt liste testini yaz**

```dart
expect(find.byKey(const ValueKey('leaderboard-compact-list')), findsOneWidget);
expect(find.byKey(const ValueKey('profile-identity-card')), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Testin eksik görsel sözleşme nedeniyle kırıldığını doğrula**

Run: `flutter test test/ronahi_profile_leaderboard_test.dart`
Expected: FAIL; yeni key'ler bulunamaz.

- [ ] **Step 3: Referansın kompakt veri hiyerarşisini uygula**

Liderlik satırı rank/avatar/isim/skor/lig rozetini tek satırda taşır; ilk üç
rank rengi ve kullanıcının kendi satır tinti korunur. Profil kimlik kartında
avatar/ad/seviye/XP tek odakta toplanır. Grafik ve strength panelleri düz metin
yerine metrik yüzeylerini kullanır. Ayarlardaki tema toggle davranışı değişmez.

- [ ] **Step 4: Profil/liderlik testlerini çalıştır**

Run: `flutter test test/ronahi_profile_leaderboard_test.dart test/leaderboard_refresh_test.dart test/profile_menu_row_test.dart test/strength_map_section_test.dart test/theme_default_test.dart`
Expected: PASS.

---

### Task 6: Giriş, Onboarding ve Sistem Yüzeyleri

**Files:**
- Create: `test/ronahi_system_surfaces_test.dart`
- Modify: `lib/src/screens/onboarding_screen.dart`
- Modify: `lib/src/screens/sign_in_screen.dart`
- Modify: `lib/src/screens/sign_up_screen.dart`
- Modify: `lib/src/widgets/empty_state.dart`
- Modify: `lib/src/widgets/error_state.dart`
- Modify: `lib/src/widgets/branded_loader.dart`

**Interfaces:**
- Consumes: mevcut onboarding tamamlanma ve auth callback'leri.
- Produces: ortak açık yüzey, turuncu ana CTA ve indigo yardımcı vurgu; route ve auth çağrıları aynı kalır.

- [ ] **Step 1: Açık-varsayılan sistem yüzeyi testi yaz**

```dart
expect(Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
    Brightness.light);
expect(find.byKey(const ValueKey('onboarding-primary-action')), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Yeni CTA key'i eksik olduğu için testi kırmızı gör**

Run: `flutter test test/ronahi_system_surfaces_test.dart`
Expected: FAIL; `onboarding-primary-action` bulunamaz.

- [ ] **Step 3: Ortak sistem görünümünü uygula**

Onboarding ve auth yüzeyleri `AppTheme.backgroundGradient(context)`, beyaz kart,
turuncu ana CTA ve indigo yardımcı link kullanır. Empty/error/loading durumları
aynı yüzey ve ikon rozeti diline geçirilir; metin ve callback'ler değişmez.

- [ ] **Step 4: Sistem ekranı testlerini çalıştır**

Run: `flutter test test/ronahi_system_surfaces_test.dart test/onboarding_hierarchy_test.dart test/splash_screen_test.dart test/accessibility_guideline_test.dart`
Expected: PASS.

---

### Task 7: Tam Doğrulama ve Görsel Eleştiri

**Files:**
- Modify only if visual verification exposes a concrete defect in files already listed above.

**Interfaces:**
- Produces: analyze/test/build/browser evidence; no new product behavior.

- [ ] **Step 1: Değişen Dart dosyalarını formatla**

Run: `dart format <changed-dart-files>`
Expected: exit 0.

- [ ] **Step 2: Statik analizi çalıştır**

Run: `dart analyze`
Expected: `No issues found!` and exit 0.

- [ ] **Step 3: Tam test paketini çalıştır**

Run: `flutter test`
Expected: all tests pass, exit 0.

- [ ] **Step 4: Flutter web build oluştur**

Run: `flutter build web --release --wasm`
Expected: exit 0 and `build/web/main.dart.js` exists.

- [ ] **Step 5: Playwright ile açık/koyu ve mobil/tablet ekranlarını incele**

Run the built app locally; capture Home, Bilîze, Quiz, Liderlik, Profil and Spin at 390x844 and 768x1024. Check overflow, contrast, clipped labels, tap target size and visible focus.
Expected: no blank screen, no console error, no RenderFlex overflow; both themes preserve hierarchy.

- [ ] **Step 6: Gereken küçük görsel düzeltmeleri yap ve doğrulamayı tekrarla**

Any correction first receives a failing widget/regression test, then the relevant focused test, `dart analyze`, full `flutter test`, and browser smoke are rerun.
