import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/friend.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/league_tier.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_state.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/player_avatar.dart';
import '../widgets/roj_mascot.dart';
import 'quiz_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.repository,
    this.scrollController,
    this.refreshSignal,
    super.key,
  });

  final ZanKurdRepository repository;
  final ScrollController? scrollController;
  final ValueNotifier<int>? refreshSignal;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<LeaderboardEntry>> _future;
  late Future<List<Friend>> _friendsFuture;
  Timer? _refreshTimer;
  LeaderboardPeriod _period = LeaderboardPeriod.weekly;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    _loadData();
    _startAutoRefresh();
    widget.refreshSignal?.addListener(_loadData);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final periods = [
      LeaderboardPeriod.daily,
      LeaderboardPeriod.weekly,
      LeaderboardPeriod.monthly,
    ];
    if (_tabController.index == 3) {
      // Friends tab
      setState(() {});
      return;
    }
    setState(() {
      _period = periods[_tabController.index];
    });
    _loadData();
  }

  void _loadData() {
    if (_tabController.index == 3) {
      setState(() {
        _friendsFuture = widget.repository.loadFriendsLeaderboard();
      });
    } else {
      setState(() {
        _future = widget.repository.loadLeaderboard(limit: 10, period: _period);
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_loadData);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Oturum sahibinin haftalık listedeki sırası; listede yoksa null.
  int? _myRank(List<LeaderboardEntry> entries) {
    final uid = widget.repository.currentUserId;
    if (uid == null) return null;
    for (final entry in entries) {
      if (entry.playerId == uid) return entry.rank;
    }
    return null;
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
              child: _tabController.index == 3
                  ? _buildFriendsTab(ku)
                  : _buildLeaderboardTab(ku),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(bool ku) {
    return FutureBuilder<List<Friend>>(
      future: _friendsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
              strokeWidth: 2.5,
            ),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: ku ? 'Heval nehatin barkirin' : 'Arkadaşlar yüklenemedi',
            message: ku
                ? 'Girêdanê kontrol bike û dîsa biceribîne.'
                : 'Bağlantıyı kontrol edip tekrar dene.',
            retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar dene',
            onRetry: _loadData,
          );
        }
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return AppEmptyState(
            icon: Icons.people_outline,
            title: ku ? 'Heval tune' : 'Arkadaş yok',
            message: ku
                ? 'Arkadaş ekleyerek sıralamanı gör!'
                : 'Arkadaş ekleyerek sıralamanı gör!',
          );
        }
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            for (final friend in friends)
              _FriendRankRow(friend: friend, isKu: ku),
          ],
        );
      },
    );
  }

  Widget _buildLeaderboardTab(bool ku) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
              strokeWidth: 2.5,
            ),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: ku ? 'Tabloya barnekirî' : 'Yüklenemedi',
            message: ku
                ? 'Girêdanê kontrol bike û dîsa biceribîne.'
                : 'Bağlantıyı kontrol edip tekrar dene.',
            retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar dene',
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
            actionLabel: ku ? 'Pêşbirkê Dest Pê Bike' : 'Yarışa Başla',
            actionIcon: Icons.bolt_rounded,
            onAction: _startQuickRace,
          );
        }
        return ListView(
          key: const ValueKey('leaderboard-compact-list'),
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            if (_period == LeaderboardPeriod.weekly) ...[
              _LeagueBanner(myRank: _myRank(entries), isKu: ku),
              const SizedBox(height: AppSpacing.cardGap),
            ],
            _Podium(entries: entries.take(3).toList(), isKu: ku),
            const SizedBox(height: AppSpacing.cardGap),
            for (final e in entries.skip(3)) _RankRow(entry: e, isKu: ku),
          ],
        );
      },
    );
  }
}

// ─── Haftalık Lig Bandı ──────────────────────────────────────────────────────

/// Haftalık ligde oyuncunun kademesini gösterir: Zêr / Zîv / Bronz.
/// Kademe canlı haftalık sıradan türetilir; Zêr'de Zana kutlama yapar.
class _LeagueBanner extends StatelessWidget {
  const _LeagueBanner({required this.myRank, required this.isKu});

  final int? myRank;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final tier = LeagueTier.forRank(myRank);
    final color = tier.color;
    final surface = AppTheme.surfaceHiColor(context);

    return Container(
      key: const ValueKey('league-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.alphaBlend(color.withValues(alpha: 0.22), surface),
            Color.alphaBlend(color.withValues(alpha: 0.06), surface),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (tier == LeagueTier.zer)
            const RojMascot(size: 44, mood: RojMood.celebrate)
          else
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(tier.icon, color: color, size: 22),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label(isKu),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  myRank != null
                      ? (isKu
                            ? 'Rêza te ya heftane: #$myRank'
                            : 'Bu haftaki sıran: #$myRank')
                      : (isKu
                            ? 'Vê heftê bilîze û bikeve lîgê!'
                            : 'Bu hafta yarış, lige gir!'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(tier.icon, color: color.withValues(alpha: 0.55), size: 28),
        ],
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: AppSpacing.sm, top: 2),
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
                  style: AppTypography.heading1.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  ku
                      ? 'Her 30 çirkeyî nûve dibe'
                      : 'Her 30 saniyede güncellenir',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppTheme.borderColor(context).withValues(alpha: 0.5),
              ),
            ),
            child: IconButton(
              key: const ValueKey('leaderboard-refresh-button'),
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
        ? ['Roj', 'Heft', 'Meh', 'Heval']
        : ['Günlük', 'Haftalık', 'Aylık', 'Arkadaşlar'];

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxs,
      ),
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppTheme.textPrimaryColor(context),
        unselectedLabelColor: AppTheme.textMutedColor(context),
        labelStyle: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.46),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        key: const ValueKey('leaderboard-podium'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.secondaryAccent, AppTheme.bgDeep],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KilimPatternPainter(
                    drawPattern: true,
                    color: Colors.white,
                    opacity: 0.05,
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: slots.map((s) => Expanded(child: s)).toList(),
            ),
          ],
        ),
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
                style: AppTypography.bodyLarge.copyWith(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
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
      key: ValueKey('leaderboard-rank-row-${entry.rank}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: AppTheme.statCard(context, AppTheme.gold).copyWith(
        border: Border.all(
          color: entry.rank <= 10
              ? AppTheme.gold.withValues(alpha: 0.22)
              : AppTheme.borderColor(context).withValues(alpha: 0.45),
        ),
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
                      : '${entry.roomsPlayed} ${isKu ? "ode" : "oda"}'
                            ' · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${entry.totalScore}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friend Rank Row (Arkadaşlar tab) ─────────────────────────────────────────

class _FriendRankRow extends StatelessWidget {
  const _FriendRankRow({required this.friend, required this.isKu});

  final Friend friend;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final online = friend.isOnline;
    return Container(
      key: ValueKey('friend-rank-row-${friend.friendId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: AppTheme.statCard(context, AppTheme.cyan).copyWith(
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          // Level badge
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
              '${friend.level}',
              style: TextStyle(
                color: AppTheme.textSubColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar with online dot
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                PlayerAvatar(
                  radius: 18,
                  colorHex: friend.friendAvatarColor,
                  displayName: friend.friendName,
                ),
                // Online status dot
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF9E9E9E),
                      border: Border.all(
                        color: AppTheme.surfaceColor(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.friendName,
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
                  online
                      ? (isKu ? 'Çevrimiçi' : 'Çevrimiçi')
                      : (isKu ? 'Offline' : 'Offline'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: online
                        ? const Color(0xFF4CAF50)
                        : AppTheme.textMutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${friend.totalScore}',
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
