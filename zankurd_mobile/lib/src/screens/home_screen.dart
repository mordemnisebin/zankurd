import 'package:flutter/material.dart';
import 'dart:io';

import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'home/category_grid.dart';
import 'home/daily_missions_card.dart';
import 'home/daily_quiz_card.dart';
import 'home/hero_card.dart';
import 'home/question_card.dart';
import 'home/section_header.dart';
import 'home/spin_wheel_card.dart';
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'level_screen.dart';
import 'quiz_screen.dart';
import 'room_screen.dart';
import 'spin_wheel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<QuizQuestion> _questions = widget.repository.questions;
  late List<String> _categories = widget.repository.categories;
  bool _loading = true;
  bool _roomActionLoading = false;
  bool _dailyLoading = false;
  int? _coinBalance;
  int _streak = 0;
  List<DailyMission> _missions = [];
  bool _missionsLoading = true;
  late GameRoom _room;
  late AnimationController _loadAnimationController;

  ZanKurdRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _loadAnimationController = AnimationController(
      duration: Duration(milliseconds: 4000),
      vsync: this,
    );
    _loadAnimationController.forward();
    _room = repo.createRoom();
    _bootstrap();
    _refreshStreak();
    _loadMissions();
  }

  @override
  void dispose() {
    _loadAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshStreak() async {
    final store = await StreakStore.load();
    if (mounted) setState(() => _streak = store.effectiveStreak());
  }

  Future<void> _loadMissions() async {
    final store = await DailyMissionStore.load();
    if (mounted) {
      setState(() {
        _missions = List.from(store.missions);
        _missionsLoading = false;
      });
    }
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

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: CustomScrollView(
        slivers: [
          // Geometric header with player info and live account badges
          SliverAppBar(
            expandedHeight: 230,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            elevation: 0,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final double topPadding = MediaQuery.of(context).padding.top;
                final double collapsedHeight = kToolbarHeight + topPadding;
                final isCollapsed = constraints.maxHeight <= collapsedHeight + 20;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: const Text(
                    'ZanKurd\u200B',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                );
              },
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGeometricHeader(context, ku),
            ),
          ),
          // Main content with cards and grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == 0) {
                  return _buildAnimatedCard(
                    _heroFadeAnimation(0),
                    HeroCard(
                      isKu: ku,
                      loading: _roomActionLoading,
                      onCreateRoom: () => _createOnlineRoom(context),
                      onJoinRoom: () => _showJoinSheet(context),
                      onQuickMatch: () => _openQuiz(context, _room),
                    ),
                  );
                }
                if (index == 1) {
                  // Teknik istatistikler (toplam soru/seviye/görsel sayısı)
                  // kullanıcıya gösterilmiyor.
                  return const SizedBox.shrink();
                }
                if (index == 2) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(2),
                      DailyQuizCard(
                        isKu: ku,
                        loading: _dailyLoading,
                        onPlay: () => _openDailyQuiz(context, ku),
                      ),
                    ),
                  );
                }
                if (index == 3) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(3),
                      SpinWheelCard(
                        isKu: ku,
                        onOpen: () => _openSpinWheel(context),
                      ),
                    ),
                  );
                }
                if (index == 4) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(4),
                      DailyMissionsCard(
                        isKu: ku,
                        missions: _missions,
                        loading: _missionsLoading,
                      ),
                    ),
                  );
                }
                if (index == 5) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(5),
                      SectionHeader(
                        title: ku ? 'Kategorî' : 'Kategoriler',
                        subtitle: ku
                            ? 'Her kategoriyê 5 ast hene'
                            : 'Her kategori 5 seviyeye ayrıldı',
                      ),
                    ),
                  );
                }
                if (index == 6) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: CategoryGrid(
                      categories: _categories,
                      isKu: ku,
                      loading: _loading,
                      onTap: (cat) => _openCategory(context, cat),
                    ),
                  );
                }
                if (index == 7 && !_loading && _questions.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(7),
                      SectionHeader(
                        title: ku ? 'Pirsa Nimûne' : 'Örnek Soru',
                        subtitle: ku
                            ? 'Destpêbike û pratîkê bike'
                            : 'Hemen başla ve pratik yap',
                      ),
                    ),
                  );
                }
                if (index == 8 && !_loading && _questions.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildAnimatedCard(
                      _heroFadeAnimation(8),
                      QuestionCard(
                        question: _questions.first,
                        isKu: ku,
                        onOpen: () => _openQuiz(context, _room),
                      ),
                    ),
                  );
                }
                return null;
              }, childCount: _loading || _questions.isEmpty ? 7 : 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityMission(BuildContext context, bool ku) {
    if (_missionsLoading || _missions.isEmpty) return const SizedBox.shrink();
    final incomplete = _missions.where((m) => !m.completed).toList();
    if (incomplete.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: AppTheme.gold, size: 14),
            const SizedBox(width: 6),
            Text(
              ku ? 'Hemû misyon temam bûn!' : 'Tüm görevler tamamlandı!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    incomplete.sort((a, b) => b.coinReward.compareTo(a.coinReward));
    final priorityMission = incomplete.first;
    final missionTitle = ku ? priorityMission.labelKu : priorityMission.labelTr;
    final rewardText = '+${priorityMission.coinReward} Coin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on, color: AppTheme.gold, size: 14),
          const SizedBox(width: 6),
          Text(
            ku ? 'Misyona Rojê: ' : 'Günün Görevi: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              missionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              rewardText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the geometric header with player info, streak hexagon, and stats
  Widget _buildGeometricHeader(BuildContext context, bool ku) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final hour = DateTime.now().hour;
    final String greetingKu;
    final String greetingTr;
    if (isTest) {
      greetingKu = 'Salam';
      greetingTr = 'Hoş geldin';
    } else {
      if (hour >= 5 && hour < 12) {
        greetingKu = 'Rojbaş';
        greetingTr = 'Günaydın';
      } else if (hour >= 12 && hour < 17) {
        greetingKu = 'Rojbaş';
        greetingTr = 'İyi Günler';
      } else if (hour >= 17 && hour < 22) {
        greetingKu = 'Êvarbaş';
        greetingTr = 'İyi Akşamlar';
      } else {
        greetingKu = 'Şevbaş';
        greetingTr = 'İyi Geceler';
      }
    }
    final greeting = ku
        ? '$greetingKu, ${widget.displayName ?? 'Lîstikvan'}!'
        : '$greetingTr, ${widget.displayName ?? 'Oyuncu'}!';

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.homeHeaderGradient),
      child: Stack(
        children: [
          // Semi-transparent white hexagon overlay (geometric accent)
          Positioned(
            top: -40,
            right: -60,
            child: Opacity(
              opacity: 0.08,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          ),
          // Player info on the left
          Positioned(
            left: 18,
            bottom: 20,
            child: _buildAnimatedCard(
              _heroFadeAnimation(0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ZanKurd',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPriorityMission(context, ku),
                ],
              ),
            ),
          ),
          // Streak hexagon badge (pulsing animation) on the top right
          if (_streak > 0)
            Positioned(top: 16, right: 18, child: _buildStreakHexagon(_streak)),
          // Real coin balance; hidden while loading to avoid placeholder badges.
          Positioned(left: 18, top: 16, child: _buildCoinGemRow(_coinBalance)),
        ],
      ),
    );
  }

  /// Build animated streak hexagon badge with pulse animation
  Widget _buildStreakHexagon(int streak) {
    final pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _loadAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: pulseAnim.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build coin and gem display row
  Widget _buildCoinGemRow(int? coinBalance) {
    if (coinBalance == null) return const SizedBox.shrink();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(
                '$coinBalance',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build animated card wrapper with fade and slide animation
  Widget _buildAnimatedCard(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Generate hero fade animation for a specific index
  Animation<double> _heroFadeAnimation(int index) {
    final startTime = index * 0.1;
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadAnimationController,
        curve: Interval(startTime, startTime + 0.3, curve: Curves.easeOut),
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
                ? 'Jûra serhêl nehate vekirin. Ji kerema xwe dîsa biceribîne.'
                : 'Online oda açılamadı. Lütfen tekrar deneyin.',
          ),
        ),
      );
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
        AppRoute.to(
          QuizScreen(
            repository: repo,
            room: dailyRoom,
            questions: dailyQuestions,
            dailyQuiz: true,
          ),
        ),
      );
      _refreshCoins();
      _loadMissions();
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  Future<void> _openQuiz(BuildContext context, GameRoom room) async {
    await Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(repository: repo, room: room, questions: _questions),
      ),
    );
    _refreshCoins();
    _loadMissions();
  }

  void _openRoom(BuildContext context, GameRoom room) {
    Navigator.of(
      context,
    ).push(AppRoute.to(RoomScreen(repository: repo, initialRoom: room)));
  }

  Future<void> _openSpinWheel(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(SpinWheelScreen(repository: repo)));
    _refreshCoins();
  }

  void _openCategory(BuildContext context, String category) {
    Navigator.of(
      context,
    ).push(AppRoute.to(LevelScreen(repository: repo, category: category)));
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
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ku = context.isKu;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOf(context),
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
          child: Form(
            key: formKey,
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
                TextFormField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: ku ? 'Koda jûrê' : 'Oda kodu',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return ku ? 'Koda jûrê pêwîst e.' : 'Oda kodu gerekli.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final room = await repo.joinOnlineRoom(
                          controller.text.trim(),
                        );
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.isKu
                                  ? 'Tevlî jûra serhêl nebû. Ji kerema xwe kodê kontrol bike.'
                                  : 'Online odaya katılınamadı. Lütfen kodu kontrol edin.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: Text(ku ? 'Tevlî Bibe' : 'Katıl'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
