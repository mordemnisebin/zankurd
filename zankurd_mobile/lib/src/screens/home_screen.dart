import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'quiz_screen.dart';
import 'home/today_task_card.dart';
import 'home/home_rows.dart';
import '../widgets/app_row_card.dart';
import 'home/daily_missions_card.dart';
import 'shop_screen.dart';
import '../data/mastery_store.dart';
import '../widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../utils/player_identity.dart';

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

  /// Bugün doğru cevaplanan soru sayısı — "bugünün görevi" ilerlemesi.
  int _todayAnswered = 0;
  int _todayTarget = 10;

  /// "Kaldığın yer" listesi: en çok ilerlenen üç kategori.
  List<CategoryProgress> _categoryProgress = const [];
  late AnimationController _loadAnimationController;
  String? _displayName;
  int _refreshCounter = 0;

  ZanKurdRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _loadAnimationController = AnimationController(
      // 4000ms + geç başlayan kademeler, ana ekran gövdesinin ~2.4–3.6 sn
      // boş kalması demekti (2026-07-25 canlı denetimi). Kademe hissi
      // korunuyor, toplam süre insan algısına uygun aralığa çekildi.
      duration: const Duration(milliseconds: 900),
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
    _refreshProgress();
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
    _refreshProgress();
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
    if (!mounted) return;
    // "Bugünün görevi" ilerlemesi günlük "doğru cevap" görevinden okunur;
    // ayrı bir sayaç tutmak yerine mevcut kaynağı kullanıyoruz.
    final answerMission = store.missions
        .where((m) => m.type == MissionType.answerCorrect)
        .firstOrNull;
    setState(() {
      _missions = List.from(store.missions);
      if (answerMission != null) {
        _todayAnswered = answerMission.progress.clamp(0, answerMission.target);
        _todayTarget = answerMission.target;
      }
    });
  }

  /// Kategori ustalık ilerlemesini okur; en çok ilerlenen üç kategori
  /// "kaldığın yer" listesinde gösterilir.
  Future<void> _refreshProgress() async {
    try {
      final mastery = await MasteryStore.load();
      final entries =
          [
            for (final category in repo.categories)
              CategoryProgress(
                category: category,
                correct: mastery.correctCount(category),
                threshold: mastery.nextThreshold(category),
              ),
          ]..sort((a, b) {
            final byCorrect = b.correct.compareTo(a.correct);
            return byCorrect != 0
                ? byCorrect
                : a.category.compareTo(b.category);
          });
      if (mounted) {
        setState(() => _categoryProgress = entries.take(3).toList());
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home mastery load failed');
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

  /// Ana ekranın gövdesi. 2026-07-24: karo ızgarası kaldırıldı — ekran tek
  /// bir soruyu yanıtlıyor ("şimdi ne yapmalıyım?"). Sıra: bugünün görevi →
  /// tekrar → kaldığın yer → günlük görevler. Yarış/Kategoriler kopyaları
  /// silindi; onlar zaten kendi sekmelerinde yaşıyor.
  Widget _buildBody(
    BuildContext context,
    bool ku,
    double bottomContentPadding,
    bool isWide,
  ) {
    final primary = _buildAnimatedCard(
      _heroFadeAnimation(0),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TodayTaskCard(
            isKu: ku,
            loading: _roomActionLoading,
            done: _todayAnswered,
            total: _todayTarget,
            onStart: _startDailyQuiz,
          ),
          if (_reviewReadyCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            AppRowCard(
              key: const ValueKey('home-review-row'),
              icon: AppIcons.arrowsRotate,
              accent: AppTheme.playPink,
              title: context.t(K.homeReviewTime),
              subtitle: context.t(K.homeReviewTimeSub, {
                'count': '$_reviewReadyCount',
              }),
              onTap: () => widget.onOpenLearning?.call(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            context.t(K.homeLearningSection),
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          KeyedSubtree(
            key: const ValueKey('home-learning-path'),
            child: AppRowCard(
              key: const ValueKey('home-lessons-row'),
              icon: AppIcons.graduationCap,
              accent: AppTheme.brand,
              title: context.t(K.homeLearningPath),
              subtitle: context.t(K.homeLessonsSub),
              onTap: () => widget.onOpenLearning?.call(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppRowCard(
            key: const ValueKey('home-topic-picker'),
            icon: AppIcons.bookOpen,
            accent: AppTheme.gold,
            title: context.t(K.homeTopicPicker),
            subtitle: context.t(K.categoriesSubtitle),
            onTap: () => widget.onOpenCategories?.call(),
          ),
        ],
      ),
    );

    final secondary = _buildAnimatedCard(
      _heroFadeAnimation(1),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: const ValueKey('home-play-handoff'),
            child: AppRowCard(
              key: const ValueKey('home-duel-row'),
              icon: AppIcons.bolt,
              accent: AppTheme.playCyan,
              title: context.t(K.homeQuickDuel),
              subtitle: context.t(K.homeQuickDuelSub),
              onTap: () => widget.onOpenPlay?.call(),
            ),
          ),
          if (_categoryProgress.any((entry) => entry.ratio > 0)) ...[
            const SizedBox(height: AppSpacing.xs),
            ContinueSection(
              isKu: ku,
              entries: _categoryProgress,
              onOpenCategory: (_) => widget.onOpenCategories?.call(),
              onBrowseCategories: () => widget.onOpenCategories?.call(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DailyMissionsCard(
            isKu: ku,
            missions: _missions,
            compact: false,
          ),
        ],
      ),
    );

    return Container(
      // Zemin düz: sayfa gradyanı, üstündeki kartların kenarlıklarını
      // yumuşatıp hiyerarşiyi bulanıklaştırıyordu. Tek gradyan CTA'da kalır.
      color: AppTheme.bgOf(context),
      child: CustomScrollView(
        controller: widget.scrollController,
        scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
        slivers: [
          SliverToBoxAdapter(child: _buildFullBleedHeader(context, ku)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: secondary),
                      ],
                    )
                  : Column(
                      children: [
                        primary,
                        const SizedBox(height: AppSpacing.md),
                        secondary,
                      ],
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
      greetingKu = 'Silav';
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
    // Ad çözümlemesi profil ekranıyla aynı kaynaktan gelir; aksi halde
    // "ZanKurd" (ana ekran) ile "Lîstikvanê ZanKurd" (profil) gibi iki
    // ayrı kimlik oluşuyordu.
    final shortName = PlayerIdentity.resolveShortName(currentName, isKu: ku);
    final greeting = context.t(K.homeGreeting, {
      'greeting': ku ? greetingKu : greetingTr,
      'name': shortName,
    });

    return Container(
      key: const ValueKey('home-profile-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: const BoxDecoration(
        // Düz renk BİLEREK duruyor. `AppTheme.homeHeaderGradient` bu şerit
        // için yazılmış ama kullanılmıyor ve 2026-07-31 denetimi bunu
        // "ölü token" diye bildirdi. Gradyana çevirmek denendi ve
        // `kulturel_modern_home_test.dart`i kırdı: o testin kuralı
        // "gradyan 'buraya bas' demektir, ekran başına bir tane" ve ana
        // ekranın gradyanı zaten "Başla" düğmesinin.
        //
        // Yani token ölü değil, kural onu dışarıda bırakıyor. Şeride
        // derinlik istenirse yol gradyan değil: filigran/doku katmanı.
        color: AppTheme.culturalBrandBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      // 2026-07-24: dekoratif daireler ve 220px'lik yıldız filigranı
      // kaldırıldı. Başlık şeridinin işi selamlama + iki metrik; arkasındaki
      // süs metnin kontrastını düşürmekten başka bir şey yapmıyordu.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seri sıfırken rozet "🔥 0" yazıyordu: serinin amacı
                      // motive etmek, oysa ilk gün kullanıcıyı sıfırla
                      // karşılıyordu (2026-07-25 canlı denetimi). Sayı
                      // yerine metin koymak ise başlık satırını dar
                      // ekranlarda taşırıyor; seri başlayana kadar rozet
                      // yalnız alevi gösterir — özellik görünür kalır,
                      // sıfır vurgulanmaz.
                      _buildHeaderBadge(
                        AppIcons.fire,
                        AppTheme.brand,
                        _streak > 0 ? '$_streak' : null,
                        semanticLabel: context.t(K.dailyStreakDays),
                        onTap: () => _showStreakFreezeBottomSheet(context),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderBadge(
                        AppIcons.coins,
                        AppTheme.gold,
                        '$_coinBalance',
                        semanticLabel: context.t(K.shop),
                        onTap: () async {
                          await Navigator.of(
                            context,
                          ).push(AppRoute.to(ShopScreen(repository: repo)));
                          if (mounted) await _refreshCoins();
                        },
                      ),
                    ],
                  );
                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderQuickControls(context, ku),
                      const SizedBox(width: 12),
                      // Avatar harfi ve rengi profil ekranıyla aynı çözümlenmiş
                      // addan türetilir; ham ad verildiğinde ana ekranda "Z",
                      // profilde "L" görünüyordu.
                      PlayerAvatar(
                        radius: 20,
                        displayName: PlayerIdentity.resolveName(
                          currentName,
                          isKu: ku,
                        ),
                      ),
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
              const SizedBox(height: 18),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  greeting,
                  maxLines: 1,
                  style: AppTypography.heading1.copyWith(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.t(K.homeMotto),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStreakFreezeBottomSheet(BuildContext context) {
    final isKu = context.isKu;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.fire, color: AppTheme.brand, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  isKu ? 'Zincîra Pêşketinê (Streak)' : 'Günlük Seri (Streak)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(ctx),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _streak > 0
                      // "sen" Türkçedir; Kurmancîde ikinci tekil şahıs
                      // "tu"dur. Cümlenin geri kalanı doğru Kurmancî
                      // olduğu için kusur göze "biraz tuhaf" gelip
                      // geçiyordu (2026-07-31 denetimi).
                      ? (isKu
                          ? '$_streak roj in ku tu bi rêkûpêk dilîzî!'
                          : '$_streak gündür aralıksız oynuyorsun!')
                      : (isKu
                          ? 'Hêj zincîra te dest pê nekiriye. Îro bilîze!'
                          : 'Henüz serin başlamadı. Bugün bir yarış başlat!'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSubColor(ctx)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(AppIcons.shieldHalved, color: AppTheme.cyan, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isKu
                                  ? 'Karta Parastina Zincîrê'
                                  : 'Seri Dondurma Koruması',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor(ctx),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isKu
                                  ? 'Rojên ku tu nekarî bilîzî zincîra te napetite!'
                                  : 'Oynamayı unuttuğun günlerde serin bozulmaz!',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSubColor(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppTheme.brand,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Navigator.of(context).push(
                      AppRoute.to(ShopScreen(repository: repo)),
                    );
                    if (mounted) await _refreshCoins();
                  },
                  icon: const Icon(AppIcons.cartShopping, color: Colors.white, size: 18),
                  label: Text(
                    // İki dil aynı düğmede yan yana yazıyordu ("Herin Dukanê
                    // / Mağazaya Git") — Kurmancî arayüzde Türkçe metin
                    // sızıyordu (2026-07-31 Antigravity eklentisi denetimi).
                    isKu ? 'Herin Dukanê' : 'Mağazaya Git (Seri Koru)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Başlık rozeti. [text] null ise yalnız ikon çizilir.
  Widget _buildHeaderBadge(
    IconData icon,
    Color iconColor,
    String? text, {
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          if (text != null) ...[
            const SizedBox(width: 6),
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return badge;
    // Coin rozeti mağazaya götürür. Mağazaya tek giriş profil ekranının
    // içindeydi: coin kazanan oyuncu onu nerede harcayacağını bulamıyordu
    // (2026-07-27 denetimi). Rozet zaten bakiyeyi gösterdiği için doğal
    // giriş noktası burasıdır.
    //
    // `InkWell` değil `GestureDetector`: başlık gradyanı `Material`
    // ağacının dışında çiziliyor ve InkWell orada "No Material widget
    // found" ile düşüyordu. Dalga efekti bu rozette zaten görünmezdi.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: badge,
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
            tooltip: context.t(K.language),
            onTap: context.langProvider.toggle,
            child: Text(
              context.t(K.languageCode),
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
            tooltip: context.t(K.darkLightMode),
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
        name: context.t(K.dailyLesson),
        questionCount: questions.length,
      );
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: repo,
            room: room,
            questions: questions,
            // "Günün Dersi" bir ders akışıdır: süre baskısı yok, her
            // cevaptan sonra açıklama gösterilir. Varsayılan `competition`
            // bırakıldığında ana ekranın tek birincil eylemi yarışma gibi
            // davranıyor ve açıklama paneli hiç render edilmiyordu
            // (2026-07-25 canlı denetimi).
            experience: QuizExperience.learning,
            enableTimer: false,
          ),
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
