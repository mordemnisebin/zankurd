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
import '../widgets/badge_collection_section.dart';
import '../widgets/weekly_performance_chart.dart';
import 'favorite_questions_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.repository,
    this.refreshSignal,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Profil tabı yeniden gösterildiğinde tetiklenir; veriler tazelenir.
  final Listenable? refreshSignal;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _practiceLoading = false;
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
      final achievementStore = await AchievementStore.load();
      final masteryStore = await MasteryStore.load();
      final xpStore = await XPStore.load();
      if (mounted) {
        setState(() {
          _currentName = name;
          _stats = stats;
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

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            : _loadFailed
            ? AppErrorState(
                title: ku ? 'Profîl nehat barkirin' : 'Profil yüklenemedi',
                message: ku
                    ? 'Girêdanê kontrol bike û dîsa bicerib.'
                    : 'Bağlantıyı kontrol edip tekrar dene.',
                retryLabel: ku ? 'Dîsa Bicerib' : 'Tekrar Dene',
                onRetry: _load,
              )
            : RefreshIndicator(
                color: AppTheme.accent,
                onRefresh: () async {
                  await Future.wait([_load(), _refreshMistakes()]);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                      child: Text(
                        ku ? 'Profîl' : 'Profil',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                    ),

                     // Avatar card
                    AppPanel(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C3AED), Color(0xFF4F1EB8)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  (_currentName?.isNotEmpty == true
                                          ? _currentName![0]
                                          : 'Z')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName(ku),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      ku
                                          ? 'Di tabloya pêşderçûnê de ev nav xuya dike'
                                          : 'Liderlik tablosunda bu isim görünür',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.2),
                            height: 1,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.military_tech_rounded,
                                    color: AppTheme.gold,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ku ? 'Ast $_level' : 'Seviye $_level',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$_xpInLevel / $_xpNeeded XP',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _levelProgress,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              color: AppTheme.gold,
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Language toggle
                    AppPanel(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.language,
                            color: AppTheme.violet,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ku ? 'Ziman' : 'Dil',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  ku ? 'Kurdî / Tirkî' : 'Kürtçe / Türkçe',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
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
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w900,
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
                                crossAxisCount: constraints.maxWidth > 600
                                    ? 4
                                    : 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 2.2,
                                children: [
                                  _StatTile(
                                    label: ku ? 'Rêze' : 'Sıralama',
                                    value: '#${_stats!.rank}',
                                    color: AppTheme.gold,
                                  ),
                                  _StatTile(
                                    label: ku ? 'Tevayî Xal' : 'Toplam Puan',
                                    value: '${_stats!.totalScore}',
                                    color: AppTheme.accent,
                                  ),
                                  _StatTile(
                                    label: ku
                                        ? 'Baştirîn Zincîr'
                                        : 'En İyi Seri',
                                    value: '${_stats!.bestStreak}',
                                    color: AppTheme.violet,
                                  ),
                                  _StatTile(
                                    label: ku ? 'Lîstik' : 'Oyun',
                                    value: '${_stats!.roomsPlayed}',
                                    color: AppTheme.correct,
                                  ),
                                ],
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: AppTheme.surfaceHi),
                          ),
                          Text(
                            ku ? 'Performansa Heftane' : 'Haftalık Performans',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<MistakeStore>(
                            future: MistakeStore.load(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                );
                              }
                              final history = snapshot.data!.getLast7DaysHistory();
                              return WeeklyPerformanceChart(
                                history: history,
                                isKu: ku,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _PedagogicalAnalyticsSection(isKu: ku),
                    const SizedBox(height: 14),

                    _AchievementShowcase(achievements: _achievements, isKu: ku),
                    const SizedBox(height: 14),

                    // Rozet Koleksiyonu
                    AppPanel(
                      child: const BadgeCollectionSection(),
                    ),
                    const SizedBox(height: 14),

                    if (_masteryStore != null) ...[
                      _MasterySection(store: _masteryStore!, isKu: ku),
                      const SizedBox(height: 14),
                    ],

                    // Saved questions shortcut
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            AppRoute.to(
                              FavoriteQuestionsScreen(
                                repository: widget.repository,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bookmark_outline,
                                color: AppTheme.gold,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ku
                                      ? 'Pirsên Tomarkirî'
                                      : 'Kaydedilen Sorular',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mistake practice shortcut
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _practiceLoading ? null : _startMistakePractice,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _practiceLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accent,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.school_outlined,
                                      color: AppTheme.accent,
                                      size: 22,
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ku ? 'Şaşiyên Min' : 'Yanlışlarım',
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _mistakeCount == 0
                                          ? (ku
                                                ? 'Şaşiyek tune — aferîn!'
                                                : 'Hiç yanlışın yok — aferin!')
                                          : (ku
                                                ? 'Ji bo dubarekirinê: $_readyMistakeCount / Tevavî: $_mistakeCount'
                                                : 'Tekrar Edilecek: $_readyMistakeCount / Toplam: $_mistakeCount'),
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Settings shortcut
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            AppRoute.to(
                              SettingsScreen(repository: widget.repository),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.settings_outlined,
                                color: AppTheme.violet,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ku ? 'Mîheng' : 'Ayarlar',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sign out
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _confirmSignOut(context),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: AppTheme.wrong,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ku ? 'Derkeve' : 'Çıkış Yap',
                                  style: const TextStyle(
                                    color: AppTheme.wrong,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
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
          side: const BorderSide(color: AppTheme.border),
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
    } catch (_) {
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
          border: Border.all(color: AppTheme.border),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppTheme.textMuted,
          fontWeight: FontWeight.w800,
          fontSize: 13,
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
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
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

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppTheme.gold,
              ),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Rozet' : 'Rozetler',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Text(
                '${achievements.length}/${AchievementStore.definitions.length}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
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
              style: const TextStyle(color: AppTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final achievement in achievements)
                  _AchievementChip(achievement: achievement, isKu: isKu),
              ],
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
  ];

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppTheme.violet,
              ),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Ustalîya Kategoriyê' : 'Kategori Ustalığı',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
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
    final progress =
        isMamoste ? 1.0 : (count / threshold).clamp(0.0, 1.0);
    final badgeColor =
        level == MasteryLevel.none ? AppTheme.textMuted : level.badgeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              CategoryNames.localized(category, isKu),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
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
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMamoste ? '✓' : '$count/$threshold',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
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
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
      future: Future.wait([
        MistakeStore.load(),
        MasteryStore.load(),
      ]),
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
        ];

        for (final cat in categories) {
          final corrects = masteryStore.correctCount(cat);
          if (corrects > maxCorrect && corrects > 0) {
            maxCorrect = corrects;
            strongestCat = cat;
          }

          final mistakes = mistakesByCategory[cat] ?? 0;
          if (mistakes > maxMistakes && mistakes > 0) {
            maxMistakes = mistakes;
            weakestCat = cat;
          }
        }

        if (strongestCat == null && weakestCat == null) {
          return const SizedBox.shrink();
        }

        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isKu ? 'Analîza Performansê' : 'Performans Analizi',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (strongestCat != null) ...[
                Text(
                  isKu
                      ? 'Kategoriya te ya herî bihêz:'
                      : 'En güçlü olduğun kategori:',
                  style: TextStyle(
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
                        style: const TextStyle(
                          color: AppTheme.correct,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isKu
                          ? '$maxCorrect bersivên rast'
                          : '$maxCorrect doğru cevap',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
                      ? 'Kategoriya ku divê tu pêş bixî (Zayıf):'
                      : 'Geliştirilmesi gereken alan (Zayıf):',
                  style: TextStyle(
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
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isKu
                          ? '$maxMistakes pirsên şaş ên çalak'
                          : '$maxMistakes aktif yanlış soru',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
