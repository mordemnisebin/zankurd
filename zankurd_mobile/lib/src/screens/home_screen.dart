import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import 'home/daily_missions_card.dart';
import 'home/hero_card.dart';
import 'home/quick_play_grid.dart';
import 'home/section_header.dart';
import '../widgets/animated_counter.dart';
import '../data/daily_mission_store.dart';
import '../models/daily_mission.dart';
import 'quiz_screen.dart';
import 'room_screen.dart';
import 'matchmaking_screen.dart';
import 'spin_wheel_screen.dart';
import 'tournament_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    this.scrollController,
    this.refreshSignal,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
  final ScrollController? scrollController;

  /// Ana Sayfa sekmesi yeniden seçildiğinde tetiklenir; coin bakiyesi ve
  /// görevler tazelenir. Kategoriler sekmesinden başlatılan solo seviye
  /// quizleri bu ekranın _refreshCoins'ini doğrudan çağıramaz (farklı bir
  /// Navigator dalında yaşarlar), bu yüzden dönüşte sekmeye tekrar
  /// basıldığında tazeleme burada yapılır.
  final Listenable? refreshSignal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<QuizQuestion> _questions = widget.repository.questions;
  bool _roomActionLoading = false;
  bool _dailyLoading = false;
  int? _coinBalance;
  int _streak = 0;
  List<DailyMission> _missions = [];
  bool _missionsLoading = true;
  late GameRoom _room;
  late AnimationController _loadAnimationController;
  String? _displayName;

  ZanKurdRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _loadAnimationController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    if (isFlutterTestEnvironment) {
      _loadAnimationController.value = 1.0;
    } else {
      _loadAnimationController.forward();
    }
    _room = repo.createRoom();
    _bootstrap();
    _refreshStreak();
    _loadMissions();
    widget.refreshSignal?.addListener(_handleRefreshSignal);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefreshSignal);
    _loadAnimationController.dispose();
    super.dispose();
  }

  /// Ana Sayfa sekmesine dönüldüğünde coin bakiyesini ve görevleri tazeler.
  void _handleRefreshSignal() {
    if (!mounted) return;
    _refreshCoins();
    _loadMissions();
    _refreshStreak();
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
      final name = await repo.getProfileName();
      if (mounted) {
        setState(() {
          _displayName = name;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home ensureProfile failed');
    }

    try {
      final qs = await repo.loadQuestions(limit: 10);
      final coins = await repo.loadCoinBalance();
      if (!mounted) return;
      setState(() {
        _questions = qs.isEmpty ? repo.questions : qs;
        _coinBalance = coins;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home bootstrap load failed');
      if (!mounted) return;
      setState(() {
        _questions = repo.questions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final bottomContentPadding = MediaQuery.paddingOf(context).bottom + 112;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 720;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surfaceColor(context),
            elevation: 0,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final double topPadding = MediaQuery.of(context).padding.top;
                final double collapsedHeight = kToolbarHeight + topPadding;
                final isCollapsed =
                    constraints.maxHeight <= collapsedHeight + 20;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: const Text(
                    'ZanKurd​',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
          if (isWide)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnimatedCard(
                            _heroFadeAnimation(0),
                            HeroCard(
                              isKu: ku,
                              loading: _roomActionLoading,
                              onCreateRoom: () => _createOnlineRoom(context),
                              onJoinRoom: () => _showJoinSheet(context),
                              onQuickMatch: () => _openQuiz(context, _room),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildAnimatedCard(
                            _heroFadeAnimation(2),
                            DailyMissionsCard(
                              isKu: ku,
                              missions: _missions,
                              loading: _missionsLoading,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnimatedCard(
                            _heroFadeAnimation(1),
                            SectionHeader(
                              title: ku ? 'Zû Bilîze' : 'Hemen Oyna',
                              subtitle: ku
                                  ? 'Yarî, xelat û pêşbirkên rojane'
                                  : 'Oyunlar, ödüller ve günlük yarışmalar',
                              icon: Icons.flash_on_rounded,
                              accentColor: AppTheme.gold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildAnimatedCard(
                            _heroFadeAnimation(1),
                            QuickPlayGrid(
                              isKu: ku,
                              dailyQuizLoading: _dailyLoading,
                              onDuel: () => Navigator.of(context).push(
                                AppRoute.to(
                                  MatchmakingScreen(repository: repo),
                                ),
                              ),
                              onDailyQuiz: () => _openDailyQuiz(context, ku),
                              onSpinWheel: () => _openSpinWheel(context),
                              onTournament: () => _openTournament(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(1),
                        SectionHeader(
                          title: ku ? 'Zû Bilîze' : 'Hemen Oyna',
                          subtitle: ku
                              ? 'Yarî, xelat û pêşbirkên rojane'
                              : 'Oyunlar, ödüller ve günlük yarışmalar',
                        ),
                      ),
                    );
                  }
                  if (index == 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(1),
                        QuickPlayGrid(
                          isKu: ku,
                          dailyQuizLoading: _dailyLoading,
                          onDuel: () => Navigator.of(context).push(
                            AppRoute.to(MatchmakingScreen(repository: repo)),
                          ),
                          onDailyQuiz: () => _openDailyQuiz(context, ku),
                          onSpinWheel: () => _openSpinWheel(context),
                          onTournament: () => _openTournament(context),
                        ),
                      ),
                    );
                  }
                  if (index == 3) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildAnimatedCard(
                        _heroFadeAnimation(2),
                        DailyMissionsCard(
                          isKu: ku,
                          missions: _missions,
                          loading: _missionsLoading,
                        ),
                      ),
                    );
                  }
                  return null;
                }, childCount: 4),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding)),
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
            Icon(Icons.stars, color: AppTheme.gold, size: 14),
            const SizedBox(width: 6),
            Text(
              ku ? 'Hemû misyon temam bûn!' : 'Tüm görevler tamamlandı!',
              style: TextStyle(
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
          Icon(Icons.flash_on, color: AppTheme.gold, size: 14),
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
              style: TextStyle(
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
              style: TextStyle(
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

  Widget _buildGeometricHeader(BuildContext context, bool ku) {
    final isTest = isFlutterTestEnvironment;
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
    final currentName = _displayName ?? widget.displayName;
    final greeting = ku
        ? '$greetingKu, ${currentName ?? 'Lîstikvan'}!'
        : '$greetingTr, ${currentName ?? 'Oyuncu'}!';

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.homeHeaderGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const RojPatternPainter()),
          ),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ZanKurd',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
          if (_streak > 0)
            Positioned(top: 16, right: 18, child: _buildStreakHexagon(_streak)),
          Positioned(left: 18, top: 16, child: _buildCoinGemRow(_coinBalance)),
        ],
      ),
    );
  }

  Widget _buildStreakHexagon(int streak) {
    final pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 1),
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoinGemRow(int? coinBalance) {
    if (coinBalance == null) return const SizedBox.shrink();

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context)
              .push(AppRoute.to(ShopScreen(repository: repo)))
              .then((_) => _refreshCoins()),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: AppTheme.gold,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    AnimatedCounter(
                      value: coinBalance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCard(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  Animation<double> _heroFadeAnimation(int index) {
    final startTime = (index * 0.1).clamp(0.0, 1.0).toDouble();
    final endTime = (startTime + 0.3).clamp(startTime, 1.0).toDouble();
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadAnimationController,
        curve: Interval(startTime, endTime, curve: Curves.easeOut),
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
                ? 'Odeya serhêl nehate vekirin. Ji kerema xwe dîsa biceribîne.'
                : 'Çevrimiçi oda açılamadı. Lütfen tekrar deneyin.',
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

  Future<void> _openTournament(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(TournamentScreen(repository: repo)));
    _refreshCoins();
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
                  ku ? 'Tevlî Odeyê Bibe' : 'Odaya Katıl',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: ku ? 'Koda odeyê' : 'Oda kodu',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return ku ? 'Koda odeyê pêwîst e.' : 'Oda kodu gerekli.';
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
                                  ? 'Tevlî odeya serhêl nebû. Ji kerema xwe kodê kontrol bike.'
                                  : 'Çevrimiçi odaya katılınamadı. Lütfen kodu kontrol edin.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.meeting_room_outlined),
                    label: Text(ku ? 'Tevlî Bibe' : 'Katıl'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    });
  }
}

class RojPatternPainter extends CustomPainter {
  const RojPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Güneş merkezi (Sağ üst / ortalama bölge)
    final center = Offset(size.width * 0.85, size.height * 0.45);

    // Güneş halkaları
    canvas.drawCircle(center, 30, paint);
    canvas.drawCircle(center, 42, paint);

    // Güneş Işınları (Roj / 12 ışın)
    final rayCount = 12;
    final innerRadius = 46.0;
    final outerRadius = 70.0;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * 3.1415926535) / rayCount;
      final start = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }

    // Geometrik kilim/dağ çizgileri
    final kilimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = -50; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i + 120, size.height), kilimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
