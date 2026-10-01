import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/coin_prices.dart';
import '../data/mistake_store.dart';
import '../data/learning_goal_store.dart';
import '../data/streak_store.dart';
import '../data/xp_award_publisher.dart';
import '../data/xp_store.dart';
import '../widgets/progress_summary.dart';
import '../widgets/streak_panel.dart';
import '../data/question_bank_loader.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../providers/sound_provider.dart';
import '../widgets/sahne/sahne.dart';
import '../utils/app_route.dart';
import '../utils/boot_diagnostics.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../utils/test_environment.dart';
import '../data/daily_mission_store.dart';
import '../data/achievement_store.dart';
import '../models/daily_mission.dart';
import '../models/quiz_question.dart';
import '../models/learning_goal.dart';
import '../services/premium_service.dart';
import '../services/daily_question_selector.dart';
import 'paywall_screen.dart';
import 'quiz_screen.dart';
import 'home/today_task_card.dart';
import 'home/home_rows.dart';
import 'home/home_sections.dart';
import 'home/daily_missions_card.dart';
import 'shop_screen.dart';
import '../data/mastery_store.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../utils/player_identity.dart';
import '../services/analytics_service.dart';
import '../widgets/learning_goal_chooser.dart';

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
    this.onOpenCategory,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
  final ScrollController? scrollController;

  /// Ana Sayfa sekmesi yeniden seçildiğinde tetiklenir; coin bakiyesi ve
  /// görevler tazelenir. Bu, ana ekranın KENDİ push'larından (Öğren)
  /// bağımsız bir ikinci tazeleme yoludur: örn. Yarış sekmesinde oynanan
  /// bir maçtan sonra Öğren'e dönmek de burayı tetikler (bkz.
  /// [onOpenLearning] — o yalnız KENDİ push'ının dönüşünü kapsar).
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

  /// Konu ızgarasında dokunulan kategoriyi doğrudan açar.
  ///
  /// Verilmezse dokunuş bir şey yapmaz. 2026-09-27'ye kadar genel kategori
  /// listesine (`CategoriesTab`) düşen bir geri çağırma daha vardı; ızgara
  /// her kategoriyi doğrudan açtığı için o liste kaldırıldı.
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

  /// Konu ızgarasının verisi: her kategorinin ustalık ilerlemesi ve
  /// oynanabilir soru sayısı.
  Map<String, CategoryProgress> _topicProgress = const {};
  Map<String, int> _topicCounts = const {};
  LearningGoal? _learningGoal;
  bool _learningGoalLoaded = false;
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
    _refreshTopicCounts();
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

  /// Belirli bir kategoriyi açar ve dönüşte tazeler.
  Future<void> _openCategory(String category) async {
    await widget.onOpenCategory?.call(category);
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

  Future<void> _claimMissionReward(DailyMission mission) async {
    SoundProvider? soundProvider;
    try {
      soundProvider = context.read<SoundProvider?>();
    } catch (_) {}

    final missionStore = await DailyMissionStore.load();
    final claimed = await missionStore.claimReward(mission);
    if (!claimed) return;

    soundProvider?.playWin();

    try {
      final xpStore = await XPStore.load();
      await xpStore.addXP(mission.xpReward);
      await _refreshXpLevel();
      unawaited(
        XpAwardPublisher.publish(
          repository: repo,
          delta: mission.xpReward,
        ).then((_) async {
          if (mounted) await _refreshXpLevel();
        }),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_claim_mission_xp');
    }

    try {
      final coins = await repo.claimMissionReward(
        missionKey: mission.missionKey,
        fallbackReward: mission.coinReward,
      );
      if (coins > 0) {
        final newBalance = await repo.loadCoinBalance();
        if (mounted) setState(() => _coinBalance = newBalance);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_claim_mission_coins');
    }

    if (mounted) {
      setState(() {
        _missions = List.from(missionStore.missions);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(K.missionXpClaimed, {'xp': '${mission.xpReward}'}),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Konu ızgarasının ilerlemesini (ustalık) ve öğrenme hedefini okur.
  ///
  /// Izgara bütün konuları sabit sırada gösterir; ilerleme her karonun
  /// içinde durur. Eskiden en çok ilerlenen üç konu ayrı bir "Kaldığın yer"
  /// listesine, önerilen konu da ayrı bir seviye yoluna çıkarılıyordu —
  /// aynı konu ana ekranda iki ayrı yerde görünebiliyordu.
  Future<void> _refreshProgress() async {
    try {
      final mastery = await MasteryStore.load();
      final learningGoalStore = await LearningGoalStore.load();
      final progress = {
        for (final category in repo.categories)
          category: CategoryProgress(
            category: category,
            correct: mastery.correctCount(category),
            threshold: mastery.nextThreshold(category),
          ),
      };
      if (mounted) {
        setState(() {
          _topicProgress = progress;
          _learningGoal = learningGoalStore.goal;
          _learningGoalLoaded = true;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home mastery load failed');
    }
  }

  /// Konu karolarındaki soru sayıları. Süs bilgisidir: gelmezse karo
  /// yalnız adıyla kalır, ekran beklemez.
  Future<void> _refreshTopicCounts() async {
    try {
      final counts = await repo.loadCategoryQuestionCounts();
      if (mounted && counts.isNotEmpty) setState(() => _topicCounts = counts);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home topic counts failed');
    }
  }

  Future<void> _selectLearningGoal(LearningGoal goal) async {
    final store = await LearningGoalStore.load();
    final saved = await store.save(goal);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.saveFailed))));
      return;
    }
    setState(() => _learningGoal = goal);
    await _refreshProgress();
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
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildBody(context, ku, constraints.maxWidth > 720),
    );
  }

  /// Ana ekranın gövdesi (2026-09-27 sade ilk deneyim; 2026-09-29 Şahnê).
  ///
  /// Ekran üç soruyu sırayla yanıtlar:
  /// 1. "Şimdi ne yapayım?" — günün dersi, tek turuncu düğme.
  /// 2. "Neyi öğrenebilirim?" — bütün konular, tek bakışta.
  /// 3. "Başka ne var?" — öğrenme alanı ve yarış kapıları, günlük görevler.
  ///
  /// Şahnê A iskeleti ([SahneTabPage]): marka satırı (logo + ZanKurd |
  /// seri, jeton, dil) → 28'lik selamlama → alt başlık → içerik. Eski
  /// başlıkta avatar madalyonu, renkli haplar ve ayrı bir satırda dil
  /// düğmesi vardı; avatar Profil sekmesinin işidir, haplar stat çipi oldu.
  Widget _buildBody(BuildContext context, bool ku, bool isWide) {
    final loader = QuestionBankLoader.instance;
    if (loader.failedAssets.isNotEmpty && loader.allQuestions.isEmpty) {
      return AppErrorState(
        title: context.t(K.bankEmptyTitle),
        message: context.t(K.bankEmptyBody),
        retryLabel: context.t(K.retry),
        onRetry: () {
          unawaited(
            loader.load().then((_) {
              if (mounted) setState(() {});
            }),
          );
        },
      );
    }
    final t = SahneTokens.of(context);

    final primary = _buildAnimatedCard(
      _heroFadeAnimation(0),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loader.failedAssets.isNotEmpty ||
              BootDiagnostics.instance.hasFailures) ...[
            Text(
              loader.failedAssets.isNotEmpty
                  ? context.t(K.bankPartialWarning)
                  : context.t(K.bootDegradedBody),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x2),
          ],
          TodayTaskCard(
            isKu: ku,
            loading: _roomActionLoading,
            done: _todayAnswered,
            total: _firstSession ? 5 : _todayTarget,
            firstSession: _firstSession,
            onStart: _startDailyQuiz,
          ),
          // İlk oturumda seviye çubuğu ("Seviye 1 · 0/1000") yeni gelen için
          // anlamsız bir sayıdır; yerine bir şey konmaz. 2026-09-30 doğallık:
          // buraya konan "3 adımda ZanKurd" kartı hemen üstteki Günün dersini
          // kelimesi kelimesine tekrarlıyordu, gerisini de sekme çubuğu zaten
          // gösteriyor. İlk turdan sonra ilerleme özeti geri gelir.
          //
          // İlerleme özeti günlük görevin ALTINDA durur: turuncu "Başla"
          // ekranın ilk ve en güçlü eylemi kalmalı. Coin burada YOK:
          // marka satırında zaten kalıcı bir jeton çipi ve mağaza girişi var.
          if (!_firstSession) ...[
            const SizedBox(height: SahneSpace.cardGap),
            SahneSurfaceCard(
              child: ProgressSummary(
                key: const ValueKey('home-progress-summary'),
                level: _level,
                xpInLevel: _xpInLevel,
                xpNeeded: _xpNeeded,
                levelLabel: context.t(K.progressLevelLabel),
              ),
            ),
          ],
          if (_reviewReadyCount > 0) ...[
            const SizedBox(height: SahneSpace.cardGap),
            // Altın yalnız ödül/ilerleme sayılarına ayrılmış; tekrar
            // satırı öğrenme akışının parçası, o yüzden Zimrût.
            HomeSupportRow(
              key: const ValueKey('home-review-row'),
              icon: AppIcons.arrowsRotate,
              role: SahneRole.learn,
              title: context.t(K.homeReviewTime),
              subtitle: context.t(K.homeReviewTimeSub, {
                'count': '$_reviewReadyCount',
              }),
              onTap: _openLearning,
            ),
          ],
          if (!_firstSession &&
              _learningGoalLoaded &&
              _learningGoal == null) ...[
            const SizedBox(height: SahneSpace.cardGap),
            LearningGoalChooser(
              key: const ValueKey('home-learning-goal-chooser'),
              isKu: ku,
              selected: null,
              onSelected: _selectLearningGoal,
            ),
          ],
          SahneSectionHeader(title: context.t(K.homeTopicsTitle)),
          HomeTopicGrid(
            isKu: ku,
            categories: repo.categories,
            progress: _topicProgress,
            questionCounts: _topicCounts,
            onOpen: _openCategory,
          ),
          const SizedBox(height: SahneSpace.x6),
          // Öğrenme alanı ve yarış: tek liste grubunda iki satır. Yarış
          // kapısı ilk oturumda da görünür: uygulamanın ikinci yüzü budur
          // ve yeni gelen onu ancak burada görürse arar.
          HomeDoors(
            learn: HomeDoorTile(
              key: const ValueKey('home-door-learn'),
              icon: AppIcons.graduationCap,
              role: SahneRole.learn,
              title: context.t(K.learnKurmanci),
              subtitle: context.t(K.homeDoorLearnSub),
              onTap: widget.onOpenLearning == null ? null : _openLearning,
            ),
            play: HomeDoorTile(
              key: const ValueKey('home-door-play'),
              icon: AppIcons.gamepad,
              role: SahneRole.race,
              title: context.t(K.homeDoorPlayTitle),
              subtitle: context.t(K.homeDoorPlaySub),
              onTap: widget.onOpenPlay,
            ),
          ),
        ],
      ),
    );

    final secondary = _buildAnimatedCard(
      _heroFadeAnimation(1),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ana sayfa günün tek bakışta okunabilen özeti olmalı. Kompakt
          // görünüm iki aktif görevi ve kalan sayısını gösterir; tüm görevler
          // ekranın altına taşınıp konuları gömmez.
          DailyMissionsCard(
            isKu: ku,
            missions: _missions,
            compact: true,
            onClaimReward: _claimMissionReward,
          ),

          // ── Abonelik girişi ────────────────────────────────────────────
          //
          // Satın alma ekranının TEK girişi ayarların en altındaydı: profil
          // sekmesi → Ayarlar → aşağı kaydır → Premium. Para kazandıran tek
          // yüzey için üç dokunuşluk, hiçbir yerde ilan edilmeyen bir yol.
          //
          // Satır GÖVDENİN SONUNDA durur ve birincil eylemle yarışmaz: ana
          // ekranın ilk sorusu "şimdi ne yapmalıyım?"dır, cevabı da turuncu
          // "Başla" düğmesidir. Renk Zêr (ödül) rolünün ikon karosunda kalır.
          //
          // Zaten abone olana gösterilmez: satın alınmış bir şeyi satmaya
          // devam etmek, ödemiş kullanıcıya reklam gibi görünür.
          // Yapılandırma yoksa da gizlenir: ürünsüz paywall ölü sokaktır
          // (2026-09-05 canlı turu).
          Consumer<PremiumService>(
            builder: (context, premium, _) {
              if (premium.isPremium || !AppConfig.hasRevenuecatConfig) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: SahneSpace.cardGap),
                child: HomeSupportRow(
                  key: const ValueKey('home-premium-row'),
                  surfaceKey: const ValueKey('home-premium-flat-surface'),
                  icon: AppIcons.gem,
                  role: SahneRole.gold,
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

    final Widget content;
    if (_firstSession) {
      content = primary;
    } else if (isWide) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: primary),
          const SizedBox(width: SahneSpace.x4),
          Expanded(child: secondary),
        ],
      );
    } else {
      content = Column(children: [primary, secondary]);
    }

    return SahneTabPage(
      controller: widget.scrollController,
      title: _greeting(context, ku),
      stats: [_buildHeaderControls(context, ku)],
      children: [content],
    );
  }

  /// Selam: adı olan oyuncuya günün saatine göre "İyi akşamlar, Zelal!",
  /// adı olmayana yalnız "Hoş geldin!". Ad yoksa "Oyuncu" demek, oyuncuya
  /// kendi adını bilmeyen bir sistem gibi görünüyordu.
  String _greeting(BuildContext context, bool ku) {
    final currentName = _displayName ?? widget.displayName;
    if (PlayerIdentity.isPlaceholderDisplayName(currentName)) {
      return context.t(K.homeGreetingAnon);
    }
    final hour = DateTime.now().hour;
    final String greeting;
    if (isFlutterTestEnvironment) {
      // Testte saat sabit değil; selam sabit kalsın.
      greeting = context.t(K.homeGreetDay);
    } else if (hour >= 5 && hour < 12) {
      greeting = context.t(K.homeGreetMorning);
    } else if (hour >= 12 && hour < 17) {
      greeting = context.t(K.homeGreetDay);
    } else if (hour >= 17 && hour < 22) {
      greeting = context.t(K.homeGreetEvening);
    } else {
      greeting = context.t(K.homeGreetNight);
    }
    // Ad çözümlemesi profil ekranıyla aynı kaynaktan gelir; aksi halde
    // "ZanKurd" (ana ekran) ile "Lîstikvanê ZanKurd" (profil) gibi iki
    // ayrı kimlik oluşuyordu.
    final shortName = PlayerIdentity.resolveShortName(currentName, isKu: ku);
    return context.t(K.homeGreeting, {'greeting': greeting, 'name': shortName});
  }

  /// Marka satırının sağı: seri, jeton (stat çipleri) ve dil düğmesi.
  ///
  /// Jeton çipi mağazaya götürür: mağazaya tek giriş profil ekranının
  /// içindeydi, coin kazanan oyuncu onu nerede harcayacağını bulamıyordu
  /// (2026-07-27 denetimi).
  ///
  /// 2026-09-29 doğallık (K6): sayı sıfırken çip çizilmez. İlk açılışta
  /// üst çubukta "0 gün" ve "0" duruyordu; sıfır sayaç bilgi değil, boş bir
  /// kalıptır ve yeni gelene "henüz hiçbir şeyin yok" der. Seri ilk günde,
  /// jeton ilk ödülde belirir; mağaza profilden her zaman açılır.
  Widget _buildHeaderControls(BuildContext context, bool ku) {
    return Wrap(
      key: const ValueKey('home-profile-header'),
      spacing: SahneSpace.x2,
      runSpacing: SahneSpace.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Dokunulabilir stat çipleri: görsel 36, dokunma kutusu 48 (bileşen
        // verir).
        if (_streak > 0)
          SahneStatChip(
            leading: const SahneGlyph(SahneGlyphKind.flame),
            label: '$_streak ${context.t(K.streakDayUnit)}',
            semanticLabel: context.t(K.dailyStreakDays, {'days': '$_streak'}),
            onTap: () => _showStreakFreezeBottomSheet(context),
          ),
        if (_coinBalance > 0)
          SahneStatChip(
            leading: const SahneGlyph(SahneGlyphKind.coin),
            label: '$_coinBalance',
            semanticLabel:
                '${context.t(K.shop)}. $_coinBalance ${context.t(K.coinWord)}',
            onTap: () async {
              await Navigator.of(
                context,
              ).push(AppRoute.to(ShopScreen(repository: repo)));
              if (mounted) await _refreshCoins();
            },
          ),
        _buildLanguageToggle(context),
      ],
    );
  }

  /// Dil düğmesi: iki dilli oyuncunun sık kullandığı tek araç.
  ///
  /// Şahnê stat çipi (Kulis zemini, M pah, 36 görsel, 48 dokunma kutusu)
  /// ve solunda dil ikonu: yalnız metin "TR" yazarken düğmeye benzemiyordu,
  /// yanındaki seri/jeton çiplerinin yanında kaybolup gidiyordu
  /// (2026-10-01 tasarım denetimi). Çip DURUM taşımaz — dokununca dil
  /// değişir; ekran okuyucu "Dil, TR" der. Tema düğmesi 2026-09-27'de
  /// başlıktan kalktı: küçük boyda ayar çarkına benziyordu; tema Ayarlar
  /// ekranında.
  Widget _buildLanguageToggle(BuildContext context) {
    final tooltip = context.t(K.language);
    final code = context.t(K.languageCode);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: SahneStatChip(
        key: const ValueKey('home-language-toggle'),
        leading: Icon(
          AppIcons.language,
          size: 18,
          color: SahneTokens.of(context).tx2,
        ),
        label: code,
        semanticLabel: '$tooltip, $code',
        onTap: context.langProvider.toggle,
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

  // Sunucu RPC'siyle eşitliği bekçili tek kaynak; üç ayrı kopya vardı.
  static const _streakFreezeCost = CoinPrices.streakFreeze;

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
    // Biçim temadan gelir (Perde, üstte L pah).
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        // Bilgilendirme sayfası değil, seriyi KORUMAK için gereken bilgi:
        // haftalık ritim, sonraki milestone ve freeze durumu tek yüzeyde.
        // Önceki hâli ikon + başlık + paragraf + bilgi kartıydı; oyuncu
        // hangi günleri kaçırdığını göremiyordu (2026-08-04).
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SahneSpace.x6),
            child: FutureBuilder<(List<StreakDayState>, StreakStore)>(
              future: () async {
                final week = await _loadStreakWeek();
                final store = await StreakStore.load();
                return (week, store);
              }(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: SahneSpace.x8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final (week, store) = snapshot.data!;
                final freezeState = _freezeStateFor(store);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        Tr.forKu(K.gunlukSeriStreak, isKu),
                        style: SahneType.headline.copyWith(
                          color: SahneTokens.of(context).tx,
                        ),
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x4),
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

  Widget _buildAnimatedCard(Animation<double> animation, Widget child) {
    if (ReducedMotionProvider.isReducedIn(context)) return child;
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

  /// "Dersê rojane" kartı: hedefe göre önceliklendirilmiş günlük solo quiz.
  /// (Kart 10 soru vaat eder; ders ağacına değil gerçek quize gider.)
  Future<void> _startDailyQuiz() async {
    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final firstSession = _firstSession;
      // Ana ekran ilk çizildiğinde ilerleme ve hedef yüklemesi hâlâ sürüyor
      // olabilir. Kullanıcı CTA'ya hemen dokunursa kalıcı hedefi yine de
      // okuyup bu turun seçiminde kullan.
      final goal = _learningGoalLoaded
          ? _learningGoal
          : (await LearningGoalStore.load()).goal;
      final questionLimit = firstSession ? 5 : 10;
      // Hedef seçilmişse, öncelikli kategorilerden seçim yapabilmek için
      // günlük depodan daha geniş bir aday havuzu isteriz. Quiz yine 5/10
      // soruda kalır; havuz küçükse saf seçici kalan sorularla doldurur.
      final candidateLimit = goal == null ? questionLimit : questionLimit * 3;
      final candidates = await repo.loadDailyQuestions(limit: candidateLimit);
      final questions = selectDailyQuestionsForGoal(
        candidates: candidates,
        goal: goal,
        limit: questionLimit,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.noQuestionsFound))));
        return;
      }
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
