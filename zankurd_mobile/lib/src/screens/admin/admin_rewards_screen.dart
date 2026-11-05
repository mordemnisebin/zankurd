import 'package:flutter/material.dart';

import '../../utils/number_format.dart';

import '../../data/admin_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/admin.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';
import 'admin_widgets.dart';

/// Ödüller (2.2): günün yarışması ya da haftalık sıralamanın ilk 3'üne tek
/// dokunuşla jeton / rozet. Otomatik ödül açıksa sunucu dönem sonunda
/// kendiliğinden verir; buradaki elle verme onu tamamlar. Aynı kişiye aynı
/// dönem için ikinci ödül sunucuda reddedilir (idempotent).
class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  AdminRewardPeriodKind _kind = AdminRewardPeriodKind.daily;

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: context.t(K.adminRewardsTitle),
      children: [
        SahneRail.fit(
          children: [
            SahneRailChip(
              key: const ValueKey('admin-period-daily'),
              label: context.t(K.adminRewardDaily),
              selected: _kind == AdminRewardPeriodKind.daily,
              role: SahneRole.gold,
              onTap: () => setState(() => _kind = AdminRewardPeriodKind.daily),
            ),
            SahneRailChip(
              key: const ValueKey('admin-period-weekly'),
              label: context.t(K.adminRewardWeekly),
              selected: _kind == AdminRewardPeriodKind.weekly,
              role: SahneRole.gold,
              onTap: () => setState(() => _kind = AdminRewardPeriodKind.weekly),
            ),
          ],
        ),
        SahneSectionHeader(title: context.t(K.adminTop3)),
        _PeriodView(
          key: ValueKey('admin-period-${_kind.name}'),
          repository: widget.repository,
          kind: _kind,
        ),
        SahneSectionHeader(title: context.t(K.adminAutoReward)),
        _AutoRewardRow(repository: widget.repository),
      ],
    );
  }
}

class _PeriodView extends StatelessWidget {
  const _PeriodView({super.key, required this.repository, required this.kind});

  final AdminRepository repository;
  final AdminRewardPeriodKind kind;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return AdminLoader<AdminRewardPeriod>(
      load: () => repository.loadRewardPeriod(kind),
      builder: (context, period, reload) {
        if (period.candidates.isEmpty) {
          return AdminEmpty(context.t(K.adminEmptyRewards));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminNote(period.periodKey),
            const SizedBox(height: SahneSpace.x3),
            for (final c in period.candidates) ...[
              SahneSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SahneAvatar(
                          initial: '${groupThousands(c.rank)}',
                          color: c.rank == 1 ? t.goldTint : t.s3,
                          foreground: c.rank == 1 ? t.goldTx : t.tx,
                        ),
                        const SizedBox(width: SahneSpace.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: SahneType.bodyStrong.copyWith(
                                  color: t.tx,
                                ),
                              ),
                              Text(
                                context.t(K.adminScorePts, {
                                  'n': '${groupThousands(c.score)}',
                                }),
                                style: SahneType.caption.copyWith(color: t.tx2),
                              ),
                            ],
                          ),
                        ),
                        if (c.rewarded)
                          SahneBadge(
                            label: context.t(K.adminRewardGiven),
                            tone: SahneBadgeTone.gold,
                          ),
                      ],
                    ),
                    if (!c.rewarded) ...[
                      const SizedBox(height: SahneSpace.x3),
                      Wrap(
                        spacing: SahneSpace.x2,
                        runSpacing: SahneSpace.x2,
                        children: [
                          SahneButton.secondary(
                            key: ValueKey('admin-grant-coins-${c.userId}'),
                            label: context.t(K.adminGiveCoins, {
                              'coins':
                                  '${groupThousands(period.suggestedCoins[c.rank - 1])}',
                            }),
                            icon: AppIcons.coins,
                            onPressed: () => _grant(context, period, c, reload),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SahneSpace.cardGap),
            ],
          ],
        );
      },
    );
  }

  Future<void> _grant(
    BuildContext context,
    AdminRewardPeriod period,
    AdminRewardCandidate c,
    Future<void> Function() reload,
  ) async {
    final coins = period.suggestedCoins[c.rank - 1];
    final ok = await adminConfirm(
      context,
      body: context.t(K.adminConfirmGrant, {
        'name': c.name,
        'coins': '${groupThousands(coins)}',
      }),
    );
    if (!ok || !context.mounted) return;
    await runAdminAction(
      context,
      () => repository.grantReward(
        kind,
        period.periodKey,
        userId: c.userId,
        coins: coins,
      ),
      reload,
    );
  }
}

class _AutoRewardRow extends StatelessWidget {
  const _AutoRewardRow({required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return AdminLoader<bool>(
      load: repository.loadAutoReward,
      builder: (context, enabled, reload) => SahneListGroup(
        children: [
          SahneListRow.plain(
            title: context.t(K.adminAutoReward),
            subtitle: context.t(K.adminAutoRewardSub),
            trailing: Switch(
              key: const ValueKey('admin-auto-reward-switch'),
              value: enabled,
              onChanged: (value) => runAdminAction(
                context,
                () => repository.setAutoReward(value),
                reload,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
