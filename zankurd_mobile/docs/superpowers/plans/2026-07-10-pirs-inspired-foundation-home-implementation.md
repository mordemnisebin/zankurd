# Pirs-Inspired Foundation and Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ZanKurd'un tasarım temelini, giriş akışını ve ana deneyimini Pirs-inspired açık, renkli ve modern görsel sisteme taşımak; mevcut logic ve navigation davranışını değiştirmemek.

**Architecture:** Mevcut `AppTheme` ve ekran componentleri korunup yeni token ailesine uyarlanacak. Tek yeni ortak görsel primitive `ColorfulActionCard` olacak; home quick-play kartları bunu kullanacak ve sonraki paketler aynı API'yi tüketebilecek. Auth, shell ve home ekranlarında yalnızca widget ağacı/stil değişecek; callback, provider ve repository çağrıları aynen kalacak.

**Tech Stack:** Flutter, Dart, Material 3, Provider, SharedPreferences, flutter_test, Playwright CLI; yeni dependency yok.

## Global Constraints

- Navigation, route, event handler, provider, repository, service, Supabase ve auth davranışı değişmeyecek.
- Quiz, oda, matchmaking, 1vs1/team, coin, XP ve ödül hesapları bu planda değişmeyecek.
- Light mode varsayılan; dark mode eksiksiz ve okunabilir kalacak.
- Ana kart radius değeri `16`; tıklanabilir alanlar en az `44x44`.
- Telefon 360 px, tablet 768 px ve desktop 1440 px doğrulanacak.
- Kurmancî/Türkçe metinlerde `maxLines`, `overflow` ve uygun line-height kullanılacak.
- Pirs logo, illüstrasyon, ikon veya ekran kompozisyonu kopyalanmayacak.
- Yeni dependency ve büyük refactor yok.

---

### Task 1: Tema Sözleşmesi ve Light-First Tokenlar

**Files:**
- Modify: `lib/src/theme/app_theme.dart:94-388`
- Modify: `lib/src/providers/theme_provider.dart:4-43`
- Modify: `test/theme_default_test.dart:22-46`
- Modify: `test/tokens_preview_test.dart`

**Interfaces:**
- Produces: `AppTheme.playGreen`, `playPink`, `playCyan`, `playPurple`, `brandOrange`, `brandOrangeWarm` sabitleri.
- Produces: `ThemeProvider()` ve kayıtlı değer bulunmayan `ThemeProvider.load()` için `ThemeMode.light`.
- Preserves: `AppTheme.primaryGradientStart`, `accent`, `cyan`, `violet` legacy isimleri.

- [ ] **Step 1: Light-first sözleşmesini testte tanımla**

`test/theme_default_test.dart` içindeki koyu tema beklentisini şu sözleşmeyle değiştir:

```dart
testWidgets('sıfır kurulumda onboarding açık temayla açılır', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final themeProvider = await ThemeProvider.load();
  expect(themeProvider.mode, ThemeMode.light);

  await tester.pumpWidget(
    ZanKurdApp(
      repository: MockZanKurdRepository(),
      authProvider: _GateAuthProvider(),
      languageProvider: LanguageProvider()..setLang('tr'),
      themeProvider: themeProvider,
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(OnboardingScreen), findsOneWidget);
  expect(
    Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
    Brightness.light,
  );
});
```

`test/tokens_preview_test.dart` içine token regresyonu ekle:

```dart
test('Pirs-inspired brand token contract stays stable', () {
  expect(AppRadius.card, 16);
  expect(AppTheme.brandOrange, const Color(0xFFF47A32));
  expect(AppTheme.playGreen, const Color(0xFF58B96B));
  expect(AppTheme.playPink, const Color(0xFFE72F8C));
  expect(AppTheme.playCyan, const Color(0xFF3BC7C1));
  expect(AppTheme.playPurple, const Color(0xFF8A62D3));
  expect(AppTheme.lightBg, const Color(0xFFF4F5F7));
});
```

- [ ] **Step 2: Testlerin beklenen nedenle başarısız olduğunu doğrula**

Run: `flutter test test/theme_default_test.dart test/tokens_preview_test.dart`

Expected: `ThemeMode.dark` ve eksik yeni tokenlar nedeniyle FAIL.

- [ ] **Step 3: Minimum tema değişikliğini uygula**

`app_theme.dart` içinde tokenları ekle/uyarla:

```dart
static const brandOrange = Color(0xFFF47A32);
static const brandOrangeWarm = Color(0xFFFF9F1C);
static const playGreen = Color(0xFF58B96B);
static const playPink = Color(0xFFE72F8C);
static const playCyan = Color(0xFF3BC7C1);
static const playPurple = Color(0xFF8A62D3);

static const primaryGradientStart = brandOrange;
static const primaryGradientEnd = brandOrangeWarm;
static const accent = playPink;
static const cyan = playCyan;
static const violet = playPurple;

static const lightBg = Color(0xFFF4F5F7);
static const lightBgDeep = Color(0xFFE9EDEB);
static const lightSurface = Color(0xFFFFFFFF);
static const lightSurfaceHi = Color(0xFFF8F9FA);
static const lightBorder = Color(0xFFDFE2E6);
```

`AppRadius.card` değerini `16` yap. `cardShadow` içindeki katı 4 px gölgeyi yumuşat:

```dart
return [
  BoxShadow(
    color: shadowColor.withValues(alpha: isDark ? 0.24 : 0.12),
    offset: const Offset(0, 8),
    blurRadius: 18,
    spreadRadius: -8,
  ),
];
```

`elevatedShadow` da katı 5 px taban yerine aynı yumuşak derinliği kullanmalı:

```dart
static List<BoxShadow> elevatedShadow(Color tint) => [
  BoxShadow(
    color: tint.withValues(alpha: 0.18),
    offset: const Offset(0, 8),
    blurRadius: 18,
    spreadRadius: -8,
  ),
];
```

`theme_provider.dart`:

```dart
ThemeProvider({ThemeMode initialMode = ThemeMode.light}) : _mode = initialMode;

static ThemeMode _decode(String? value) {
  return switch (value) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };
}
```

- [ ] **Step 4: Tema testlerini çalıştır**

Run: `flutter test test/theme_default_test.dart test/tokens_preview_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/theme/app_theme.dart lib/src/providers/theme_provider.dart test/theme_default_test.dart test/tokens_preview_test.dart
git commit -m "ui: establish Pirs-inspired light-first tokens"
```

### Task 2: Ortak Renkli Aksiyon Kartı

**Files:**
- Create: `lib/src/widgets/colorful_action_card.dart`
- Create: `test/colorful_action_card_test.dart`

**Interfaces:**
- Produces: `ColorfulActionCard({title, subtitle, icon, colors, onTap, loading, semanticLabel, key})`.
- Consumes: Task 1 tokenları ve `AppRadius.card`.

- [ ] **Step 1: Render, callback ve loading testlerini yaz**

```dart
testWidgets('ColorfulActionCard renders and invokes callback', (tester) async {
  var taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ColorfulActionCard(
          title: '1 vs 1',
          subtitle: 'Hemen oyna',
          icon: Icons.bolt_rounded,
          colors: const [AppTheme.playPink, Color(0xFFFF6B70)],
          onTap: () => taps++,
        ),
      ),
    ),
  );

  expect(find.text('1 vs 1'), findsOneWidget);
  expect(find.text('Hemen oyna'), findsOneWidget);
  await tester.tap(find.text('1 vs 1'));
  expect(taps, 1);
});

testWidgets('loading card ignores taps and shows progress', (tester) async {
  var tapped = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ColorfulActionCard(
          title: 'Günün Yarışması',
          icon: Icons.emoji_events_rounded,
          colors: const [AppTheme.brandOrange, AppTheme.brandOrangeWarm],
          loading: true,
          onTap: () => tapped = true,
        ),
      ),
    ),
  );
  await tester.tap(find.text('Günün Yarışması'));
  expect(tapped, isFalse);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

- [ ] **Step 2: Testin eksik widget nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/colorful_action_card_test.dart`

Expected: import/class bulunamadığı için FAIL.

- [ ] **Step 3: Widgetı uygula**

Widget şu yapıyı kullanmalı:

```dart
class ColorfulActionCard extends StatelessWidget {
  const ColorfulActionCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.loading = false,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool loading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: semanticLabel ?? title,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppTheme.elevatedShadow(colors.first),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 10,
                bottom: -8,
                child: Icon(icon, size: 68, color: Colors.white12),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Widget testini çalıştır**

Run: `flutter test test/colorful_action_card_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/widgets/colorful_action_card.dart test/colorful_action_card_test.dart
git commit -m "ui: add reusable colorful action card"
```

### Task 3: App Shell ve Alt Navigasyon

**Files:**
- Modify: `lib/src/screens/app_shell.dart:117-355`
- Modify: `test/widget_test.dart:614-677`

**Interfaces:**
- Preserves: `_tab`, scroll-to-top, refresh signals ve beş `NavigationDestination` callback akışı.
- Consumes: Task 1 `brandOrange` ve context-aware yüzey tokenları.

- [ ] **Step 1: Light navigation görsel sözleşmesini ekle**

Mevcut home testine şu assertionları ekle:

```dart
final navTheme = tester.widget<NavigationBarTheme>(
  find.byType(NavigationBarTheme),
);
expect(navTheme.data.height, 68);
expect(navTheme.data.backgroundColor, AppTheme.lightSurface);
expect(navTheme.data.indicatorColor, AppTheme.brandOrange.withValues(alpha: 0.14));
```

Sekme değişimi için mevcut callback davranışını koruyan assertion:

```dart
await tester.tap(find.text('Kategoriler'));
await tester.pumpAndSettle();
expect(find.byType(CategoriesTab), findsOneWidget);
```

- [ ] **Step 2: Testin eski seçili renk nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "home header exposes language and theme quick controls"`

Expected: indicator rengi eski `_tabAccent` olduğu için FAIL.

- [ ] **Step 3: NavigationBar stilini sadeleştir**

`onDestinationSelected` bloğunu değiştirme. Yalnızca theme değerlerini şu sözleşmeye getir:

```dart
backgroundColor: AppTheme.surfaceColor(context),
indicatorColor: AppTheme.brandOrange.withValues(alpha: 0.14),
indicatorShape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadius.sm),
),
shadowColor: Colors.black.withValues(alpha: 0.08),
elevation: 4,
```

Seçili ikon/label `brandOrange`, seçili olmayanlar `textMutedColor(context)` kullanmalı. Sekme kimlik renkleri içerik header'larında kalmalı; bottom nav her sekmede renk değiştirmemeli.

- [ ] **Step 4: Shell testlerini çalıştır**

Run: `flutter test test/widget_test.dart --plain-name "home header exposes language and theme quick controls"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/app_shell.dart test/widget_test.dart
git commit -m "ui: simplify colorful app navigation"
```

### Task 4: Splash ve Onboarding'i Açık/Renkli Sisteme Taşı

**Files:**
- Modify: `lib/src/screens/splash_screen.dart`
- Modify: `lib/src/screens/onboarding_screen.dart:51-610`
- Modify: `test/widget_test.dart:469-559`

**Interfaces:**
- Preserves: onboarding page count, `onComplete`, skip/next callbacks ve SharedPreferences kapısı.
- Consumes: Task 1 theme tokenları.

- [ ] **Step 1: Onboarding responsive ve tema testlerini genişlet**

Mevcut portrait/tablet testlerine ekle:

```dart
expect(
  Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
  Brightness.light,
);
expect(tester.takeException(), isNull);
expect(find.text('İleri'), findsOneWidget);
```

İlk sayfa root container'ına `ValueKey('onboarding-surface')` eklenmesini bekleyen test:

```dart
final surface = tester.widget<Container>(
  find.byKey(const ValueKey('onboarding-surface')),
);
final decoration = surface.decoration as BoxDecoration;
expect(decoration.color, AppTheme.lightBg);
```

- [ ] **Step 2: Testin key ve açık yüzey eksikliği nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "onboarding fits"`

Expected: key/yüzey assertionı nedeniyle FAIL.

- [ ] **Step 3: Görsel uygulamayı yap**

- Root yüzey `AppTheme.bgOf(context)` kullanmalı; sabit koyu gradient kaldırılmalı.
- Üst logo daha küçük ve nefes alan beyaz kartta kalmalı.
- Her sayfanın ana görsel kartı sırasıyla `playCyan`, `playPink`, `brandOrange` tint kullanmalı.
- Başlık `textPrimaryColor(context)`, açıklama `textSubColor(context)` olmalı.
- Primary next CTA `brandOrange -> brandOrangeWarm` gradient kullanmalı.
- Dekoratif kilim deseni yüzde 5-8 opaklıkta yalnızca görsel kart içinde kalmalı.
- Splash mevcut yönlendirme zamanlamasını değiştirmeden `lightBg` + logo + `brandOrange` progress kullanmalı.

- [ ] **Step 4: Onboarding testlerini çalıştır**

Run: `flutter test test/theme_default_test.dart test/widget_test.dart --plain-name "onboarding"`

Expected: PASS ve overflow yok.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/splash_screen.dart lib/src/screens/onboarding_screen.dart test/widget_test.dart
git commit -m "ui: refresh splash and onboarding surfaces"
```

### Task 5: Sign-in, Sign-up ve Name Gate Tema Uyumu

**Files:**
- Modify: `lib/src/screens/sign_in_screen.dart:180-870`
- Modify: `lib/src/screens/sign_up_screen.dart:175-520`
- Modify: `lib/src/screens/profile_name_gate_screen.dart:81-345`
- Modify: `test/widget_test.dart:339-455, 678-805`

**Interfaces:**
- Preserves: `_signIn`, `_signInAsGuest`, Google OAuth, form validation, loading kilidi, language toggle ve name save callbackleri.
- Removes: Auth ekranlarını zorla `Theme(data: AppTheme.dark())` ile sarmalama.

- [ ] **Step 1: Auth ekranlarının iki temada okunabilirliğini test et**

```dart
for (final theme in [AppTheme.light(), AppTheme.dark()]) {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _GateAuthProvider(),
          ),
          ChangeNotifierProvider(create: (_) => _turkishLang()),
        ],
        child: const SignInScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Misafir olarak devam et'), findsOneWidget);
  expect(tester.takeException(), isNull);
}
```

Sign-up ve name gate için aynı test yapısını kullan; mevcut field key'lerini ve CTA metinlerini assert et.

- [ ] **Step 2: Testin sabit koyu `Theme` nedeniyle light beklentisinde başarısız olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "auth form text stays readable"`

Expected: light brightness assertionı nedeniyle FAIL.

- [ ] **Step 3: Auth yüzeylerini context-aware yap**

- `Theme(data: AppTheme.dark())` wrapperlarını kaldır.
- Light: `lightBg`, beyaz form kartı, turuncu CTA, yeşil/turuncu compact welcome banner.
- Dark: `darkBg`, `surface`, aynı turuncu CTA; metin helperları context üzerinden.
- Google butonu iki temada beyaz; guest butonu outline/context yüzeyi.
- Inputlar `Theme.of(context).inputDecorationTheme` kullanmalı; sabit beyaz metin kaldırılmalı.
- Desktop iki kolon ve mobil tek kolon mevcut breakpointlerini koru.
- `maxLines: 1`, `TextOverflow.ellipsis` ve 44 px minimum action yüksekliği korunsun.

- [ ] **Step 4: Auth testlerini çalıştır**

Run: `flutter test test/widget_test.dart --plain-name "auth"`

Run: `flutter test test/widget_test.dart --plain-name "player name"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/sign_in_screen.dart lib/src/screens/sign_up_screen.dart lib/src/screens/profile_name_gate_screen.dart test/widget_test.dart
git commit -m "ui: make auth gates light-first and theme aware"
```

### Task 6: Home Profil Header ve Multiplayer Hero

**Files:**
- Modify: `lib/src/screens/home_screen.dart:141-640`
- Modify: `lib/src/screens/home/hero_card.dart`
- Modify: `test/home_before_after_test.dart`
- Modify: `test/widget_test.dart:614-990`

**Interfaces:**
- Preserves: `_bootstrap`, `_refreshCoins`, `_refreshStreak`, mission loading, shop navigation ve room/match callbacks.
- Keeps: `HeroCard` constructor signature unchanged.

- [ ] **Step 1: Home görsel sözleşmesini test et**

Header root'una `ValueKey('home-profile-header')`, hero'ya `ValueKey('home-multiplayer-hero')` eklenmesini bekle:

```dart
expect(find.byKey(const ValueKey('home-profile-header')), findsOneWidget);
expect(find.byKey(const ValueKey('home-multiplayer-hero')), findsOneWidget);
expect(find.text('Oda kur'), findsOneWidget);
expect(find.text('Kodla katıl'), findsOneWidget);
expect(find.text('1vs1 — Hemen oyna'), findsOneWidget);
```

Header decoration assertionı:

```dart
final header = tester.widget<Container>(
  find.byKey(const ValueKey('home-profile-header')),
);
final decoration = header.decoration as BoxDecoration;
final gradient = decoration.gradient as LinearGradient;
expect(gradient.colors, [AppTheme.brandOrange, AppTheme.brandOrangeWarm]);
```

- [ ] **Step 2: Testin eski yeşil header nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/home_before_after_test.dart test/widget_test.dart --plain-name "home header"`

Expected: key ve gradient mismatch nedeniyle FAIL.

- [ ] **Step 3: Home header ve hero stilini uygula**

- `_buildGeometricHeader` içindeki veri/animasyon mantığını koru; header gradientini turuncu yap.
- Selamlama, oyuncu adı, coin, streak ve öncelikli görev turuncu header içinde tek taranabilir blok olmalı.
- Coin/streak chipleri yarı saydam beyaz, 44 px action alanı ve ellipsis taşımalı.
- `HeroCard` light modda beyaz yüzey + yeşil/turuncu vurgu; dark modda `surface` kullanmalı.
- Hero ana CTA turuncu; oda aksiyonları outline. `onQuickMatch`, `onCreateRoom`, `onJoinRoom` doğrudan aynı kontrollere bağlanmalı.
- Kilim deseni sadece hero içinde yüzde 5 opaklıkta kalmalı.

- [ ] **Step 4: Home/navigation testlerini çalıştır**

Run: `flutter test test/home_before_after_test.dart test/widget_test.dart --plain-name "home"`

Expected: PASS; oda, daily quiz, spin wheel ve join-code testleri korunur.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/home_screen.dart lib/src/screens/home/hero_card.dart test/home_before_after_test.dart test/widget_test.dart
git commit -m "ui: add colorful profile header and home hero"
```

### Task 7: Quick Play, Günlük Görev ve Zana Kartları

**Files:**
- Modify: `lib/src/screens/home/quick_play_grid.dart`
- Modify: `lib/src/screens/home/daily_missions_card.dart`
- Modify: `lib/src/widgets/zana_daily_card.dart`
- Modify: `test/quick_play_grid_test.dart`
- Modify: `test/home_before_after_test.dart`

**Interfaces:**
- Consumes: `ColorfulActionCard`.
- Preserves: `onDuel`, `onDailyQuiz`, `onSpinWheel`, `onTournament` ve loading davranışı.

- [ ] **Step 1: Quick-play renk ve callback sözleşmesini genişlet**

Mevcut callback testlerini koru ve dört kart key'i ekle:

```dart
expect(find.byKey(const ValueKey('quick-play-duel')), findsOneWidget);
expect(find.byKey(const ValueKey('quick-play-daily')), findsOneWidget);
expect(find.byKey(const ValueKey('quick-play-wheel')), findsOneWidget);
expect(find.byKey(const ValueKey('quick-play-tournament')), findsOneWidget);
expect(find.byType(ColorfulActionCard), findsNWidgets(4));
```

Dar ekran testi:

```dart
await tester.binding.setSurfaceSize(const Size(360, 740));
addTearDown(() => tester.binding.setSurfaceSize(null));
await tester.pumpWidget(wrap(buildGrid()));
await tester.pumpAndSettle();
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Testin eski `_QuickPlayTile` nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/quick_play_grid_test.dart`

Expected: `ColorfulActionCard` sayısı/key assertionı nedeniyle FAIL.

- [ ] **Step 3: Home kartlarını yeni dile taşı**

- `_QuickPlayTile` yerine dört `ColorfulActionCard` kullan.
- Renkler: duel `playPink`, daily `brandOrange`, wheel `playGreen`, tournament `playCyan`.
- 360 px'de 2 kolon; yatay/dar height durumunda mevcut responsive çözümü koru.
- `dailyQuizLoading` yalnızca daily karta aktarılmalı ve callback devre dışı kalmalı.
- `DailyMissionsCard`: beyaz/context surface, küçük renkli görev ikonları, ince progress, altın reward chip; büyük gradient yüzey yok.
- `ZanaDailyCard`: açık sıcak sarı yüzey, küçük maskot, tek satırlık etiket ve en fazla iki satır söz; kilim yüzde 4.

- [ ] **Step 4: Home component testlerini çalıştır**

Run: `flutter test test/quick_play_grid_test.dart test/home_before_after_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/home/quick_play_grid.dart lib/src/screens/home/daily_missions_card.dart lib/src/widgets/zana_daily_card.dart test/quick_play_grid_test.dart test/home_before_after_test.dart
git commit -m "ui: unify colorful home action cards"
```

### Task 8: Paket Doğrulaması ve Görsel Kanıt

**Files:**
- Create: `docs/screenshots/pirs-inspired/package-01/` altındaki screenshotlar.
- Modify only if assertions intentionally changed: ilgili golden/before-after testleri.

**Interfaces:**
- Produces: light/dark ve üç viewport için doğrulama kanıtı.

- [ ] **Step 1: Format kontrolü**

Run:

```bash
dart format lib/src/theme/app_theme.dart lib/src/providers/theme_provider.dart lib/src/widgets/colorful_action_card.dart lib/src/screens/app_shell.dart lib/src/screens/splash_screen.dart lib/src/screens/onboarding_screen.dart lib/src/screens/sign_in_screen.dart lib/src/screens/sign_up_screen.dart lib/src/screens/profile_name_gate_screen.dart lib/src/screens/home_screen.dart lib/src/screens/home/hero_card.dart lib/src/screens/home/quick_play_grid.dart lib/src/screens/home/daily_missions_card.dart lib/src/widgets/zana_daily_card.dart test/theme_default_test.dart test/tokens_preview_test.dart test/colorful_action_card_test.dart test/widget_test.dart test/home_before_after_test.dart test/quick_play_grid_test.dart
```

Expected: exit 0.

- [ ] **Step 2: Statik analiz**

Run: `dart analyze`

Expected: `No issues found!`

- [ ] **Step 3: Odaklı ve tam testler**

Run:

```bash
flutter test test/theme_default_test.dart test/tokens_preview_test.dart test/colorful_action_card_test.dart test/quick_play_grid_test.dart test/home_before_after_test.dart
flutter test
```

Expected: tüm testler PASS.

- [ ] **Step 4: Release web build**

Run: `flutter build web --release`

Windows path sorunu oluşursa aynı commit'i ASCII checkout `C:\src\zankurd_mobile` içinde, `TMP=C:\src\tmp` ve `TEMP=C:\src\tmp` ile doğrula.

Expected: `build/web` başarıyla oluşur; `main.dart.js`, `flutter_bootstrap.js`, `assets/`, `canvaskit/`, `manifest.json` ve `version.json` bulunur.

- [ ] **Step 5: Playwright görsel matrisi**

Release build'i yerel sunucuda aç ve şu screenshotları al:

```text
docs/screenshots/pirs-inspired/package-01/light-390x844-home.png
docs/screenshots/pirs-inspired/package-01/light-768x1024-home.png
docs/screenshots/pirs-inspired/package-01/light-1440x900-auth.png
docs/screenshots/pirs-inspired/package-01/dark-390x844-home.png
docs/screenshots/pirs-inspired/package-01/dark-390x844-auth.png
```

Her karede overflow, kesilen Kurmancî metin, 44 px'den küçük action, kaybolan metin, gereksiz koyu blok ve kontrolsüz desktop genişliği olmadığını doğrula. Console error/warning ve 4xx/5xx asset isteği olmamalı.

- [ ] **Step 6: Logic diff audit**

Run:

```bash
git diff --word-diff=porcelain HEAD~7..HEAD -- lib/src/screens lib/src/providers lib/src/theme lib/src/widgets
git diff --check HEAD~7..HEAD
```

Callback, navigation, repository/provider/service çağrılarında davranış farkı olmadığını diff üzerinden doğrula.

- [ ] **Step 7: Final doğrulama commit'i**

```bash
git add docs/screenshots/pirs-inspired/package-01
git commit -m "docs: verify Pirs-inspired foundation and home"
```

## Sonraki Paket

Bu plan tamamlandıktan ve görsel olarak onaylandıktan sonra ayrı planla Paket 2'ye geçilir: `categories_tab.dart`, `subcategory_screen.dart`, `learning_screen.dart` ve `level_screen.dart`. Bu dosyalar bu planda değiştirilmez.
