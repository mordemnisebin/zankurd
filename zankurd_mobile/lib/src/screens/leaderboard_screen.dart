import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import 'quiz_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.repository,
    this.scrollController,
    super.key,
  });

  final ZanKurdRepository repository;
  final ScrollController? scrollController;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<LeaderboardEntry>> _future;
  Timer? _refreshTimer;
  LeaderboardPeriod _period = LeaderboardPeriod.weekly;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    _loadData();
    _startAutoRefresh();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final periods = [
      LeaderboardPeriod.daily,
      LeaderboardPeriod.weekly,
      LeaderboardPeriod.monthly,
    ];
    setState(() {
      _period = periods[_tabController.index];
    });
    _loadData();
  }

  void _loadData() {
    setState(() {
      _future = widget.repository.loadLeaderboard(limit: 10, period: _period);
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _startQuickRace() async {
    final questions = await widget.repository.loadQuestions(limit: 10);
    if (!mounted) return;
    final raceQuestions = questions.isEmpty
        ? widget.repository.questions
        : questions;
    Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: widget.repository.createRoom(),
          questions: raceQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: Column(
          children: [
            _Header(ku: ku, onRefresh: _loadData),
            _PeriodTabs(controller: _tabController, ku: ku),
            Expanded(
              child: FutureBuilder<List<LeaderboardEntry>>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 2.5,
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return AppErrorState(
                      title: ku ? 'Tabloya barnekirî' : 'Yüklenemedi',
                      message: ku
                          ? 'Girêdanê kontrol bike û dîsa bicerib.'
                          : 'Bağlantıyı kontrol edip tekrar dene.',
                      retryLabel: ku ? 'Dîsa Bicerib' : 'Tekrar Dene',
                      onRetry: _loadData,
                    );
                  }
                  final entries = snap.data ?? [];
                  if (entries.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: ku ? 'Hîn xal tune' : 'Henüz puan yok',
                      message: ku
                          ? 'Pêşbirkekê dest pê bike.'
                          : 'Bir yarış başlat; puanların burada görünür.',
                      actionLabel: ku
                          ? 'Pêşbirkê Dest Pê Bike'
                          : 'Yarışa Başla',
                      actionIcon: Icons.bolt_rounded,
                      onAction: _startQuickRace,
                    );
                  }
                  return ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _Podium(entries: entries.take(3).toList(), isKu: ku),
                      const SizedBox(height: 12),
                      for (final e in entries.skip(3))
                        _RankRow(entry: e, isKu: ku),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.ku, required this.onRefresh});

  final bool ku;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.gold, AppTheme.primaryGradientStart],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ku ? 'Tabloya Pêşderiyan' : 'Liderlik Tablosu',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ku
                      ? 'Her 30 çirkeyî nûve dibe'
                      : 'Her 30 saniyede güncellenir',
                  style: TextStyle(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor(context).withValues(alpha: 0.5),
              ),
            ),
            child: IconButton(
              onPressed: onRefresh,
              icon: Icon(
                Icons.refresh_rounded,
                color: AppTheme.textSubColor(context),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period Tabs ─────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.controller, required this.ku});

  final TabController controller;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final labels = ku
        ? ['Roj', 'Heft', 'Meh']
        : ['Günlük', 'Haftalık', 'Aylık'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppTheme.textPrimaryColor(context),
        unselectedLabelColor: AppTheme.textMutedColor(context),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        indicator: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}

// ─── Podium (top 3) ──────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.isKu});

  final List<LeaderboardEntry> entries;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    // Yerleşim: 2. sol, 1. orta (daha büyük), 3. sağ
    final slots = [
      if (second != null) _PodiumSlot(entry: second, isCenter: false),
      if (first != null) _PodiumSlot(entry: first, isCenter: true),
      if (third != null) _PodiumSlot(entry: third, isCenter: false),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2C21), Color(0xFF163E30), Color(0xFF1A4E3B)],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5F47).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: slots.map((s) => Expanded(child: s)).toList(),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.entry, required this.isCenter});

  final LeaderboardEntry entry;
  final bool isCenter;

  static const _gold = Color(0xFFFFB800);
  static const _silver = Color(0xFF9AA6B4);
  static const _bronze = Color(0xFFB66A3A);

  Color get _color {
    switch (entry.rank) {
      case 1:
        return _gold;
      case 2:
        return _silver;
      default:
        return _bronze;
    }
  }

  IconData get _medalIcon {
    if (entry.rank == 1) return Icons.emoji_events_rounded;
    return Icons.military_tech_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final avatarR = isCenter ? 26.0 : 21.0;
    final nameFontSz = isCenter ? 13.5 : 12.0;
    final scoreFontSz = isCenter ? 15.5 : 13.5;

    // Outer Column uses center alignment so the inner Container shrink-wraps
    // to intrinsic width (required by the landscape-width test).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: ValueKey('podium-slot-${entry.rank}'),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_medalIcon, color: color, size: isCenter ? 28 : 22),
              const SizedBox(height: 6),
              PlayerAvatar(
                radius: avatarR,
                photoUrl: entry.avatarUrl,
                iconId: entry.avatarIcon,
                colorHex: entry.avatarColor,
                frameId: entry.avatarFrame,
                displayName: entry.displayName,
              ),
              const SizedBox(height: 6),
              Text(
                entry.displayName,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: nameFontSz,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (entry.showcaseTitle != null)
                Text(
                  entry.showcaseTitle!,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${entry.totalScore}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: scoreFontSz,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 4),
              Text(
                '#${entry.rank}',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Rank Row (4-10) ─────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isKu});

  final LeaderboardEntry entry;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.borderColor(context),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: AppTheme.textSubColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PlayerAvatar(
            radius: 18,
            photoUrl: entry.avatarUrl,
            iconId: entry.avatarIcon,
            colorHex: entry.avatarColor,
            frameId: entry.avatarFrame,
            displayName: entry.displayName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  entry.showcaseTitle != null
                      ? '${entry.showcaseTitle} · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}'
                      : '${entry.roomsPlayed} ${isKu ? "jûr" : "oda"}'
                            ' · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}',
                  style: TextStyle(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.totalScore}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
