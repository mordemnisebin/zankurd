import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/xp_store.dart';
import '../widgets/progress_summary.dart';
import '../widgets/streak_panel.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import '../data/daily_mission_store.dart';
import '../data/achievement_store.dart';
import '../models/daily_mission.dart';
import '../models/quiz_question.dart';
import '../services/premium_service.dart';
import 'paywall_screen.dart';
import 'quiz_screen.dart';
import 'home/today_task_card.dart';
import 'home/home_rows.dart';
import '../widgets/app_row_card.dart';
import '../widgets/mode_card.dart';
import 'home/daily_missions_card.dart';
import 'shop_screen.dart';
import '../data/mastery_store.dart';
import '../widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../utils/player_identity.dart';
import '../services/analytics_service.dart';

/// [MistakeStore.readyIds] içindeki kimlikleri gerçekten açılabilir
/// (`playableQuestions`) sorularla kesiştirir.
///
/// Ham `readyCount` yalnız kayıtlı kimlik sayısını verir, kaynağa bakmaz.
/// Çevrimiçi maçlarda yanlış yapılan sorular sunucu UUID'siyle kaydedilir
/// ve içerik kalite karantinasıyla bankadan çıkarılan sorular da aynı
/// şekilde asla çözülemez — "Tekrar zamanı" satırı bu yüzden Öğren
/// sekmesinin gerçekte sunabileceğinden daha yüksek bir sayı gösteriyordu
/// (2026-08-14 denetimi; `profile_screen.dart`taki `_launchableMistakeIds`
/// ve `todays_review_card.dart`taki 2026-08-06 düzeltmesiyle aynı kök
/// neden).
int launchableReviewCount(
  Set<String> readyIds,
  List<QuizQuestion> playableQuestions,
) {
  final launchableIds = playableQuestions.map((q) => q.id).toSet();
  return readyIds.where(launchableIds.contains).length;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    this.scrollController,
    this.refreshSignal,
    this.onOpenLearning,
    this.onOpenPlay,
    this.onOpenCategories,
    this.onOpenCategory,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
  final ScrollController? scrollController;

  /// Ana Sayfa sekmesi yeniden seçildiğinde tetiklenir; coin bakiyesi ve
  /// görevler tazelenir. Bu, ana ekranın KENDİ push'larından (Öğren/
  /// Kategoriler) bağımsız bir ikinci tazeleme yoludur: örn. Yarış
  /// sekmesinde oynanan bir maçtan sonra Öğren'e dönmek de burayı tetikler
  /// (bkz. [onOpenLearning]/[onOpenCategories] — onlar yalnız KENDİ
  /// push'larının dönüşünü kapsar).
  final Listenable? refreshSignal;

  /// Öğrenme akışına geçiş. Dönüşü (Future) BEKLENİR: eskiden `VoidCallback`
  /// idi ve push'un tamamlanması hiç izlenmiyordu, bu yüzden Fêr Bibe
  /// sekmesinde push/pop ile kalan bir oyuncu ders/quiz bitirip geri
  /// döndüğünde coin/XP/tekrar sayısı/"kaldığın yer" YALNIZ sekmeye tekrar
  /// basılırsa (bir sekme değişimiyle) tazeleniyordu — aynı sekme içi
  /// push/pop dönüşünde asla (2026-08-14 denetimi). Artık dönüşte
  /// doğrudan tazelenir.
  final Future<void> Function()? onOpenLearning;

  /// "Zû Bilîze" bölümü kaldırıldı (Bilîze sekmesiyle bire bir aynıydı);
  /// bunun yerine Bilîze sekmesine geçiş yapan kısa bir teaser gösterilir.
  final VoidCallback? onOpenPlay;

  /// Kategorî akışına geçiş (Faz 3: kategoriler ayrı sekme değil, Fêr Bibe
  /// sekmesi içinden açılır). [onOpenLearning] ile aynı sebeple dönüş
  /// beklenir.
  final Future<void> Function()? onOpenCategories;

  /// Belirli bir kategoriyi doğrudan açar ("Kaldığın yer" satırları).
  ///
  /// Verilmezse [onOpenCategories] genel listeye düşer. Eskiden "Kaldığın
  /// yer" satırındaki kategori argümanı `(_) => onOpenCategories?.call()`
  /// ile YOK SAYILIYORDU — kullanıcı "Tarîx %40" satırına dokununca genel
  /// kategori listesine düşüyordu, doğrudan Tarîx'e değil (2026-08-14
  /// denetimi).
  final Future<void> Function(String category)? onOpenCategory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _roomActionLoading = false;
  // "—" yükleme placeholder'ı yerine 0 ile başlıyor: kısa an için kırık
  // görünen bir tire yerine, gerçek bakiye gelince normal bir güncelleme.
  int _coinBalance = 0;
  int _level = 1;
  int _xpInLevel = 0;
  int _xpNeeded = 0;
  int _streak = 0;
  List<DailyMission> _missions = [];
  int _reviewReadyCount = 0;

  /// Bugün doğru cevaplanan soru sayısı — "bugünün görevi" ilerlemesi.
  int _todayAnswered = 0;
  int _todayTarget = 10;
  bool _firstSession = true;

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
    _refreshFirstSession();
    _refreshXpLevel();
    _refreshReviewCount();
    // "Kaldığın yer" ilk açılışta hiç çağrılmıyordu — yalnız
    // `_handleRefreshSignal` içinden tetikleniyordu, o da yalnız sekmeye
    // TEKRAR basıldığında çalışır. Öğren zaten açılış sekmesi olduğu için
    // (bkz. app_shell.dart `_tab = 0`) o ilk seçim asla bir sekme
    // DEĞİŞİMİ tetiklemiyor — kullanıcı başka bir sekmeye gidip dönene
    // kadar bölüm hep boş kalıyordu (2026-08-14 denetimi).
    _refreshProgress();
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
    _refreshXpLevel();
    _loadMissions();
    _refreshFirstSession();
    _refreshStreak();
    _refreshProgress();
    _refreshReviewCount();
    setState(() => _refreshCounter++);
  }

  /// Öğrenme akışına gider ve dönüşte ana ekranı tazeler.
  ///
  /// Push tab-içi kaldığı (bir sekme değişimi olmadığı) için tek tazeleme
  /// fırsatı bu dönüştür — bkz. [onOpenLearning] doc yorumu.
  Future<void> _openLearning() async {
    await widget.onOpenLearning?.call();
    if (mounted) _handleRefreshSignal();
  }

  /// Genel kategori listesine gider ve dönüşte ana ekranı tazeler.
  Future<void> _openCategories() async {
    await widget.onOpenCategories?.call();
    if (mounted) _handleRefreshSignal();
  }

  /// Belirli bir kategoriyi açar (varsa [HomeScreen.onOpenCategory]
  /// aracılığıyla, yoksa genel listeye düşer) ve dönüşte tazeler.
  Future<void> _openCategory(String category) async {
    final specific = widget.onOpenCategory;
    if (specific != null) {
      await specific(category);
    } else {
      await widget.onOpenCategories?.call();
    }
    if (mounted) _handleRefreshSignal();
  }

  Future<void> _refreshXpLevel() async {
    try {
      final store = await XPStore.load();
      if (!mounted) return;
      setState(() {
        _level = store.currentLevel;
        _xpInLevel = store.xpInCurrentLevel;
        _xpNeeded = store.xpNeededForNextLevel;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_progress');
    }
  }

  Future<void> _refreshStreak() async {
    final store = await StreakStore.load();
    if (mounted) setState(() => _streak = store.effectiveStreak());
  }

  Future<void> _refreshFirstSession() async {
    final store = await AchievementStore.load();
    if (mounted) {
      setState(() {
        _firstSession = !store.isUnlocked(AchievementIds.firstGame);
      });
    }
  }

  Future<void> _refreshReviewCount() async {
    try {
      final store = await MistakeStore.load();
      if (mounted) {
        setState(
          () => _reviewReadyCount = launchableReviewCount(
            store.readyIds,
            repo.playableQuestions,
          ),
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_load');
    }
  }

  Future<void> _loadMissions() async {
    final store = await DailyMissionStore.load();
    if (!mounted) return;
    // "Bugünün görevi" ilerlemesi deponun kendi günlük sayacından okunur.
    //
    // Buradaki kaynak bir zamanlar `MissionType.answerCorrect` göreviydi:
    // görev seçilmediği günlerde kart gün boyu 0'da donuyordu, çünkü günün
    // üç görevi on altı tanelik havuzdan çekiliyor ve o türden yalnız üç
    // tanım var (bkz. `DailyMissionStore.correctAnswersToday`). Hedef hâlâ
    // görevden gelir — varsa oyuncunun o gün gördüğü sayıyla aynı kalsın;
    // yoksa varsayılan hedef kullanılır.
    final answerMission = store.missions
        .where((m) => m.type == MissionType.answerCorrect)
        .firstOrNull;
    setState(() {
      _missions = List.from(store.missions);
      _todayTarget = answerMission?.target ?? _todayTarget;
      _todayAnswered = store.correctAnswersToday.clamp(0, _todayTarget);
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
            total: _firstSession ? 5 : _todayTarget,
            firstSession: _firstSession,
            onStart: _startDailyQuiz,
          ),
          const SizedBox(height: AppSpacing.xs),
          // İlerleme özeti günlük görevin ALTINDA durur: turuncu "Başla"
          // ekranın ilk ve en güçlü eylemi kalmalı. Üstte denendiğinde
          // CTA'yı aşağı itiyordu (2026-08-04 görsel denetimi).
          //
          // Coin burada YOK: başlıkta zaten kalıcı bir coin rozeti ve
          // mağaza girişi var; ikisini birden çizmek aynı bilgiyi iki kez
          // göstermekti.
          ProgressSummary(
            key: const ValueKey('home-progress-summary'),
            level: _level,
            xpInLevel: _xpInLevel,
            xpNeeded: _xpNeeded,
            levelLabel: context.t(K.progressLevelLabel),
          ),
          if (_reviewReadyCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            AppRowCard(
              key: const ValueKey('home-review-row'),
              icon: AppIcons.arrowsRotate,
              // Altın yalnız ödül/ilerleme sayılarına ayrılmış; tekrar
              // satırı öğrenme akışının parçası, o yüzden marka yeşili.
              accent: AppTheme.playGreen,
              title: context.t(K.homeReviewTime),
              subtitle: context.t(K.homeReviewTimeSub, {
                'count': '$_reviewReadyCount',
              }),
              onTap: _openLearning,
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
            // Üç mod artık birbirinin aynı satır değil; her biri kendi
            // rengini ve amblemini taşıyan bir mod kartı (2026-08-03).
            child: ModeCard(
              key: const ValueKey('home-lessons-row'),
              icon: AppIcons.graduationCap,
              // Marka turuncusu DEĞİL: o ton birincil CTA'ya ayrılmış ve
              // hemen üstteki "Başla" düğmesi onu kullanıyor. Mod kartı da
              // aynı turuncuyu alınca ikisi yarışıyor ve CTA'nın "tek
              // eylem rengi" olma özelliği kayboluyordu (2026-08-03 görsel
              // denetimi). Ders yolu bir öğrenme yüzeyi; zümrüt ailesi.
              accent: const Color(0xFF0E7A57),
              title: context.t(K.homeLearningPath),
              subtitle: context.t(K.homeLessonsSub),
              onTap: _openLearning,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ModeCard(
            key: const ValueKey('home-topic-picker'),
            icon: AppIcons.bookOpen,
            // Altın yalnız ödül/ilerleme için ayrılmış; konu seçimi bir
            // öğrenme yüzeyi olduğu için safir ailesinden bir ton alır.
            accent: const Color(0xFF1E4FA6),
            title: context.t(K.homeTopicPicker),
            subtitle: context.t(K.categoriesSubtitle),
            onTap: _openCategories,
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
            child: ModeCard(
              key: const ValueKey('home-duel-row'),
              icon: AppIcons.bolt,
              // Düello rekabet yüzeyi: madder ailesinden enerjik bir ton.
              accent: const Color(0xFFB31E3B),
              title: context.t(K.homeQuickDuel),
              subtitle: context.t(K.homeQuickDuelSub),
              onTap: () => widget.onOpenPlay?.call(),
            ),
          ),
          // Dıştaki koşul BİLEREK yok: `ContinueSection` kendi içinde zaten
          // "ilerleme varsa liste, yoksa keşif daveti" ayrımını yapıyor
          // (bkz. `home_rows.dart` `_buildDiscovery`). Eskiden bölüm
          // yalnız `_categoryProgress.any(ratio > 0)` doğruyken
          // çiziliyordu — ilerleme boşken widget'ın kendi keşif dalı hiç
          // ÇAĞRILMIYORDU, "Başlayalım" daveti asla görünmüyordu
          // (2026-08-14 denetimi).
          const SizedBox(height: AppSpacing.xs),
          ContinueSection(
            isKu: ku,
            entries: _categoryProgress,
            onOpenCategory: _openCategory,
            onBrowseCategories: _openCategories,
          ),
          const SizedBox(height: AppSpacing.md),
          // Ana sayfa günün tek bakışta okunabilen özeti olmalı. Kompakt
          // görünüm iki aktif görevi ve kalan sayısını gösterir; tüm görevler
          // ekranın altına taşınıp öğrenme yollarını gömmez.
          DailyMissionsCard(isKu: ku, missions: _missions, compact: true),

          // ── Abonelik girişi ────────────────────────────────────────────
          //
          // Satın alma ekranının TEK girişi ayarların en altındaydı: profil
          // sekmesi → Ayarlar → aşağı kaydır → Premium. Para kazandıran tek
          // yüzey için üç dokunuşluk, hiçbir yerde ilan edilmeyen bir yol.
          // Coin rozetinin mağazaya taşınmasıyla aynı karar (bkz. başlık
          // rozetleri): kazanan ya da destek olmak isteyen oyuncu nereye
          // gideceğini bulabilmeli.
          //
          // Kart başlıkta değil GÖVDENİN SONUNDA durur ve birincil eylemle
          // yarışmaz: ana ekranın ilk sorusu "şimdi ne yapmalıyım?"dır,
          // cevabı da turuncu "Başla" düğmesidir. Üçüncü bir başlık rozeti
          // ise dar ekranlarda (320pt) rozet satırını taşırıyordu.
          //
          // Zaten abone olana gösterilmez: satın alınmış bir şeyi satmaya
          // devam etmek, ödemiş kullanıcıya reklam gibi görünür.
          Consumer<PremiumService>(
            builder: (context, premium, _) {
              if (premium.isPremium) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: AppRowCard(
                  key: const ValueKey('home-premium-row'),
                  icon: AppIcons.gem,
                  // Altın ödül/ilerleme ailesine ayrılmış; abonelik de o
                  // aileye girer ve paywall'ın kendi vurgusu da altındır.
                  accent: AppTheme.gold,
                  // Ad çevrilmez: App Store Connect'teki abonelik adının
                  // kendisidir (bkz. `AppConfig.subscriptionDisplayName`).
                  title: AppConfig.subscriptionDisplayName,
                  subtitle: context.t(K.paywallSubtitle),
                  onTap: () => Navigator.of(
                    context,
                  ).push(AppRoute.to(PaywallScreen(repository: repo))),
                ),
              );
            },
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
                        semanticLabel: context.t(K.dailyStreakDays, {
                          'days': '$_streak',
                        }),
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
                        // Renk dilden bağımsız tohumdan: ad yer tutucuysa
                        // dile göre değişiyordu (2026-08-10).
                        colorSeed: PlayerIdentity.resolveColorSeed(currentName),
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

  /// Son yedi günün streak durumunu GERÇEK geçmişten türetir.
  ///
  /// `MistakeStore` zaten günlük doğru/yanlış sayısını tutuyor; oynanmış
  /// gün, o günde en az bir cevap bulunan gündür. Uydurma yok: veri yoksa
  /// gün "kaçırıldı" değil, olduğu gibi boş kalır ve bugünden sonrası
  /// `upcoming` olarak işaretlenir.
  Future<List<StreakDayState>> _loadStreakWeek() async {
    final store = await MistakeStore.load();
    final history = store.getLast7DaysHistory();
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final states = <StreakDayState>[];
    for (final entry in history.entries) {
      final played =
          (entry.value['correct'] ?? 0) + (entry.value['wrong'] ?? 0) > 0;
      if (entry.key == todayKey) {
        states.add(played ? StreakDayState.completed : StreakDayState.today);
      } else {
        states.add(played ? StreakDayState.completed : StreakDayState.missed);
      }
    }
    return states;
  }

  /// Freeze'in o andaki durumu — yalnız gerçekten türetilebilen hâller.
  ///
  /// `uncertain`, `offline` ve `unavailable` ana sayfada türetilemez:
  /// dondurma burada tetiklenmiyor, dolayısıyla belirsiz bir işlem yok.
  /// Türetilemeyen durumu uydurmak yerine gösterilmez.
  StreakFreezeState _freezeStateFor(StreakStore store) {
    if (!store.willBreakOnPlay()) return StreakFreezeState.notNeeded;
    if (store.freezeCount > 0) return StreakFreezeState.available;
    return _coinBalance >= _streakFreezeCost
        ? StreakFreezeState.available
        : StreakFreezeState.insufficientCoins;
  }

  static const _streakFreezeCost = 50;

  /// Bir sonraki kilometre taşı. Sabit eşikler; modelde ayrı bir milestone
  /// kaynağı yok, bu yüzden uydurma bir "maksimum" da tanımlanmaz.
  static int? _nextStreakMilestone(int current) {
    for (final milestone in const [3, 7, 14, 30, 60, 100]) {
      if (milestone > current) return milestone;
    }
    return null;
  }

  String _freezeLabel(BuildContext context, StreakFreezeState state) {
    return switch (state) {
      StreakFreezeState.available => context.t(K.streakFreezeAvailable),
      StreakFreezeState.notNeeded => context.t(K.streakFreezeNotNeeded),
      StreakFreezeState.insufficientCoins => context.t(K.streakFreezeNoCoins),
      StreakFreezeState.applying => context.t(K.streakFreezeApplying),
      StreakFreezeState.applied => context.t(K.streakFreezeApplied),
      StreakFreezeState.uncertain => context.t(K.streakFreezeUncertain),
      StreakFreezeState.offline => context.t(K.streakFreezeOffline),
      StreakFreezeState.unavailable => context.t(K.streakFreezeUnavailable),
    };
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
        // Bilgilendirme sayfası değil, seriyi KORUMAK için gereken bilgi:
        // haftalık ritim, sonraki milestone ve freeze durumu tek yüzeyde.
        // Önceki hâli ikon + başlık + paragraf + bilgi kartıydı; oyuncu
        // hangi günleri kaçırdığını göremiyordu (2026-08-04).
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<(List<StreakDayState>, StreakStore)>(
              future: () async {
                final week = await _loadStreakWeek();
                final store = await StreakStore.load();
                return (week, store);
              }(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final (week, store) = snapshot.data!;
                final freezeState = _freezeStateFor(store);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Tr.forKu(K.gunlukSeriStreak, isKu),
                      style: AppTypography.heading2.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreakPanel(
                      current: _streak,
                      days: week,
                      freezeState: freezeState,
                      freezeLabel: _freezeLabel(context, freezeState),
                      dayLabels: context.t(K.streakWeekdays).split(','),
                      dayUnitLabel: context.t(K.streakDayUnit),
                      nextMilestone: _nextStreakMilestone(_streak),
                      freezeCost: store.freezeCount > 0
                          ? null
                          : _streakFreezeCost,
                      freezeActionLabel: context.t(K.streakProtectAction),
                      // Dondurma sonuç ekranında, ödül akışının içinde
                      // uygulanıyor; buradan tetiklemek ikinci bir yol
                      // açar ve idempotency anahtarını bağlamsız bırakır.
                      onFreeze: null,
                    ),
                  ],
                );
              },
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
      final firstSession = _firstSession;
      final questions = await repo.loadDailyQuestions(
        limit: firstSession ? 5 : 10,
      );
      if (!mounted || questions.isEmpty) return;
      if (firstSession) {
        AnalyticsService.instance.logActivationStep('first_quiz_started');
      }
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
      // Buradaki tazeleme bilerek KALDIRILDI.
      //
      // `await push(QuizScreen)`, quiz ekranı sonucu `pushReplacement` ile
      // açtığı anda tamamlanır — yani bu satır, oyuncu daha sonuç
      // ekranındayken ve ödüller yazılmadan önce koşuyordu. Faydası yoktu,
      // zararı vardı: kabuk gerçek dönüşte (`didPopNext`) zaten tazeliyor,
      // dolayısıyla her ders turu ana ekranı iki kez yüklüyordu — biri
      // erken ve yanlış, biri doğru.
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home daily quiz');
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  Future<void> _refreshCoins() async {
    try {
      final coins = await repo.loadCoinBalance();
      if (mounted) {
        setState(() => _coinBalance = coins);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'coin refresh failed');
    }
  }
}
