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
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../models/avatar_identity.dart';
import '../widgets/badge_collection_section.dart';
import '../widgets/player_avatar.dart';
import '../widgets/strength_map_section.dart';
import '../widgets/weekly_performance_chart.dart';
import 'avatar_editor_screen.dart';
import 'favorite_questions_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'suggest_question_screen.dart';
import 'shop_screen.dart';

part 'profile/profile_widgets.dart';

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
  int? _coinBalance;
  double? _accuracyPercent;

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
      // Coin bakiyesi + doğruluk oranı istatistik kartları için (UI-only).
      int? coinBalance;
      try {
        coinBalance = await widget.repository.loadCoinBalance();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'loadCoinBalance failed');
        coinBalance = null;
      }
      final mistakeStore = await MistakeStore.load();
      if (mounted) {
        setState(() {
          _currentName = name;
          _stats = stats;
          _avatarIdentity = avatarIdentity;
          _achievements = achievementStore.unlockedAchievements;
          _masteryStore = masteryStore;
          _level = xpStore.currentLevel;
          _xpInLevel = xpStore.xpInCurrentLevel;
          _xpNeeded = xpStore.xpNeededForNextLevel;
          _levelProgress = xpStore.levelProgress;
          _coinBalance = coinBalance;
          _accuracyPercent = mistakeStore.accuracyPercent;
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
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('profile-stats-start-cta'),
                      onPressed: _startQuickRace,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(ku ? 'Îro dest pê bike' : 'Bugün başla'),
                    ),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      _StatTile(
                        label: ku ? 'Rêze' : 'Sıralama',
                        // Hiç oyun yokken sahte görünen sıra gösterme.
                        value: _stats!.roomsPlayed > 0
                            ? '#${_stats!.rank}'
                            : '—',
                        color: AppTheme.gold,
                        icon: Icons.leaderboard_rounded,
                      ),
                      _StatTile(
                        label: ku ? 'Tevayî Xal' : 'Toplam Puan',
                        value: '${_stats!.totalScore}',
                        color: AppTheme.accent,
                        icon: Icons.star_rounded,
                      ),
                      _StatTile(
                        label: ku ? 'Baştirîn Zincîr' : 'En İyi Seri',
                        value: '${_stats!.bestStreak}',
                        color: AppTheme.violet,
                        icon: Icons.local_fire_department_rounded,
                      ),
                      _StatTile(
                        label: ku ? 'Lîstik' : 'Oyun',
                        value: '${_stats!.roomsPlayed}',
                        color: AppTheme.correct,
                        icon: Icons.sports_esports_rounded,
                      ),
                      _StatTile(
                        label: ku ? 'Xeruz' : 'Coin',
                        value: _coinBalance == null ? '—' : '$_coinBalance',
                        color: AppTheme.gold,
                        icon: Icons.monetization_on_rounded,
                      ),
                      _StatTile(
                        label: ku ? 'Rastî' : 'Doğruluk',
                        value: _accuracyPercent == null
                            ? '—'
                            : '%${_accuracyPercent!.round()}',
                        color: AppTheme.cyan,
                        icon: Icons.track_changes_rounded,
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

    Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AchievementShowcase(achievements: _achievements, isKu: ku),
        const SizedBox(height: 14),

        // Rozet Koleksiyonu
        const AppPanel(glass: true, child: BadgeCollectionSection()),
        const SizedBox(height: 14),

        // Navigasyon kısayolları — tek panel içinde gruplandı
        _buildMenuPanel(ku),
      ],
    );

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGradientStart,
                ),
              )
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
              Icons.chevron_right_rounded,
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
                  Icons.bookmark_outline,
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
                        Icons.school_outlined,
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
                  Icons.add_circle_outline,
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
        AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _menuRow(
                iconBadgeKey: const ValueKey('profile-menu-icon-Dukan'),
                leading: const Icon(
                  Icons.storefront_outlined,
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
                  Icons.settings_outlined,
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
                  Icons.logout_rounded,
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
        content: Text(
          ku
              ? 'Tu dixwazî ji hesabê xwe derkevî?'
              : 'Hesabından çıkmak istiyor musun?',
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
      ErrorReporter.record(error, stack, reason: 'profile_load');
      // AppShell zaten auth durumuna göre giriş ekranına döner.
    }
  }
}
