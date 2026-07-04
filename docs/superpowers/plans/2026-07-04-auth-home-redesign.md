# Sign-in ve Ana Sayfa Yeniden Tasarımı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sign-in ekranında Google/Misafir butonlarını öne çıkarıp dolgun/renkli hale getirmek; ana sayfadan Kategori-sekmesiyle çakışan kategori ızgarasını ve örnek soru kartını kaldırıp dört aksiyon kartını (1v1/günün yarışması/çark/turnuva) tek bir kompakt `QuickPlayGrid`'e birleştirmek.

**Architecture:** İki bağımsız, birbirini etkilemeyen dosya grubunda değişiklik: (1) `sign_in_screen.dart` içinde iki yeni private widget (`_GoogleSignInButton`, `_GuestSignInButton`) + `build()` metodunda sıralama değişikliği; (2) yeni `home/quick_play_grid.dart` widget'ı + `home_screen.dart`'ın `build()`/`_bootstrap()` metodlarının sadeleştirilmesi + artık kullanılmayan 6 kart dosyasının silinmesi. Her iki grup da mevcut `AppTheme` renk sabitlerini kullanır, yeni bağımlılık eklenmez.

**Tech Stack:** Flutter (Dart), mevcut `flutter_test` widget test altyapısı, mevcut `AppTheme` tema sistemi.

**Spec:** `docs/superpowers/specs/2026-07-04-auth-home-redesign-design.md`

---

## Ön Bilgi (tüm görevler için ortak bağlam)

- Proje kökü: `zankurd_mobile/` (bu yol her komutta `cd` ile kullanılacak, komutlar zaten proje köküne göre yazılmıştır).
- `dart analyze` kullan, **`flutter analyze` kullanma** (bu ortamda Türkçe `İ` içeren yol nedeniyle LSP çöküyor — bkz. proje `CLAUDE.md`).
- Her görev sonunda `dart analyze` ve ilgili test(ler) çalıştırılıp commit atılacak. Tüm görevler bittikten sonra tam `flutter test` süiti (240+ test) çalıştırılacak.
- `AppTheme` renk sabitleri (`lib/src/theme/app_theme.dart`): `accent` (#FF4B91 neon pembe), `violet` (#8E8FFA), `secondaryAccent` (#6F61C0), `gold` (#FFD23F), `bgDeep` (#080711), `homeHeaderGradient` (violet→accent), `cardRadius` (20), `cardRadiusSmall` (12), `elevatedShadow(Color tint)` (List<BoxShadow> döner).

---

## Task 1: `QuickPlayGrid` widget'ını oluştur

**Files:**
- Create: `zankurd_mobile/lib/src/screens/home/quick_play_grid.dart`
- Test: `zankurd_mobile/test/quick_play_grid_test.dart`

- [ ] **Step 1: Başarısız olacak testi yaz**

`zankurd_mobile/test/quick_play_grid_test.dart` dosyasını oluştur:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/quick_play_grid.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders all four quick-play tiles with Turkish labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: false,
          dailyQuizLoading: false,
          onDuel: () {},
          onDailyQuiz: () {},
          onSpinWheel: () {},
          onTournament: () {},
        ),
      ),
    );

    expect(find.text('1V1 Düello'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsOneWidget);
    expect(find.text('Günün Çarkı'), findsOneWidget);
    expect(find.text('Turnuva Modu'), findsOneWidget);
  });

  testWidgets('renders all four quick-play tiles with Kurdish labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: true,
          dailyQuizLoading: false,
          onDuel: () {},
          onDailyQuiz: () {},
          onSpinWheel: () {},
          onTournament: () {},
        ),
      ),
    );

    expect(find.text('Şerê 1V1'), findsOneWidget);
    expect(find.text('Pêşbirka Rojê'), findsOneWidget);
    expect(find.text('Çerxa Rojê'), findsOneWidget);
    expect(find.text('Turnuva'), findsOneWidget);
  });

  testWidgets('tapping a tile invokes its own callback only', (tester) async {
    var duelTapped = false;
    var dailyQuizTapped = false;
    var spinWheelTapped = false;
    var tournamentTapped = false;

    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: false,
          dailyQuizLoading: false,
          onDuel: () => duelTapped = true,
          onDailyQuiz: () => dailyQuizTapped = true,
          onSpinWheel: () => spinWheelTapped = true,
          onTournament: () => tournamentTapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Turnuva Modu'));
    await tester.pump();

    expect(tournamentTapped, isTrue);
    expect(duelTapped, isFalse);
    expect(dailyQuizTapped, isFalse);
    expect(spinWheelTapped, isFalse);
  });

  testWidgets('daily quiz tile shows a spinner and ignores taps while loading', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: false,
          dailyQuizLoading: true,
          onDuel: () {},
          onDailyQuiz: () => tapped = true,
          onSpinWheel: () {},
          onTournament: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Günün Yarışması'));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `cd zankurd_mobile && flutter test test/quick_play_grid_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/src/screens/home/quick_play_grid.dart': No such file or directory` (dosya henüz yok).

- [ ] **Step 3: `QuickPlayGrid` widget'ını yaz**

`zankurd_mobile/lib/src/screens/home/quick_play_grid.dart` dosyasını oluştur:

```dart
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Kompakt 2x2 "hemen oyna" ızgarası: 1v1 düello, günün yarışması, çark,
/// turnuva. Bu dört aksiyon eskiden ayrı ayrı tam-genişlik kartlardı
/// (bkz. docs/superpowers/specs/2026-07-04-auth-home-redesign-design.md);
/// burada tek bir yoğun, hâlâ renkli ve okunaklı ızgarada birleşiyor.
class QuickPlayGrid extends StatelessWidget {
  const QuickPlayGrid({
    required this.isKu,
    required this.dailyQuizLoading,
    required this.onDuel,
    required this.onDailyQuiz,
    required this.onSpinWheel,
    required this.onTournament,
    super.key,
  });

  final bool isKu;
  final bool dailyQuizLoading;
  final VoidCallback onDuel;
  final VoidCallback onDailyQuiz;
  final VoidCallback onSpinWheel;
  final VoidCallback onTournament;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            _QuickPlayTile(
              gradientColors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
              icon: Icons.bolt_rounded,
              title: isKu ? 'Şerê 1V1' : '1V1 Düello',
              subtitle: isKu ? 'Zindî' : 'Canlı',
              onTap: onDuel,
            ),
            _QuickPlayTile(
              gradientColors: const [AppTheme.gold, Color(0xFFFF8F00)],
              icon: Icons.today_rounded,
              title: isKu ? 'Pêşbirka Rojê' : 'Günün Yarışması',
              subtitle: isKu ? '10 pirs' : '10 soru',
              loading: dailyQuizLoading,
              onTap: onDailyQuiz,
            ),
            _QuickPlayTile(
              gradientColors: const [
                AppTheme.violet,
                AppTheme.secondaryAccent,
              ],
              icon: Icons.casino_outlined,
              title: isKu ? 'Çerxa Rojê' : 'Günün Çarkı',
              subtitle: '100 coin',
              onTap: onSpinWheel,
            ),
            _QuickPlayTile(
              gradientColors: const [Color(0xFF00BFA5), Color(0xFF00897B)],
              icon: Icons.emoji_events_outlined,
              title: isKu ? 'Turnuva' : 'Turnuva Modu',
              subtitle: isKu ? 'Kûpa' : 'Kupa',
              onTap: onTournament,
            ),
          ],
        );
      },
    );
  }
}

class _QuickPlayTile extends StatelessWidget {
  const _QuickPlayTile({
    required this.gradientColors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final List<Color> gradientColors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
            boxShadow: AppTheme.elevatedShadow(gradientColors.first),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `cd zankurd_mobile && flutter test test/quick_play_grid_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Statik analiz**

Run: `cd zankurd_mobile && dart analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home/quick_play_grid.dart zankurd_mobile/test/quick_play_grid_test.dart
git commit -m "feat(home): QuickPlayGrid widget'ını ekle

1v1/günün yarışması/çark/turnuva aksiyonlarını tek bir kompakt 2x2
ızgarada birleştiren yeni widget. Henüz home_screen.dart'a bağlanmadı
(Task 2)."
```

---

## Task 2: `QuickPlayGrid`'i ana sayfaya bağla, eski kartları kaldır

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart`
- Delete: `zankurd_mobile/lib/src/screens/home/category_grid.dart`
- Delete: `zankurd_mobile/lib/src/screens/home/battle_1v1_card.dart`
- Delete: `zankurd_mobile/lib/src/screens/home/daily_quiz_card.dart`
- Delete: `zankurd_mobile/lib/src/screens/home/spin_wheel_card.dart`
- Delete: `zankurd_mobile/lib/src/screens/home/tournament_card.dart`
- Delete: `zankurd_mobile/lib/src/screens/home/question_card.dart`

Bu 6 dosyanın hiçbiri `home_screen.dart` dışında import edilmiyor (doğrulandı: `grep -rln` ile proje genelinde tarandı, tek kullanım yeri `home_screen.dart`). Bu görev sonunda hepsi ölü kod olacağı için siliniyor.

- [ ] **Step 1: `home_screen.dart`'ın tamamını aşağıdaki içerikle değiştir**

`zankurd_mobile/lib/src/screens/home_screen.dart` dosyasının tamamını şu içerikle değiştir:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import 'home/daily_missions_card.dart';
import 'home/hero_card.dart';
import 'home/quick_play_grid.dart';
import 'home/section_header.dart';
import '../widgets/animated_counter.dart';
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'quiz_screen.dart';
import 'room_screen.dart';
import 'matchmaking_screen.dart';
import 'spin_wheel_screen.dart';
import 'tournament_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    this.scrollController,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
  final ScrollController? scrollController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<QuizQuestion> _questions = widget.repository.questions;
  bool _roomActionLoading = false;
  bool _dailyLoading = false;
  int? _coinBalance;
  int _streak = 0;
  List<DailyMission> _missions = [];
  bool _missionsLoading = true;
  late GameRoom _room;
  late AnimationController _loadAnimationController;
  String? _displayName;

  ZanKurdRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _loadAnimationController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    if (isFlutterTestEnvironment) {
      _loadAnimationController.value = 1.0;
    } else {
      _loadAnimationController.forward();
    }
    _room = repo.createRoom();
    _bootstrap();
    _refreshStreak();
    _loadMissions();
  }

  @override
  void dispose() {
    _loadAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshStreak() async {
    final store = await StreakStore.load();
    if (mounted) setState(() => _streak = store.effectiveStreak());
  }

  Future<void> _loadMissions() async {
    final store = await DailyMissionStore.load();
    if (mounted) {
      setState(() {
        _missions = List.from(store.missions);
        _missionsLoading = false;
      });
    }
  }

  Future<void> _bootstrap() async {
    try {
      await repo.ensureProfile();
      final name = await repo.getProfileName();
      if (mounted) {
        setState(() {
          _displayName = name;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home ensureProfile failed');
    }

    try {
      final qs = await repo.loadQuestions(limit: 10);
      final coins = await repo.loadCoinBalance();
      if (!mounted) return;
      setState(() {
        _questions = qs.isEmpty ? repo.questions : qs;
        _coinBalance = coins;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home bootstrap load failed');
      if (!mounted) return;
      setState(() {
        _questions = repo.questions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final bottomContentPadding = MediaQuery.paddingOf(context).bottom + 112;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 720;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surfaceColor(context),
            elevation: 0,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final double topPadding = MediaQuery.of(context).padding.top;
                final double collapsedHeight = kToolbarHeight + topPadding;
                final isCollapsed =
                    constraints.maxHeight <= collapsedHeight + 20;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: const Text(
                    'ZanKurd​',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                );
              },
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGeometricHeader(context, ku),
            ),
          ),
          if (isWide)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnimatedCard(
                            _heroFadeAnimation(0),
                            HeroCard(
                              isKu: ku,
                              loading: _roomActionLoading,
                              onCreateRoom: () => _createOnlineRoom(context),
                              onJoinRoom: () => _showJoinSheet(context),
                              onQuickMatch: () => _openQuiz(context, _room),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildAnimatedCard(
                            _heroFadeAnimation(2),
                            DailyMissionsCard(
                              isKu: ku,
                              missions: _missions,
                              loading: _missionsLoading,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnimatedCard(
                            _heroFadeAnimation(1),
                            SectionHeader(
                              title: ku ? 'Zû Bilîze' : 'Hemen Oyna',
                              subtitle: ku
                                  ? 'Yarî, xelat û pêşbirkên rojane'
                                  : 'Oyunlar, ödüller ve günlük yarışmalar',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildAnimatedCard(
                            _heroFadeAnimation(1),
                            QuickPlayGrid(
                              isKu: ku,
                              dailyQuizLoading: _dailyLoading,
                              onDuel: () => Navigator.of(context).push(
                                AppRoute.to(
                                  MatchmakingScreen(repository: repo),
                                ),
                              ),
                              onDailyQuiz: () => _openDailyQuiz(context, ku),
                              onSpinWheel: () => _openSpinWheel(context),
                              onTournament: () => _openTournament(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return _buildAnimatedCard(
                      _heroFadeAnimation(0),
                      HeroCard(
                        isKu: ku,
                        loading: _roomActionLoading,
                        onCreateRoom: () => _createOnlineRoom(context),
                        onJoinRoom: () => _showJoinSheet(context),
                        onQuickMatch: () => _openQuiz(context, _room),
                      ),
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(1),
                        SectionHeader(
                          title: ku ? 'Zû Bilîze' : 'Hemen Oyna',
                          subtitle: ku
                              ? 'Yarî, xelat û pêşbirkên rojane'
                              : 'Oyunlar, ödüller ve günlük yarışmalar',
                        ),
                      ),
                    );
                  }
                  if (index == 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(1),
                        QuickPlayGrid(
                          isKu: ku,
                          dailyQuizLoading: _dailyLoading,
                          onDuel: () => Navigator.of(context).push(
                            AppRoute.to(MatchmakingScreen(repository: repo)),
                          ),
                          onDailyQuiz: () => _openDailyQuiz(context, ku),
                          onSpinWheel: () => _openSpinWheel(context),
                          onTournament: () => _openTournament(context),
                        ),
                      ),
                    );
                  }
                  if (index == 3) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(2),
                        DailyMissionsCard(
                          isKu: ku,
                          missions: _missions,
                          loading: _missionsLoading,
                        ),
                      ),
                    );
                  }
                  return null;
                }, childCount: 4),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding)),
        ],
      ),
    );
  }

  Widget _buildPriorityMission(BuildContext context, bool ku) {
    if (_missionsLoading || _missions.isEmpty) return const SizedBox.shrink();
    final incomplete = _missions.where((m) => !m.completed).toList();
    if (incomplete.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars, color: AppTheme.gold, size: 14),
            const SizedBox(width: 6),
            Text(
              ku ? 'Hemû misyon temam bûn!' : 'Tüm görevler tamamlandı!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    incomplete.sort((a, b) => b.coinReward.compareTo(a.coinReward));
    final priorityMission = incomplete.first;
    final missionTitle = ku ? priorityMission.labelKu : priorityMission.labelTr;
    final rewardText = '+${priorityMission.coinReward} Coin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on, color: AppTheme.gold, size: 14),
          const SizedBox(width: 6),
          Text(
            ku ? 'Misyona Rojê: ' : 'Günün Görevi: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              missionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              rewardText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeometricHeader(BuildContext context, bool ku) {
    final isTest = isFlutterTestEnvironment;
    final hour = DateTime.now().hour;
    final String greetingKu;
    final String greetingTr;
    if (isTest) {
      greetingKu = 'Salam';
      greetingTr = 'Hoş geldin';
    } else {
      if (hour >= 5 && hour < 12) {
        greetingKu = 'Rojbaş';
        greetingTr = 'Günaydın';
      } else if (hour >= 12 && hour < 17) {
        greetingKu = 'Rojbaş';
        greetingTr = 'İyi Günler';
      } else if (hour >= 17 && hour < 22) {
        greetingKu = 'Êvarbaş';
        greetingTr = 'İyi Akşamlar';
      } else {
        greetingKu = 'Şevbaş';
        greetingTr = 'İyi Geceler';
      }
    }
    final currentName = _displayName ?? widget.displayName;
    final greeting = ku
        ? '$greetingKu, ${currentName ?? 'Lîstikvan'}!'
        : '$greetingTr, ${currentName ?? 'Oyuncu'}!';

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.homeHeaderGradient),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -60,
            child: Opacity(
              opacity: 0.08,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 20,
            child: _buildAnimatedCard(
              _heroFadeAnimation(0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ZanKurd',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPriorityMission(context, ku),
                ],
              ),
            ),
          ),
          if (_streak > 0)
            Positioned(top: 16, right: 18, child: _buildStreakHexagon(_streak)),
          Positioned(left: 18, top: 16, child: _buildCoinGemRow(_coinBalance)),
        ],
      ),
    );
  }

  Widget _buildStreakHexagon(int streak) {
    final pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _loadAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: pulseAnim.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  '$streak',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoinGemRow(int? coinBalance) {
    if (coinBalance == null) return const SizedBox.shrink();

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            AppRoute.to(ShopScreen(repository: repo)),
          ).then((_) => _refreshCoins()),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    AnimatedCounter(
                      value: coinBalance,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCard(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  Animation<double> _heroFadeAnimation(int index) {
    final startTime = (index * 0.1).clamp(0.0, 1.0).toDouble();
    final endTime = (startTime + 0.3).clamp(startTime, 1.0).toDouble();
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadAnimationController,
        curve: Interval(startTime, endTime, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _createOnlineRoom(BuildContext context) async {
    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final room = await repo.createOnlineRoom();
      if (!context.mounted) return;
      _openRoom(context, room);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'createOnlineRoom failed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isKu
                ? 'Jûra serhêl nehate vekirin. Ji kerema xwe dîsa biceribîne.'
                : 'Online oda açılamadı. Lütfen tekrar deneyin.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  Future<void> _openDailyQuiz(BuildContext context, bool ku) async {
    if (_dailyLoading) return;
    setState(() => _dailyLoading = true);
    try {
      final dailyQuestions = await repo.loadDailyQuestions(limit: 10);
      if (!context.mounted) return;
      final dailyRoom = repo.createRoom().copyWith(
        name: ku ? 'Pêşbirka Rojê' : 'Günün Yarışması',
        questionCount: dailyQuestions.length,
      );
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: repo,
            room: dailyRoom,
            questions: dailyQuestions,
            dailyQuiz: true,
          ),
        ),
      );
      _refreshCoins();
      _loadMissions();
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  Future<void> _openQuiz(BuildContext context, GameRoom room) async {
    await Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(repository: repo, room: room, questions: _questions),
      ),
    );
    _refreshCoins();
    _loadMissions();
  }

  void _openRoom(BuildContext context, GameRoom room) {
    Navigator.of(
      context,
    ).push(AppRoute.to(RoomScreen(repository: repo, initialRoom: room)));
  }

  Future<void> _openSpinWheel(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(SpinWheelScreen(repository: repo)));
    _refreshCoins();
  }

  Future<void> _openTournament(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(TournamentScreen(repository: repo)));
    _refreshCoins();
  }

  Future<void> _refreshCoins() async {
    try {
      final coins = await repo.loadCoinBalance();
      if (mounted) setState(() => _coinBalance = coins);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'coin refresh failed');
    }
  }

  void _showJoinSheet(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ku = context.isKu;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetCtx).bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ku ? 'Tevlî Jûrê Bibe' : 'Odaya Katıl',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: ku ? 'Koda jûrê' : 'Oda kodu',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return ku ? 'Koda jûrê pêwîst e.' : 'Oda kodu gerekli.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final room = await repo.joinOnlineRoom(
                          controller.text.trim(),
                        );
                        if (!sheetCtx.mounted) return;
                        Navigator.of(sheetCtx).pop();
                        if (!context.mounted) return;
                        _openRoom(context, room);
                      } catch (error, stack) {
                        ErrorReporter.record(
                          error,
                          stack,
                          reason: 'joinOnlineRoom failed',
                        );
                        if (!sheetCtx.mounted) return;
                        Navigator.of(sheetCtx).pop();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.isKu
                                  ? 'Tevlî jûra serhêl nebû. Ji kerema xwe kodê kontrol bike.'
                                  : 'Online odaya katılınamadı. Lütfen kodu kontrol edin.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.meeting_room_outlined),
                    label: Text(ku ? 'Tevlî Bibe' : 'Katıl'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

**Not:** `_showJoinSheet` içindeki `AppTheme.surfaceOf(context)` çağrısı doğrulandı — `app_theme.dart:362`'de gerçekten tanımlı bir alias (`surfaceColor`'a eşdeğer). Aynen kopyalandı, herhangi bir değişiklik gerekmiyor.

- [ ] **Step 2: Artık kullanılmayan 6 dosyayı sil**

```bash
cd zankurd_mobile
rm lib/src/screens/home/category_grid.dart
rm lib/src/screens/home/battle_1v1_card.dart
rm lib/src/screens/home/daily_quiz_card.dart
rm lib/src/screens/home/spin_wheel_card.dart
rm lib/src/screens/home/tournament_card.dart
rm lib/src/screens/home/question_card.dart
```

- [ ] **Step 3: Statik analiz — kalan referans/import hatası olmadığını doğrula**

Run: `cd zankurd_mobile && dart analyze`
Expected: `No issues found!` (hata çıkarsa: silinen widget'lara kalan bir referans vardır — hatada gösterilen satırı bul ve importu/kullanımı temizle).

- [ ] **Step 4: Home screen ile ilgili mevcut testleri çalıştır**

Run: `cd zankurd_mobile && flutter test test/widget_test.dart --plain-name "home screen"`

Bu, isminde "home screen" geçen testleri (`opens the daily quiz from the home screen`, `opens the spin wheel from the home screen`, `kurdish home room join action uses compact label` vb.) çalıştırır.
Expected: Hepsi PASS (tile başlıkları `'Günün Yarışması'` ve `'Günün Çarkı'` metinleri korunduğu için bu testler değişmeden geçmeli).

- [ ] **Step 5: Tam test süitini çalıştır**

Run: `cd zankurd_mobile && flutter test`
Expected: Tüm testler PASS (önceki 240 testten `question_card`/`category_grid`'e özel bir test yoktu, bu yüzden toplam sayı aynı kalmalı + Task 1'de eklenen 4 yeni test = toplam +4).

- [ ] **Step 6: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home_screen.dart
git rm zankurd_mobile/lib/src/screens/home/category_grid.dart
git rm zankurd_mobile/lib/src/screens/home/battle_1v1_card.dart
git rm zankurd_mobile/lib/src/screens/home/daily_quiz_card.dart
git rm zankurd_mobile/lib/src/screens/home/spin_wheel_card.dart
git rm zankurd_mobile/lib/src/screens/home/tournament_card.dart
git rm zankurd_mobile/lib/src/screens/home/question_card.dart
git commit -m "refactor(home): kategori ızgarasını ve örnek soru kartını kaldır, QuickPlayGrid'e geç

Ana sayfadaki kategori ızgarası Kategori sekmesiyle birebir aynıydı
(bkz. docs/superpowers/specs/2026-07-04-auth-home-redesign-design.md).
Kaldırıldı. 1v1/günün yarışması/çark/turnuva artık tek kompakt
QuickPlayGrid içinde. 6 artık-kullanılmayan kart dosyası silindi."
```

---

## Task 3: Sign-in ekranında Google/Misafir butonlarını yeniden tasarla (aynı konumda)

Bu görev butonların GÖRÜNÜMÜNÜ değiştirir, henüz YERİNİ değiştirmez (yer değişikliği Task 4'te). Böylece her adım tek bir değişkeni test eder.

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/sign_in_screen.dart`
- Modify: `zankurd_mobile/test/widget_test.dart:264-299`

- [ ] **Step 1: Mevcut testi yeni tasarımın sözleşmesine göre güncelle (TDD — bu adımdan sonra test FAIL etmeli)**

`zankurd_mobile/test/widget_test.dart` dosyasında satır 264-299'daki testi bul:

```dart
  testWidgets('auth alternative buttons stay readable on dark background', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: const SignInScreen(),
        authProvider: _GateAuthProvider(),
      ),
    );
    await tester.pumpAndSettle();

    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Google ile giriş yap'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final guestButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Misafir olarak devam et'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(
      googleButton.style?.foregroundColor?.resolve({}),
      equals(Colors.white),
    );
    expect(
      guestButton.style?.foregroundColor?.resolve({}),
      equals(Colors.white),
    );
  });
```

Bunu şununla değiştir:

```dart
  testWidgets('auth alternative buttons stay readable on their own backgrounds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: const SignInScreen(),
        authProvider: _GateAuthProvider(),
      ),
    );
    await tester.pumpAndSettle();

    // Google butonu: beyaz dolgu -> koyu metin kontrast sağlamalı.
    final googleLabel = tester.widget<Text>(find.text('Google ile giriş yap'));
    expect(googleLabel.style?.color?.computeLuminance(), lessThan(0.3));

    // Misafir butonu: marka gradyanı dolgu -> beyaz metin kontrast sağlamalı.
    final guestLabel = tester.widget<Text>(find.text('Misafir olarak devam et'));
    expect(guestLabel.style?.color, equals(Colors.white));
  });
```

- [ ] **Step 2: Testin (eski koda karşı) başarısız olduğunu doğrula**

Run: `cd zankurd_mobile && flutter test test/widget_test.dart --plain-name "auth alternative buttons stay readable on their own backgrounds"`
Expected: FAIL (eski `OutlinedButton` etiketlerinin `Text` widget'ında açıkça atanmış bir `style.color` yok, `googleLabel.style?.color` `null` döner — `null` için `lessThan(0.3)` karşılaştırması test'i başarısız kılar).

- [ ] **Step 3: `sign_in_screen.dart` sonuna iki yeni private widget ekle, `_authOutlineButtonStyle` fonksiyonunu sil**

`zankurd_mobile/lib/src/screens/sign_in_screen.dart` dosyasında satır 994-1002'deki şu fonksiyonu bul ve **tamamen sil**:

```dart
ButtonStyle _authOutlineButtonStyle({bool dense = false}) {
  return OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.72), width: 1.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: EdgeInsets.symmetric(vertical: dense ? 8 : 14, horizontal: 20),
  );
}
```

Onun yerine (aynı konuma) şunu ekle:

```dart
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            height: dense ? 48 : 58,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'G',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: dense ? 18 : 22,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    context.s('Bi Google têkeve', 'Google ile giriş yap'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.bgDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: dense ? 13 : 16,
                    ),
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

class _GuestSignInButton extends StatelessWidget {
  const _GuestSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: dense ? 48 : 58,
          decoration: BoxDecoration(
            gradient: AppTheme.homeHeaderGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.violet.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: dense ? 24 : 30,
                    height: dense ? 24 : 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: dense ? 15 : 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.s(
                        'Wek mêvan bidomîne',
                        'Misafir olarak devam et',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: dense ? 13 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Google/Misafir butonlarının 4 kullanım yerini (dar+geniş ekran, dense+normal) yeni widget'lara geçir**

`sign_in_screen.dart` içinde şu **4 bloğu**, aynı konumda kalacak şekilde (henüz taşımadan), değiştir:

**4a. Dar ekran (narrow/Column) branch'inde**, satır ~900-923 civarındaki (orijinal dosyada `// Google Sign In` yorumundan `// Guest Sign In` bloğunun sonuna kadar) şu kodu:

```dart
                          // Google Sign In
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: _authOutlineButtonStyle(),
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () => _signInWithGoogle(authProvider),
                              icon: const Text(
                                'G',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppTheme.accent,
                                ),
                              ),
                              label: Text(
                                context.s(
                                  'Bi Google têkeve',
                                  'Google ile giriş yap',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Guest Sign In
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: _authOutlineButtonStyle(),
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () => _signInAsGuest(authProvider),
                              icon: Icon(
                                Icons.person_outline,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.86),
                              ),
                              label: Text(
                                context.s(
                                  'Wek mêvan bidomîne',
                                  'Misafir olarak devam et',
                                ),
                              ),
                            ),
                          ),
```

şununla değiştir:

```dart
                          // Google Sign In
                          _GoogleSignInButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => _signInWithGoogle(authProvider),
                          ),
                          const SizedBox(height: 12),
                          // Guest Sign In
                          _GuestSignInButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => _signInAsGuest(authProvider),
                          ),
```

**4b. Geniş ekran (isWide), `denseWide` dalı**, satır ~530-592 civarındaki şu kodu:

```dart
                                  if (denseWide)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: _authOutlineButtonStyle(
                                              dense: true,
                                            ),
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInWithGoogle(
                                                    authProvider,
                                                  ),
                                            icon: const Text(
                                              'G',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 18,
                                                color: AppTheme.accent,
                                              ),
                                            ),
                                            label: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                context.s(
                                                  'Bi Google têkeve',
                                                  'Google ile giriş yap',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: _authOutlineButtonStyle(
                                              dense: true,
                                            ),
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInAsGuest(
                                                    authProvider,
                                                  ),
                                            icon: Icon(
                                              Icons.person_outline,
                                              size: 20,
                                              color: Colors.white.withValues(
                                                alpha: 0.86,
                                              ),
                                            ),
                                            label: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                context.s(
                                                  'Wek mêvan bidomîne',
                                                  'Misafir olarak devam et',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
```

şununla değiştir:

```dart
                                  if (denseWide)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _GoogleSignInButton(
                                            dense: true,
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInWithGoogle(
                                                    authProvider,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _GuestSignInButton(
                                            dense: true,
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInAsGuest(
                                                    authProvider,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    )
```

**4c. Geniş ekran, `else` (dense olmayan) dalı**, hemen 4b'nin devamındaki şu kodu:

```dart
                                  else ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: _authOutlineButtonStyle(),
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : () => _signInWithGoogle(
                                                authProvider,
                                              ),
                                        icon: const Text(
                                          'G',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: AppTheme.accent,
                                          ),
                                        ),
                                        label: Text(
                                          context.s(
                                            'Bi Google têkeve',
                                            'Google ile giriş yap',
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: wideButtonGap),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: _authOutlineButtonStyle(),
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : () =>
                                                  _signInAsGuest(authProvider),
                                        icon: Icon(
                                          Icons.person_outline,
                                          size: 20,
                                          color: Colors.white.withValues(
                                            alpha: 0.86,
                                          ),
                                        ),
                                        label: Text(
                                          context.s(
                                            'Wek mêvan bidomîne',
                                            'Misafir olarak devam et',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
```

şununla değiştir:

```dart
                                  else ...[
                                    _GoogleSignInButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () =>
                                                _signInWithGoogle(authProvider),
                                    ),
                                    SizedBox(height: wideButtonGap),
                                    _GuestSignInButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () => _signInAsGuest(authProvider),
                                    ),
                                  ],
```

- [ ] **Step 5: Testin geçtiğini doğrula**

Run: `cd zankurd_mobile && flutter test test/widget_test.dart --plain-name "auth alternative buttons stay readable on their own backgrounds"`
Expected: `+1: All tests passed!`

- [ ] **Step 6: Statik analiz**

Run: `cd zankurd_mobile && dart analyze`
Expected: `No issues found!` (`_authOutlineButtonStyle` silindiği ve hiçbir yerde çağrılmadığı için "unused element" uyarısı çıkmamalı — çıkarsa fonksiyonun tüm çağrı yerlerinin gerçekten değiştirildiğini kontrol et).

- [ ] **Step 7: Tüm sign-in testlerini çalıştır**

Run: `cd zankurd_mobile && flutter test test/widget_test.dart --plain-name "auth"`
Expected: Tüm `auth`-isimli testler PASS (bu, `SignInScreen` ile ilgili tüm mevcut testleri kapsar).

- [ ] **Step 8: Commit**

```bash
git add zankurd_mobile/lib/src/screens/sign_in_screen.dart zankurd_mobile/test/widget_test.dart
git commit -m "feat(auth): Google/Misafir butonlarını dolgun, marka renkli tasarıma geçir

Google: beyaz zemin + koyu metin (Google konvansiyonuna uygun, yüksek
kontrast). Misafir: marka gradyanı (homeHeaderGradient) dolgu + beyaz
metin. Eski ince-çerçeveli OutlinedButton'lar ve artık kullanılmayan
_authOutlineButtonStyle kaldırıldı. Konum henüz değişmedi (Task 4)."
```

---

## Task 4: Sign-in ekranında buton sırasını değiştir (Google/Misafir forma öncelik alır)

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/sign_in_screen.dart`

- [ ] **Step 1: Dar ekran (narrow/Column) branch'inde sırayı değiştir**

`sign_in_screen.dart` içinde dar-ekran `Column`'unun children listesinde şu mevcut sıra:

```
1. Language toggle
2. SizedBox(topGap)
3. Logo
4. SizedBox(titleGap)
5. Title+subtitle
6. SizedBox(formGap)
7. Form (email/password/forgot-password)  [FadeTransition ile sarılı]
8. SizedBox(actionGap)
9. Giriş Yap butonu
10. SizedBox(actionGap)
11. Divider ("AN JÎ" / "VEYA")
12. SizedBox(altGap)
13. _GoogleSignInButton
14. SizedBox(12)
15. _GuestSignInButton
16. SizedBox(compact ? 16 : 24)
17. Kayıt ol Wrap
18. SizedBox(bottomGap)
```

Bunu şu sıraya getir (7 ve 11 numaralı elemanların yerini/pozisyonunu 13-15 ile değiştir; divider metni de güncellenir):

```
1. Language toggle
2. SizedBox(topGap)
3. Logo
4. SizedBox(titleGap)
5. Title+subtitle
6. SizedBox(formGap)
7. _GoogleSignInButton
8. SizedBox(12)
9. _GuestSignInButton
10. SizedBox(actionGap)
11. Divider ("An jî bi e-peyamê" / "Veya e-posta ile")
12. SizedBox(altGap)
13. Form (email/password/forgot-password)  [aynı FadeTransition sarmalayıcıyla]
14. SizedBox(actionGap)
15. Giriş Yap butonu
16. SizedBox(compact ? 16 : 24)
17. Kayıt ol Wrap
18. SizedBox(bottomGap)
```

Somut olarak: `SizedBox(height: formGap)` satırından hemen sonra gelen **Form bloğunun tamamını** (yani `FadeTransition(opacity: LoadAnimationSequence.formField1FadeAnimation(...), child: Form(key: _formKey, child: Column([...])))` — bu blok orijinal dosyada e-posta alanından şifremi-unuttum linkine kadar her şeyi içerir) o konumdan **kesip**, mevcut Divider bloğunun (`Row([Expanded(Divider), Padding(Text(...)), Expanded(Divider)])`) hemen **altına, `SizedBox(height: altGap)`'ten sonraya** taşı.

Ardından, Form'un eski konumunda (yani artık boşalan yerde, `SizedBox(height: formGap)`'ten hemen sonra) şunu ekle:

```dart
                          _GoogleSignInButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => _signInWithGoogle(authProvider),
                          ),
                          const SizedBox(height: 12),
                          _GuestSignInButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => _signInAsGuest(authProvider),
                          ),
                          SizedBox(height: actionGap),
```

Ve Divider metnini güncelle — şu satırı:

```dart
                                Text(
                                  context.s('AN JÎ', 'VEYA'),
```

(dar ekran branch'indeki tek kopyasını) şuna çevir:

```dart
                                Text(
                                  context.s(
                                    'An jî bi e-peyamê',
                                    'Veya e-posta ile',
                                  ),
```

Divider'dan hemen sonra (`SizedBox(height: altGap)`'ten sonra), taşıdığın Form bloğunu yapıştır; Form bloğundan hemen sonra gelen eski `SizedBox(height: actionGap)` (Giriş Yap butonundan önceki) olduğu gibi kalsın — Form + bu SizedBox + Giriş Yap butonu birbirini takip etmeye devam etmeli.

- [ ] **Step 2: Geniş ekran (isWide) branch'inde aynı mantıkla sırayı değiştir**

Aynı işlemi geniş-ekran sağ kolonunda tekrarla: `_LanguageToggle` + `SizedBox(wideGap)`'ten hemen sonra gelen **Form bloğunu** (email/password/forgot-password, `FadeTransition` sarmalayıcısıyla birlikte) kes; onun yerine (aynı konuma) şunu ekle:

```dart
                                  if (denseWide)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _GoogleSignInButton(
                                            dense: true,
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInWithGoogle(
                                                    authProvider,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _GuestSignInButton(
                                            dense: true,
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInAsGuest(
                                                    authProvider,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _GoogleSignInButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () =>
                                                _signInWithGoogle(authProvider),
                                    ),
                                    SizedBox(height: wideButtonGap),
                                    _GuestSignInButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () => _signInAsGuest(authProvider),
                                    ),
                                  ],
                                  SizedBox(height: wideButtonGap),
```

Ardından Divider bloğunu (metni "An jî bi e-peyamê"/"Veya e-posta ile" olacak şekilde güncellenmiş) ve `SizedBox(height: wideButtonGap)`'i ekle, ardından **kestiğin Form bloğunu** yapıştır, ardından `SizedBox(height: wideButtonGap)` + Giriş Yap butonu (`GeometricGradientButton`) olduğu gibi devam etsin.

Bu branch'te **Task 3'te zaten yerinde değiştirdiğin** `if (denseWide) ... else ...` Google/Guest bloğu (eskiden Divider'dan sonra duruyordu) — o eski konumundan **silinir** (yukarıda Form'un eski yerine taşındığı için artık orada tekrar durmamalı). Divider'dan sonraki bölümde artık sadece kestiğin Form bloğu + Giriş Yap butonu kalmalı.

Geniş ekran branch'indeki Divider metnini de dar ekrandakiyle aynı şekilde güncelle:

```dart
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      context.s(
                                        'An jî bi e-peyamê',
                                        'Veya e-posta ile',
                                      ),
```

- [ ] **Step 3: Statik analiz**

Run: `cd zankurd_mobile && dart analyze`
Expected: `No issues found!`

- [ ] **Step 4: Tüm sign-in testlerini çalıştır**

Run: `cd zankurd_mobile && flutter test test/widget_test.dart --plain-name "auth"`
Expected: Tüm testler PASS. Özellikle:
- `guest sign in is reachable in the first mobile auth viewport` — Misafir butonu artık daha ERKEN konumda olduğu için `dy < 844` koşulu daha rahat sağlanmalı, PASS beklenir.
- `auth alternative buttons stay readable on their own backgrounds` (Task 3'te güncellenen test) — pozisyon değişse de renk/kontrast sözleşmesi aynı kaldığı için PASS beklenir.
- `auth form text stays readable on the dark auth background` — form'un konumu değişse de `E-posta adresi` etiketinin rengi/stilini hiç değiştirmedik, PASS beklenir.

- [ ] **Step 5: Tam test süitini çalıştır**

Run: `cd zankurd_mobile && flutter test`
Expected: Tüm testler PASS (240 + Task 1'in 4 yeni testi).

- [ ] **Step 6: Commit**

```bash
git add zankurd_mobile/lib/src/screens/sign_in_screen.dart
git commit -m "feat(auth): Google/Misafir butonlarını e-posta formunun önüne al

En hızlı giriş yolları (Google, misafir) artık ekranın en üstünde;
e-posta/şifre formu 'Veya e-posta ile' ayracının altına, ikincil
konuma taşındı. Fonksiyonellik/validasyon değişmedi, sadece sıra."
```

---

## Task 5: Görsel doğrulama (web) ve final kontrol

**Files:** Yok (yalnızca doğrulama; kod değişikliği beklenmiyor, sorun çıkarsa küçük düzeltme yapılabilir).

- [ ] **Step 1: Web sürümünü başlat**

Run (arka planda): `cd zankurd_mobile && flutter run -d web-server --web-port 8787 --web-hostname 127.0.0.1`

Sunucunun hazır olmasını bekle (`Flutter run key commands.` satırı çıkana kadar).

- [ ] **Step 2: Sign-in ekranını görsel olarak incele**

Tarayıcıda `http://127.0.0.1:8787` adresine git. Onboarding'i geç (varsa). Sign-in ekranında:
- Google butonu üstte, beyaz zemin, koyu okunaklı metin, "G" harfi net görünüyor mu?
- Misafir butonu hemen altında, renkli (mor→pembe) dolgu, beyaz metin net okunuyor mu?
- "Veya e-posta ile" ayracı altında e-posta/şifre formu görünüyor mu?
- Konsolda (`preview_console_logs` veya benzeri) RenderFlex overflow / exception var mı? — Olmamalı.

Ekran görüntüsü al, gözle kontrol et.

- [ ] **Step 3: Ana sayfayı görsel olarak incele**

Misafir girişi yap. Ana sayfada:
- Hero kart (Oda Kur/Kodla Katıl) üstte tam genişlikte mi?
- "Zû Bilîze"/"Hemen Oyna" başlığı altında 2x2 renkli ızgara (1v1 kırmızı-turuncu, Günün Yarışması altın, Çark mor, Turnuva turkuaz) görünüyor mu, taşma yok mu?
- Görevler kartı altında mı?
- Kategori ızgarası ve "Örnek Soru" kartı **hiç yok** mu?
- Konsolda overflow/exception var mı? — Olmamalı.

Ekran görüntüsü al, gözle kontrol et. Sorun varsa (taşma, kontrast, hizalama) ilgili dosyada küçük bir düzeltme yap, `dart analyze` + `flutter test` ile doğrula, ayrı bir commit at.

- [ ] **Step 4: Web sunucusunu durdur, geçici dosyaları temizle**

Web sunucu sürecini durdur. Ekran görüntüsü dosyalarını (varsa proje köküne kaydedilenleri) sil.

- [ ] **Step 5: Son tam kontrol**

Run: `cd zankurd_mobile && dart analyze && flutter test`
Expected: `No issues found!` + tüm testler PASS.

- [ ] **Step 6: (Yalnızca Step 3'te düzeltme yapıldıysa) son commit**

```bash
git add -A
git commit -m "fix(ui): görsel QA sonrası [kısa açıklama]"
```

Düzeltme gerekmediyse bu adım atlanır, plan Task 4'ün commit'iyle tamamlanmış sayılır.

---

## Self-Review Notları (bu plan yazılırken yapıldı)

- **Spec kapsaması:** Spec'in "1. Sign-in Ekranı Tasarımı" bölümündeki tüm maddeler (buton sırası, Google/Misafir görselleri, ayraç metni, form'un fonksiyonel/görsel durumu, geniş ekran davranışı) Task 3+4'te karşılanıyor. "2. Ana Sayfa Tasarımı" bölümündeki tüm maddeler (kaldırılanlar, yeni QuickPlayGrid, renk ilkesi, geniş ekran davranışı) Task 1+2'de karşılanıyor. Spec'in "Açık Kalan Küçük Kararlar" listesi bu planda kesin karara bağlandı: `category_grid.dart` (+ 4 kart dosyası daha) silindi, geniş-ekran sütun sayısı 2 olarak sabitlendi (900px üstü LayoutBuilder ile 4'e çıkar ama iki mevcut kullanım bağlamında da tetiklenmez), Google "G" harfi düz metin olarak (daire rozet değil) karar verildi.
- **Placeholder taraması:** Plan içinde "TBD"/"sonra eklenir"/"benzer şekilde" yok; her adım tam kod içeriyor.
- **Tip/isim tutarlılığı:** `QuickPlayGrid` constructor parametreleri (`isKu`, `dailyQuizLoading`, `onDuel`, `onDailyQuiz`, `onSpinWheel`, `onTournament`) Task 1'de tanımlandığı gibi Task 2'nin `home_screen.dart` kullanım yerlerinde birebir aynı isimlerle çağrılıyor. `_GoogleSignInButton`/`_GuestSignInButton` (`onPressed`, `dense`) Task 3'te tanımlandığı gibi Task 4'ün tüm kullanım yerlerinde aynı isimlerle geçiyor.
- **Doğrulanan nokta:** `_showJoinSheet` içindeki `AppTheme.surfaceOf(context)` çağrısı `app_theme.dart:362`'de gerçekten tanımlı olduğu doğrulandı; kopyalama sırasında isim uyuşmazlığı riski yok.
