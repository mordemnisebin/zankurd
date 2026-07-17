import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _section = 0;
  String _category = 'Hemû';

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Material(
      color: AppTheme.bgOf(context),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xs,
              ),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: Text(ku ? 'Lîg' : 'Ligler'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.people_outline_rounded),
                    label: Text(ku ? 'Heval' : 'Arkadaşlar'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
            ),
          ),
          if (_section == 0)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: [
                  for (final category in const [
                    'Hemû',
                    'Ziman',
                    'Dîrok',
                    'Çand',
                    'Wêje',
                    'Muzîk',
                    'Erdnîgarî',
                    'Siyaset',
                    'Teknolojî',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        key: ValueKey('league-category-$category'),
                        label: Text(
                          category == 'Hemû' && !ku ? 'Tümü' : category,
                        ),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              key: const ValueKey('friend-quest-card'),
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xs,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppTheme.playCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppTheme.playCyan.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.handshake_outlined,
                    color: AppTheme.playCyan,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      ku
                          ? 'Bi hev re 10 bersivên rast'
                          : 'Birlikte 10 doğru cevap',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _section,
              children: [
                LeaderboardScreen(repository: widget.repository),
                FriendsScreen(repository: widget.repository),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
