import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/achievement_store.dart';
import '../data/mistake_store.dart';
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
import 'favorite_questions_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _practiceLoading = false;
  int _mistakeCount = 0;
  String? _currentName;
  LeaderboardEntry? _stats;
  List<Achievement> _achievements = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _refreshMistakes();
  }

  Future<void> _refreshMistakes() async {
    final store = await MistakeStore.load();
    if (mounted) setState(() => _mistakeCount = store.count);
  }

  Future<void> _startMistakePractice() async {
    final ku = context.isKu;
    final store = await MistakeStore.load();
    if (!mounted) return;
    final mistakeIds = store.ids;
    final questions = widget.repository.questions
        .where((question) => mistakeIds.contains(question.id))
        .toList();
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ku
                ? 'Pirsên şaş tune. Pêşî pêşbirkekê bilîze!'
                : 'Tekrar edilecek yanlış yok. Önce bir yarış oyna!',
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
      if (mounted) {
        setState(() {
          _currentName = name;
          _stats = stats;
          _achievements = achievementStore.unlockedAchievements;
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
                      child: Row(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _AchievementShowcase(achievements: _achievements, isKu: ku),
                    const SizedBox(height: 14),

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
                                                ? '$_mistakeCount pirs li benda dubarekirinê'
                                                : '$_mistakeCount soru tekrar bekliyor'),
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
