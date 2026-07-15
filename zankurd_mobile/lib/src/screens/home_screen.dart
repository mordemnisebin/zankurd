import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
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
import 'home/daily_race_card.dart';

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
    final headerStart = isLight
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: 0.12),
            AppTheme.brandOrange,
          )
        : AppTheme.brandOrange;
    final headerEnd = isLight
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: 0.18),
            AppTheme.brandOrangeWarm,
          )
        : AppTheme.brandOrangeWarm;

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

class _CategoryEntry extends StatelessWidget {
  const _CategoryEntry({required this.isKu, required this.onOpen});

  final bool isKu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isKu ? 'Mijar û mijaran bibîne' : 'Kategori ve konular',
      child: GestureDetector(
        key: const ValueKey('home-category-entry'),
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHiColor(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTheme.violet.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppTheme.violet,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKu ? 'Mijar û mijaran bibîne' : 'Kategori ve konular',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      isKu
                          ? 'Mijarên fêrbûnê û pêşbirkê bibîne'
                          : 'Öğrenme ve yarışma konularına göz at',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.violet),
            ],
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
