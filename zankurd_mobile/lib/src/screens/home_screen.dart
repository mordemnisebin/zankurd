import 'package:flutter/material.dart';

import '../data/local_data_service.dart';
import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import 'battle_screen.dart';
import 'daily_quiz_screen.dart';
import 'favorites_screen.dart';
import 'level_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'quiz_screen.dart';
import 'room_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<QuizQuestion> _questions = widget.repository.questions;
  late List<String> _categories = widget.repository.categories;
  bool _loading = true;
  bool _roomActionLoading = false;
  String? _loadMessage;
  int _coins = 0;

  ZanKurdRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var profileReady = true;
    try {
      await repository.ensureProfile();
    } catch (_) {
      profileReady = false;
    }

    // Show local coins immediately
    final local = await LocalDataService.getInstance();
    if (mounted) setState(() => _coins = local.coins);

    try {
      final results = await Future.wait([
        repository.loadCategories(),
        repository.loadQuestions(limit: 10),
        repository.getProfileCoins(),
      ]);
      final categories = results[0] as List<String>;
      final questions = results[1] as List<QuizQuestion>;
      final remoteCoins = results[2] as int;
      final coins = remoteCoins > 0 ? remoteCoins : local.coins;
      if (!mounted) return;
      final message = questions.isEmpty
          ? 'Supabase bağlantısı var, onaylı soru bulunamadı.'
          : profileReady
          ? null
          : 'Sorular Supabase’den geldi, profil için anonim giriş ayarı gerekiyor.';
      setState(() {
        _categories = categories.isEmpty ? repository.categories : categories;
        _questions = questions.isEmpty ? repository.questions : questions;
        _coins = coins;
        _loading = false;
        _loadMessage = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questions = repository.questions;
        _categories = repository.categories;
        _coins = local.coins;
        _loading = false;
        _loadMessage =
            'Supabase verisi alınamadı, yerel örneklerle devam ediliyor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = repository.createRoom();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            _Header(coins: _coins, onSettings: () => _openSettings(context)),
            const SizedBox(height: 22),
            const _HeroPanel(),
            const SizedBox(height: 12),
            const _DashboardStats(),
            const SizedBox(height: 16),
            _ActionGrid(
              loading: _roomActionLoading,
              onCreateRoom: () => _createOnlineRoom(context),
              onJoinRoom: () => _showJoinSheet(context),
              onQuickMatch: () => _openQuiz(context, room),
              onLearn: () => _openCategory(context, _categories.first),
              onLeaderboard: () => _openLeaderboard(context),
              onFavorites: () => _openFavorites(context),
              onProfile: () => _openProfile(context),
              onDailyQuiz: () => _openDailyQuiz(context),
              onBattle: () => _openBattle(context),
              onSpin: () => _openSpin(context),
            ),
            const SizedBox(height: 16),
            _RoomPreview(room: room, onOpen: () => _openRoom(context, room)),
            const SizedBox(height: 16),
            if (_loading) const _LoadingPanel(),
            if (!_loading && _loadMessage != null) ...[
              _InfoPanel(message: _loadMessage!),
              const SizedBox(height: 16),
            ],
            if (!_loading)
              _QuestionPreview(
                question: _questions.first,
                onOpen: () => _openQuiz(context, room),
              ),
            const SizedBox(height: 16),
            _CategoryStrip(
              categories: _categories,
              onCategoryTap: (category) => _openCategory(context, category),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoom(BuildContext context, GameRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(repository: repository, initialRoom: room),
      ),
    );
  }

  Future<void> _createOnlineRoom(BuildContext context) async {
    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final onlineRoom = await repository.createOnlineRoom();
      if (!context.mounted) return;
      _openRoom(context, onlineRoom);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Online oda açılamadı, yerel oda ile devam ediliyor.'),
        ),
      );
      _openRoom(context, repository.createRoom());
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  void _openQuiz(BuildContext context, GameRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          repository: widget.repository,
          room: room,
          questions: _questions,
        ),
      ),
    );
  }

  void _openLeaderboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(repository: repository),
      ),
    );
  }

  void _openCategory(BuildContext context, String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelScreen(repository: repository, category: category),
      ),
    );
  }

  void _openFavorites(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(repository: repository),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(repository: repository),
      ),
    );
  }

  void _openDailyQuiz(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyQuizScreen(repository: repository),
      ),
    );
  }

  void _openBattle(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          repository: repository,
          category: _categories.isNotEmpty ? _categories.first : 'Ziman',
        ),
      ),
    );
  }

  void _openSpin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpinWheelScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _showJoinSheet(BuildContext context) {
    final controller = TextEditingController(text: 'ZK-4821');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Odaya Katıl',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Oda kodu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      final room = await repository.joinOnlineRoom(
                        controller.text,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                      if (!context.mounted) return;
                      _openRoom(context, room);
                    } catch (_) {
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Odaya bağlanılamadı, kodla yerel oda açıldı.',
                          ),
                        ),
                      );
                      _openRoom(context, repository.joinRoom(controller.text));
                    }
                  },
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: const Text('Katıl'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.coins, required this.onSettings});
  final int coins;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'ZK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZanKurd',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppTheme.ink,
                ),
              ),
              Text(
                'Pêşbirka Kurmancî',
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF4C430).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 4),
              Text(
                '$coins',
                style: const TextStyle(
                  color: Color(0xFF92600A),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
              boxShadow: AppTheme.softShadow,
            ),
            child: const Icon(Icons.settings_outlined, color: AppTheme.ink, size: 20),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🔥 Günlük Meydan Okuma',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Kurmancîyê hîn bibe,\nxwe biceribîne!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF4C430), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '90+ soru · 6 kategori',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatPill(icon: '🏆', label: 'Sıralama', value: '#1', color: const Color(0xFFF4C430)),
          const SizedBox(width: 10),
          _StatPill(icon: '🔥', label: 'Seri', value: '0', color: AppTheme.warning),
          const SizedBox(width: 10),
          _StatPill(icon: '✅', label: 'Doğru', value: '0', color: AppTheme.success),
          const SizedBox(width: 10),
          _StatPill(icon: '🎯', label: 'Puan', value: '0', color: AppTheme.primary),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final String icon, label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.loading,
    required this.onCreateRoom,
    required this.onJoinRoom,
    required this.onQuickMatch,
    required this.onLearn,
    required this.onLeaderboard,
    required this.onFavorites,
    required this.onProfile,
    required this.onDailyQuiz,
    required this.onBattle,
    required this.onSpin,
  });

  final bool loading;
  final VoidCallback onCreateRoom,
      onJoinRoom,
      onQuickMatch,
      onLearn,
      onLeaderboard,
      onFavorites,
      onProfile,
      onDailyQuiz,
      onBattle,
      onSpin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hızlı Erişim',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FeaturedCard(
                gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                emoji: '📅',
                title: 'Günlük Quiz',
                subtitle: '+50 coin',
                onTap: onDailyQuiz,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeaturedCard(
                gradient: const [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                emoji: '⚔️',
                title: 'Robot Düello',
                subtitle: 'Rakibe meydan oku',
                onTap: onBattle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _GridAction(
              emoji: '⚡',
              label: 'Hızlı\nOyun',
              color: AppTheme.primary,
              onTap: onQuickMatch,
            ),
            _GridAction(
              emoji: '🌐',
              label: 'Oda\nAç',
              color: const Color(0xFF0891B2),
              onTap: loading ? () {} : onCreateRoom,
            ),
            _GridAction(
              emoji: '🔗',
              label: 'Odaya\nKatıl',
              color: const Color(0xFF7C3AED),
              onTap: onJoinRoom,
            ),
            _GridAction(
              emoji: '🎡',
              label: 'Günlük\nÇark',
              color: const Color(0xFFE74C3C),
              onTap: onSpin,
            ),
            _GridAction(
              emoji: '📚',
              label: 'Çalış',
              color: const Color(0xFF059669),
              onTap: onLearn,
            ),
            _GridAction(
              emoji: '🏆',
              label: 'Sıralama',
              color: const Color(0xFFF59E0B),
              onTap: onLeaderboard,
            ),
            _GridAction(
              emoji: '❤️',
              label: 'Favoriler',
              color: const Color(0xFFEC4899),
              onTap: onFavorites,
            ),
            _GridAction(
              emoji: '👤',
              label: 'Profil',
              color: const Color(0xFF6366F1),
              onTap: onProfile,
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.gradient,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final List<Color> gradient;
  final String emoji, title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridAction extends StatelessWidget {
  const _GridAction({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPreview extends StatelessWidget {
  const _RoomPreview({required this.room, required this.onOpen});
  final GameRoom room;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oda: ${room.code}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    '${room.players.length} oyuncu · ${room.category}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  const _QuestionPreview({required this.question, required this.onOpen});
  final QuizQuestion question;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.category,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Örnek Soru',
                  style: TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.prompt,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      question.answers.isNotEmpty ? question.answers[0] : '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Oyna →',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
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

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.onCategoryTap,
  });
  final List<String> categories;
  final void Function(String) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategoriler',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onCategoryTap(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.line),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}



