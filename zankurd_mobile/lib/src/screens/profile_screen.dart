import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/xp_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/achievement.dart';
import '../models/leaderboard_entry.dart';
import '../models/league_tier.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/skeleton_loader.dart';
import '../models/avatar_identity.dart';
import '../data/badge_service.dart';
import '../widgets/badge_widget.dart';
import '../widgets/player_avatar.dart';
import '../widgets/strength_map_section.dart';
import '../widgets/weekly_performance_chart.dart';
import 'avatar_editor_screen.dart';
import 'favorite_questions_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'suggest_question_screen.dart';
import 'shop_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

part 'profile/profile_widgets.dart';

// 2026-07-23 M18: misafir hesap yükseltme dialog'unun üç olası çıkışı —
// email/şifre başarılı, email/şifre başarısız, Google bağlama istendi.
enum _GuestUpgradeAction { emailSuccess, emailFailure, googleRequested }

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
  bool _loading = true;
  bool _loadFailed = false;
  bool _practiceLoading = false;
  AvatarIdentity _avatarIdentity = const AvatarIdentity();
  int _mistakeCount = 0;
  int _readyMistakeCount = 0;
  String? _currentName;
  LeaderboardEntry? _stats;
  List<Achievement> _achievements = const [];
  MasteryStore? _masteryStore;
  int _level = 1;
  int _xpInLevel = 0;
  int _xpNeeded = 1000;
  double _levelProgress = 0.0;
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

  Future<void> _refreshMistakes() async {
    final store = await MistakeStore.load();
    if (mounted) {
      setState(() {
        _mistakeCount = store.count;
        _readyMistakeCount = store.readyCount;
      });
    }
  }

  Future<void> _startMistakePractice() async {
    final ku = context.isKu;
    final store = await MistakeStore.load();
    if (!mounted) return;
    final mistakeIds = store.readyIds;
    final questions = widget.repository.questions
        .where((question) => mistakeIds.contains(question.id))
        .toList();
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            store.count > 0
                ? (ku
                      ? 'Hemû pirsên şaş li benda dema dubarekirinê ne. Paşê biceribîne!'
                      : 'Tüm yanlışlarınızın tekrar süreleri bekleniyor. Daha sonra tekrar deneyin!')
                : (ku
                      ? 'Pirsên şaş tune. Pêşî pêşbirkekê bilîze!'
                      : 'Tekrar edilecek yanlış yok. Önce bir yarış oyna!'),
          ),
        ),
      );
      return;
    }
    setState(() => _practiceLoading = true);
    final practiceRoom = widget.repository.createRoom().copyWith(
      name: ku ? 'Şaşiyên Min' : 'Yanlışlarım',
      questionCount: questions.length,
    );
    await Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: practiceRoom,
          questions: questions,
          practice: true,
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
        ? widget.repository.questions
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
          _avatarIdentity = avatarIdentity;
          _achievements = achievementStore.unlockedAchievements;
          _badgeUnlocked = badgeService.unlockedBadges;
          _masteryStore = masteryStore;
          _level = xpStore.currentLevel;
          _xpInLevel = xpStore.xpInCurrentLevel;
          _xpNeeded = xpStore.xpNeededForNextLevel;
          _levelProgress = xpStore.levelProgress;
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

  /// Sunucudaki varsayılan ad Türkçedir; KU modunda görünümde çevrilir.
  String _displayName(bool ku) {
    final name = _currentName;
    if (name == null || name.isEmpty || name == 'ZanKurd Oyuncusu') {
      return ku ? 'Lîstikvanê ZanKurd' : 'ZanKurd Oyuncusu';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 720;

    final profileHero = _ProfileHeroCard(
      ku: ku,
      displayName: _displayName(ku),
      avatarIdentity: _avatarIdentity,
      showcaseTitle: _avatarIdentity.showcaseTitle,
      level: _level,
      xpInLevel: _xpInLevel,
      xpNeeded: _xpNeeded,
      rank: _stats?.roomsPlayed != null && _stats!.roomsPlayed > 0
          ? _stats?.rank
          : null,
      levelProgress: _levelProgress,
      onEditAvatar: _openAvatarEditor,
    );

    Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        profileHero,
        const SizedBox(height: AppSpacing.cardGap),

        // Stats
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ku ? 'Statîstîkên Min' : 'İstatistiklerim',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 14),
              if (_stats == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ku
                          ? 'Hîn dîroka lîstikê ya serhêl tune.\nBi yekê re bikevin an yek çêbikin.'
                          : 'Henüz çevrimiçi oyun geçmişin yok.\nBir odaya katıl veya oluştur.',
                      style: TextStyle(color: AppTheme.textMutedColor(context)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('profile-stats-start-cta'),
                      onPressed: _startQuickRace,
                      icon: const Icon(AppIcons.bolt, size: 18),
                      label: Text(ku ? 'Îro dest pê bike' : 'Bugün başla'),
                    ),
                  ],
                )
              else
                // İlk bakışta 4 metrik — kalanı "Detaylı İstatistik"te.
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _StatTile(
                        label: ku ? 'Rêze' : 'Sıralama',
                        value: _answeredTotal > 0 ? '#${_stats!.rank}' : '—',
                        color: AppTheme.gold,
                        icon: AppIcons.chartColumn,
                      ),
                      _StatTile(
                        label: ku ? 'Tevayî Xal' : 'Toplam Puan',
                        value: '${_stats!.totalScore}',
                        color: AppTheme.accent,
                        icon: AppIcons.star,
                      ),
                      _StatTile(
                        label: ku ? 'Pirsên Bersivandî' : 'Cevaplanan Soru',
                        value: '$_answeredTotal',
                        color: AppTheme.correct,
                        icon: AppIcons.gamepad,
                      ),
                      _StatTile(
                        label: ku ? 'Rastî' : 'Doğruluk',
                        value: _accuracyPercent == null
                            ? '—'
                            : '%${_accuracyPercent!.round()}',
                        color: AppTheme.cyan,
                        icon: AppIcons.bullseye,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Detaylı analiz (grafik, kategori ustalığı, güçlü/zayıf yön) —
        // mockup 10'un sadeliğine uymak için varsayılan kapalı.
        AppPanel(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12),
                title: Text(
                  ku ? 'Analîza Berfireh' : 'Detaylı İstatistik',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                children: [
                  Text(
                    ku ? 'Performansa Heftane' : 'Haftalık Performans',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<MistakeStore>(
                    future: MistakeStore.load(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return SizedBox(
                          height: 160,
                          child: Center(
                            child: Text(
                              ku
                                  ? 'Performans nehat barkirin.'
                                  : 'Performans yüklenemedi.',
                              style: TextStyle(
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 160,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryGradientStart,
                            ),
                          ),
                        );
                      }
                      final history = snapshot.data!.getLast7DaysHistory();
                      return WeeklyPerformanceChart(history: history, isKu: ku);
                    },
                  ),
                  const SizedBox(height: 14),
                  _PedagogicalAnalyticsSection(isKu: ku),
                  const SizedBox(height: 14),
                  StrengthMapSection(
                    isKu: ku,
                    refreshSignal: widget.refreshSignal,
                  ),
                  if (_masteryStore != null) ...[
                    const SizedBox(height: 14),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UnifiedRewardsSection(
          achievements: _achievements,
          badgeUnlocked: _badgeUnlocked,
          isKu: ku,
        ),
        const SizedBox(height: 14),

        // Navigasyon kısayolları — tek panel içinde gruplandı
        _buildMenuPanel(ku),
      ],
    );

    return Container(
      color: AppTheme.bgOf(context),
      child: SafeArea(
        // 2026-07-22 canlı UX denetimi: profil iskelet yükleme
        child: _loading
            ? _buildProfileSkeleton()
            : _loadFailed
            ? AppErrorState(
                title: ku ? 'Profîl nehat barkirin' : 'Profil yüklenemedi',
                message: ku
                    ? 'Girêdanê kontrol bike û dîsa biceribîne.'
                    : 'Bağlantıyı kontrol edip tekrar dene.',
                retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar dene',
                onRetry: _load,
              )
            : RefreshIndicator(
                color: AppTheme.primaryGradientStart,
                onRefresh: () async {
                  await Future.wait([_load(), _refreshMistakes()]);
                },
                child: ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxs,
                        AppSpacing.xs,
                        AppSpacing.xxs,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 32,
                            margin: const EdgeInsets.only(right: AppSpacing.sm),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: AppTheme.accentGradient,
                            ),
                          ),
                          Text(
                            ku ? 'Profîl' : 'Profil',
                            style: AppTypography.heading1.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontSize: 28,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: leftColumn),
                          const SizedBox(width: 16),
                          Expanded(flex: 10, child: rightColumn),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leftColumn,
                          const SizedBox(height: AppSpacing.md),
                          rightColumn,
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // 2026-07-22 canlı UX denetimi: profil iskelet yükleme
  Widget _buildProfileSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        // Hero card placeholder
        const SkeletonLine(
          width: double.infinity,
          height: 180,
          borderRadius: 16,
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // Stats grid placeholder — 2x2 kareler
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.isLight(context)
                      ? AppTheme.shimmerBaseLight
                      : AppTheme.shimmerBaseDark,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.isLight(context)
                      ? AppTheme.shimmerBaseLight
                      : AppTheme.shimmerBaseDark,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.isLight(context)
                      ? AppTheme.shimmerBaseLight
                      : AppTheme.shimmerBaseDark,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.shimmerBaseDark
                      : AppTheme.shimmerBaseLight,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Menu satır placeholder'ları
        const SkeletonLine(
          width: double.infinity,
          height: 56,
          borderRadius: 12,
        ),
        const SizedBox(height: 10),
        const SkeletonLine(
          width: double.infinity,
          height: 56,
          borderRadius: 12,
        ),
        const SizedBox(height: 10),
        const SkeletonLine(
          width: double.infinity,
          height: 56,
          borderRadius: 12,
        ),
        const SizedBox(height: 10),
        const SkeletonLine(
          width: double.infinity,
          height: 56,
          borderRadius: 12,
        ),
      ],
    );
  }

  Widget _menuRow({
    required Widget leading,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback? onTap,
    BorderRadius borderRadius = BorderRadius.zero,
    Key? iconBadgeKey,
  }) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              key: iconBadgeKey,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconTileBg(context, iconColor),
                shape: BoxShape.circle,
              ),
              child: leading,
            ),
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
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
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

    Widget sectionLabel(String text) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xxs,
          bottom: AppSpacing.xs,
          top: AppSpacing.xxs,
        ),
        child: Text(
          text,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(ku ? 'FÊRBÛN' : 'ÖĞRENME'),
        AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _menuRow(
                leading: const Icon(
                  AppIcons.bookmark,
                  color: AppTheme.gold,
                  size: 20,
                ),
                iconColor: AppTheme.gold,
                title: ku ? 'Pirsên Tomarkirî' : 'Kaydedilen Sorular',
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
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
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGradientStart,
                        ),
                      )
                    : const Icon(
                        AppIcons.graduationCap,
                        color: AppTheme.primaryGradientStart,
                        size: 20,
                      ),
                iconColor: AppTheme.primaryGradientStart,
                title: ku ? 'Şaşiyên Min' : 'Yanlışlarım',
                subtitle: _mistakeCount == 0
                    ? (ku
                          ? 'Şaşiyek tune — aferîn!'
                          : 'Hiç yanlışın yok — aferin!')
                    : (ku
                          ? 'Ji bo dubarekirinê: $_readyMistakeCount / Tevavî: $_mistakeCount'
                          : 'Tekrar Edilecek: $_readyMistakeCount / Toplam: $_mistakeCount'),
                onTap: _practiceLoading ? null : _startMistakePractice,
              ),
              divider,
              _menuRow(
                leading: const Icon(
                  AppIcons.circlePlus,
                  color: AppTheme.playCyan,
                  size: 20,
                ),
                iconColor: AppTheme.playCyan,
                title: ku ? 'Pirs Pêşniyar Bike' : 'Soru Öner',
                subtitle: ku
                    ? 'Pirsa xwe pêşniyar bike, piştî pejirandinê were zêdekirin'
                    : 'Kendi sorunu öner, onaylandıktan sonra eklensin',
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md),
                ),
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
        ),
        const SizedBox(height: AppSpacing.md),
        sectionLabel(ku ? 'HESAB' : 'HESAP'),
        // 2026-07-22 canlı UX denetimi: misafir hesap yükseltme
        if (context.watch<AuthProvider>().isGuest) ...[
          AppPanel(
            padding: EdgeInsets.zero,
            child: _menuRow(
              leading: const Icon(
                AppIcons.userPlus,
                color: AppTheme.correct,
                size: 20,
              ),
              iconColor: AppTheme.correct,
              title: ku ? 'Hesabê Xwe Tomar Bike' : 'Hesabını Kaydet',
              subtitle: ku
                  ? 'E-posta û şîfreyekê binivîse — hesabê te yê mêvan bibe mayînde'
                  : 'E-posta ve şifre belirle — misafir hesabın kalıcı olsun',
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _showGuestUpgradeDialog,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _menuRow(
                iconBadgeKey: const ValueKey('profile-menu-icon-Dukan'),
                leading: const Icon(
                  AppIcons.store,
                  color: AppTheme.gold,
                  size: 20,
                ),
                iconColor: AppTheme.gold,
                title: ku ? 'Dukan' : 'Mağaza',
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    AppRoute.to(ShopScreen(repository: widget.repository)),
                  );
                },
              ),
              divider,
              _menuRow(
                leading: const Icon(
                  AppIcons.gear,
                  color: AppTheme.secondaryAccent,
                  size: 20,
                ),
                iconColor: AppTheme.secondaryAccent,
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
                  AppIcons.rightFromBracket,
                  color: AppTheme.wrong,
                  size: 20,
                ),
                iconColor: AppTheme.wrong,
                title: ku ? 'Derkeve' : 'Çıkış Yap',
                titleColor: AppTheme.wrong,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md),
                ),
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2026-07-22 canlı UX denetimi: misafir hesap yükseltme dialog'u
  Future<void> _showGuestUpgradeDialog() async {
    final ku = context.isKu;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final result = await showDialog<_GuestUpgradeAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceOf(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor(ctx)),
          ),
          title: Text(
            ku ? 'Hesabê Xwe Tomar Bike' : 'Hesabını Kaydet',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(ctx),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ku
                      ? 'E-posta û şîfreyekê binivîse da ku hesabê xwe yê mêvan bikî hesabê mayînde.'
                      : 'Misafir hesabını kalıcı yapmak için e-posta ve şifre belirle.',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: ku ? 'E-posta' : 'E-posta',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty || !v.contains('@')) {
                      return ku
                          ? 'E-postayek derbasdar binivîse'
                          : 'Geçerli bir e-posta gir';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ku ? 'Şîfre' : 'Şifre',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return ku
                          ? 'Şîfre divê herî kêm 6 tîpan be'
                          : 'Şifre en az 6 karakter olmalı';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.borderColor(ctx))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ku ? 'an jî' : 'veya',
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textMutedColor(ctx),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.borderColor(ctx))),
                  ],
                ),
                const SizedBox(height: 12),
                // 2026-07-23 M18: Google linkIdentity mevcut oturumu
                // korur, bu yüzden dialog anında kapanır — sonucu dış
                // kapsamda _linkGoogleAccount() ele alır.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: submitting
                        ? null
                        : () => Navigator.pop(
                            dialogContext,
                            _GuestUpgradeAction.googleRequested,
                          ),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    label: Text(
                      ku ? 'Bi Google ve Girêde' : 'Google ile Bağla',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.pop(dialogContext, null),
              child: Text(ku ? 'Betal' : 'Vazgeç'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => submitting = true);
                      final auth = context.read<AuthProvider>();
                      final success = await auth.upgradeGuestAccount(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(
                        dialogContext,
                        success
                            ? _GuestUpgradeAction.emailSuccess
                            : _GuestUpgradeAction.emailFailure,
                      );
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(ku ? 'Tomar Bike' : 'Kaydet'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ku
                  ? 'Hesabê te bi serkeftî hat tomarkirin!'
                  : 'Hesabın başarıyla kaydedildi!',
            ),
          ),
        );
      case _GuestUpgradeAction.emailFailure:
        final message = context.read<AuthProvider>().errorMessage;
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
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
    final ku = context.isKu;
    LoadingOverlay.show(
      context,
      message: ku ? 'Bi Google ve tê girêdan...' : 'Google ile bağlanılıyor...',
    );
    final auth = context.read<AuthProvider>();
    final success = await auth.linkGoogleAccount();
    if (!mounted) return;
    LoadingOverlay.hide(context);
    if (!success && auth.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ku = context.isKu;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(ku ? 'Derkeve' : 'Çıkış Yap'),
        // Misafir hesabında çıkış geri dönüşsüzdür: hesap anonim olduğu
        // için XP, coin, rozet ve seri kalıcı olarak kaybolur. Önceki
        // metin bunu hiç söylemiyordu (2026-07-22 canlı UX denetimi).
        content: Text(
          context.read<AuthProvider>().isGuest
              ? (ku
                    ? 'Tu wek mêvan têketî yî. Heke derkevî, XP, coin, '
                          'rozet û zincîra te bi tevahî winda dibin — '
                          'vegerandin tune.'
                    : 'Misafir olarak giriş yaptın. Çıkarsan XP, coin, '
                          'rozet ve serin kalıcı olarak silinir — geri '
                          'getirilemez.')
              : (ku
                    ? 'Tu dixwazî ji hesabê xwe derkevî?'
                    : 'Hesabından çıkmak istiyor musun?'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ku ? 'Betal' : 'Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ku ? 'Derkeve' : 'Çıkış Yap'),
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
