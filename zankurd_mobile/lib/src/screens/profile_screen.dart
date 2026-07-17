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
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/player_avatar.dart';
import '../widgets/strength_map_section.dart';
import '../widgets/weekly_performance_chart.dart';
import 'avatar_editor_screen.dart';
import 'favorite_questions_screen.dart';
import 'quiz_screen.dart';
import 'friends_screen.dart';
import 'community_screen.dart';
import 'settings_screen.dart';
import 'suggest_question_screen.dart';
import 'shop_screen.dart';

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final name = await widget.repository.getProfileName();
      final stats = await widget.repository.getPlayerStats();
      final avatarIdentity = await widget.repository.loadAvatarIdentity();
      final achievementStore = await AchievementStore.load();
      final masteryStore = await MasteryStore.load();
      final xpStore = await XPStore.load();
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
    final langProvider = context.langProvider;
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

        // Language toggle
        AppPanel(
          child: Row(
            children: [
              const Icon(Icons.language, color: AppTheme.violet, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ku ? 'Ziman' : 'Dil',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ku ? 'Kurdî / Tirkî' : 'Kürtçe / Türkçe',
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              _LangToggle(isKu: ku, onToggle: langProvider.toggle),
            ],
          ),
        ),
        const SizedBox(height: 14),

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
                Text(
                  ku
                      ? 'Hîn dîroka lîstikê ya serhêl tune.\nBi yekê re bikevin an yek çêbikin.'
                      : 'Henüz çevrimiçi oyun geçmişin yok.\nBir odaya katıl veya oluştur.',
                  style: const TextStyle(color: AppTheme.textMuted),
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
                        value: '#${_stats!.rank}',
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
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: AppTheme.surfaceHiColor(context)),
              ),
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
            ],
          ),
        ),
        const SizedBox(height: 14),

        _PedagogicalAnalyticsSection(isKu: ku),
        const SizedBox(height: 14),
        StrengthMapSection(isKu: ku, refreshSignal: widget.refreshSignal),
        if (_masteryStore != null) ...[
          const SizedBox(height: 14),
          _MasterySection(store: _masteryStore!, isKu: ku),
        ],
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
                          const Spacer(),
                          Tooltip(
                            message: ku ? 'Mîheng' : 'Ayarlar',
                            child: IconButton.filledTonal(
                              key: const ValueKey('profile-settings-top'),
                              onPressed: () => Navigator.of(context).push(
                                AppRoute.to(
                                  SettingsScreen(repository: widget.repository),
                                ),
                              ),
                              icon: const Icon(Icons.settings_outlined),
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
                color: iconColor.withValues(alpha: 0.14),
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
                  Icons.people_outline,
                  color: AppTheme.primaryGradientStart,
                  size: 20,
                ),
                iconColor: AppTheme.primaryGradientStart,
                title: ku ? 'Hevalên Min' : 'Arkadaşlarım',
                onTap: () {
                  Navigator.of(context).push(
                    AppRoute.to(FriendsScreen(repository: widget.repository)),
                  );
                },
              ),
              divider,
              _menuRow(
                leading: const Icon(
                  Icons.leaderboard_outlined,
                  color: AppTheme.playCyan,
                  size: 20,
                ),
                iconColor: AppTheme.playCyan,
                title: ku ? 'Civak û Lîg' : 'Topluluk ve Ligler',
                onTap: () {
                  Navigator.of(context).push(
                    AppRoute.to(CommunityScreen(repository: widget.repository)),
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

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.isKu, required this.onToggle});

  final bool isKu;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceHiOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tab(label: 'KU', active: isKu, onTap: onToggle),
            _Tab(label: 'TR', active: !isKu, onTap: onToggle),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: active ? AppTheme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(
          color: active ? Colors.white : AppTheme.textMutedColor(context),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.ku,
    required this.displayName,
    required this.avatarIdentity,
    required this.showcaseTitle,
    required this.level,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.levelProgress,
    required this.onEditAvatar,
  });

  final bool ku;
  final String displayName;
  final AvatarIdentity avatarIdentity;
  final String? showcaseTitle;
  final int level;
  final int xpInLevel;
  final int xpNeeded;
  final double levelProgress;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          // Profil sekmesinin kimlik rengi mor (bkz. AppShell._tabAccent);
          // hero kartı aynı imzayı taşır.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.violet, AppTheme.bgDeep],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: AppTheme.glowShadow(AppTheme.violet, intensity: 0.16),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KilimPatternPainter(
                    drawPattern: true,
                    color: Colors.white,
                    opacity: 0.05,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -8,
              top: -12,
              child: IgnorePointer(
                child: Icon(
                  Icons.person_rounded,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      key: const ValueKey('profile-avatar-edit'),
                      customBorder: const CircleBorder(),
                      onTap: onEditAvatar,
                      child: Stack(
                        children: [
                          // Mockup 10: altın halkalı avatar.
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.gold,
                                width: 2.5,
                              ),
                            ),
                            child: PlayerAvatar(
                              radius: 34,
                              photoUrl: avatarIdentity.photoUrl,
                              iconId: avatarIdentity.iconId,
                              colorHex: avatarIdentity.colorHex,
                              frameId: avatarIdentity.frameId,
                              displayName: displayName,
                            ),
                          ),
                          // Mockup 10: yeşil kamera rozeti.
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.correct,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.bgDeep,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_camera,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (showcaseTitle != null)
                            Container(
                              margin: const EdgeInsets.only(
                                top: AppSpacing.xxs,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                showcaseTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.gold,
                                ),
                              ),
                            )
                          else
                            Text(
                              ku
                                  ? 'Di tabloya pêşderçûnê de ev nav xuya dike'
                                  : 'Liderlik tablosunda bu isim görünür',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      color: AppTheme.gold,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        ku ? 'Ast $level' : 'Seviye $level',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '$xpInLevel / $xpNeeded XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      FractionallySizedBox(
                        widthFactor: levelProgress.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.statCard(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLarge.copyWith(color: color, fontSize: 17),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementShowcase extends StatelessWidget {
  const _AchievementShowcase({required this.achievements, required this.isKu});

  final List<Achievement> achievements;
  final bool isKu;

  void _showAllAchievementsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isKu ? 'Hemû Rozet' : 'Tüm Rozetler',
                    style: AppTypography.heading2.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 20,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: AchievementStore.definitions.length,
                  itemBuilder: (context, index) {
                    final definition = AchievementStore.definitions[index];
                    final isUnlocked = achievements.any(
                      (a) => a.id == definition.id,
                    );
                    final color = isUnlocked
                        ? AppTheme.gold
                        : AppTheme.textMutedColor(context);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? AppTheme.gold.withValues(alpha: 0.08)
                            : AppTheme.surfaceHiColor(
                                context,
                              ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? AppTheme.gold.withValues(alpha: 0.25)
                              : AppTheme.borderColor(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(definition.icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  definition.title(isKu),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: isUnlocked
                                        ? AppTheme.textPrimaryColor(context)
                                        : AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  definition.description(isKu),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppTheme.textMutedColor(context),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Rozet' : 'Rozetler',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAllAchievementsSheet(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${achievements.length}/${AchievementStore.definitions.length}',
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMutedColor(context),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (achievements.isEmpty)
            Text(
              isKu
                  ? 'Pêşbirkekê biqedîne û rozeta yekem veke.'
                  : 'Bir yarış tamamla ve ilk rozetini aç.',
              style: TextStyle(color: AppTheme.textMuted),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _AchievementChip(
                      achievement: achievement,
                      isKu: isKu,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MasterySection extends StatelessWidget {
  const _MasterySection({required this.store, required this.isKu});

  final MasteryStore store;
  final bool isKu;

  static const _categories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
    'Teknolojî',
  ];

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: AppTheme.violet),
              const SizedBox(width: 8),
              // Dar (iki sütunlu masaüstü) panelde başlık taşmasın.
              Expanded(
                child: Text(
                  isKu ? 'Ustalîya Kategoriyê' : 'Kategori Ustalığı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final cat in _categories)
            _MasteryRow(category: cat, store: store, isKu: isKu),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.category,
    required this.store,
    required this.isKu,
  });

  final String category;
  final MasteryStore store;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final level = store.levelFor(category);
    final count = store.correctCount(category);
    final threshold = store.nextThreshold(category);
    final isMamoste = level == MasteryLevel.mamoste;
    final progress = isMamoste ? 1.0 : (count / threshold).clamp(0.0, 1.0);
    final badgeColor = level == MasteryLevel.none
        ? AppTheme.textMuted
        : level.badgeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              CategoryNames.localized(category, isKu),
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Rozet çipi dar panelde satırı taşırmasın diye esner.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                level == MasteryLevel.none
                    ? (isKu ? 'Destpêkirin' : 'Başlangıç')
                    : (isKu ? level.titleKu : level.titleTr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: badgeColor,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMamoste ? '✓' : '$count/$threshold',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement, required this.isKu});

  final Achievement achievement;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(achievement.icon, color: AppTheme.gold, size: 18),
          const SizedBox(width: 6),
          Text(
            achievement.title(isKu),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PedagogicalAnalyticsSection extends StatelessWidget {
  const _PedagogicalAnalyticsSection({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([MistakeStore.load(), MasteryStore.load()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final mistakeStore = snapshot.data![0] as MistakeStore;
        final masteryStore = snapshot.data![1] as MasteryStore;

        final mistakesByCategory = mistakeStore.getMistakesCountByCategory();

        // Find strongest category (highest correctCount in MasteryStore)
        String? strongestCat;
        int maxCorrect = -1;

        // Find weakest category (highest active mistakes in MistakeStore)
        String? weakestCat;
        int maxMistakes = -1;

        const categories = [
          'Ziman',
          'Çand',
          'Dîrok',
          'Edebiyat',
          'Cografya',
          'Muzîk',
          'Siyaset',
          'Paradigma',
          'Teknolojî',
        ];

        var masteryCategoriesPlayed = 0;
        var mistakeCategoriesPlayed = 0;

        for (final cat in categories) {
          final corrects = masteryStore.correctCount(cat);
          if (corrects > 0) {
            masteryCategoriesPlayed++;
            if (corrects > maxCorrect) {
              maxCorrect = corrects;
              strongestCat = cat;
            }
          }

          final mistakes = mistakesByCategory[cat] ?? 0;
          if (mistakes > 0) {
            mistakeCategoriesPlayed++;
            if (mistakes > maxMistakes) {
              maxMistakes = mistakes;
              weakestCat = cat;
            }
          }
        }

        // Tek bir kategori oynanmışken o kategori hem "en güçlü" hem de
        // "en zayıf" olarak aynı anda görünüyordu (karşılaştırma yapılacak
        // ikinci bir kategori yoktu) — bkz. 2026-07-04 keşif turu bulgusu.
        // Anlamlı bir karşılaştırma için en az 2 farklı kategoride veri
        // birikene kadar ilgili rozeti gösterme.
        if (masteryCategoriesPlayed < 2) strongestCat = null;
        if (mistakeCategoriesPlayed < 2) weakestCat = null;

        // Build category bar data even if no strongest/weakest
        final categoryBars = <_CategoryBarData>[];
        for (final cat in categories) {
          final corrects = masteryStore.correctCount(cat);
          final mistakes = mistakesByCategory[cat] ?? 0;
          if (corrects > 0 || mistakes > 0) {
            categoryBars.add(_CategoryBarData(cat, corrects, mistakes));
          }
        }
        // Sort by correct count descending
        categoryBars.sort((a, b) => b.correct.compareTo(a.correct));
        final maxBar = categoryBars.isEmpty
            ? 1
            : categoryBars
                  .map((e) => e.correct + e.mistakes)
                  .reduce((a, b) => a > b ? a : b);

        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isKu ? 'Analîza Performansê' : 'Performans Analizi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 📊 Category performance bars
              if (categoryBars.isNotEmpty) ...[
                Text(
                  isKu
                      ? 'Performansa li gor kategoriyan'
                      : 'Kategorilere göre performans',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final bar in categoryBars) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            isKu
                                ? CategoryNames.localized(bar.category, true)
                                : CategoryNames.localized(bar.category, false),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: (bar.correct + bar.mistakes) / maxBar,
                              ),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 16,
                                    backgroundColor: AppTheme.surfaceColor(
                                      context,
                                    ),
                                    color: AppTheme.correct,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${bar.correct}',
                            textAlign: TextAlign.right,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.correct,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Legend
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      _LegendDot(
                        color: AppTheme.correct,
                        label: isKu ? 'Rast' : 'Doğru',
                      ),
                      const SizedBox(width: 16),
                      _LegendDot(
                        color: AppTheme.wrong,
                        label: isKu ? 'Şaş' : 'Yanlış',
                      ),
                    ],
                  ),
                ),
                if (strongestCat != null || weakestCat != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),
              ],

              if (strongestCat != null) ...[
                Text(
                  isKu
                      ? 'Kategoriya te ya herî bihêz:'
                      : 'En güçlü olduğun kategori:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.correct.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.correct.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        strongestCat,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.correct,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isKu
                            ? '$maxCorrect bersivên rast'
                            : '$maxCorrect doğru cevap',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (strongestCat != null && weakestCat != null)
                const SizedBox(height: 14),
              if (weakestCat != null) ...[
                Text(
                  isKu
                      ? 'Kategoriya ku divê tu pêş bixî:'
                      : 'Geliştirilmesi gereken alan:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        weakestCat,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isKu
                            ? '$maxMistakes pirsên şaş ên çalak'
                            : '$maxMistakes aktif yanlış soru',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Category Bar Data Model ────────────────────────────────────────────────

class _CategoryBarData {
  const _CategoryBarData(this.category, this.correct, this.mistakes);
  final String category;
  final int correct;
  final int mistakes;
}

// ─── Legend Dot ─────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
