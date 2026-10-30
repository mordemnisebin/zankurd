import 'dart:math' as math;
import '../widgets/doza_widgets.dart';
import 'package:flutter/material.dart';
import '../widgets/auth_social_buttons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/feature_flags.dart';
import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/zan_mascot.dart';
import '../data/streak_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/sync_manager.dart';
import '../data/xp_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/achievement.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/league_tier.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_verify_card.dart';
import '../providers/reduced_motion_provider.dart';
import '../providers/remote_availability.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/dialog_action_pair.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/skeleton_loader.dart';
import '../models/avatar_identity.dart';
import '../data/badge_service.dart';
import '../widgets/badge_widget.dart';
import '../widgets/reward_progress_view.dart';
import '../data/reward_progress_snapshot.dart';
import '../widgets/player_avatar.dart';
import '../widgets/rolling_count.dart';
import '../widgets/strength_map_section.dart';
import '../widgets/weekly_performance_chart.dart';
import '../widgets/sahne/sahne.dart';
import 'home/home_rows.dart' show TabStatChips;
import 'avatar_editor_screen.dart';
import 'favorite_questions_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'suggest_question_screen.dart';
import 'shop_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../utils/percent_format.dart';
import '../utils/player_identity.dart';
import '../utils/number_format.dart';

import 'profile/profile_week_strip.dart';
import 'profile/profile_matches_section.dart';
import 'my_suggestions_screen.dart';

part 'profile/profile_widgets.dart';

// 2026-07-23 M18: misafir hesap yükseltme dialog'unun üç olası çıkışı —
// email/şifre başarılı, email/şifre başarısız, Google bağlama istendi.
enum _GuestUpgradeAction {
  emailSuccess,
  // E-posta onayı AÇIKKEN GoTrue hesabı kaydetmez, yalnız onaya alır:
  // kullanıcı hâlâ anonimdir ve adres `new_email`de bekler. Bu durum
  // ayrı bir sonuç olarak taşınmazsa "kaydedildi" denip geçiliyordu
  // (2026-08-06 denetimi).
  emailPendingConfirmation,
  emailFailure,
  googleRequested,
  appleRequested,
  existingAccountRequested,
}

bool get _supportsGoogleAccountLinking => true;
bool get _supportsAppleAccountLinking => supportsAppleAuth;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.repository,
    this.refreshSignal,
    this.scrollController,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Profil tabı yeniden gösterildiğinde tetiklenir; veriler tazelenir.
  final Listenable? refreshSignal;
  final ScrollController? scrollController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _loadGeneration = 0;

  /// "Ayrıntılı istatistik" bağlantısıyla açılan ayrıntı paneli.
  bool _statsDetailsOpen = false;

  late final Future<MistakeStore> _mistakeStoreFuture = MistakeStore.load();
  bool _loading = true;

  /// İlk yükleme bitti mi; sonraki yüklemeler iskelet göstermez.
  bool _loadedOnce = false;
  bool _loadFailed = false;
  AvatarIdentity _avatarIdentity = const AvatarIdentity();
  String? _currentName;
  LeaderboardEntry? _stats;

  /// Haftalık sıra: Yarış sekmesindeki "Bu hafta" kartıyla AYNI kaynak
  /// (`getMyLeaderboardRank(weekly)`). Profil karosu eskiden `getPlayerStats`
  /// sırasını (toplam XP, tüm profiller) gösteriyordu; iki ekranda aynı
  /// "sıra" iki farklı sayı oluyordu.
  LeaderboardEntry? _weeklyEntry;

  /// Oyuncunun kendi kodu; sunucu vermezse null kalır ve hiç gösterilmez.
  String? _playerTag;
  List<Achievement> _achievements = const [];
  MasteryStore? _masteryStore;
  int? _coins;
  int _level = 1;
  int _xpInLevel = 0;
  int _xpNeeded = 1000;
  double? _accuracyPercent;
  Set<String> _badgeUnlocked = {};
  Map<String, RewardProgress> _rewardProgress = const {};
  Map<String, DateTime> _rewardUnlockedOn = const {};

  /// Tüm modlarda cevaplanan toplam soru sayısı. "Oyun" karosu daha önce
  /// `roomsPlayed` gösteriyordu; o yalnız çevrimiçi oda sayısıdır, solo quiz
  /// onu artırmaz ve oyuncu quiz bitirdiği hâlde "0" görüyordu
  /// (2026-07-22 canlı UX denetimi, P0-4).
  int _answeredTotal = 0;
  bool _answerStatsAvailable = true;
  bool _answerStatsFailed = false;
  bool _answerStatsLoading = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
    widget.refreshSignal?.addListener(_handleRefreshSignal);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_handleRefreshSignal);
      widget.refreshSignal?.addListener(_handleRefreshSignal);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefreshSignal);
    super.dispose();
  }

  /// Profil tabına dönüldüğünde rozet/istatistik/yanlış verilerini tazeler.
  void _handleRefreshSignal() {
    if (!mounted) return;
    _load();
  }

  /// `store`teki kimlikleri GERÇEKTEN AÇILABİLECEK sorularla kesiştirir.
  ///
  /// `MistakeStore.count`/`readyCount` yalnız kayıtlı kimlik sayısını
  /// verir — hangi kaynaktan geldiğine bakmaz. Çevrimiçi maçlarda yanlış
  /// yapılan sorular sunucu UUID'siyle kaydediliyor
  /// (`get_room_questions` satırın `id`sini döndürür); bu UUID'ler
  /// paketli bankada hiç yoktur ve içerik kalite karantinasıyla
  /// (`2026-08-01_live_question_*_quarantine.sql`) bankadan tamamen
  /// çıkarılmış sorular da aynı şekilde asla çözülemez. Satır bu yüzden
  /// sıfırdan büyük bir sayı gösterip dokunulunca "bekliyor" diyordu —
  /// oysa gerçek neden o sorunun artık hiçbir yerde bulunamamasıydı
  /// (2026-08-14 denetimi; `todays_review_card.dart`taki 2026-08-06
  /// düzeltmesiyle aynı kök neden).
  /// İstatistiği olmayan kullanıcıyı doğrudan hızlı yarışa götürür.
  Future<void> _startQuickRace() async {
    final questions = await widget.repository.loadQuestions(limit: 10);
    if (!mounted) return;
    final raceQuestions = questions.isEmpty
        ? widget.repository.playableQuestions
        : questions;
    Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: widget.repository.createRoom(),
          questions: raceQuestions,
        ),
      ),
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    // İskelet yalnız ilk yüklemede. Alt sayfadan dönüşte de iskelete
    // geçiliyordu; içerik yeniden kurulup kaydırma en üste sıçrıyordu
    // (2026-10-22 simülatör turu). Sonraki yüklemeler içerik yerindeyken
    // sessizce tazeler.
    if (!_loadedOnce) setState(() => _loading = true);
    try {
      final name = await widget.repository.getProfileName();
      final stats = await widget.repository.getPlayerStats();
      LeaderboardEntry? weekly;
      try {
        weekly = await widget.repository.getMyLeaderboardRank(
          LeaderboardPeriod.weekly,
        );
      } catch (_) {
        weekly = null; // sıra yoksa karo çizilmez
      }
      final tag = await widget.repository.getPlayerTag();
      final avatarIdentity = await widget.repository.loadAvatarIdentity();
      final achievementStore = await AchievementStore.load();
      final masteryStore = await MasteryStore.load();
      final xpStore = await XPStore.load();
      // Doğruluk oranı istatistik kartı için (UI-only). Coin bakiyesi artık
      // profil gridinde gösterilmiyor, quiz üst barında görünüyor.
      final mistakeStore = await MistakeStore.load();
      ({int correct, int wrong})? onlineAnswers;
      var answerStatsFailed = false;
      try {
        onlineAnswers = await widget.repository.loadOnlineAnswerStats();
      } catch (_) {
        answerStatsFailed = true;
        // Diğer profil bölümleri erişilebilir kalır; eksik toplam gösterilmez.
      }
      final correct = mistakeStore.totalCorrect + (onlineAnswers?.correct ?? 0);
      final wrong = mistakeStore.totalWrong + (onlineAnswers?.wrong ?? 0);
      final answered = correct + wrong;
      // Eski/silinmiş cevap kayıtlarından sıfır sonucunu çıkaramayız:
      // maç veya ilerleme kanıtı varsa boş toplam da bilinmeyendir.
      final missingAnswerHistory =
          answered == 0 &&
          ((stats?.roomsPlayed ?? 0) > 0 ||
              xpStore.currentLevel > 1 ||
              xpStore.xpInCurrentLevel > 0);
      final badgeService = await BadgeService.load();
      final rewardView = await RewardProgressSnapshot.load(
        achievements: achievementStore,
        badges: badgeService,
      );
      int? coins;
      try {
        coins = await widget.repository.loadCoinBalance();
      } catch (_) {
        coins = null; // bakiye yoksa jeton satırı çizilmez
      }
      // Kimlik kartındaki seri (vay 2B). Okunamazsa 0 — kart yine çizilir.
      var streak = 0;
      try {
        streak = (await StreakStore.load()).effectiveStreak();
      } catch (_) {}
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _currentName = name;
          _coins = coins;
          _streak = streak;
          _stats = stats;
          _weeklyEntry = weekly;
          _playerTag = tag;
          _avatarIdentity = avatarIdentity;
          _achievements = achievementStore.unlockedAchievements;
          _badgeUnlocked = badgeService.unlockedBadges;
          _rewardProgress = rewardView.progress;
          _rewardUnlockedOn = rewardView.unlockedOn;
          _masteryStore = masteryStore;
          _level = xpStore.currentLevel;
          _xpInLevel = xpStore.xpInCurrentLevel;
          _xpNeeded = xpStore.xpNeededForNextLevel;
          _answerStatsFailed = answerStatsFailed;
          _answerStatsAvailable =
              onlineAnswers != null && !missingAnswerHistory;
          _accuracyPercent = onlineAnswers != null && answered > 0
              ? correct / answered * 100
              : null;
          _answeredTotal = answered;
          _loading = false;
          _loadedOnce = true;
          _loadFailed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile load failed');
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// Yalnız yanıt bölümünü yeniler; rekorlar ve kaydırma konumu korunur.
  Future<void> _retryAnswerStats() async {
    if (_answerStatsLoading) return;
    setState(() => _answerStatsLoading = true);
    try {
      final online = await widget.repository.loadOnlineAnswerStats();
      final local = await MistakeStore.load();
      if (!mounted) return;
      final correct = local.totalCorrect + (online?.correct ?? 0);
      final wrong = local.totalWrong + (online?.wrong ?? 0);
      final total = correct + wrong;
      setState(() {
        _answerStatsFailed = false;
        _answerStatsAvailable = online != null && total > 0;
        _answeredTotal = total;
        _accuracyPercent = total > 0 ? correct / total * 100 : null;
      });
    } catch (_) {
      if (mounted) setState(() => _answerStatsFailed = true);
    } finally {
      if (mounted) setState(() => _answerStatsLoading = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(SettingsScreen(repository: widget.repository)));
    if (mounted) _load();
  }

  Future<void> _openAvatarEditor() async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute.to(AvatarEditorScreen(repository: widget.repository)),
    );
    if (changed == true && mounted) _load();
  }

  /// Ad çözümlemesi tek kaynaktan yapılır ([PlayerIdentity]); ekran-yerel
  /// yedekler ana ekranla çelişen ikinci bir kimlik üretiyordu.
  String _displayName(bool ku) =>
      PlayerIdentity.resolveName(_currentName, isKu: ku);

  /// Sıralama ve lig rozeti için ortak kapı.
  ///
  /// İki koşul da gerekli. Yalnız yerel "kaç soru cevapladın" yetmiyordu:
  /// canlı denetimde profil "#85" derken toplam puan 0'dı ve haftalık tablo
  /// bomboştu. Sıralama, herkesin sıfırda eşitlendiği bir listedeki gelişigüzel
  /// bir yer gösteriyordu; oyuncuya "85. sıradasın" demek yanlıştı.
  ///
  /// Yalnız sunucu puanına bakmak da yetmez: sahte depo "benim
  /// istatistiğim" olarak tablonun birincisini döndürür ve hiç oynamamış
  /// oyuncu yine altın rozet görürdü — 2026-07-26'da kapatılan kusurun
  /// aynısı. İki kapı birlikte durmalı (2026-07-27).
  bool get _hasServerScore =>
      _answeredTotal > 0 && (_stats?.totalScore ?? 0) > 0;

  /// Oyuncu en az bir tur oynadı mı (ya da bir şey kazandı mı)?
  ///
  /// 2026-09-29 doğallık (K6): ilk turdan önce seviye kartı ("Seviye 1 ·
  /// 0/1000" + boş çubuk) ve başarı çubuğu ("0/13" + boş çubuk) yeni
  /// gelene iki ayrı boş sayaç gösteriyordu. İkisi de bu kapıyla gizlenir;
  /// ana sayfa aynı nedenle ilk oturumda ilerleme özetini göstermez.
  /// XP ya da açılmış başarı varsa (ör. başka cihazdan) kapı açıktır.
  bool get _hasPlayed =>
      _answeredTotal > 0 ||
      _level > 1 ||
      _xpInLevel > 0 ||
      _achievements.isNotEmpty ||
      _badgeUnlocked.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 720;
    final remoteMatches = context.watch<AuthProvider>().canUseRemoteActions;

    // 2026-09-29 Şahnê A iskeleti: marka satırı → "Profil" → kimlik
    // (avatar + ad + kod) → seviye kartı → bölümler (tek bölüm
    // başlığı + liste grupları). Eski yeşil degrade kahraman kart, süs
    // daireleri, kilim bordürü ve büyük harfli gri bölüm etiketleri kalktı.
    // U4 (2026-10-28 tur 4): hiç oynamamış oyuncuda boş bölümler (0/7 hafta,
    // "Henüz soru çözmedin", "İlk rekorunu kır", boş Başarılar ipucu) dört ayrı
    // boş kart olarak üst üste diziliyordu; tek "Başlangıç" kartında toplanır.
    final fresh =
        _answerStatsAvailable &&
        _stats == null &&
        _answeredTotal == 0 &&
        !_hasPlayed;
    final identity = _ProfileHeroCard(
      ku: ku,
      displayName: _displayName(ku),
      hasOwnName: !PlayerIdentity.isPlaceholderDisplayName(_currentName),
      avatarIdentity: _avatarIdentity,
      showcaseTitle: _avatarIdentity.showcaseTitle,
      playerTag: _playerTag,
      // Lig rozeti ile sıralama karosu aynı kapıyı kullanmalı: rozet
      // sunucudan gelen `roomsPlayed`e, karo yerel `_answeredTotal`a
      // bakınca aynı ekranda "Altın Lig" ile "Sıralama —" yan yana
      // duruyordu (2026-07-26 denetimi).
      rank: _hasServerScore ? _stats?.rank : null,
      onEditAvatar: _openAvatarEditor,
      level: _level,
      xpInLevel: _xpInLevel,
      xpNeeded: _xpNeeded,
      coins: _coins,
      streak: _streak,
      onSetName: _openSettings,
    );

    Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identity,
        const SizedBox(height: SahneSpace.x3),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: _SyncStatusChip(),
        ),
        if (context.watch<AuthProvider>().isGuest) ...[
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(K.t12AccountRecovery),
            key: const ValueKey('profile-guest-recovery'),
            style: SahneType.caption.copyWith(
              color: SahneTokens.of(context).tx2,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('profile-guest-protect'),
              onPressed: _showGuestUpgradeDialog,
              child: Text(context.t(K.t12AccountProtect)),
            ),
          ),
        ],
        const SizedBox(height: SahneSpace.x2),
        if (fresh)
          _ProfileStartCard(onStart: _startQuickRace)
        else ...[
          const ProfileWeekStrip(),
          // Seviye + XP çubuğu + jeton artık kimlik başlığındadır (kurul 5. tur).
          // 2026-10-19 sadeleşme (ikinci tur): "Ayrıntılı istatistik" ayrı bir
          // açılır kart değil, başlığın yanındaki bağlantıdır; ayrıntılar
          // altta, bağlantıya basınca açılır (varsayılan kapalı).
          SahneSectionHeader(
            title: context.t(K.myStats),
            actionLabel: context.t(K.detailedStats),
            onAction: () =>
                setState(() => _statsDetailsOpen = !_statsDetailsOpen),
          ),
          // Sunucu satırı yoksa yerel ilerleme de gizleniyordu: çevrimdışı
          // 2 soru cevaplamış oyuncu kendi cevapladığı soru sayısını
          // göremiyordu (2026-07-27). Kapı sunucu satırına değil,
          // gösterilecek bir şey olup olmadığına bakar; karolar sunucu
          // metriği yokken "—" gösterir.
          if (!_answerStatsAvailable)
            SahneSurfaceCard(
              key: ValueKey(
                _answerStatsFailed
                    ? 'profile-answer-stats-unavailable'
                    : 'profile-answer-stats-empty',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.t15AnswerStatsTitle),
                    style: SahneType.bodyStrong.copyWith(
                      color: SahneTokens.of(context).tx,
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.t(
                        _answerStatsLoading
                            ? K.t15AnswerStatsLoading
                            : _answerStatsFailed
                            ? K.answerStatsUnavailable
                            : K.t15AnswerStatsEmpty,
                      ),
                      key: _answerStatsLoading
                          ? const ValueKey('profile-answer-stats-loading')
                          : null,
                      style: SahneType.body.copyWith(
                        color: SahneTokens.of(context).tx2,
                      ),
                    ),
                  ),
                  if (_answerStatsFailed)
                    SahneButton.text(
                      key: const ValueKey('profile-answer-stats-retry'),
                      label: context.t(K.t15Retry),
                      arrow: false,
                      onPressed: _answerStatsLoading ? null : _retryAnswerStats,
                    ),
                ],
              ),
            )
          else if (_stats == null && _answeredTotal == 0)
            // Boş durum: bağlamsal çizgi ikon + tek cümle + ekranın tek
            // birincil eylemi. İkon semantik ağaca düğüm eklemez.
            //
            // 2026-09-29 doğallık (K3): burada 64'lük maskot/logo plakası
            // duruyordu; boş durumların ortak dili gibi 32'lik üçüncül bir
            // çizgi ikon (istatistik sütunu) oldu. Logo marka satırının işi.
            // 2026-10-19 sadeleşme (ikinci tur): boş durum 190 px'lik büyük
            // karttı ve içinde ikinci bir turuncu düğme vardı; artık tek
            // satırlık küçük şerit: simge + cümle, altında metin eylemi.
            SahneSurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SahneSpace.x4,
                vertical: SahneSpace.x3,
              ),
              child: Builder(
                builder: (context) {
                  final t = SahneTokens.of(context);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ExcludeSemantics(
                          child: Icon(
                            AppIcons.chartColumn,
                            size: 20,
                            color: t.tx3,
                          ),
                        ),
                      ),
                      const SizedBox(width: SahneSpace.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(K.noOnlineHistory),
                              style: SahneType.caption.copyWith(color: t.tx2),
                            ),
                            // Kurul 5. tur 2026-10-20 (Opus, Grok): boş durumun
                            // eylemi metin bağlantısıydı, kart sönük kalıyordu;
                            // artık net birincil düğme.
                            const SizedBox(height: SahneSpace.x2),
                            SahneButton.primary(
                              buttonKey: const ValueKey(
                                'profile-stats-start-cta',
                              ),
                              label: context.t(K.startToday),
                              arrow: true,
                              onPressed: _startQuickRace,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else
            // İlk bakışta 4 metrik — kalanı "Detaylı İstatistik"te.
            _StatGrid(
              tiles: [
                // 2026-09-30 simülatör: 390 XP ve 16 cevaplı soru varken bu iki
                // karo "Hîn tune / Henüz yok" diyordu — yan yana çelişki.
                // Sıra ve toplam puan SUNUCU yarış puanından gelir; yerel
                // olarak bilinen bir toplam yoktur (XP ayrı bir kavram, seviye
                // kartında). Veri yokken karo göstermek yerine gizlenir; yeni
                // bir "ilk yarıştan sonra" cümlesi uydurulmaz. Sıralama sekmesi
                // ve ilk yarış eylemi zaten durur.
                if (_hasServerScore) ...[
                  if ((_weeklyEntry?.rank ?? 0) > 0)
                    _StatTile(
                      label: context.t(K.thisWeek),
                      value: '—',
                      count: _weeklyEntry!.rank,
                      countPrefix: '#',
                      role: SahneRole.gold,
                      icon: AppIcons.chartColumn,
                    ),
                  _StatTile(
                    label: context.t(K.statTotalScore),
                    value: '—',
                    count: _stats!.totalScore,
                    role: SahneRole.gold,
                    icon: AppIcons.star,
                  ),
                ],
                _StatTile(
                  label: context.t(K.statAnswered),
                  value: groupThousands(_answeredTotal),
                  count: _answeredTotal,
                  role: SahneRole.learn,
                  icon: AppIcons.gamepad,
                ),
                _StatTile(
                  label: context.t(K.statAccuracy),
                  value: _accuracyPercent == null
                      ? '—'
                      : context.percent(_accuracyPercent!.round()),
                  // Doğruluk bir durum değil bir ölçüdür: yeşil "iyi", kırmızı
                  // "kötü" demez (renk tek başına anlam taşımaz). Nötr karo.
                  role: SahneRole.social,
                  icon: AppIcons.bullseye,
                ),
              ],
            ),
          const SizedBox(height: SahneSpace.cardGap),

          // Detaylı analiz (grafik, kategori ustalığı, güçlü/zayıf yön) —
          // sadelik için varsayılan kapalı; başlıktaki bağlantı açar.
          if (_statsDetailsOpen)
            SahneSurfaceCard(
              key: const ValueKey('profile-detailed-stats'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SubHeading(context.t(K.weeklyPerformance)),
                  const SizedBox(height: SahneSpace.x3),
                  FutureBuilder<MistakeStore>(
                    future: _mistakeStoreFuture,
                    builder: (context, snapshot) {
                      final t = SahneTokens.of(context);
                      if (snapshot.hasError) {
                        return SizedBox(
                          height: 160,
                          child: Center(
                            child: Text(
                              context.t(K.performanceLoadFail),
                              style: SahneType.caption.copyWith(color: t.tx2),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return SizedBox(
                          height: 160,
                          child: Center(
                            child: CircularProgressIndicator(color: t.tx2),
                          ),
                        );
                      }
                      final history = snapshot.data!.getLast7DaysHistory();
                      return WeeklyPerformanceChart(history: history, isKu: ku);
                    },
                  ),
                  const SizedBox(height: SahneSpace.x6),
                  _PedagogicalAnalyticsSection(isKu: ku),
                  const SizedBox(height: SahneSpace.x6),
                  StrengthMapSection(
                    isKu: ku,
                    refreshSignal: widget.refreshSignal,
                  ),
                  if (_masteryStore != null) ...[
                    const SizedBox(height: SahneSpace.x6),
                    _MasterySection(store: _masteryStore!, isKu: ku),
                  ],
                ],
              ),
            ),
          // 2026-10-24: kişisel rekorlar ve son maçlar. Çevrimdışı/yerel
          // misafirde sunucuya sorulmaz; yerel seri yine görünür.
          ProfileRecordsSection(
            repository: widget.repository,
            refreshSignal: widget.refreshSignal,
            remote: remoteMatches,
            // Yeni oyuncunun boş rekor kartı oyuna götürür; üstteki boş
            // istatistik kartı zaten "Bugün başla" taşıyorsa tekrarlanmaz.
            onStartPlay: _stats == null && _answeredTotal == 0
                ? null
                : _startQuickRace,
          ),
        ],
      ],
    );

    // 2026-07-22 canlı UX denetimi: rozet bölümleri birleştirme
    Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!fresh) ...[
          _UnifiedRewardsSection(
            achievements: _achievements,
            badgeUnlocked: _badgeUnlocked,
            progress: _rewardProgress,
            unlockedOn: _rewardUnlockedOn,
            showProgress: _hasPlayed,
            isKu: ku,
          ),
          // 2026-10-27 (rakip kıyası): başarımlar maç geçmişinin ALTINDA,
          // sayfanın dibine yakındı; Duolingo profilinde istatistiğin hemen
          // ardından gelir. Geçmiş artık rozetlerin altında.
          ProfileMatchHistorySection(
            repository: widget.repository,
            refreshSignal: widget.refreshSignal,
            remote: remoteMatches,
            // Üstteki boş istatistik kartı zaten "Bugün başla" düğmesini
            // taşır; aynı eylem iki kez çizilmez.
            onStartPlay: _stats == null && _answeredTotal == 0
                ? null
                : _startQuickRace,
          ),
        ],
        // Navigasyon kısayolları — iki adlandırılmış liste grubu
        ..._buildMenuSections(ku),
        // 2026-10-28 tur 3 T5: "Davamız" kartı dolu doygun yeşildi (ekranın
        // en ağır bloğu, istatistiğin hemen altında); tonlu karta döndü ve
        // Hesap'ın ardına, sayfanın sonuna taşındı. Hâlâ bir dokunuşla erişilir.
        const SizedBox(height: SahneSpace.cardGap),
        const DozaMeEntryCard(),
      ],
    );

    // 2026-07-22 canlı UX denetimi: profil iskelet yükleme
    if (_loading) return _buildProfileSkeleton();
    if (_loadFailed) {
      return ColoredBox(
        color: SahneTokens.of(context).bg,
        child: SafeArea(
          child: AppErrorState(
            title: context.t(K.profileLoadFail),
            message: context.t(K.checkConnection),
            retryLabel: context.t(K.retry),
            onRetry: _load,
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: SahneTokens.of(context).tx,
      backgroundColor: SahneTokens.of(context).s2,
      onRefresh: () async {
        await _load();
      },
      child: SahneTabPage(
        controller: widget.scrollController,
        title: context.t(K.profileTitle),
        titleEyebrow: context.secondLabel(K.profileTitle),
        stats: [
          TabStatChips(
            repository: widget.repository,
            refreshSignal: widget.refreshSignal,
          ),
        ],
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: leftColumn),
                const SizedBox(width: SahneSpace.x4),
                Expanded(flex: 10, child: rightColumn),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [leftColumn, rightColumn],
            ),
        ],
      ),
    );
  }

  /// Profil yüklenirken iskelet: kimlik satırı, seviye kartı, 2 × 2 karo
  /// ve menü satırları — gerçek düzenin yerleri.
  Widget _buildProfileSkeleton() {
    Widget block(double height) => SkeletonLine(
      width: double.infinity,
      height: height,
      borderRadius: SahneShape.lValue,
    );
    Widget pair() => Row(
      children: [
        Expanded(child: block(88)),
        const SizedBox(width: SahneSpace.x3),
        Expanded(child: block(88)),
      ],
    );
    return ColoredBox(
      color: SahneTokens.of(context).bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(SahneSpace.page),
          children: [
            block(96),
            const SizedBox(height: SahneSpace.cardGap),
            block(88),
            const SizedBox(height: SahneSpace.x6),
            pair(),
            const SizedBox(height: SahneSpace.x3),
            pair(),
            const SizedBox(height: SahneSpace.x6),
            block(64),
            const SizedBox(height: SahneSpace.x2),
            block(64),
            const SizedBox(height: SahneSpace.x2),
            block(64),
          ],
        ),
      ),
    );
  }

  /// "Öğrenme" ve "Hesap" bölümleri: tek bölüm başlığı + liste grubu.
  /// Renk rol taşır: öğrenme satırları Zimrût, mağaza Zêr, ayarlar ve
  /// çıkış nötr. Çıkış kırmızıya boyanmaz — kırmızı bir durum (yanlış)
  /// rengidir; geri alınamazlığı onay diyaloğu söyler.
  List<Widget> _buildMenuSections(bool ku) {
    final auth = context.watch<AuthProvider>();
    return [
      SahneSectionHeader(title: context.t(K.secLearning)),
      SahneListGroup(
        children: [
          SahneListRow.icon(
            // Yıldız: Pratik merkezindeki aynı girişle aynı ikon; yer imi
            // Kelimelerim'indir (2026-10-27).
            icon: AppIcons.star,
            role: SahneRole.learn,
            title: context.t(K.savedQuestions),
            chevron: true,
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(
                  FavoriteQuestionsScreen(repository: widget.repository),
                ),
              );
            },
          ),
          // "Yanlışlarım" buradan kalktı (2026-10-28 kurul K9): Öğren →
          // Tekrar aynı yanlış sorulara götürür; Profil'de yalnız Kaydedilen,
          // Soru öner ve Önerilerim kalır.
          if (auth.canUseRemoteActions)
            SahneListRow.icon(
              icon: AppIcons.circlePlus,
              role: SahneRole.learn,
              title: context.t(K.suggestQuestion),
              subtitle: context.t(K.suggestQuestionSub),
              chevron: true,
              onTap: () {
                Navigator.of(context).push(
                  AppRoute.to(
                    SuggestQuestionScreen(repository: widget.repository),
                  ),
                );
              },
            ),
          // Gönderilen önerilerin durumu (Trivia Crack'te soru fabrikasının
          // yanında durur); eskiden yalnız öneri ekranının içindeydi.
          if (auth.canUseRemoteActions)
            SahneListRow.icon(
              key: const ValueKey('profile-my-suggestions'),
              icon: AppIcons.listCheck,
              role: SahneRole.learn,
              title: context.t(K.mySuggestions),
              chevron: true,
              onTap: () {
                Navigator.of(context).push(
                  AppRoute.to(
                    MySuggestionsScreen(repository: widget.repository),
                  ),
                );
              },
            ),
        ],
      ),
      // Nazik e-posta doğrulaması: yalnız doğrulanmamış e-posta hesabında
      // çizilir; oyun ve sıralama buna bağlı değildir.
      if (!auth.isGuest && auth.canUseRemoteActions)
        if (auth.emailVerificationGateway case final gateway?)
          EmailVerifyCard(gateway: gateway),
      SahneSectionHeader(title: context.t(K.secAccount)),
      SahneListGroup(
        children: [
          // 2026-07-22 canlı UX denetimi: misafir hesap yükseltme
          if (auth.isGuest)
            SahneListRow.icon(
              icon: AppIcons.userPlus,
              role: SahneRole.learn,
              title: context.t(K.saveAccount),
              subtitle: context.t(K.saveAccountSub),
              chevron: true,
              onTap: _showGuestUpgradeDialog,
            ),
          SahneListRow.icon(
            key: const ValueKey('profile-menu-icon-Dukan'),
            icon: AppIcons.store,
            role: SahneRole.gold,
            title: context.t(K.shop),
            chevron: true,
            onTap: () async {
              // Mağazadan satın alınan çerçeve/unvan buradan güncellenene
              // kadar görünmüyordu (2026-08-14 denetimi).
              await Navigator.of(
                context,
              ).push(AppRoute.to(ShopScreen(repository: widget.repository)));
              if (mounted) _load();
            },
          ),
          SahneListRow.icon(
            icon: AppIcons.gear,
            title: context.t(K.settings),
            chevron: true,
            onTap: () async {
              // Ayarlar'da değiştirilen ad geri dönüldüğünde eski
              // hâliyle kalıyordu (2026-08-14 denetimi).
              await Navigator.of(context).push(
                AppRoute.to(SettingsScreen(repository: widget.repository)),
              );
              if (mounted) _load();
            },
          ),
          SahneListRow.icon(
            icon: AppIcons.rightFromBracket,
            title: context.t(K.signOut),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    ];
  }

  // 2026-07-22 canlı UX denetimi: misafir hesap yükseltme dialog'u
  Future<void> _showGuestUpgradeDialog() async {
    // Alan denetleyicilerini diyalogun kendi State'i yönetir (bkz.
    // [_GuestUpgradeDialog]); burada atmak kapanış animasyonunda çöküş
    // riskiydi.
    final result = await showDialog<_GuestUpgradeAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuestUpgradeDialog(
        supportsGoogleLinking: _supportsGoogleAccountLinking,
        supportsAppleLinking: _supportsAppleAccountLinking,
      ),
    );

    if (!mounted) return;
    switch (result) {
      case _GuestUpgradeAction.emailSuccess:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.accountSaved))));
      case _GuestUpgradeAction.emailPendingConfirmation:
        // Hesap HENÜZ kalıcı değil; adres onay bekliyor. Kayıt akışının
        // zaten kullandığı metin burada da doğrudur.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.accountCreated))));
      case _GuestUpgradeAction.emailFailure:
        final message = context.read<AuthProvider>().errorMessage;
        if (message != null) {
          // Sunucu metni Türkçe sabittir; `sign_in`/`sign_up` ekranları
          // gibi burada da anahtar defterinden çevrilir, yoksa Kurmancî
          // kullanıcı Türkçe hata görürdü.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translateAuthError(message))),
          );
        }
      case _GuestUpgradeAction.googleRequested:
        await _linkGoogleAccount();
      case _GuestUpgradeAction.appleRequested:
        await _linkAppleAccount();
      case _GuestUpgradeAction.existingAccountRequested:
        // Mevcut hesaba geçiş misafir oturumunu kapatır. Önce var olan
        // kayıp uyarısı/onayı gösterilir; iptal mevcut ilerlemeyi korur.
        // Onay sonrası AppShell giriş ekranını kendisi açar.
        await _confirmSignOut(context);
      case null:
        break;
    }
  }

  // 2026-07-23 M18: linkIdentity anonim oturumu değiştirmez, sadece
  // tarayıcıyı açar — sonuç auth state listener üzerinden asenkron gelir.
  Future<void> _linkGoogleAccount() async {
    LoadingOverlay.show(context, message: context.t(K.connectingGoogle));
    final auth = context.read<AuthProvider>();
    final success = await auth.linkGoogleAccount();
    if (!mounted) return;
    LoadingOverlay.hide(context);
    if (!success && auth.errorMessage != null) {
      // Sunucu metni Türkçe sabittir; hemen üstteki `emailFailure` dalı
      // gibi burada da anahtar defterinden çevrilmesi gerekir — yoksa
      // Kurmancî kullanıcı Google bağlama hatasını Türkçe görür
      // (2026-08-14 denetimi).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translateAuthError(auth.errorMessage!))),
      );
    }
  }

  /// [_linkGoogleAccount] ile aynı akış ve aynı hata işleme: yükleme perdesi,
  /// sonuç auth dinleyicisinden gelir, hata anahtar defterinden çevrilir.
  Future<void> _linkAppleAccount() async {
    LoadingOverlay.show(context, message: context.t(K.connectingApple));
    final auth = context.read<AuthProvider>();
    final success = await auth.linkAppleAccount();
    if (!mounted) return;
    LoadingOverlay.hide(context);
    if (!success && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translateAuthError(auth.errorMessage!))),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t(K.signOut)),
        // Misafir hesabında çıkış geri dönüşsüzdür: hesap anonim olduğu
        // için XP, coin, rozet ve seri kalıcı olarak kaybolur. Önceki
        // metin bunu hiç söylemiyordu (2026-07-22 canlı UX denetimi).
        content: Text(
          context.read<AuthProvider>().isGuest
              ? context.t(K.signOutGuestWarn)
              : (context.t(K.signOutConfirm)),
        ),
        actions: [
          DialogActionPair(
            cancel: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.t(K.cancel)),
            ),
            confirm: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.t(K.signOut)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await this.context.read<AuthProvider>().signOut();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile_sign_out');
      // AppShell zaten auth durumuna göre giriş ekranına döner.
    }
  }
}

/// Bulut eşitleme durumu: S pahlı küçük rozet, ikon + söz (durum hiçbir
/// zaman yalnız renkle verilmez). Eşitlendi Rast tonu, başarısız Şaş tonu
/// (dokununca yeniden dener), bekleyen Zêr, yalnız cihazda nötr.
class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip();

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final t = SahneTokens.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: SyncManager.syncingNotifier,
      builder: (context, syncing, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncManager.pendingCountNotifier,
          builder: (context, pending, _) {
            return ValueListenableBuilder<int>(
              valueListenable: SyncManager.failedCountNotifier,
              builder: (context, failed, _) {
                final isSynced = !syncing && pending == 0 && failed == 0;
                // `pending == 0` retry'ları tükenip kalıcı olarak
                // düşürülmüş ödülleri de gizleyebiliyordu — o kayıt
                // artık `failed`te durur, "senkronize" burada YALAN
                // söylememeli (2026-08-14 denetimi).
                final hasFailed = !syncing && failed > 0;
                // Sunucuya HİÇ ulaşılamıyorken (çevrimdışı misafir) de
                // bekleyen kayıt olmadığı için çip "Bulutla senkronize"
                // diyordu. Yalan: bulut yok (2026-09-27 simülatör turu).
                final deviceOnly =
                    isSynced && RemoteAvailability.socialLockedWatch(context);
                // 2026-10-29 (X3): misafir (anonim) hesabın ilerlemesi
                // sunucuya yazılsa da hesap cihazla birlikte kaybolur;
                // "İlerleme kayıtlı" gerçek hesabın sözüdür. Misafire
                // "Bu cihazda kayıtlı" denir, nötr tonla.
                final guestSynced =
                    isSynced &&
                    !deviceOnly &&
                    context.select<AuthProvider, bool>((a) => a.isGuest);
                final (bg, fg) = hasFailed
                    ? (t.errTint, t.errTx)
                    : (deviceOnly || guestSynced)
                    ? (t.s2, t.tx2)
                    : isSynced
                    ? (t.okTint, t.okTx)
                    : (t.goldTint, t.goldTx);
                final icon = syncing
                    ? AppIcons.arrowsRotate
                    : (hasFailed
                          ? AppIcons.triangleExclamation
                          : ((deviceOnly || guestSynced)
                                ? AppIcons.mobileScreen
                                : (isSynced
                                      ? AppIcons.circleCheck
                                      : AppIcons.cloud)));
                final label = syncing
                    ? (Tr.forKu(K.senkronizeEdiliyor, isKu))
                    : (hasFailed
                          ? Tr.forKu(K.pSenkronizeEdilemedi, isKu, {
                              'p0': groupThousands(failed),
                            })
                          : (deviceOnly
                                ? Tr.forKu(K.deviceOnlyProgress, isKu)
                                : guestSynced
                                ? Tr.forKu(K.guestSavedOnDevice, isKu)
                                : (isSynced
                                      ? (Tr.forKu(K.bulutlaSenkronize, isKu))
                                      : Tr.forKu(K.pendingOnDeviceP, isKu, {
                                          'p0': groupThousands(pending),
                                        }))));

                final chip = DecoratedBox(
                  decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SahneSpace.x2,
                      vertical: SahneSpace.x1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: fg),
                        const SizedBox(width: SahneSpace.x2),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SahneType.captionStrong.copyWith(color: fg),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (!hasFailed) return chip;
                // Kullanıcı elle yeniden deneyebilsin — otomatik retry
                // burada yok, aksi hâlde kalıcı bir hata (ör. eksik
                // migration) sonsuz döngüye girer.
                return GestureDetector(
                  onTap: () => SyncManager.maybeInstance?.retryFailedItems(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      child: chip,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Hiç oynamamış oyuncunun TEK başlangıç kartı (U4, 2026-10-28 tur 4):
/// küçük rozet + tek cümle + ekranın tek turuncu eylemi. Veri oluşunca bu kart
/// kalkar, bölümler normal görünür.
class _ProfileStartCard extends StatelessWidget {
  const _ProfileStartCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x2),
      child: SahneSurfaceCard(
        key: const ValueKey('profile-start-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Vay 2B (B10): boş durumun karşılama maskotu.
                const ZanMascot(
                  key: ValueKey('profile-start-mascot'),
                  pose: ZanPose.welcome,
                  size: 88,
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Semantics(
                    header: true,
                    // Dar ekranda + büyük yazıda söz harf harf bölünmez.
                    child: SahneUnbrokenText(
                      context.t(K.baslangic),
                      style: SahneType.headline.copyWith(color: t.tx),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.profileStartBody),
              style: SahneType.body.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x3),
            SahneButton.primary(
              buttonKey: const ValueKey('profile-stats-start-cta'),
              label: context.t(K.profileStartCta),
              arrow: true,
              expand: true,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}
