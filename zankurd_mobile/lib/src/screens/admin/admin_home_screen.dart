import 'package:flutter/material.dart';

import '../../utils/number_format.dart';

import '../../data/admin_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/admin.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../widgets/sahne/sahne.dart';
import 'admin_notify_screen.dart';
import 'admin_content_screen.dart';
import 'admin_rewards_screen.dart';
import 'admin_users_screen.dart';
import 'admin_widgets.dart';

/// Yönetim ana ekranı: pano (yalnız toplam sayılar), bölümlere giriş ve son
/// işlemler (2.2).
///
/// Yalnız sahip hesabında açılır (bkz. [AdminEntryRow]); sunucu her
/// çağrıda yetkiyi yeniden denetler.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.repository});

  final AdminRepository repository;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(AppRoute.to(page));

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: context.t(K.adminEntry),
      children: [
        AdminNote(context.t(K.adminOwnerNote)),
        AdminLoader<_HomeData>(
          load: () async => _HomeData(
            await repository.loadStats(),
            await repository.loadRecentActions(),
          ),
          builder: (context, data, reload) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SahneSectionHeader(title: context.t(K.adminOverviewTitle)),
              _StatGrid(stats: data.stats),
              const SizedBox(height: SahneSpace.cardGap),
              _ModeUsageCard(usage: data.stats.modeUsage),
              const SizedBox(height: SahneSpace.x2),
              AdminNote(context.t(K.adminTotalsNote)),
              SahneSectionHeader(title: context.t(K.adminWaiting)),
              SahneListGroup(
                children: [
                  SahneListRow.icon(
                    key: const ValueKey('admin-open-questions'),
                    icon: AppIcons.listCheck,
                    role: SahneRole.learn,
                    title: context.t(K.adminQuestionsTitle),
                    subtitle: context.t(K.adminSecQuestionsSub),
                    trailing: _countBadge(data.stats.pendingSuggestions),
                    chevron: true,
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppRoute.to(
                          AdminQuestionsScreen(repository: repository),
                        ),
                      );
                      await reload();
                    },
                  ),
                  SahneListRow.icon(
                    key: const ValueKey('admin-open-rewards'),
                    icon: AppIcons.trophy,
                    role: SahneRole.gold,
                    title: context.t(K.adminRewardsTitle),
                    subtitle: context.t(K.adminSecRewardsSub),
                    chevron: true,
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppRoute.to(AdminRewardsScreen(repository: repository)),
                      );
                      await reload();
                    },
                  ),
                  SahneListRow.icon(
                    key: const ValueKey('admin-open-users'),
                    icon: AppIcons.gavel,
                    role: SahneRole.race,
                    title: context.t(K.adminUsersTitle),
                    subtitle: context.t(K.adminSecUsersSub),
                    trailing: _countBadge(data.stats.openReports),
                    chevron: true,
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppRoute.to(AdminUsersScreen(repository: repository)),
                      );
                      await reload();
                    },
                  ),
                  SahneListRow.icon(
                    key: const ValueKey('admin-open-notify'),
                    icon: AppIcons.bell,
                    title: context.t(K.adminSecNotify),
                    subtitle: context.t(K.adminSecNotifySub),
                    chevron: true,
                    onTap: () => _open(
                      context,
                      AdminNotifyScreen(repository: repository),
                    ),
                  ),
                ],
              ),
              SahneSectionHeader(title: context.t(K.adminRecentActions)),
              if (data.recent.isEmpty)
                AdminEmpty(context.t(K.adminNoActions))
              else
                SahneListGroup(
                  children: [
                    for (final entry in data.recent)
                      SahneListRow.plain(
                        title: _actionLabel(context, entry.action),
                        subtitle: [
                          entry.target,
                          adminTime(entry.at),
                        ].join(' · '),
                      ),
                  ],
                ),
              if (repository.isSample) ...[
                const SizedBox(height: SahneSpace.x4),
                AdminNote(context.t(K.adminMockNote)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Widget? _countBadge(int count) => count > 0
      ? SahneBadge(label: '${groupThousands(count)}', tone: SahneBadgeTone.gold)
      : null;
}

class _HomeData {
  const _HomeData(this.stats, this.recent);

  final AdminStats stats;
  final List<AdminAuditEntry> recent;
}

/// Denetim işleminin kullanıcı dilindeki adı.
String _actionLabel(BuildContext context, AdminAuditAction action) =>
    context.t(switch (action) {
      AdminAuditAction.approve => K.adminActApprove,
      AdminAuditAction.reject => K.adminActReject,
      AdminAuditAction.fix => K.adminActFix,
      AdminAuditAction.retire => K.adminActRetire,
      AdminAuditAction.dismiss => K.adminActDismiss,
      AdminAuditAction.reward => K.adminActReward,
      AdminAuditAction.warn => K.adminActWarn,
      AdminAuditAction.block => K.adminActBlock,
      AdminAuditAction.suspend => K.adminActSuspend,
      AdminAuditAction.lift => K.adminActLift,
    });

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, int?)>[
      (context.t(K.adminStatUsers), stats.totalUsers),
      (context.t(K.adminStatActiveToday), stats.activeToday),
      (context.t(K.adminStatActiveWeek), stats.activeWeek),
      (context.t(K.adminStatNewToday), stats.newToday),
      (context.t(K.adminStatNewWeek), stats.newWeek),
      (context.t(K.adminStatCrashes), stats.crashesWeek),
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: SahneSpace.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StatTile(tiles[i].$1, tiles[i].$2)),
                const SizedBox(width: SahneSpace.cardGap),
                Expanded(child: _StatTile(tiles[i + 1].$1, tiles[i + 1].$2)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value);

  final String label;

  /// `null` = bilinmiyor (sunucuda yok): "—" çizilir.
  final int? value;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      semanticLabel: '$label: ${value ?? '—'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value == null ? '—' : '$value',
            style: SahneType.title.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(label, style: SahneType.caption.copyWith(color: t.tx2)),
        ],
      ),
    );
  }
}

class _ModeUsageCard extends StatelessWidget {
  const _ModeUsageCard({required this.usage});

  final Map<String, int> usage;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final rows = <(String, int)>[
      (context.t(K.adminModeSolo), usage['solo'] ?? 0),
      (context.t(K.adminModeRoom), usage['room'] ?? 0),
      (context.t(K.quickDuel), usage['duel'] ?? 0),
      (context.t(K.tournament), usage['tournament'] ?? 0),
      (context.t(K.dailyContest), usage['contest'] ?? 0),
    ];
    final maxValue = rows.fold<int>(1, (m, r) => r.$2 > m ? r.$2 : m);
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.adminModeUsage),
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x3),
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ),
                Text(
                  '${row.$2}',
                  style: SahneType.captionStrong.copyWith(color: t.tx),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x1),
            SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (row.$2 > 0)
                    Expanded(
                      flex: row.$2,
                      child: ColoredBox(color: t.learn),
                    ),
                  if (maxValue - row.$2 > 0)
                    Expanded(
                      flex: maxValue - row.$2,
                      child: ColoredBox(color: t.s3),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SahneSpace.x3),
          ],
        ],
      ),
    );
  }
}
