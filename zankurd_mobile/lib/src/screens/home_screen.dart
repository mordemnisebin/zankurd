import 'package:flutter/material.dart';

import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'home/category_grid.dart';
import 'home/daily_quiz_card.dart';
import 'home/hero_card.dart';
import 'home/home_header.dart';
import 'home/question_card.dart';
import 'home/room_actions.dart';
import 'home/section_header.dart';
import 'home/spin_wheel_card.dart';
import 'home/stats_row.dart';
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
  int _streak = 0;

  ZanKurdRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshStreak();
  }

  Future<void> _refreshStreak() async {
    final store = await StreakStore.load();
    if (mounted) setState(() => _streak = store.effectiveStreak());
  }

  Future<void> _bootstrap() async {
    try {
      await repo.ensureProfile();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home ensureProfile failed');
    }

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
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home bootstrap load failed');
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
            HomeHeader(coinBalance: _coinBalance, isKu: ku, streak: _streak),
            const SizedBox(height: 20),
            HeroCard(isKu: ku, onQuickMatch: () => _openQuiz(context, room)),
            const SizedBox(height: 12),
            StatsRow(isKu: ku),
            const SizedBox(height: 12),
            DailyQuizCard(
              isKu: ku,
              loading: _dailyLoading,
              onPlay: () => _openDailyQuiz(context, ku),
            ),
            const SizedBox(height: 12),
            SpinWheelCard(isKu: ku, onOpen: () => _openSpinWheel(context)),
            const SizedBox(height: 16),
            RoomActions(
              loading: _roomActionLoading,
              isKu: ku,
              onCreateRoom: () => _createOnlineRoom(context),
              onJoinRoom: () => _showJoinSheet(context),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: ku ? 'Kategorî' : 'Kategoriler',
              subtitle: ku
                  ? 'Her kategoriyê 5 ast hene'
                  : 'Her kategori 5 seviyeye ayrıldı',
            ),
            const SizedBox(height: 10),
            CategoryGrid(
              categories: _categories,
              isKu: ku,
              loading: _loading,
              onTap: (cat) => _openCategory(context, cat),
            ),
            if (!_loading && _questions.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(
                title: ku ? 'Pirsa Nimûne' : 'Örnek Soru',
                subtitle: ku
                    ? 'Destpêbike û pratîkê bike'
                    : 'Hemen başla ve pratik yap',
              ),
              const SizedBox(height: 10),
              QuestionCard(
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
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'createOnlineRoom failed');
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
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'coin refresh failed');
    }
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
                    } catch (error, stack) {
                      ErrorReporter.record(
                        error,
                        stack,
                        reason: 'joinOnlineRoom failed',
                      );
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
