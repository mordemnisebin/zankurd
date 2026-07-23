import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/leaderboard_entry.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import '../widgets/zana_daily_card.dart';
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'quiz_screen.dart';
import 'home/play_teaser_card.dart';
import 'home/categories_teaser_card.dart';
import 'home/daily_missions_card.dart';
import '../widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    this.scrollController,
    this.refreshSignal,
    this.onOpenLearning,
    this.onOpenPlay,
    this.onOpenCategories,
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

  /// Kategorî akışına geçiş (Faz 3: kategoriler ayrı sekme değil, Fêr Bibe
  /// sekmesi içinden açılır).
  final VoidCallback? onOpenCategories;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _roomActionLoading = false;
  // "—" yükleme placeholder'ı yerine 0 ile başlıyor: kısa an için kırık
  // görünen bir tire yerine, gerçek bakiye gelince normal bir güncelleme.
  int _coinBalance = 0;
  int _streak = 0;
  List<DailyMission> _missions = [];
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
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    // Landscape'te alt nav'a yapışan içerik için ekstra nefes payı (faz1 P3).
    final bottomContentPadding =
        MediaQuery.paddingOf(context).bottom + (isLandscape ? 140 : 112);

    return LayoutBuilder(
      builder: (context, constraints) => _buildBody(
        context,
        ku,
        bottomContentPadding,
        constraints.maxWidth > 720,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool ku,
    double bottomContentPadding,
    bool isWide,
  ) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: CustomScrollView(
        controller: widget.scrollController,
        scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
        slivers: [
          // Pirs stili tam-genişlik header: kenarlarda boşluk yok, ekrandan
          // ekrana uzanır. BorderRadius sadece altta (bottomLeft/Right 20dp).
          SliverToBoxAdapter(child: _buildFullBleedHeader(context, ku)),
          // Metric strip removed per Variant C design
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
                            _DailyLessonHero(
                              isKu: ku,
                              reviewReadyCount: _reviewReadyCount,
                              onStart: _reviewReadyCount > 0
                                  ? widget.onOpenLearning
                                  : _startDailyQuiz,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildAnimatedCard(
                            _heroFadeAnimation(1),
                            DailyMissionsCard(isKu: ku, missions: _missions),
                          ),
                          const SizedBox(height: 24),
                          _buildAnimatedCard(
                            _heroFadeAnimation(2),
                            KeyedSubtree(
                              key: const ValueKey('home-learning-entry'),
                              child: ZanaDailyCard(isKu: ku),
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
                          // Günlük yarışma girişi Pêşbazî sekmesinde yaşar;
                          // home'da üçüncü bir günlük CTA karmaşası olmasın.
                          if (widget.onOpenPlay != null)
                            _buildAnimatedCard(
                              _heroFadeAnimation(2),
                              PlayTeaserCard(onTap: widget.onOpenPlay!),
                            ),
                          if (widget.onOpenCategories != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: _buildAnimatedCard(
                                _heroFadeAnimation(3),
                                CategoriesTeaserCard(
                                  onTap: widget.onOpenCategories!,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isWide)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildAnimatedCard(
                      _heroFadeAnimation(0),
                      _DailyLessonHero(
                        isKu: ku,
                        reviewReadyCount: _reviewReadyCount,
                        onStart: _reviewReadyCount > 0
                            ? widget.onOpenLearning
                            : _startDailyQuiz,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(1),
                        DailyMissionsCard(isKu: ku, missions: _missions),
                      ),
                    ),
                    if (widget.onOpenPlay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildAnimatedCard(
                          _heroFadeAnimation(2),
                          PlayTeaserCard(onTap: widget.onOpenPlay!),
                        ),
                      ),
                    if (widget.onOpenCategories != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildAnimatedCard(
                          _heroFadeAnimation(3),
                          CategoriesTeaserCard(
                            onTap: widget.onOpenCategories!,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(3),
                        KeyedSubtree(
                          key: const ValueKey('home-learning-entry'),
                          child: ZanaDailyCard(isKu: ku),
                        ),
                      ),
                    ),
                  ],
                ),
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

  /// Pirs stili tam-genişlik (full-bleed) gradient header.
  /// Kenarlarda kenar boşluğu yok; altında yuvarlatılmış köşeler.
  Widget _buildFullBleedHeader(BuildContext context, bool ku) {
    return SafeArea(bottom: false, child: _buildCompactHeader(context, ku));
  }

  Widget _buildCompactHeader(BuildContext context, bool ku) {
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
    final shortName = currentName?.trim().split(RegExp(r'\s+')).first;
    final greeting = ku
        ? '$greetingKu, ${shortName ?? 'Lîstikvan'}!'
        : '$greetingTr, ${shortName ?? 'Oyuncu'}!';

    return Container(
      key: const ValueKey('home-profile-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: const BoxDecoration(
        color: AppTheme.culturalBrandBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -20,
            top: 20,
            child: Opacity(
              opacity: 0.05,
              child: Icon(
                Icons.star_border_purple500_sharp,
                size: 240,
                color: Colors.white,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderBadge(
                        AppIcons.fire,
                        AppTheme.brand,
                        '$_streak',
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderBadge(
                        AppIcons.coins,
                        AppTheme.gold,
                        '$_coinBalance',
                      ),
                    ],
                  );
                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderQuickControls(context, ku),
                      const SizedBox(width: 12),
                      PlayerAvatar(radius: 20, displayName: currentName ?? 'Z'),
                    ],
                  );
                  if (constraints.maxWidth < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: metrics),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: controls,
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [metrics, controls],
                  );
                },
              ),
              const SizedBox(height: 32),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  greeting,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ku
                    ? 'Zanîn, ronahiya tarîtiyê ye.'
                    : 'Bilgi, karanlığın aydınlığıdır.',
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, Color iconColor, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderQuickControls(BuildContext context, bool ku) {
    final themeProvider = context.watch<ThemeProvider>();
    const border = Colors.white24;
    const fill = Colors.white12;

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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Row(
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
              themeProvider.isDark ? AppIcons.moon : AppIcons.sun,
              color: Colors.white,
              size: 19,
            ),
          ),
        ],
      ),
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

  /// "Dersê rojane" kartı: karışık kategorili 10 soruluk günlük solo quiz.
  /// (Kart 10 soru vaat eder; ders ağacına değil gerçek quize gider.)
  Future<void> _startDailyQuiz() async {
    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final questions = await repo.loadDailyQuestions(limit: 10);
      if (!mounted || questions.isEmpty) return;
      final room = repo.createRoom().copyWith(
        name: context.isKu ? 'Dersê rojane' : 'Günün Dersi',
        questionCount: questions.length,
      );
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(repository: repo, room: room, questions: questions),
        ),
      );
      if (mounted) _handleRefreshSignal();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home daily quiz');
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  Future<void> _refreshCoins() async {
    try {
      final coins = await repo.loadCoinBalance();
      if (mounted) setState(() => _coinBalance = coins);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'coin refresh failed');
    }
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
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.isLight(context)
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
        border: AppTheme.isLight(context)
            ? null
            : Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count Pirs • $subtitle',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSubColor(context),
            ),
          ),
          const SizedBox(height: 24),
          if (onStart != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCtaColor(context),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onStart,
                child: Text(
                  ctaLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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

  static const _medalColors = [AppTheme.gold, AppTheme.silver, AppTheme.bronze];

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
            Semantics(
              button: true,
              label: ku ? 'Hemûyê bibîne' : 'Tümünü gör',
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    AppRoute.to(
                      LeaderboardScreen(repository: widget.repository),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  // Dokunma hedefi min 44px yükseklik (WCAG 2.5.5).
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ku ? 'Hemûyê bibîne ›' : 'Tümünü gör ›',
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ),
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
                        AppIcons.coins,
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
