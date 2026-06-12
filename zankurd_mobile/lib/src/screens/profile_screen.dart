import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/leaderboard_entry.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import 'favorite_questions_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _currentName;
  LeaderboardEntry? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final name = await widget.repository.getProfileName();
      final stats = await widget.repository.getPlayerStats();
      if (mounted) {
        setState(() {
          _currentName = name;
          _nameCtrl.text = name;
          _stats = stats;
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

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name == _currentName) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateProfileName(name);
      if (mounted) {
        setState(() {
          _currentName = name;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.isKu
                  ? 'Profîl bi serketî hat nûve kirin.'
                  : 'Profil başarıyla güncellendi.',
            ),
          ),
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile name save failed');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final langProvider = context.langProvider;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
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
            : ListView(
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
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
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
                                _currentName ??
                                    (ku
                                        ? 'ZanKurd Lîstikvan'
                                        : 'ZanKurd Oyuncusu'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                ku
                                    ? 'Navê te biguhêze'
                                    : 'İsmini değiştirebilirsin',
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

                  // Name editor
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku ? 'Navê Lîstikvanê' : 'Oyuncu Adı',
                          style: const TextStyle(
                            color: AppTheme.textSub,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: ku
                                ? 'Navê xwe binivîse...'
                                : 'Adını gir...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(ku ? 'Tomar Bike' : 'Kaydet'),
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
                          GridView.count(
                            crossAxisCount: 2,
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
                                label: ku ? 'Baştirîn Zincîr' : 'En İyi Seri',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Saved questions shortcut
                  AppPanel(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FavoriteQuestionsScreen(
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
                                ku ? 'Pirsên Tomarkirî' : 'Kaydedilen Sorular',
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

                  // Settings shortcut
                  AppPanel(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
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
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ku = context.isKu;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
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
          color: AppTheme.surfaceHi,
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
