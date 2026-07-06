# Profil + Joker Sadeleştirme — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Profil ekranını tek düzenli "Oyuncu Kartı" yapısına indirgeyip mor palet sapmasını ve rozet tekrarını kaldırmak; quiz jokerlerini kimlikli renkli şeride dönüştürmek; hero gradyanını sakinleştirip solo modda ölü skorboard'u gizlemek.

**Architecture:** Tüm değişiklikler görsel/yerleşim katmanında. `profile_screen.dart` içindeki mobil/geniş kopya düzenler, paylaşılan private widget/metotlara indirgenir. Joker mekanikleri (`spendCoins`, onay diyaloğu, `WildcardState`) değişmez; yalnızca `_WildcardButton` görsel katmanı ve `WildcardType` renk/etiket uzantıları güncellenir. Repository ve Supabase'e dokunulmaz.

**Tech Stack:** Flutter/Dart, Provider, `flutter_test`. Analiz için **`dart analyze`** (bu Windows ortamında `flutter analyze` çöküyor — kullanma). Spec: `docs/superpowers/specs/2026-07-06-profil-joker-sadelestirme-design.md`.

**Önemli ortam notları:**
- Çalışma ağacında bu plana ait OLMAYAN commit'lenmemiş değişiklikler var (Antigravity görsel yenilemesi). Commit adımlarında **yalnızca dokunduğun dosyaları** `git add <yol>` ile ekle; asla `git add -A` kullanma.
- Testlerin dil varsayılanı **Türkçe** (`_testShell` → `LanguageProvider()..setLang('tr')`), tema **light**. Metin beklentilerini TR yaz.
- Widget testlerinin varsayılan yüzeyi 800×600 → `ProfileScreen` için `isWide == true`. Mobil düzeni test etmek için viewport'u daralt (aşağıdaki test kodlarında var).
- `quiz/quiz_widgets.dart` bir `part of '../quiz_screen.dart'` dosyasıdır — kendi import'u olamaz.
- Tüm test komutları `zankurd_mobile/` dizininden çalıştırılır.

---

### Task 1: Profil menü panelini tek kaynağa indir (mobilde 6 öğe)

Mobil düzendeki menü paneli 4 öğe (Dukan ve Hevalên Min eksik), geniş düzendeki 6 öğe. İkisi de elle kopyalanmış ~250'şer satır. Tek metoda in.

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart`
- Test: `zankurd_mobile/test/widget_test.dart`

- [ ] **Step 1: Kırmızı testi yaz**

`widget_test.dart` içinde, mevcut `profile screen shows unlocked achievement showcase` testinin hemen üstüne ekle:

```dart
  testWidgets('profil mobil düzende 6 menü öğesinin tamamını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    // Geniş düzende var olup mobil kopyada unutulmuş iki öğe:
    await tester.scrollUntilVisible(
      find.text('Mağaza'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mağaza'), findsOneWidget);
    expect(find.text('Arkadaşlarım'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Çıkış Yap'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Çıkış Yap'), findsOneWidget);
  });
```

- [ ] **Step 2: Testin KIRMIZI olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "profil mobil düzende 6 menü öğesinin tamamını gösterir"`
Expected: FAIL — `find.text('Mağaza')` scrollUntilVisible zaman aşımı ya da findsNothing (mobil kopyada Mağaza yok).

- [ ] **Step 3: `_buildMenuPanel` metodunu yaz, iki düzeni de ona bağla**

`_ProfileScreenState` içine (örn. `_confirmSignOut`'un üstüne) ekle:

```dart
  Widget _menuRow({
    required Widget leading,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback? onTap,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMutedColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuPanel(bool ku) {
    final divider = Divider(
      height: 1,
      indent: 50,
      color: AppTheme.borderColor(context),
    );
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _menuRow(
            leading: const Icon(
              Icons.bookmark_outline,
              color: AppTheme.gold,
              size: 22,
            ),
            title: ku ? 'Pirsên Tomarkirî' : 'Kaydedilen Sorular',
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(
                  FavoriteQuestionsScreen(repository: widget.repository),
                ),
              );
            },
          ),
          divider,
          _menuRow(
            leading: _practiceLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                : const Icon(
                    Icons.school_outlined,
                    color: AppTheme.accent,
                    size: 22,
                  ),
            title: ku ? 'Şaşiyên Min' : 'Yanlışlarım',
            subtitle: _mistakeCount == 0
                ? (ku ? 'Şaşiyek tune — aferîn!' : 'Hiç yanlışın yok — aferin!')
                : (ku
                      ? 'Ji bo dubarekirinê: $_readyMistakeCount / Tevavî: $_mistakeCount'
                      : 'Tekrar Edilecek: $_readyMistakeCount / Toplam: $_mistakeCount'),
            onTap: _practiceLoading ? null : _startMistakePractice,
          ),
          divider,
          _menuRow(
            leading: const Icon(
              Icons.storefront_outlined,
              color: AppTheme.gold,
              size: 22,
            ),
            title: ku ? 'Dukan' : 'Mağaza',
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(ShopScreen(repository: widget.repository)),
              );
            },
          ),
          divider,
          _menuRow(
            leading: const Icon(
              Icons.people_outline,
              color: AppTheme.accent,
              size: 22,
            ),
            title: ku ? 'Hevalên Min' : 'Arkadaşlarım',
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(FriendsScreen(repository: widget.repository)),
              );
            },
          ),
          divider,
          _menuRow(
            leading: const Icon(
              Icons.settings_outlined,
              color: AppTheme.violet,
              size: 22,
            ),
            title: ku ? 'Mîheng' : 'Ayarlar',
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(SettingsScreen(repository: widget.repository)),
              );
            },
          ),
          divider,
          _menuRow(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppTheme.wrong,
              size: 22,
            ),
            title: ku ? 'Derkeve' : 'Çıkış Yap',
            titleColor: AppTheme.wrong,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
```

Sonra:
- `rightColumn` içindeki `// Navigasyon kısayolları` yorumuyla başlayan `AppPanel(...)` bloğunun tamamını (satır ~508-769) `_buildMenuPanel(ku),` ile değiştir.
- Mobil daldaki (else `...[` bloğu) aynı şekilde `// Navigasyon kısayolları` yorumlu `AppPanel(...)` bloğunun tamamını (satır ~1124-1326) `_buildMenuPanel(ku),` ile değiştir.

- [ ] **Step 4: Testin YEŞİL olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "profil mobil düzende 6 menü öğesinin tamamını gösterir"`
Expected: PASS

- [ ] **Step 5: Analiz + ilgili test dosyası**

Run: `dart analyze` → Expected: `No issues found!`
Run: `flutter test test/widget_test.dart` → Expected: tümü PASS

- [ ] **Step 6: Commit**

```bash
git add lib/src/screens/profile_screen.dart test/widget_test.dart
git commit -m "refactor(profil): menü paneli tek kaynağa indi, mobilde 6 öğenin tamamı"
```

---

### Task 2: `_PlayerHeaderCard` — mor kart ölüyor, oyuncu kartı geliyor

Mobildeki mor gradyan başlık kartı ve geniş düzendeki yeşil kart, tek bir `_PlayerHeaderCard` widget'ında birleşir: `PlayerAvatar` + düzenleme rozeti + unvan çipi + Ast/XP + üç istatistik çipi (coin / günlük seri / oyun).

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart`
- Test: `zankurd_mobile/test/widget_test.dart`

- [ ] **Step 1: Kırmızı testi yaz**

Task 1'de eklenen testin altına ekle:

```dart
  testWidgets('profil mobil düzende oyuncu kartını (avatar düzenleme dahil) gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    // Mobil kopyadaki mor kart PlayerAvatar ve düzenleme rozetinden yoksundu.
    expect(find.byType(PlayerAvatar), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-avatar-edit')), findsOneWidget);
  });
```

`widget_test.dart` import'larına (yoksa) ekle:

```dart
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';
```

- [ ] **Step 2: Testin KIRMIZI olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "profil mobil düzende oyuncu kartını (avatar düzenleme dahil) gösterir"`
Expected: FAIL — mobil düzen `CircleAvatar` kullanıyor, `PlayerAvatar` ve `profile-avatar-edit` yok.

- [ ] **Step 3: State'e coin/seri verisi ekle**

`_ProfileScreenState` alanlarına ekle:

```dart
  int? _coinBalance;
  int _dailyStreak = 0;
```

`profile_screen.dart` import'larına ekle:

```dart
import '../data/streak_store.dart';
```

`_load()` metodunda `final xpStore = await XPStore.load();` satırından sonra ekle (coin hatası tüm profili düşürmesin diye kendi try'ında):

```dart
      final streakStore = await StreakStore.load();
      int? coins;
      try {
        coins = await widget.repository.loadCoinBalance();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'profile coin load failed');
      }
```

Aynı metottaki `setState` bloğuna ekle:

```dart
          _coinBalance = coins;
          _dailyStreak = streakStore.effectiveStreak();
```

- [ ] **Step 4: `_PlayerHeaderCard` widget'ını yaz**

Dosyanın sonuna (örn. `_LangToggle`'ın üstüne) ekle:

```dart
class _PlayerHeaderCard extends StatelessWidget {
  const _PlayerHeaderCard({
    required this.isKu,
    required this.displayName,
    required this.avatarIdentity,
    required this.level,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.levelProgress,
    required this.coinBalance,
    required this.dailyStreak,
    required this.roomsPlayed,
    required this.onEditAvatar,
  });

  final bool isKu;
  final String displayName;
  final AvatarIdentity avatarIdentity;
  final int level;
  final int xpInLevel;
  final int xpNeeded;
  final double levelProgress;
  final int? coinBalance;
  final int dailyStreak;
  final int? roomsPlayed;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (coinBalance != null)
        _statChip(Icons.monetization_on_outlined, '$coinBalance',
            isKu ? 'Coin' : 'Coin'),
      if (dailyStreak > 0)
        _statChip(Icons.local_fire_department_rounded, '$dailyStreak',
            isKu ? 'roj' : 'gün'),
      if (roomsPlayed != null)
        _statChip(Icons.sports_esports_rounded, '$roomsPlayed',
            isKu ? 'Lîstik' : 'Oyun'),
    ];

    return AppPanel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E5F47), Color(0xFF123427)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                key: const ValueKey('profile-avatar-edit'),
                customBorder: const CircleBorder(),
                onTap: onEditAvatar,
                child: Stack(
                  children: [
                    PlayerAvatar(
                      radius: 34,
                      photoUrl: avatarIdentity.photoUrl,
                      iconId: avatarIdentity.iconId,
                      colorHex: avatarIdentity.colorHex,
                      frameId: avatarIdentity.frameId,
                      displayName: displayName,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 12,
                          color: Color(0xFF1E5F47),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    if (avatarIdentity.showcaseTitle != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          avatarIdentity.showcaseTitle!,
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Text(
                        isKu
                            ? 'Di tabloya pêşderçûnê de ev nav xuya dike'
                            : 'Liderlik tablosunda bu isim görünür',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.military_tech_rounded,
                    color: AppTheme.gold,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isKu ? 'Ast $level' : 'Seviye $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                '$xpInLevel / $xpNeeded XP',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                FractionallySizedBox(
                  widthFactor: levelProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: chips[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.gold, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: İki düzeni de `_PlayerHeaderCard`'a bağla**

Build metodunda yardımcı bir getter tanımla (`build`'in hemen üstüne):

```dart
  Widget _headerCard(bool ku) => _PlayerHeaderCard(
        isKu: ku,
        displayName: _displayName(ku),
        avatarIdentity: _avatarIdentity,
        level: _level,
        xpInLevel: _xpInLevel,
        xpNeeded: _xpNeeded,
        levelProgress: _levelProgress,
        coinBalance: _coinBalance,
        dailyStreak: _dailyStreak,
        roomsPlayed: _stats?.roomsPlayed,
        onEditAvatar: _openAvatarEditor,
      );
```

- `leftColumn` içindeki `// Avatar card` yorumlu `AppPanel(gradient: ... [Color(0xFF1E5F47), Color(0xFF123427)] ...)` bloğunun tamamını (satır ~201-360) `_headerCard(ku),` ile değiştir.
- Mobil daldaki `// Avatar card` yorumlu **mor** `AppPanel(gradient: ... [Color(0xFF7C3AED), Color(0xFF4F1EB8)] ...)` bloğunun tamamını (satır ~838-947) `_headerCard(ku),` ile değiştir.

- [ ] **Step 6: Mor rengin kaynakta kalmadığını doğrula**

Run (PowerShell): `Select-String -Path lib/src/screens/profile_screen.dart -Pattern "7C3AED"`
Expected: çıktı yok.

- [ ] **Step 7: Testlerin YEŞİL olduğunu doğrula**

Run: `flutter test test/widget_test.dart`
Expected: yeni test dahil tümü PASS. (Mevcut `profile-avatar-edit` bekleyen avatar testi de bu key korunarak geçmeli.)

- [ ] **Step 8: Analiz + commit**

Run: `dart analyze` → `No issues found!`

```bash
git add lib/src/screens/profile_screen.dart test/widget_test.dart
git commit -m "feat(profil): tek oyuncu kartı — mor kart kalktı, coin/seri/oyun çipleri geldi"
```

---

### Task 3: İstatistik kartı tek kaynak + boş durum + koşullu grafik

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart`
- Test: `zankurd_mobile/test/widget_test.dart`

- [ ] **Step 1: Kırmızı testi yaz**

```dart
  testWidgets('profil, veri yokken haftalık grafiği gizler', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    // Taze MistakeStore → 7 günün tamamı sıfır → grafik yerine sakin not.
    expect(find.byType(WeeklyPerformanceChart), findsNothing);
    await tester.scrollUntilVisible(
      find.text('İlk quizden sonra grafiğin burada oluşur.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('İlk quizden sonra grafiğin burada oluşur.'),
      findsOneWidget,
    );
  });
```

Import (yoksa):

```dart
import 'package:zankurd_mobile/src/widgets/weekly_performance_chart.dart';
```

- [ ] **Step 2: Testin KIRMIZI olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "profil, veri yokken haftalık grafiği gizler"`
Expected: FAIL — grafik veri olmasa da render ediliyor.

- [ ] **Step 3: `_buildStatsPanel` metodunu yaz, iki düzeni de ona bağla**

`_ProfileScreenState` içine ekle:

```dart
  Widget _buildStatsPanel(bool ku) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ku ? 'Statîstîkên Min' : 'İstatistiklerim',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          if (_stats == null)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sports_esports_outlined,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ku
                        ? 'Hîn dîroka lîstikê ya serhêl tune. Bi yekê re bikevin an yek çêbikin.'
                        : 'Henüz çevrimiçi oyun geçmişin yok. Bir odaya katıl veya oluştur.',
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _StatTile(
                    label: ku ? 'Rêze' : 'Sıralama',
                    value: '#${_stats!.rank}',
                    color: AppTheme.gold,
                    icon: Icons.leaderboard_rounded,
                  ),
                  _StatTile(
                    label: ku ? 'Tevayî Xal' : 'Toplam Puan',
                    value: '${_stats!.totalScore}',
                    color: AppTheme.accent,
                    icon: Icons.star_rounded,
                  ),
                  _StatTile(
                    label: ku ? 'Baştirîn Zincîr' : 'En İyi Seri',
                    value: '${_stats!.bestStreak}',
                    color: AppTheme.violet,
                    icon: Icons.local_fire_department_rounded,
                  ),
                  _StatTile(
                    label: ku ? 'Lîstik' : 'Oyun',
                    value: '${_stats!.roomsPlayed}',
                    color: AppTheme.correct,
                    icon: Icons.sports_esports_rounded,
                  ),
                ],
              ),
            ),
          FutureBuilder<MistakeStore>(
            future: MistakeStore.load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final history = snapshot.data!.getLast7DaysHistory();
              final hasData = history.values.any(
                (day) => (day['correct'] ?? 0) > 0 || (day['wrong'] ?? 0) > 0,
              );
              if (!hasData) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    ku
                        ? 'Piştî pêşbirka yekem grafîka te li vir çêdibe.'
                        : 'İlk quizden sonra grafiğin burada oluşur.',
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: AppTheme.surfaceHiColor(context)),
                  ),
                  Text(
                    ku ? 'Performansa Heftane' : 'Haftalık Performans',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WeeklyPerformanceChart(history: history, isKu: ku),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
```

**Not:** `getLast7DaysHistory()` dönüşü `Map<String, Map<String, int>>` tipindedir; gün girdileri `{'correct': n, 'wrong': m}` biçimindedir (bkz. `mistake_store.dart:229`). Amaç: 7 günün tamamı sıfırsa grafiği çizmemek.

Sonra iki düzendeki `// Stats` yorumlu `AppPanel(...)` bloklarını (geniş: satır ~397-486, mobil: satır ~991-1099) `_buildStatsPanel(ku),` ile değiştir.

- [ ] **Step 4: Test YEŞİL + analiz**

Run: `flutter test test/widget_test.dart` → tümü PASS
Run: `dart analyze` → `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/profile_screen.dart test/widget_test.dart
git commit -m "feat(profil): istatistik kartı tek kaynak; boş durum ikonlu, grafik koşullu"
```

---

### Task 4: Rozet birleşimi — tek `_BadgeSection`

`_AchievementShowcase` (8 başarım) + `BadgeCollectionSection` (5 koleksiyon rozeti) → tek kart, birleşik sayaç, tek şerit, tek "Hemû" sheet'i.

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart`
- Test: `zankurd_mobile/test/widget_test.dart`

- [ ] **Step 1: Kırmızı testi yaz**

```dart
  testWidgets('profil rozetleri tek birleşik kartta toplar', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rozetler'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rozetler'), findsOneWidget);
    // Eski ikinci kartın başlığı artık ayrı bölüm olarak yok.
    expect(find.text('Rozet Koleksiyonu'), findsNothing);
    // Birleşik sayaç: 8 başarım + 5 koleksiyon rozeti, hiçbiri açık değil.
    expect(find.text('0/13'), findsOneWidget);
  });
```

**Not:** `AchievementStore.definitions.length` 8 ve `BadgeService.badgeDefinitions.length` 5 değilse `0/13` beklentisini gerçek toplamla güncelle (test yazmadan önce iki dosyaya bakıp doğrula: `lib/src/data/achievement_store.dart`, `lib/src/data/badge_service.dart`).

- [ ] **Step 2: KIRMIZI doğrula**

Run: `flutter test test/widget_test.dart --plain-name "profil rozetleri tek birleşik kartta toplar"`
Expected: FAIL — 'Rozet Koleksiyonu' ayrı kart olarak bulunur.

- [ ] **Step 3: `_BadgeSection` widget'ını yaz**

`profile_screen.dart` import'larına ekle:

```dart
import '../data/badge_service.dart';
import '../widgets/badge_widget.dart';
```

`_AchievementShowcase` sınıfını komple **sil** ve yerine şunu ekle:

```dart
class _BadgeSection extends StatefulWidget {
  const _BadgeSection({required this.achievements, required this.isKu});

  final List<Achievement> achievements;
  final bool isKu;

  @override
  State<_BadgeSection> createState() => _BadgeSectionState();
}

class _BadgeSectionState extends State<_BadgeSection> {
  Set<String> _unlockedBadges = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = await BadgeService.load();
    if (mounted) {
      setState(() {
        _unlockedBadges = service.unlockedBadges;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = widget.isKu;
    final badgeDefs = BadgeService.badgeDefinitions.entries.toList();
    final total = AchievementStore.definitions.length + badgeDefs.length;
    final unlocked = widget.achievements.length + _unlockedBadges.length;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: AppTheme.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ku ? 'Rozet' : 'Rozetler',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showAllSheet(context, badgeDefs, ku),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$unlocked/$total',
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMutedColor(context),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final definition in AchievementStore.definitions)
                    _AchievementBadgeTile(
                      icon: definition.icon,
                      title: definition.title(ku),
                      isUnlocked: widget.achievements
                          .any((a) => a.id == definition.id),
                    ),
                  for (final entry in badgeDefs)
                    SizedBox(
                      width: 86,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BadgeWidget(
                          badgeId: entry.key,
                          titleKu: entry.value['titleKu'] ?? '',
                          titleTr: entry.value['titleTr'] ?? '',
                          descriptionKu: entry.value['descKu'] ?? '',
                          descriptionTr: entry.value['descTr'] ?? '',
                          iconName: entry.value['icon'] ?? 'badge',
                          isUnlocked: _unlockedBadges.contains(entry.key),
                          isKu: ku,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAllSheet(
    BuildContext context,
    List<MapEntry<String, Map<String, String>>> badgeDefs,
    bool ku,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ku ? 'Hemû Rozet' : 'Tüm Rozetler',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ku ? 'Serkeftin' : 'Başarımlar',
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: AchievementStore.definitions.length,
                    itemBuilder: (context, index) {
                      final definition = AchievementStore.definitions[index];
                      final isUnlocked = widget.achievements.any(
                        (a) => a.id == definition.id,
                      );
                      final color = isUnlocked
                          ? AppTheme.gold
                          : AppTheme.textMutedColor(context);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? AppTheme.gold.withValues(alpha: 0.08)
                              : AppTheme.surfaceHiColor(context)
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUnlocked
                                ? AppTheme.gold.withValues(alpha: 0.25)
                                : AppTheme.borderColor(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(definition.icon, color: color, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    definition.title(ku),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isUnlocked
                                          ? AppTheme.textPrimaryColor(context)
                                          : AppTheme.textMutedColor(context),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    definition.description(ku),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.textMutedColor(context),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ku ? 'Koleksiyon' : 'Koleksiyon',
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: badgeDefs.length,
                    itemBuilder: (context, index) {
                      final entry = badgeDefs[index];
                      return BadgeWidget(
                        badgeId: entry.key,
                        titleKu: entry.value['titleKu'] ?? '',
                        titleTr: entry.value['titleTr'] ?? '',
                        descriptionKu: entry.value['descKu'] ?? '',
                        descriptionTr: entry.value['descTr'] ?? '',
                        iconName: entry.value['icon'] ?? 'badge',
                        isUnlocked: _unlockedBadges.contains(entry.key),
                        isKu: ku,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AchievementBadgeTile extends StatelessWidget {
  const _AchievementBadgeTile({
    required this.icon,
    required this.title,
    required this.isUnlocked,
  });

  final IconData icon;
  final String title;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? AppTheme.gold : AppTheme.textMutedColor(context);
    return SizedBox(
      width: 86,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: isUnlocked ? 0.15 : 0.08),
                border: Border.all(
                  color: color.withValues(alpha: isUnlocked ? 0.45 : 0.2),
                ),
              ),
              child: Icon(
                isUnlocked ? icon : Icons.lock_outline,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isUnlocked
                    ? AppTheme.textPrimaryColor(context)
                    : AppTheme.textMutedColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Kullanım yerlerini değiştir**

- `rightColumn` içindeki `_AchievementShowcase(achievements: _achievements, isKu: ku),` + `const SizedBox(height: 14),` + `// Rozet Koleksiyonu` yorumlu `const AppPanel(glass: true, child: BadgeCollectionSection()),` üçlüsünü şununla değiştir:

```dart
        _BadgeSection(achievements: _achievements, isKu: ku),
```

- Mobil dalda aynı üçlüyü (satır ~1105-1116) aynı şekilde `_BadgeSection(achievements: _achievements, isKu: ku),` ile değiştir.
- `import '../widgets/badge_collection_section.dart';` satırını sil (başka kullanım kalmadıysa; `badge_collection_section.dart` dosyası silinmez — başka ekran kullanıyor olabilir, `Select-String -Path lib -Pattern "BadgeCollectionSection" -Recurse` ile kontrol et; kullanım kalmadıysa dosyayı da silebilirsin).

- [ ] **Step 5: Testler YEŞİL + analiz**

Run: `flutter test test/widget_test.dart`
Expected: yeni test PASS; mevcut `profile screen shows unlocked achievement showcase` testi de PASS (`Rozetler` başlığı ve `İlk Oyun` başlık metni `_AchievementBadgeTile` içinde görünmeye devam ediyor).
Run: `dart analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/screens/profile_screen.dart test/widget_test.dart
git commit -m "feat(profil): iki rozet bölümü tek birleşik kartta toplandı"
```

---

### Task 5: Ustalık listesi → 2 sütunlu ızgara

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart`

- [ ] **Step 1: `_MasteryRow`'u `_MasteryCell` ile değiştir**

`_MasterySection.build` içindeki

```dart
          for (final cat in _categories)
            _MasteryRow(category: cat, store: store, isKu: isKu),
```

bloğunu şununla değiştir:

```dart
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.9,
            children: [
              for (var i = 0; i < _categories.length; i++)
                _MasteryCell(
                  category: _categories[i],
                  categoryIndex: i,
                  store: store,
                  isKu: isKu,
                ),
            ],
          ),
```

`_MasteryRow` sınıfını komple sil, yerine ekle:

```dart
class _MasteryCell extends StatelessWidget {
  const _MasteryCell({
    required this.category,
    required this.categoryIndex,
    required this.store,
    required this.isKu,
  });

  final String category;
  final int categoryIndex;
  final MasteryStore store;
  final bool isKu;

  static const _icons = <String, IconData>{
    'Ziman': Icons.translate,
    'Çand': Icons.diversity_3,
    'Dîrok': Icons.account_balance,
    'Edebiyat': Icons.menu_book,
    'Cografya': Icons.public,
    'Muzîk': Icons.music_note,
    'Siyaset': Icons.gavel,
    'Paradigma': Icons.psychology,
  };

  @override
  Widget build(BuildContext context) {
    final level = store.levelFor(category);
    final count = store.correctCount(category);
    final threshold = store.nextThreshold(category);
    final isMamoste = level == MasteryLevel.mamoste;
    final progress = isMamoste ? 1.0 : (count / threshold).clamp(0.0, 1.0);
    final badgeColor = level == MasteryLevel.none
        ? AppTheme.textMutedColor(context)
        : level.badgeColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.categoryGradient(categoryIndex),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _icons[category] ?? Icons.category_outlined,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        CategoryNames.localized(category, isKu),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      isMamoste ? '✓' : '$count/$threshold',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Not:** `_MasteryRow`'daki eski `AppTheme.textMuted` sabiti context-bağımlı `textMutedColor(context)` ile değişti (light modda okunabilirlik); `MasteryLevel.badgeColor` mevcut API'dir, dokunma.

- [ ] **Step 2: Analiz + tüm testler**

Run: `dart analyze` → `No issues found!`
Run: `flutter test` → tümü PASS (mastery ile ilgili widget testi kırılırsa: metin beklentileri aynı kaldı — `Destpêkirin` çipi kalktı, seviye bilgisi artık sayaçta; kırılan test eski çip metnini arıyorsa beklentiyi `count/threshold` biçimine güncelle).

- [ ] **Step 3: Commit**

```bash
git add lib/src/screens/profile_screen.dart test/widget_test.dart
git commit -m "feat(profil): ustalık listesi 2 sütunlu kompakt ızgaraya indi"
```

---

### Task 6: Joker kimlik renkleri + kısa etiket + açıklama (`wildcard.dart`)

**Files:**
- Modify: `zankurd_mobile/lib/src/models/wildcard.dart`
- Test: `zankurd_mobile/test/wildcard_test.dart`

- [ ] **Step 1: Kırmızı testleri yaz**

`wildcard_test.dart`'a mevcut `tüm WildcardType değerlerine ikon ve etiket atanmış` testinin yanına ekle:

```dart
    test('joker kimlik renkleri palete uyumlu', () {
      expect(WildcardType.fiftyFifty.themeColor, const Color(0xFFE76F51));
      expect(WildcardType.audience.themeColor, const Color(0xFF2B5C8F));
      expect(WildcardType.doubleAnswer.themeColor, const Color(0xFF1E5F47));
      expect(WildcardType.changeQuestion.themeColor, const Color(0xFF26A69A));
    });

    test('tüm jokerlerin kısa etiketi ve açıklaması dolu (ku + tr)', () {
      for (final type in WildcardType.values) {
        expect(type.shortLabel(true).isNotEmpty, isTrue);
        expect(type.shortLabel(false).isNotEmpty, isTrue);
        expect(type.description(true).isNotEmpty, isTrue);
        expect(type.description(false).isNotEmpty, isTrue);
      }
    });
```

Dosyanın import'larında `package:flutter/material.dart` yoksa (`Color` için) ekle.

- [ ] **Step 2: KIRMIZI doğrula**

Run: `flutter test test/wildcard_test.dart`
Expected: FAIL — `shortLabel`/`description` tanımsız, renkler eski.

- [ ] **Step 3: `wildcard.dart` uzantısını güncelle**

`WildcardTypeDetails` extension'ında `themeColor`'ı şununla değiştir ve iki yeni metot ekle:

```dart
  Color get themeColor => switch (this) {
    WildcardType.fiftyFifty     => const Color(0xFFE76F51), // Mercan
    WildcardType.audience       => const Color(0xFF2B5C8F), // Kobalt
    WildcardType.doubleAnswer   => const Color(0xFF1E5F47), // Derin yeşil
    WildcardType.changeQuestion => const Color(0xFF26A69A), // Turkuaz
  };

  /// Joker şeridindeki kısa etiket (daire altına sığacak uzunlukta).
  String shortLabel(bool isKu) => switch (this) {
    WildcardType.fiftyFifty     => '50/50',
    WildcardType.audience       => isKu ? 'Seyîrvan'   : 'Seyirci',
    WildcardType.doubleAnswer   => isKu ? '2 Bersiv'   : 'Çift Cevap',
    WildcardType.changeQuestion => isKu ? 'Biguherîne' : 'Değiştir',
  };

  /// Uzun basış balonunda gösterilen tek cümlelik açıklama.
  String description(bool isKu) => switch (this) {
    WildcardType.fiftyFifty => isKu
        ? 'Du bersivên şaş radike'
        : 'İki yanlış şıkkı eler',
    WildcardType.audience => isKu
        ? 'Rêjeya dengên temaşevanan nîşan dide'
        : 'Seyirci oylarının dağılımını gösterir',
    WildcardType.doubleAnswer => isKu
        ? 'Du şansên bersivê dide'
        : 'Aynı soruda iki cevap hakkı verir',
    WildcardType.changeQuestion => isKu
        ? 'Pirsê bi pirseke nû diguherîne'
        : 'Soruyu yenisiyle değiştirir',
  };
```

`label(bool isKu)` metoduna dokunma — onay diyalogları onu kullanıyor.

- [ ] **Step 4: YEŞİL + analiz + commit**

Run: `flutter test test/wildcard_test.dart` → PASS
Run: `dart analyze` → `No issues found!`

```bash
git add lib/src/models/wildcard.dart test/wildcard_test.dart
git commit -m "feat(joker): palet uyumlu kimlik renkleri, kısa etiket ve açıklama metinleri"
```

---

### Task 7: `_WildcardButton` yeniden tasarımı — kimlikli şerit

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz/quiz_widgets.dart` (satır ~899-1012, `_WildcardButton` + `_WildcardButtonState`)
- Test: `zankurd_mobile/test/widget_test.dart`

- [ ] **Step 1: Kırmızı testi yaz**

`widget_test.dart`'taki quiz testlerinin yanına ekle (mevcut quiz testlerinin `QuizScreen`'i nasıl pump'ladığına bak ve aynı kurulumu kullan — repository + `repository.createRoom()` + `repository.questions.take(3).toList()`):

```dart
  testWidgets('quiz jokerleri kısa etiket ve fiyat rozetiyle görünür', (
    tester,
  ) async {
    final room = repository.createRoom();
    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: repository.questions.take(3).toList(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Kısa etiketler (TR) ve fiyat rozetleri ("20" — artık "20c" değil).
    expect(find.text('50/50'), findsOneWidget);
    expect(find.text('Seyirci'), findsOneWidget);
    expect(find.text('Çift Cevap'), findsOneWidget);
    expect(find.text('Değiştir'), findsOneWidget); // solo modda görünür
    expect(find.text('20'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });
```

**Not:** Quiz ekranında timer animasyonları sürdüğü için `pumpAndSettle` kilitlenebilir — mevcut quiz testlerinin kullandığı pump düzenini birebir kopyala (`pump` + sabit süre). Fiyat sayıları skor değerleriyle çakışıp `findsOneWidget` yerine fazla eşleşme verirse beklentiyi `findsWidgets` yap.

- [ ] **Step 2: KIRMIZI doğrula**

Run: `flutter test test/widget_test.dart --plain-name "quiz jokerleri kısa etiket ve fiyat rozetiyle görünür"`
Expected: FAIL — mevcut buton yalnızca `20c` biçiminde fiyat gösteriyor, etiket yok.

- [ ] **Step 3: `_WildcardButtonState.build`'i yeni tasarımla değiştir**

`_WildcardButton` sınıfının alan/parametre imzası aynı kalır (`type, isKu, isEnabled, isActive, cantAfford, onTap`). `_WildcardButtonState`'in tamamını şununla değiştir:

```dart
class _WildcardButtonState extends State<_WildcardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final identity = widget.type.themeColor;
    final used = !widget.isEnabled && !widget.cantAfford && !widget.isActive;

    final Color circleColor;
    final Color iconColor;
    if (widget.isActive) {
      circleColor = identity;
      iconColor = Colors.white;
    } else if (widget.isEnabled) {
      circleColor = identity;
      iconColor = Colors.white;
    } else if (widget.cantAfford) {
      circleColor = AppTheme.surfaceHiColor(context);
      iconColor = AppTheme.textMutedColor(context);
    } else {
      // Kullanılmış (ya da cevap sonrası kilitli).
      circleColor = AppTheme.surfaceHiColor(context);
      iconColor = AppTheme.textMutedColor(context);
    }

    final priceBg = (widget.isEnabled || widget.isActive)
        ? AppTheme.gold
        : AppTheme.borderColor(context);
    final priceFg = (widget.isEnabled || widget.isActive)
        ? const Color(0xFF412402)
        : AppTheme.textMutedColor(context);

    return Tooltip(
      triggerMode: TooltipTriggerMode.longPress,
      message:
          '${widget.type.label(widget.isKu)} — ${widget.type.description(widget.isKu)} (${widget.type.coinCost} coin)',
      child: GestureDetector(
        onTapDown:
            widget.isEnabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.isEnabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel:
            widget.isEnabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: used ? 0.45 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 54,
                  height: 52,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: circleColor,
                          border: widget.isActive
                              ? Border.all(color: AppTheme.accent, width: 2.5)
                              : null,
                          boxShadow: (widget.isEnabled || widget.isActive)
                              ? [
                                  BoxShadow(
                                    color: identity.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          used ? Icons.check_rounded : widget.type.icon,
                          size: 21,
                          color: iconColor,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: priceBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.surfaceColor(context),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${widget.type.coinCost}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: priceFg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.type.shortLabel(widget.isKu),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: (widget.isEnabled || widget.isActive)
                        ? AppTheme.textPrimaryColor(context)
                        : AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Not:** `used` türetimi mevcut çağrı sözleşmesine dayanır: `quiz_screen._buildWildcardButton` kullanılmış jokerde `isEnabled:false, cantAfford:false, isActive:false` gönderir. Cevap verilmiş ama kullanılmamış joker de aynı kombinasyona düşer — ikisinde de soluk görünüm doğru davranıştır (o an tıklanamaz). `isActive` yalnızca Çift Cevap'ta gelir; pembe halka + dolu renk verir.

- [ ] **Step 4: YEŞİL + analiz + tüm testler**

Run: `flutter test test/widget_test.dart` → tümü PASS
Run: `dart analyze` → `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/quiz/quiz_widgets.dart test/widget_test.dart
git commit -m "feat(joker): kimlikli renkli joker şeridi — dolgun daire, fiyat rozeti, uzun basış açıklaması"
```

---

### Task 8: Solo modda canlı skorboard'u gizle

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz_screen.dart` (satır ~459 ve ~489)
- Test: `zankurd_mobile/test/widget_test.dart`

- [ ] **Step 1: Kırmızı testi yaz**

```dart
  testWidgets('solo quizde canlı skorboard gösterilmez', (tester) async {
    final room = repository.createRoom(); // solo: room.id == null
    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: repository.questions.take(3).toList(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Canlı skor'), findsNothing);
  });
```

- [ ] **Step 2: KIRMIZI doğrula**

Run: `flutter test test/widget_test.dart --plain-name "solo quizde canlı skorboard gösterilmez"`
Expected: FAIL — 'Canlı skor' başlığı bulunur.

- [ ] **Step 3: İki kullanım yerini koşula bağla**

Dikey düzendeki (satır ~456-459):

```dart
                          _buildActionControls(),
                          const SizedBox(height: 16),
                          _LiveScoreboard(players: livePlayers),
```

şu olacak:

```dart
                          _buildActionControls(),
                          if (!_isSoloMode) ...[
                            const SizedBox(height: 16),
                            _LiveScoreboard(players: livePlayers),
                          ],
```

Yatay düzendeki (satır ~487-489):

```dart
                              _buildActionControls(),
                              const SizedBox(height: 12),
                              _LiveScoreboard(players: livePlayers),
```

şu olacak:

```dart
                              _buildActionControls(),
                              if (!_isSoloMode) ...[
                                const SizedBox(height: 12),
                                _LiveScoreboard(players: livePlayers),
                              ],
```

- [ ] **Step 4: YEŞİL + analiz + tüm testler**

Run: `flutter test test/widget_test.dart` → tümü PASS (online/botRace quiz testi 'Canlı skor' bekliyorsa etkilenmez — o modlarda `_isSoloMode` false).
Run: `dart analyze` → `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/quiz_screen.dart test/widget_test.dart
git commit -m "fix(quiz): solo modda tek kişilik canlı skorboard gizlendi"
```

---

### Task 9: Hero kartı gradyanını sakinleştir

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home/hero_card.dart`

- [ ] **Step 1: Gradyan ve gölgeyi tek renk ailesine indir**

`hero_card.dart` satır ~27-51'deki dekorasyonu şununla değiştir (mercan gradyandan ve mercan glow'dan çıkar):

```dart
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E5F47), Color(0xFF123427)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5F47).withValues(alpha: 0.4),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
```

- [ ] **Step 2: Birincil CTA'yı mercana çevir**

`_HeroActionButtonState.build` içindeki (satır ~254-257):

```dart
    final background = widget.primary
        ? Colors.white
        : Colors.white.withValues(alpha: 0.16);
    final foreground = widget.primary ? const Color(0xFF1E5F47) : Colors.white;
```

şu olacak:

```dart
    final background = widget.primary
        ? const Color(0xFFE76F51)
        : Colors.white.withValues(alpha: 0.16);
    final foreground = Colors.white;
```

Ve `primary` gölgesindeki `Colors.white.withValues(alpha: 0.25)` rengini `const Color(0xFFE76F51).withValues(alpha: 0.35)` yap. Sol-alt dekoratif mercan daire (alpha 0.08) olduğu gibi kalır — motif olarak yeter.

- [ ] **Step 3: Analiz + tüm testler**

Run: `dart analyze` → `No issues found!`
Run: `flutter test` → tümü PASS

- [ ] **Step 4: Commit**

```bash
git add lib/src/screens/home/hero_card.dart
git commit -m "style(home): hero gradyanı tek renk ailesine indi; mercan yalnız birincil CTA'da"
```

---

### Task 10: Final doğrulama (tam paket + görsel kontrol)

**Files:** —

- [ ] **Step 1: Tam doğrulama**

Run: `dart analyze` → `No issues found!`
Run: `flutter test` → tüm testler PASS (322 + bu planda eklenen ~6 yeni test).

- [ ] **Step 2: Web'de görsel kontrol**

```bash
flutter run -d web-server --web-port 8091 --web-hostname 127.0.0.1
```

Tarayıcıda (ya da Playwright ile) 360-412px genişlikte kontrol listesi:
- Profil: yeşil oyuncu kartı + çipler; mor yok; tek Rozet kartı; ustalık 2 sütun; 6 menü öğesi; taşma yok.
- Quiz (solo): 4 renkli joker dairesi + fiyat rozetleri okunuyor; "Canlı skor" kartı yok; uzun basışta açıklama balonu çıkıyor.
- Ana Sayfa: hero kartı tek renk ailesi, mercan CTA.
- Işık/karanlık tema ikisinde de kontrol et (Profil → Mîheng'den tema değiştir).

- [ ] **Step 3: Sürüm notu (opsiyonel, kullanıcıya sor)**

`pubspec.yaml` sürümü (1.8.0+10) yükseltilecekse kullanıcı onayıyla `1.9.0+11` yap; istenmediyse dokunma.

---

## Self-review notları (plan yazarı doldurdu)

- **Spec kapsama:** Spec §1 → Task 1-5; §2 → Task 6-7; §3 → Task 8-9; test stratejisi → her taskın step'leri + Task 10. Boşluk yok.
- **Tip tutarlılığı:** `shortLabel`/`description` Task 6'da tanımlanır, Task 7 kullanır. `_headerCard` Task 2'de tanımlanır. `getLast7DaysHistory()` tipi (`Map<String, Map<String, int>>`) kaynaktan doğrulandı, Task 3 kodu buna göre yazıldı.
- **Yerleşik riskler:** Satır numaraları yaklaşıktır (çalışma ağacında commit'lenmemiş değişiklikler var) — blokları yorum başlıklarıyla (`// Avatar card`, `// Stats`, `// Navigasyon kısayolları`, `// Rozet Koleksiyonu`) bul.
