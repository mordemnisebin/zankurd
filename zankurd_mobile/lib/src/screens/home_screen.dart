import 'package:flutter/material.dart';

import '../data/local_data_service.dart';
import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
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
    return const AppPanel(
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Supabase soruları yükleniyor...')),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      color: const Color(0xFFFFF7E6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFBD7B2B)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.green,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'ZK',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZanKurd',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
              Text(
                'Pêşbirka Kurmancî',
                style: TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, color: AppTheme.muted),
        ),
        _CoinBadge(coins: coins),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return const AppPanel(
      color: AppTheme.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(),
          SizedBox(height: 14),
          Text(
            'Kurmancî yarış merkezi.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 31,
              height: 1.05,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Kategori seç, seviye geç, arkadaşlarınla odada yarış ve liderlikte yüksel.',
            style: TextStyle(color: Color(0xFFE6F1EB), fontSize: 15),
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
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: const [
          Expanded(
            child: _StatItem(
              icon: Icons.quiz_outlined,
              value: '2250+',
              label: 'Soru',
              color: AppTheme.green,
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.layers_outlined,
              value: '30',
              label: 'Seviye',
              color: Color(0xFF4059AD),
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.image_outlined,
              value: '72',
              label: 'Görsel',
              color: Color(0xFFBD7B2B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: AppTheme.line);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
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
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback onQuickMatch;
  final VoidCallback onLearn;
  final VoidCallback onLeaderboard;
  final VoidCallback onFavorites;
  final VoidCallback onProfile;
  final VoidCallback onDailyQuiz;
  final VoidCallback onBattle;
  final VoidCallback onSpin;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _HomeAction(
        loading ? 'Açılıyor' : 'Oda Kur',
        Icons.add_circle_outline,
        AppTheme.red,
        onCreateRoom,
      ),
      _HomeAction(
        'Kodla Katıl',
        Icons.meeting_room_outlined,
        AppTheme.green,
        onJoinRoom,
      ),
      _HomeAction(
        'Günlük Quiz',
        Icons.calendar_today_outlined,
        const Color(0xFFBD7B2B),
        onDailyQuiz,
      ),
      _HomeAction(
        'Robot Battle',
        Icons.smart_toy_outlined,
        const Color(0xFF9C27B0),
        onBattle,
      ),
      _HomeAction(
        'Hızlı Yarış',
        Icons.bolt_outlined,
        AppTheme.brown,
        onQuickMatch,
      ),
      _HomeAction(
        'Öğren',
        Icons.menu_book_outlined,
        const Color(0xFF4059AD),
        onLearn,
      ),
      _HomeAction(
        'Kaydedilenler',
        Icons.bookmark_outlined,
        const Color(0xFF008891),
        onFavorites,
      ),
      _HomeAction(
        'Günlük Çark',
        Icons.casino_outlined,
        const Color(0xFFFF5722),
        onSpin,
      ),
      _HomeAction(
        'Liderlik',
        Icons.emoji_events_outlined,
        const Color(0xFF6B4F3C),
        onLeaderboard,
      ),
      _HomeAction(
        'Profil',
        Icons.person_outlined,
        const Color(0xFF1976D2),
        onProfile,
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.75,
      ),
      itemBuilder: (context, index) => _ActionTile(action: actions[index]),
    );
  }
}

class _RoomPreview extends StatelessWidget {
  const _RoomPreview({required this.room, required this.onOpen});

  final GameRoom room;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Oda kodu: ${room.code}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Aç'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final player in room.players.take(3))
            _PlayerRow(
              name: player.name,
              score: player.score,
              state: player.state,
            ),
        ],
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
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyTag(label: question.category),
              const Spacer(),
              const _TinyTag(label: '08 sn'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.prompt,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.14,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Örnek soruyu çöz'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories, required this.onCategoryTap});

  final List<String> categories;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategoriler',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 4),
        const Text(
          'Her kategori 5 seviyeye ayrıldı.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: categories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final color = _categoryColor(index);
            return _CategoryCard(
              category: category,
              color: color,
              icon: _categoryIcon(category),
              onTap: () => onCategoryTap(category),
            );
          },
        ),
      ],
    );
  }

  Color _categoryColor(int index) {
    const colors = [
      AppTheme.green,
      Color(0xFF4059AD),
      AppTheme.red,
      Color(0xFFBD7B2B),
      AppTheme.brown,
      Color(0xFF008891),
    ];
    return colors[index % colors.length];
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'Ziman' => Icons.translate_outlined,
      'Çand' => Icons.diversity_3_outlined,
      'Dîrok' => Icons.account_balance_outlined,
      'Edebiyat' => Icons.menu_book_outlined,
      'Cografya' => Icons.public_outlined,
      'Muzîk' => Icons.music_note_outlined,
      _ => Icons.category_outlined,
    };
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String category;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: color),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '5 seviye · yarış modu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: action.onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: action.color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(14),
      ),
      child: Row(
        children: [
          Icon(action.icon, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.score,
    required this.state,
  });

  final String name;
  final int score;
  final String state;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.page,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE8F3EE),
            child: Text(
              name.characters.first,
              style: const TextStyle(color: AppTheme.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  state,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text('$score', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.brown,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 5),
          Text(
            '$coins',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_checked, color: Colors.white, size: 16),
          SizedBox(width: 7),
          Text(
            'Canlı oda açık',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.green,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction(this.title, this.icon, this.color, this.onTap);

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
