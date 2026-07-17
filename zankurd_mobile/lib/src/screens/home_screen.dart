import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/leaderboard_entry.dart';
import '../models/room.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import 'home/hero_card.dart';
import '../widgets/animated_counter.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/zana_daily_card.dart';
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'room_screen.dart';
import 'matchmaking_screen.dart';
import 'shop_screen.dart';
import 'categories_tab.dart';
import 'contest_screen.dart';
import 'leaderboard_screen.dart';
import 'home/daily_race_card.dart';
import '../widgets/player_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    this.scrollController,
    this.refreshSignal,
    this.onOpenLearning,
    this.onOpenPlay,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
  final ScrollController? scrollController;

  /// Ana Sayfa sekmesi yeniden seçildiğinde tetiklenir; coin bakiyesi ve
  /// görevler tazelenir. Kategoriler sekmesinden başlatılan solo seviye
  /// quizleri bu ekranın _refreshCoins'ini doğrudan çağıramaz (farklı bir
  /// Navigator dalında yaşarlar), bu yüzden dönüşte sekmeye tekrar
  /// basıldığında tazeleme burada yapılır.
  final Listenable? refreshSignal;
  final VoidCallback? onOpenLearning;

  /// "Zû Bilîze" bölümü kaldırıldı (Bilîze sekmesiyle bire bir aynıydı);
  /// bunun yerine Bilîze sekmesine geçiş yapan kısa bir teaser gösterilir.
  final VoidCallback? onOpenPlay;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _roomActionLoading = false;
  int? _coinBalance;
  int _streak = 0;
  List<DailyMission> _missions = [];
  bool _missionsLoading = true;
  int _reviewReadyCount = 0;
  late AnimationController _loadAnimationController;
  String? _displayName;
  int _refreshCounter = 0;

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
    _bootstrap();
    _refreshStreak();
    _loadMissions();
    _refreshReviewCount();
    widget.refreshSignal?.addListener(_handleRefreshSignal);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefreshSignal);
    _loadAnimationController.dispose();
    super.dispose();
  }

  /// Ana Sayfa sekmesine dönüldüğünde coin bakiyesini ve görevleri tazeler.
  void _handleRefreshSignal() {
    if (!mounted) return;
    _refreshCoins();
    _loadMissions();
    _refreshStreak();
    _refreshReviewCount();
    setState(() => _refreshCounter++);
  }

  Future<void> _refreshStreak() async {
    final store = await StreakStore.load();
    if (mounted) setState(() => _streak = store.effectiveStreak());
  }

  Future<void> _refreshReviewCount() async {
    try {
      final store = await MistakeStore.load();
      if (mounted) setState(() => _reviewReadyCount = store.readyCount);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_load');
    }
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
      // Soru havuzunu ısıt (home doğrudan quiz açmaz; matchmaking/oda/quiz ayrı).
      await repo.loadQuestions(limit: 10);
      final coins = await repo.loadCoinBalance();
      if (!mounted) return;
      setState(() => _coinBalance = coins);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home bootstrap load failed');
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
            // Mobilde ilk bakışta yarış aksiyonu görünür kalsın.
            expandedHeight: 190,
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
                // Metni yalnızca collapse'ta koy: aksi halde header'daki
                // "ZanKurd" ile çift find (test + Semantics) oluşur.
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Text(
                    isCollapsed ? 'ZanKurd' : '',
                    style: TextStyle(
                      // Light mode: surface krem — white title kaybolmasın
                      color: AppTheme.textPrimaryColor(context),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                0,
              ),
              child: _buildAnimatedCard(
                _heroFadeAnimation(0),
                _buildMetricStrip(context, ku),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                0,
              ),
              child: _buildAnimatedCard(
                _heroFadeAnimation(1),
                _DailyLessonHero(
                  isKu: ku,
                  reviewReadyCount: _reviewReadyCount,
                  onStart: widget.onOpenLearning,
                ),
              ),
            ),
          ),
          if (isWide)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.lg,
              ),
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
                              onQuickMatch: () => Navigator.of(context).push(
                                AppRoute.to(
                                  MatchmakingScreen(repository: repo),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildAnimatedCard(
                            _heroFadeAnimation(2),
                            KeyedSubtree(
                              key: const ValueKey('home-learning-entry'),
                              child: ZanaDailyCard(
                                isKu: ku,
                                onStart: widget.onOpenLearning,
                                reviewReadyCount: _reviewReadyCount,
                              ),
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
                            _PlayHubTeaser(isKu: ku, onOpen: widget.onOpenPlay),
                          ),
                          const SizedBox(height: 16),
                          _buildAnimatedCard(
                            _heroFadeAnimation(2),
                            DailyRaceCard(
                              onTap: () => Navigator.of(context).push(
                                AppRoute.to(
                                  ContestScreen(repository: widget.repository),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAnimatedCard(
                            _heroFadeAnimation(3),
                            _CategoryEntry(
                              isKu: ku,
                              onOpen: () => Navigator.of(context).push(
                                AppRoute.to(
                                  CategoriesTab(repository: widget.repository),
                                ),
                              ),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.lg,
              ),
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
                        onQuickMatch: () => Navigator.of(context).push(
                          AppRoute.to(MatchmakingScreen(repository: repo)),
                        ),
                      ),
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(1),
                        _PlayHubTeaser(isKu: ku, onOpen: widget.onOpenPlay),
                      ),
                    );
                  }
                  if (index == 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(2),
                        DailyRaceCard(
                          onTap: () => Navigator.of(context).push(
                            AppRoute.to(
                              ContestScreen(repository: widget.repository),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (index == 3) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(3),
                        _CategoryEntry(
                          isKu: ku,
                          onOpen: () => Navigator.of(context).push(
                            AppRoute.to(
                              CategoriesTab(repository: widget.repository),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (index == 4) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(3),
                        KeyedSubtree(
                          key: const ValueKey('home-learning-entry'),
                          child: ZanaDailyCard(
                            isKu: ku,
                            onStart: widget.onOpenLearning,
                            reviewReadyCount: _reviewReadyCount,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                }, childCount: 5),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                0,
              ),
              child: _buildAnimatedCard(
                _heroFadeAnimation(3),
                _MiniLeaderboard(repository: widget.repository, isKu: ku),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding)),
        ],
      ),
    );
  }

  // Onaylı mockup 3 imza öğesi: 3 kompakt metrik çip + haftalık zincir barı.
  Widget _buildMetricStrip(BuildContext context, bool ku) {
    final completed = _missions.where((m) => m.completed).length;
    final total = _missions.length;

    Widget chip(IconData icon, Color color, String value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTypography.heading2.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textSubColor(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    const weekTarget = 7;
    final progress = (_streak.clamp(0, weekTarget)) / weekTarget;

    return Column(
      key: const ValueKey('home-metric-strip'),
      children: [
        Row(
          children: [
            chip(
              Icons.local_fire_department,
              AppTheme.wrong,
              '$_streak',
              ku ? 'Zincîr' : 'Seri',
            ),
            const SizedBox(width: 10),
            chip(
              Icons.monetization_on,
              AppTheme.gold,
              _coinBalance == null ? '—' : '$_coinBalance',
              ku ? 'Xeruz' : 'Coin',
            ),
            const SizedBox(width: 10),
            chip(
              Icons.task_alt,
              AppTheme.correct,
              total == 0 ? '0' : '$completed/$total',
              ku ? 'Misyon' : 'Görev',
            ),
          ],
        ),
        if (_streak > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Text(
                  '$_streak / $weekTarget',
                  style: AppTypography.heading2.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 9, color: AppTheme.borderColor(context)),
                        FractionallySizedBox(
                          widthFactor: progress == 0 ? 0.02 : progress,
                          child: Container(
                            height: 9,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.gold, AppTheme.correct],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
              // Turuncu header üzerinde okunur kalması için beyaz chip.
              color: Colors.white.withValues(alpha: 0.22),
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
    final isLight = AppTheme.isLight(context);
    // Onaylı mockup masthead'i: koyu Kürdistan yeşili yayın kimliği.
    final headerStart = isLight
        ? const Color(0xFF14503A)
        : const Color(0xFF0B251C);
    final headerEnd = isLight
        ? const Color(0xFF1F6B4E)
        : const Color(0xFF1A4E3B);

    return Container(
      key: const ValueKey('home-profile-header'),
      decoration: BoxDecoration(
        // Pirs-inspired büyük turuncu karşılama/profil header'ı.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [headerStart, headerEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: KilimPatternPainter(
                drawPattern: true,
                color: Colors.white,
                opacity: 0.05,
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.page,
            bottom: AppSpacing.lg,
            child: _buildAnimatedCard(
              _heroFadeAnimation(0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'ZanKurd',
                    style: AppTypography.display.copyWith(
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPriorityMission(context, ku),
                ],
              ),
            ),
          ),
          if (_streak > 0)
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.page,
              child: _buildStreakHexagon(_streak),
            ),
          Positioned(
            left: AppSpacing.page,
            top: AppSpacing.lg,
            child: _buildCoinGemRow(_coinBalance),
          ),
          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.page,
            child: _buildHeaderQuickControls(context, ku),
          ),
          Positioned(
            right: AppSpacing.page,
            bottom: AppSpacing.lg,
            child: _buildAnimatedCard(
              _heroFadeAnimation(0),
              const RojMascot(
                key: ValueKey('home-header-roj-mascot'),
                size: 72,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderQuickControls(BuildContext context, bool ku) {
    final themeProvider = context.watch<ThemeProvider>();
    final border = Colors.white.withValues(alpha: 0.35);
    final fill = Colors.white.withValues(alpha: 0.16);

    Widget control({
      required Key key,
      required String tooltip,
      required Widget child,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            key: key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: border),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        control(
          key: const ValueKey('home-language-toggle'),
          tooltip: ku ? 'Ziman' : 'Dil',
          onTap: context.langProvider.toggle,
          child: Text(
            ku ? 'KU' : 'TR',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        control(
          key: const ValueKey('home-theme-toggle'),
          tooltip: 'Tema',
          onTap: themeProvider.toggleDarkLight,
          child: Icon(
            themeProvider.isDark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            color: Colors.white,
            size: 19,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakHexagon(int streak) {
    final pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              // Turuncu header üzerinde yarı saydam beyaz chip.
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 1),
                Text(
                  '$streak',
                  style: AppTypography.caption.copyWith(color: Colors.white),
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
        Semantics(
          button: true,
          label: context.s('Dikan, hejmara coinan', 'Mağaza, coin bakiyesi'),
          value: '$coinBalance',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context)
                .push(AppRoute.to(ShopScreen(repository: repo)))
                .then((_) => _refreshCoins()),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  // Mağazayı açan chip için min 44 px dokunma alanı.
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: AppTheme.gold,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      AnimatedCounter(
                        value: coinBalance,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
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
    final categories = repo.categories;
    var selectedCategory = categories.isNotEmpty ? categories.first : 'Ziman';
    var selectedSeconds = GameRoom.defaultSecondsPerQuestion;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final ku = context.isKu;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ku ? 'Ode ava bike' : 'Oda oluştur',
                    style: AppTypography.heading2.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ku
                        ? 'Mijara û demê ji bo hemû lîstikvanan hilbijêre.'
                        : 'Kategori ve soru süresini sen belirle.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ku ? 'Kategori' : 'Kategori',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        ChoiceChip(
                          label: Text(category),
                          selected: category == selectedCategory,
                          onSelected: (_) =>
                              setSheetState(() => selectedCategory = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ku ? 'Dem ji bo pirsê' : 'Süre / soru',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final seconds in GameRoom.allowedSecondsPerQuestion)
                        ChoiceChip(
                          label: Text('$seconds sn'),
                          selected: seconds == selectedSeconds,
                          onSelected: (_) =>
                              setSheetState(() => selectedSeconds = seconds),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.add_home_work_outlined),
                      label: Text(ku ? 'Ode ava bike' : 'Odayı oluştur'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final room = await repo.createOnlineRoom(
        category: selectedCategory,
        secondsPerQuestion: selectedSeconds,
      );
      if (!context.mounted) return;
      _openRoom(context, room);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'createOnlineRoom failed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isKu
                ? 'Odeya serhêl nehate vekirin. Ji kerema xwe dîsa biceribîne.'
                : 'Çevrimiçi oda açılamadı. Lütfen tekrar deneyin.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  void _openRoom(BuildContext context, GameRoom room) {
    Navigator.of(
      context,
    ).push(AppRoute.to(RoomScreen(repository: repo, initialRoom: room)));
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
        final fieldLabel = ku ? 'Koda odeyê' : 'Oda kodu';
        final inputTextStyle = AppTypography.bodyLarge.copyWith(
          color: AppTheme.textPrimaryColor(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );
        final hintTextStyle = AppTypography.bodyLarge.copyWith(
          color: AppTheme.textSubColor(context),
          fontWeight: FontWeight.w500,
        );
        final fieldBorderRadius = BorderRadius.circular(AppRadius.sm);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(sheetCtx).bottom + AppSpacing.md,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ku ? 'Tevlî Odeyê Bibe' : 'Odaya Katıl',
                  style: AppTypography.heading1.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  fieldLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textSubColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const ValueKey('join-room-code-field'),
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: inputTextStyle,
                  cursorColor: AppColors.focus,
                  decoration: InputDecoration(
                    hintText: 'ZK-XXXX',
                    hintStyle: hintTextStyle,
                    filled: true,
                    fillColor: AppTheme.surfaceHiColor(context),
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: AppTheme.textSubColor(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppTheme.borderColor(context),
                      ),
                      borderRadius: fieldBorderRadius,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.focus,
                        width: 2,
                      ),
                      borderRadius: fieldBorderRadius,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppTheme.wrong),
                      borderRadius: fieldBorderRadius,
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppTheme.wrong,
                        width: 2,
                      ),
                      borderRadius: fieldBorderRadius,
                    ),
                    errorStyle: const TextStyle(
                      color: AppTheme.wrong,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return ku ? 'Koda odeyê pêwîst e.' : 'Oda kodu gerekli.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
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
                                  ? 'Tevlî odeya serhêl nebû. Ji kerema xwe kodê kontrol bike.'
                                  : 'Çevrimiçi odaya katılınamadı. Lütfen kodu kontrol edin.',
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
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    });
  }
}

/// Onaylı mockup 3 "Dersê rojane" kartı: sıcak zeminli, üretilmiş coin
/// illüstrasyonlu günlük ders/tekrar girişi. CTA [onStart] akışını (öğrenme
/// sekmesi) tetikler; hazır tekrar varsa aralıklı tekrarı önceliklendirir.
class _DailyLessonHero extends StatelessWidget {
  const _DailyLessonHero({
    required this.isKu,
    required this.reviewReadyCount,
    this.onStart,
  });

  final bool isKu;
  final int reviewReadyCount;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final hasReview = reviewReadyCount > 0;
    final title = hasReview
        ? (isKu ? 'Dubarekirinên Îro' : 'Bugünkü Tekrarlar')
        : (isKu ? 'Dersê rojane' : 'Günün Dersi');
    final count = hasReview ? reviewReadyCount : 10;
    final subtitle = hasReview
        ? (isKu ? 'Li benda dubarekirinê ne' : 'Tekrara hazır')
        : (isKu ? 'Dawî bike û xelat bistîne!' : 'Bitir ve ödül kazan!');
    final ctaLabel = hasReview
        ? (isKu ? 'Dest bi dubarekirinê' : 'Tekrara başla')
        : (isKu ? 'Destpêk bike' : 'Başla');

    return Container(
      key: const ValueKey('home-daily-lesson'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2A2412), Color(0xFF1B2A1E)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFF4A3D1C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: AppTheme.gold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: const Color(0xFFE9CF8F),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$count ',
                            style: AppTypography.display.copyWith(
                              color: Colors.white,
                              fontSize: 30,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: 'Pirs',
                            style: AppTypography.heading2.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFFD9C9A0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/illustrations/daily_coins.png',
                width: 120,
                height: 84,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
          if (onStart != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.wrong,
                  foregroundColor: Colors.white,
                ),
                child: Text(ctaLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniLeaderboard extends StatefulWidget {
  const _MiniLeaderboard({required this.repository, required this.isKu});

  final ZanKurdRepository repository;
  final bool isKu;

  @override
  State<_MiniLeaderboard> createState() => _MiniLeaderboardState();
}

class _MiniLeaderboardState extends State<_MiniLeaderboard> {
  List<LeaderboardEntry>? _top;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Test ortamında ağ/async liderlik yüklemesi pumpAndSettle'ı zorlamasın
    // ve mevcut oda testlerindeki oyuncu-adı nöbetçileriyle çakışmasın.
    if (isFlutterTestEnvironment) return;
    try {
      final entries = await widget.repository.loadLeaderboard(limit: 3);
      if (mounted) setState(() => _top = entries);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home mini leaderboard');
      if (mounted) setState(() => _top = const []);
    }
  }

  static const _medalColors = [
    AppTheme.gold,
    Color(0xFFB8C0C4),
    Color(0xFFC17A44),
  ];

  @override
  Widget build(BuildContext context) {
    final ku = widget.isKu;
    final entries = _top;
    // Yüklenene kadar (ve boşsa) gizli kalır — sonsuz spinner pumpAndSettle'ı
    // bloke etmesin ve boş liderlik yer kaplamasın.
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ku ? 'Lîsteya bilind' : 'Liderlik',
              style: AppTypography.heading2.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                AppRoute.to(LeaderboardScreen(repository: widget.repository)),
              ),
              child: Text(
                ku ? 'Hemûyê bibîne ›' : 'Tümünü gör ›',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textSubColor(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          i == 0 ? AppSpacing.sm : 6,
                          AppSpacing.sm,
                          i == entries.length - 1 ? AppSpacing.sm : 6,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${entries[i].rank}',
                                textAlign: TextAlign.center,
                                style: AppTypography.heading2.copyWith(
                                  color: _medalColors[i.clamp(0, 2)],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PlayerAvatar(
                              radius: 16,
                              photoUrl: entries[i].avatarUrl,
                              iconId: entries[i].avatarIcon,
                              colorHex: entries[i].avatarColor,
                              displayName: entries[i].displayName,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entries[i].displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.monetization_on,
                              color: AppTheme.gold,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${entries[i].totalScore}',
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CategoryEntry extends StatelessWidget {
  const _CategoryEntry({required this.isKu, required this.onOpen});

  final bool isKu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // Pirs-inspired gradient card — vibrant indigo-to-violet with white text.
    const gradientColors = [
      Color(0xFF5B4DBC),
      Color(0xFF7B68EE),
    ];

    return Semantics(
      button: true,
      label: isKu ? 'Mijar û mijaran bibîne' : 'Kategori ve konular',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home-category-entry'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative background icon
                Positioned(
                  right: -10,
                  bottom: -16,
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                Row(
                  children: [
                    // Icon circle
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isKu
                                ? 'Mijar û mijaran bibîne'
                                : 'Kategori ve konular',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Color(0x55000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            isKu
                                ? 'Mijarên fêrbûnê û pêşbirkê bibîne'
                                : 'Öğrenme ve yarışma konularına göz at',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 22,
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

/// Bilîze sekmesine kısa yol — tam mod listesi (Şerê 1vs1, Pêşbirka Rojê,
/// Çerxa Rojê, Turnuva) artık yalnızca Bilîze'de gösteriliyor; burada aynı
/// kartları tekrarlamak yerine oraya yönlendiren tek bir teaser var.
class _PlayHubTeaser extends StatelessWidget {
  const _PlayHubTeaser({required this.isKu, this.onOpen});

  final bool isKu;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surfaceHiColor(context);
    final accent = AppTheme.playCyan;

    return Semantics(
      button: true,
      label: isKu ? 'Pêşbaziyên din' : 'Yarış modları',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home-direct-play-entry'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Color.alphaBlend(accent.withValues(alpha: 0.12), surface),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: accent.withValues(alpha: 0.42),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKu ? 'Pêşbaziyên din' : 'Yarış modları',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        isKu
                            ? '1vs1, ode, turnuva û pêşbirkên rojane'
                            : 'Günün yarışması, düello, oda ve turnuva burada',
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textSubColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: accent,
                      size: 24,
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

class RojPatternPainter extends CustomPainter {
  const RojPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Güneş merkezi (Sağ üst / ortalama bölge)
    final center = Offset(size.width * 0.85, size.height * 0.45);

    // Güneş halkaları
    canvas.drawCircle(center, 30, paint);
    canvas.drawCircle(center, 42, paint);

    // Güneş Işınları (Roj / 12 ışın)
    final rayCount = 12;
    final innerRadius = 46.0;
    final outerRadius = 70.0;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * 3.1415926535) / rayCount;
      final start = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }

    // Geometrik kilim/dağ çizgileri
    final kilimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = -50; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i + 120, size.height), kilimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
