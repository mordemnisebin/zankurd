import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../theme/brand_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/feature_flags.dart';
import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/sync_manager.dart';
import '../data/xp_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/achievement.dart';
import '../models/leaderboard_entry.dart';
import '../models/league_tier.dart';
import '../providers/auth_provider.dart';
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
import '../widgets/player_avatar.dart';
import '../widgets/rolling_count.dart';
import '../widgets/strength_map_section.dart';
import '../widgets/weekly_performance_chart.dart';
import '../widgets/progress_summary.dart';
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
}

bool get _supportsGoogleAccountLinking =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS);

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
  late final Future<MistakeStore> _mistakeStoreFuture = MistakeStore.load();
  bool _loading = true;
  bool _loadFailed = false;
  bool _practiceLoading = false;
  AvatarIdentity _avatarIdentity = const AvatarIdentity();
  int _mistakeCount = 0;
  int _readyMistakeCount = 0;
  String? _currentName;
  LeaderboardEntry? _stats;

  /// Oyuncunun kendi kodu; sunucu vermezse null kalır ve hiç gösterilmez.
  String? _playerTag;
  List<Achievement> _achievements = const [];
  MasteryStore? _masteryStore;
  int _level = 1;
  int _xpInLevel = 0;
  int _xpNeeded = 1000;
  double? _accuracyPercent;
  Set<String> _badgeUnlocked = {};

  /// Tüm modlarda cevaplanan toplam soru sayısı. "Oyun" karosu daha önce
  /// `roomsPlayed` gösteriyordu; o yalnız çevrimiçi oda sayısıdır, solo quiz
  /// onu artırmaz ve oyuncu quiz bitirdiği hâlde "0" görüyordu
  /// (2026-07-22 canlı UX denetimi, P0-4).
  int _answeredTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshMistakes();
    widget.refreshSignal?.addListener(_handleRefreshSignal);
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
    _refreshMistakes();
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
  Set<String> _launchableMistakeIds(Set<String> ids) {
    final launchableIds = widget.repository.playableQuestions
        .map((question) => question.id)
        .toSet();
    return ids.where(launchableIds.contains).toSet();
  }

  Future<void> _refreshMistakes() async {
    final store = await MistakeStore.load();
    if (mounted) {
      setState(() {
        _mistakeCount = _launchableMistakeIds(store.ids).length;
        _readyMistakeCount = _launchableMistakeIds(store.readyIds).length;
      });
    }
  }

  Future<void> _startMistakePractice() async {
    final store = await MistakeStore.load();
    if (!mounted) return;
    final mistakeIds = _launchableMistakeIds(store.readyIds);
    final questions = widget.repository.playableQuestions
        .where((question) => mistakeIds.contains(question.id))
        .toList();
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _launchableMistakeIds(store.ids).isNotEmpty
                ? (context.t(K.allMistakesWaiting))
                : (context.t(K.noMistakesPlayFirst)),
          ),
        ),
      );
      return;
    }
    setState(() => _practiceLoading = true);
    final practiceRoom = widget.repository.createRoom().copyWith(
      name: context.t(K.myMistakes),
      questionCount: questions.length,
    );
    await Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: practiceRoom,
          questions: questions,
          practice: true,
          enableTimer: false,
          experience: QuizExperience.learning,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _practiceLoading = false);
    _refreshMistakes();
  }

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
    setState(() => _loading = true);
    try {
      final name = await widget.repository.getProfileName();
      final stats = await widget.repository.getPlayerStats();
      final tag = await widget.repository.getPlayerTag();
      final avatarIdentity = await widget.repository.loadAvatarIdentity();
      final achievementStore = await AchievementStore.load();
      final masteryStore = await MasteryStore.load();
      final xpStore = await XPStore.load();
      // Doğruluk oranı istatistik kartı için (UI-only). Coin bakiyesi artık
      // profil gridinde gösterilmiyor, quiz üst barında görünüyor.
      final mistakeStore = await MistakeStore.load();
      final badgeService = await BadgeService.load();
      if (mounted) {
        setState(() {
          _currentName = name;
          _stats = stats;
          _playerTag = tag;
          _avatarIdentity = avatarIdentity;
          _achievements = achievementStore.unlockedAchievements;
          _badgeUnlocked = badgeService.unlockedBadges;
          _masteryStore = masteryStore;
          _level = xpStore.currentLevel;
          _xpInLevel = xpStore.xpInCurrentLevel;
          _xpNeeded = xpStore.xpNeededForNextLevel;
          _accuracyPercent = mistakeStore.accuracyPercent;
          _answeredTotal = mistakeStore.totalCorrect + mistakeStore.totalWrong;
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile load failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
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

    // 2026-09-29 Şahnê A iskeleti: marka satırı → "Profil" → kimlik
    // (avatar + ad + kod) → seviye kartı → bölümler (tek bölüm
    // başlığı + liste grupları). Eski yeşil degrade kahraman kart, süs
    // daireleri, kilim bordürü ve büyük harfli gri bölüm etiketleri kalktı.
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
        // Seviye kartı: seviye karosu + XP çipi + Zêr ilerleme çubuğu.
        // İlk turdan önce yok ([_hasPlayed]).
        if (_hasPlayed) ...[
          const SizedBox(height: SahneSpace.cardGap),
          SahneSurfaceCard(
            key: const ValueKey('profile-level-card'),
            child: ProgressSummary(
              level: _level,
              xpInLevel: _xpInLevel,
              xpNeeded: _xpNeeded,
              levelLabel: context.t(K.progressLevelLabel),
            ),
          ),
        ],
        SahneSectionHeader(title: context.t(K.myStats)),
        // Sunucu satırı yoksa yerel ilerleme de gizleniyordu: çevrimdışı
        // 2 soru cevaplamış oyuncu kendi cevapladığı soru sayısını
        // göremiyordu (2026-07-27). Kapı sunucu satırına değil,
        // gösterilecek bir şey olup olmadığına bakar; karolar sunucu
        // metriği yokken "—" gösterir.
        if (_stats == null && _answeredTotal == 0)
          // Boş durum: bağlamsal çizgi ikon + tek cümle + ekranın tek
          // birincil eylemi. İkon semantik ağaca düğüm eklemez.
          //
          // 2026-09-29 doğallık (K3): burada 64'lük maskot/logo plakası
          // duruyordu; boş durumların ortak dili gibi 32'lik üçüncül bir
          // çizgi ikon (istatistik sütunu) oldu. Logo marka satırının işi.
          SahneSurfaceCard(
            child: Builder(
              builder: (context) {
                final t = SahneTokens.of(context);
                final body = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(K.noOnlineHistory),
                      style: SahneType.body.copyWith(color: t.tx2),
                    ),
                    const SizedBox(height: SahneSpace.x3),
                    SahneButton.primary(
                      key: const ValueKey('profile-stats-start-cta'),
                      label: context.t(K.startToday),
                      icon: AppIcons.bolt,
                      arrow: false,
                      onPressed: _startQuickRace,
                    ),
                  ],
                );
                final plate = ExcludeSemantics(
                  child: Icon(AppIcons.chartColumn, size: 32, color: t.tx3),
                );
                // Büyük yazıda metin dar sütunda harf harf bölünmesin:
                // plaka üste, metin ve düğme tam genişliğe.
                if (MediaQuery.textScalerOf(context).scale(16) >= 24) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      plate,
                      const SizedBox(height: SahneSpace.x3),
                      body,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    plate,
                    const SizedBox(width: SahneSpace.x4),
                    Expanded(child: body),
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
                _StatTile(
                  label: context.t(K.statRank),
                  value: '—',
                  count: _stats!.rank,
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
                value: '$_answeredTotal',
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
                role: SahneRole.neutral,
                icon: AppIcons.bullseye,
              ),
            ],
          ),
        const SizedBox(height: SahneSpace.cardGap),

        // Detaylı analiz (grafik, kategori ustalığı, güçlü/zayıf yön) —
        // sadelik için varsayılan kapalı.
        SahneSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x4),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: SahneSpace.x4),
                iconColor: SahneTokens.of(context).tx2,
                collapsedIconColor: SahneTokens.of(context).tx2,
                title: Text(
                  context.t(K.detailedStats),
                  style: SahneType.bodyStrong.copyWith(
                    color: SahneTokens.of(context).tx,
                  ),
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
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
          ),
        ),
      ],
    );

    // 2026-07-22 canlı UX denetimi: rozet bölümleri birleştirme
    Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UnifiedRewardsSection(
          achievements: _achievements,
          badgeUnlocked: _badgeUnlocked,
          showProgress: _hasPlayed,
          isKu: ku,
        ),
        // Navigasyon kısayolları — iki adlandırılmış liste grubu
        ..._buildMenuSections(ku),
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
        await Future.wait([_load(), _refreshMistakes()]);
      },
      child: SahneTabPage(
        controller: widget.scrollController,
        title: context.t(K.profileTitle),
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
            icon: AppIcons.bookmark,
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
          SahneListRow.icon(
            icon: AppIcons.graduationCap,
            role: SahneRole.learn,
            title: context.t(K.myMistakes),
            subtitle: _mistakeCount == 0
                ? (context.t(K.noMistakes))
                : (context.t(K.mistakeCounts, {
                    'ready': '$_readyMistakeCount',
                    'total': '$_mistakeCount',
                  })),
            trailing: _practiceLoading
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SahneTokens.of(context).tx2,
                    ),
                  )
                : null,
            chevron: !_practiceLoading,
            onTap: _practiceLoading ? null : _startMistakePractice,
          ),
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
        ],
      ),
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
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final result = await showDialog<_GuestUpgradeAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            context.t(K.saveAccount),
            style: SahneType.headline.copyWith(color: SahneTokens.of(ctx).tx),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t(K.saveAccountBody),
                  style: SahneType.caption.copyWith(
                    color: SahneTokens.of(ctx).tx2,
                  ),
                ),
                const SizedBox(height: SahneSpace.x4),
                SahneField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  label: context.t(K.email),
                  validator: (v) {
                    if (v == null || v.isEmpty || !v.contains('@')) {
                      return context.t(K.emailInvalid);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SahneField(
                  controller: passwordController,
                  obscureText: true,
                  label: context.t(K.password),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return context.t(K.passwordTooShort);
                    }
                    return null;
                  },
                ),
                if (_supportsGoogleAccountLinking) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: SahneTokens.of(ctx).line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          context.t(K.orSeparator),
                          style: SahneType.caption.copyWith(
                            color: SahneTokens.of(ctx).tx2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: SahneTokens.of(ctx).line)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(
                              dialogContext,
                              _GuestUpgradeAction.googleRequested,
                            ),
                      icon: const BrandIcon(
                        BrandIcons.google,
                        size: 18,
                        color: Color(0xFF4285F4),
                      ),
                      label: Text(context.t(K.linkGoogle)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            DialogActionPair(
              cancel: OutlinedButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext, null),
                child: Text(context.t(K.cancel)),
              ),
              confirm: FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() => submitting = true);
                        final auth = context.read<AuthProvider>();
                        final success = await auth.upgradeGuestAccount(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(
                          dialogContext,
                          !success
                              ? _GuestUpgradeAction.emailFailure
                              : auth.needsEmailConfirmation
                              ? _GuestUpgradeAction.emailPendingConfirmation
                              : _GuestUpgradeAction.emailSuccess,
                        );
                      },
                child: submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SahneTokens.of(ctx).tx3,
                        ),
                      )
                    : Text(context.t(K.save)),
              ),
            ),
          ],
        ),
      ),
    );

    // Controller'ları bir sonraki frame'den sonra imha et; dialog widget
    // ağacı henüz deaktive edilmemiş olabilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      emailController.dispose();
      passwordController.dispose();
    });

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
                final (bg, fg) = hasFailed
                    ? (t.errTint, t.errTx)
                    : deviceOnly
                    ? (t.s2, t.tx2)
                    : isSynced
                    ? (t.okTint, t.okTx)
                    : (t.goldTint, t.goldTx);
                final icon = syncing
                    ? AppIcons.arrowsRotate
                    : (hasFailed
                          ? AppIcons.triangleExclamation
                          : (deviceOnly
                                ? AppIcons.mobileScreen
                                : (isSynced
                                      ? AppIcons.circleCheck
                                      : AppIcons.cloud)));
                final label = syncing
                    ? (Tr.forKu(K.senkronizeEdiliyor, isKu))
                    : (hasFailed
                          ? Tr.forKu(K.pSenkronizeEdilemedi, isKu, {
                              'p0': '$failed',
                            })
                          : (deviceOnly
                                ? Tr.forKu(K.deviceOnlyProgress, isKu)
                                : (isSynced
                                      ? (Tr.forKu(K.bulutlaSenkronize, isKu))
                                      : Tr.forKu(K.pendingOnDeviceP, isKu, {
                                          'p0': '$pending',
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
