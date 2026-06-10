import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import 'level_screen.dart';
import 'quiz_screen.dart';
import 'room_screen.dart';
import 'spin_wheel_screen.dart';

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
  bool _dailyLoading = false;
  int _coinBalance = 0;

  ZanKurdRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await repo.ensureProfile();
    } catch (_) {}

    try {
      final cats = await repo.loadCategories();
      final qs = await repo.loadQuestions(limit: 10);
      final coins = await repo.loadCoinBalance();
      if (!mounted) return;
      setState(() {
        _categories = cats.isEmpty ? repo.categories : cats;
        _questions = qs.isEmpty ? repo.questions : qs;
        _coinBalance = coins;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questions = repo.questions;
        _categories = repo.categories;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final room = repo.createRoom();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            _Header(coinBalance: _coinBalance, isKu: ku),
            const SizedBox(height: 20),
            _HeroCard(isKu: ku, onQuickMatch: () => _openQuiz(context, room)),
            const SizedBox(height: 12),
            _StatsRow(isKu: ku),
            const SizedBox(height: 12),
            _DailyQuizCard(
              isKu: ku,
              loading: _dailyLoading,
              onPlay: () => _openDailyQuiz(context, ku),
            ),
            const SizedBox(height: 12),
            _SpinWheelCard(isKu: ku, onOpen: () => _openSpinWheel(context)),
            const SizedBox(height: 16),
            _RoomActions(
              loading: _roomActionLoading,
              isKu: ku,
              onCreateRoom: () => _createOnlineRoom(context),
              onJoinRoom: () => _showJoinSheet(context),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: ku ? 'Kategorî' : 'Kategoriler',
              subtitle: ku
                  ? 'Her kategoriyê 5 ast hene'
                  : 'Her kategori 5 seviyeye ayrıldı',
            ),
            const SizedBox(height: 10),
            _CategoryGrid(
              categories: _categories,
              isKu: ku,
              loading: _loading,
              onTap: (cat) => _openCategory(context, cat),
            ),
            if (!_loading && _questions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionHeader(
                title: ku ? 'Pirsa Nimûne' : 'Örnek Soru',
                subtitle: ku
                    ? 'Destpêbike û pratîkê bike'
                    : 'Hemen başla ve pratik yap',
              ),
              const SizedBox(height: 10),
              _QuestionCard(
                question: _questions.first,
                isKu: ku,
                onOpen: () => _openQuiz(context, room),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createOnlineRoom(BuildContext context) async {
    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final room = await repo.createOnlineRoom();
      if (!context.mounted) return;
      _openRoom(context, room);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isKu
                ? 'Jûra serhêl nehate vekirin, cihêreng berdewam dike.'
                : 'Online oda açılamadı, yerel oda ile devam ediliyor.',
          ),
        ),
      );
      _openRoom(context, repo.createRoom());
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  Future<void> _openDailyQuiz(BuildContext context, bool ku) async {
    if (_dailyLoading) return;
    setState(() => _dailyLoading = true);
    try {
      final dailyQuestions = await repo.loadDailyQuestions(limit: 10);
      if (!context.mounted) return;
      final dailyRoom = repo.createRoom().copyWith(
        name: ku ? 'Pêşbirka Rojê' : 'Günün Yarışması',
        questionCount: dailyQuestions.length,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            repository: repo,
            room: dailyRoom,
            questions: dailyQuestions,
          ),
        ),
      );
      _refreshCoins();
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  Future<void> _openQuiz(BuildContext context, GameRoom room) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(repository: repo, room: room, questions: _questions),
      ),
    );
    _refreshCoins();
  }

  void _openRoom(BuildContext context, GameRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomScreen(repository: repo, initialRoom: room),
      ),
    );
  }

  Future<void> _openSpinWheel(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SpinWheelScreen(repository: repo)),
    );
    _refreshCoins();
  }

  void _openCategory(BuildContext context, String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelScreen(repository: repo, category: category),
      ),
    );
  }

  Future<void> _refreshCoins() async {
    try {
      final coins = await repo.loadCoinBalance();
      if (mounted) setState(() => _coinBalance = coins);
    } catch (_) {}
  }

  void _showJoinSheet(BuildContext context) {
    final controller = TextEditingController(text: 'ZK-4821');
    final ku = context.isKu;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetCtx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ku ? 'Tevlî Jûrê Bibe' : 'Odaya Katıl',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: ku ? 'Koda jûrê' : 'Oda kodu',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      final room = await repo.joinOnlineRoom(controller.text);
                      if (!sheetCtx.mounted) return;
                      Navigator.of(sheetCtx).pop();
                      if (!context.mounted) return;
                      _openRoom(context, room);
                    } catch (_) {
                      if (!sheetCtx.mounted) return;
                      Navigator.of(sheetCtx).pop();
                      if (!context.mounted) return;
                      _openRoom(context, repo.joinRoom(controller.text));
                    }
                  },
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: Text(ku ? 'Tevlî Bibe' : 'Katıl'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.coinBalance, required this.isKu});

  final int coinBalance;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'ZK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ZanKurd',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              Text(
                isKu ? 'Pêşbirka Kurmancî' : 'Kürtçe Yarışması',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        _CoinBadge(value: coinBalance),
      ],
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.white, size: 17),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isKu, required this.onQuickMatch});

  final bool isKu;
  final VoidCallback onQuickMatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF4F1EB8), Color(0xFFE94560)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isKu ? 'Jûra Zindî Vekirî' : 'Canlı Oda Açık',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isKu ? 'Navenda Pêşbirka\nKurmancî' : 'Kurmancî Yarış\nMerkezi',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isKu
                    ? 'Kategoriyekê hilbijêre, ast bide ser ast û li leaderboard bilind bibe.'
                    : 'Kategori seç, seviye geç ve liderlik tablosuna yüksel.',
                style: const TextStyle(color: Color(0xFFE0D0FF), fontSize: 13),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onQuickMatch,
                icon: const Icon(Icons.bolt, size: 18),
                label: Text(
                  isKu ? 'Pêşbirka Bilez' : 'Hızlı Yarış',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.quiz_outlined,
          value: '2250+',
          label: isKu ? 'Pirs' : 'Soru',
          color: AppTheme.violet,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.layers_outlined,
          value: '30',
          label: isKu ? 'Ast' : 'Seviye',
          color: AppTheme.accent,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.image_outlined,
          value: '72',
          label: isKu ? 'Wêne' : 'Görsel',
          color: AppTheme.gold,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomActions extends StatelessWidget {
  const _RoomActions({
    required this.loading,
    required this.isKu,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final bool loading;
  final bool isKu;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GradientButton(
            label: loading
                ? (isKu ? 'Tê Vekirin...' : 'Açılıyor...')
                : (isKu ? 'Jûr Ava Bike' : 'Oda Kur'),
            icon: Icons.add_circle_outline,
            gradient: AppTheme.accentGradient,
            onTap: onCreateRoom,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GradientButton(
            label: isKu ? 'Bi Kodê Tevlî Bibe' : 'Kodla Katıl',
            icon: Icons.meeting_room_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            onTap: onJoinRoom,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.isKu,
    required this.loading,
    required this.onTap,
  });

  final List<String> categories;
  final bool isKu;
  final bool loading;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return GridView.builder(
      itemCount: categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryCard(
          category: cat,
          index: index,
          isKu: isKu,
          onTap: () => onTap(cat),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isKu,
    required this.onTap,
  });

  final String category;
  final int index;
  final bool isKu;
  final VoidCallback onTap;

  IconData _icon(String cat) => switch (cat) {
    'Ziman' => Icons.translate_outlined,
    'Çand' => Icons.diversity_3_outlined,
    'Dîrok' => Icons.account_balance_outlined,
    'Edebiyat' => Icons.menu_book_outlined,
    'Cografya' => Icons.public_outlined,
    'Muzîk' => Icons.music_note_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.categoryGradient(index);
    final glowColor = AppTheme
        .categoryGradients[index % AppTheme.categoryGradients.length]
        .first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              top: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon(category), color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    CategoryNames.localized(category, isKu),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isKu ? '5 ast · pêşbaz' : '5 seviye · yarış',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.isKu,
    required this.onOpen,
  });

  final QuizQuestion question;
  final bool isKu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tag(label: question.category, color: AppTheme.violet),
              const Spacer(),
              _Tag(
                label: isKu ? '08 çirke' : '08 sn',
                color: AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.prompt,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.quiz_outlined),
              label: Text(isKu ? 'Pirs Çareser Bike' : 'Soruyu Çöz'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppTheme.textMuted ? AppTheme.textMuted : color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DailyQuizCard extends StatelessWidget {
  const _DailyQuizCard({
    required this.isKu,
    required this.loading,
    required this.onPlay,
  });

  final bool isKu;
  final bool loading;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      gradient: AppTheme.goldGradient,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: loading ? null : onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.today_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKu ? 'Pêşbirka Rojê' : 'Günün Yarışması',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isKu
                          ? 'Her roj 10 pirsên nû — îro bilîze!'
                          : 'Her gün 10 yeni soru — bugün oyna!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpinWheelCard extends StatelessWidget {
  const _SpinWheelCard({required this.isKu, required this.onOpen});

  final bool isKu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
      ),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.casino_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKu ? 'Çerxa Rojê' : 'Günün Çarkı',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isKu
                          ? 'Bizivirîne, heta 100 coin qezenc bike!'
                          : 'Çevir, 100 coine kadar kazan!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
