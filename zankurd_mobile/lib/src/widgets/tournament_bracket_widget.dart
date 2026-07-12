import 'package:flutter/material.dart';

import '../models/tournament.dart';
import '../theme/app_theme.dart';
import 'player_avatar.dart';

/// Visual single-elimination tournament bracket with connecting lines,
/// player avatars, scores, and winner highlighting.
///
/// Supports 8 or 16 player brackets shown across 3-4 rounds.
class TournamentBracketWidget extends StatelessWidget {
  const TournamentBracketWidget({
    required this.bracket,
    required this.userId,
    required this.ku,
    this.onTapMatch,
    super.key,
  });

  final TournamentBracket bracket;
  final String userId;
  final bool ku;
  final void Function(TournamentMatch match, int roundIndex)? onTapMatch;

  List<String> get _roundNames => ku
      ? const ['Dawiya 16an', 'Çaryeka Fînalê', 'Nîv-Fînal', 'Fînal']
      : const ['Son 16', 'Çeyrek Final', 'Yarı Final', 'Final'];

  @override
  Widget build(BuildContext context) {
    if (bracket.rounds.isEmpty) return const SizedBox.shrink();

    final totalRounds = bracket.rounds.length;
    // Horizontal scroll for mobile: the bracket can be wide.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < totalRounds; i++) ...[
              if (i > 0)
                _ConnectorColumn(roundIndex: i, roundCount: totalRounds),
              _RoundColumn(
                round: bracket.rounds[i],
                roundName: _roundNames[i],
                userId: userId,
                ku: ku,
                isActive: i == bracket.currentRound,
                isCompleted: i < bracket.currentRound,
                matchCount: bracket.rounds[i].matches.length,
                onTapMatch: (match) => onTapMatch?.call(match, i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vertical column for one round showing all match cards.
class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.round,
    required this.roundName,
    required this.userId,
    required this.ku,
    required this.isActive,
    required this.isCompleted,
    required this.matchCount,
    required this.onTapMatch,
  });

  final TournamentRound round;
  final String roundName;
  final String userId;
  final bool ku;
  final bool isActive;
  final bool isCompleted;
  final int matchCount;
  final void Function(TournamentMatch match) onTapMatch;

  @override
  Widget build(BuildContext context) {
    final spacingFactor = matchCount <= 2 ? 3.0 : (matchCount <= 4 ? 1.5 : 0.7);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Round header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.accent.withValues(alpha: 0.2)
                : isCompleted
                ? AppTheme.gold.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: isActive
                ? Border.all(color: AppTheme.accent.withValues(alpha: 0.5))
                : isCompleted
                ? Border.all(color: AppTheme.gold.withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            roundName,
            style: AppTypography.caption.copyWith(
              color: isActive
                  ? AppTheme.accent
                  : isCompleted
                  ? AppTheme.gold
                  : AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // Match cards centered in available space
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final match in round.matches)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: spacingFactor * 8),
                  child: _BracketMatchCard(
                    match: match,
                    userId: userId,
                    ku: ku,
                    onTap: () => onTapMatch(match),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Connector lines between rounds showing the bracket links.
class _ConnectorColumn extends StatelessWidget {
  const _ConnectorColumn({required this.roundIndex, required this.roundCount});

  final int roundIndex;
  final int roundCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: CustomPaint(
        size: Size(28, double.infinity),
        painter: _ConnectorPainter(
          roundIndex: roundIndex,
          roundCount: roundCount,
          color: AppTheme.borderColor(context),
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.roundIndex,
    required this.roundCount,
    required this.color,
  });

  final int roundIndex;
  final int roundCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final matchCountPrev = 16 >> roundIndex; // 16, 8, 4, 2
    final matchCountCurr = 16 >> (roundIndex + 1); // 8, 4, 2, 1

    if (matchCountPrev <= 0 || matchCountCurr <= 0) return;

    // Draw horizontal connecting lines
    final rowHeight = size.height / matchCountPrev;

    for (int i = 0; i < matchCountCurr; i++) {
      final topY = (i * 2) * rowHeight + rowHeight / 2;
      final bottomY = (i * 2 + 1) * rowHeight + rowHeight / 2;
      final midY = (topY + bottomY) / 2;
      final midX = size.width / 2;

      // Vertical line connecting top and bottom match outputs
      canvas.drawLine(Offset(midX, topY), Offset(midX, bottomY), paint);

      // Horizontal lines from edges to vertical
      canvas.drawLine(Offset(0, topY), Offset(midX, topY), paint);
      canvas.drawLine(Offset(0, bottomY), Offset(midX, bottomY), paint);

      // Horizontal line from vertical to next round
      canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Single match card in the bracket with player avatars, names, scores,
/// and winner gold highlight.
class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({
    required this.match,
    required this.userId,
    required this.ku,
    required this.onTap,
  });

  final TournamentMatch match;
  final String userId;
  final bool ku;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = match.status == 'completed';
    final hasPlayers =
        match.playerOneId.isNotEmpty && match.playerTwoId.isNotEmpty;
    final isUserMatch =
        match.playerOneId == userId || match.playerTwoId == userId;

    final p1Won = isCompleted && match.winnerId == match.playerOneId;
    final p2Won = isCompleted && match.winnerId == match.playerTwoId;

    final cardWidth = 150.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        width: cardWidth,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isUserMatch
              ? AppTheme.accent.withValues(alpha: 0.08)
              : AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: isUserMatch
                ? AppTheme.accent.withValues(alpha: 0.5)
                : isCompleted
                ? AppTheme.gold.withValues(alpha: 0.4)
                : AppTheme.borderColor(context).withValues(alpha: 0.6),
            width: isUserMatch ? 1.5 : 0.8,
          ),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerSlot(
              name: match.playerOneName,
              playerId: match.playerOneId,
              score: match.playerOneScore,
              isWinner: p1Won,
              isUser: match.playerOneId == userId,
              isCompleted: isCompleted,
              ku: ku,
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.gold.withValues(alpha: 0.15)
                          : AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCompleted
                          ? (ku ? 'Bİ DAWÎ BÛ' : 'BİTTİ')
                          : hasPlayers
                          ? 'VS'
                          : '—',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isCompleted
                            ? AppTheme.gold
                            : AppTheme.accent.withValues(alpha: 0.7),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            _PlayerSlot(
              name: match.playerTwoName,
              playerId: match.playerTwoId,
              score: match.playerTwoScore,
              isWinner: p2Won,
              isUser: match.playerTwoId == userId,
              isCompleted: isCompleted,
              ku: ku,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual player row inside a bracket match card.
class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({
    required this.name,
    required this.playerId,
    required this.score,
    required this.isWinner,
    required this.isUser,
    required this.isCompleted,
    required this.ku,
  });

  final String name;
  final String playerId;
  final int score;
  final bool isWinner;
  final bool isUser;
  final bool isCompleted;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final placeholder = ku ? 'Nediyar' : 'Belirsiz';
    final displayName = name == 'TBD' || name.isEmpty ? placeholder : name;
    final isDimmed = isCompleted && !isWinner;
    final hasPlayer = name.isNotEmpty && name != 'TBD';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isWinner
            ? AppTheme.gold.withValues(alpha: 0.18)
            : isUser
            ? AppTheme.accent.withValues(alpha: 0.06)
            : null,
        borderRadius: BorderRadius.circular(6),
        border: isWinner
            ? Border.all(
                color: AppTheme.gold.withValues(alpha: 0.5),
                width: 1.2,
              )
            : null,
      ),
      child: Row(
        children: [
          // Player avatar
          if (hasPlayer)
            PlayerAvatar(
              radius: 12,
              displayName: displayName,
              iconId: _playerIconId(playerId),
              colorHex: _playerColorHex(playerId),
            )
          else
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.textMutedColor(context).withValues(alpha: 0.2),
              ),
              child: Icon(
                Icons.person_outline,
                size: 14,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          const SizedBox(width: 6),
          // Player name
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isUser ? FontWeight.w800 : FontWeight.w600,
                color: isWinner
                    ? AppTheme.gold
                    : isDimmed
                    ? AppTheme.textMutedColor(context)
                    : isUser
                    ? AppTheme.accent
                    : AppTheme.textPrimaryColor(context),
                decoration: isDimmed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          // Winner crown icon
          if (isWinner)
            const Icon(
              Icons.emoji_events_rounded,
              size: 14,
              color: AppTheme.gold,
            )
          else if (isCompleted && hasPlayer)
            Icon(
              Icons.cancel_outlined,
              size: 12,
              color: AppTheme.textMutedColor(context).withValues(alpha: 0.6),
            )
          else if (score > 0) ...[
            const SizedBox(width: 2),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Deterministic icon selection for bot players based on playerId.
String? _playerIconId(String playerId) {
  if (playerId.isEmpty || playerId == 'TBD') return null;
  const icons = [
    'tembur',
    'dengbej',
    'ciya',
    'roj',
    'pirtuk',
    'newroz',
    'ster',
    'pen',
    'cihan',
    'mertal',
    'tac',
    'gul',
    'dar',
    'cav',
    'birusk',
    'kupa',
  ];
  final hash = playerId.hashCode.abs();
  return icons[hash % icons.length];
}

/// Deterministic color selection for bot players based on playerId.
String? _playerColorHex(String playerId) {
  if (playerId.isEmpty || playerId == 'TBD') return null;
  const colors = [
    '#E94560',
    '#7C3AED',
    '#2563EB',
    '#10B981',
    '#F59E0B',
    '#EC4899',
    '#0EA5E9',
    '#F97316',
    '#8B5CF6',
    '#06B6D4',
    '#84CC16',
    '#EF4444',
    '#14B8A6',
    '#D946EF',
    '#F43F5E',
    '#6366F1',
  ];
  final hash = playerId.hashCode.abs();
  return colors[hash % colors.length];
}
