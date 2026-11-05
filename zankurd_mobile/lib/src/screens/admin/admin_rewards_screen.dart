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

  /// Seçili geçmiş dönem anahtarı; `null` = son tamamlanan dönem. Yalnız
  /// TAMAMLANMIŞ dönem ödüllenir (sunucu bitmemişi reddeder).
  String? _periodKey;

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
              onTap: () => setState(() {
                _kind = AdminRewardPeriodKind.daily;
                _periodKey = null;
              }),
            ),
            SahneRailChip(
              key: const ValueKey('admin-period-weekly'),
              label: context.t(K.adminRewardWeekly),
              selected: _kind == AdminRewardPeriodKind.weekly,
              role: SahneRole.gold,
              onTap: () => setState(() {
                _kind = AdminRewardPeriodKind.weekly;
                _periodKey = null;
              }),
            ),
          ],
        ),
        SahneSectionHeader(title: context.t(K.adminTop3)),
        _PeriodView(
          key: ValueKey('admin-period-${_kind.name}-${_periodKey ?? 'last'}'),
          repository: widget.repository,
          kind: _kind,
          periodKey: _periodKey,
          onPeriod: (key) => setState(() => _periodKey = key),
        ),
        SahneSectionHeader(title: context.t(K.adminAutoReward)),
        _AutoRewardRow(repository: widget.repository),
      ],
    );
  }
}

class _PeriodView extends StatelessWidget {
  const _PeriodView({
    super.key,
    required this.repository,
    required this.kind,
    required this.periodKey,
    required this.onPeriod,
  });

  final AdminRepository repository;
  final AdminRewardPeriodKind kind;
  final String? periodKey;
  final ValueChanged<String?> onPeriod;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return AdminLoader<AdminRewardPeriod>(
      load: () => repository.loadRewardPeriod(kind, periodKey: periodKey),
      builder: (context, period, reload) {
        final nav = Row(
          children: [
            if (period.prevKey != null)
              SahneButton.text(
                key: const ValueKey('admin-period-prev'),
                label: context.t(K.adminPeriodPrev),
                arrow: false,
                onPressed: () => onPeriod(period.prevKey),
              ),
            const Spacer(),
            if (period.nextKey != null)
              SahneButton.text(
                key: const ValueKey('admin-period-next'),
                label: context.t(K.adminPeriodNext),
                arrow: false,
                onPressed: () => onPeriod(period.nextKey),
              ),
          ],
        );
        if (period.candidates.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminNote(period.periodKey),
              nav,
              AdminEmpty(context.t(K.adminEmptyRewards)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminNote(period.periodKey),
            nav,
            const SizedBox(height: SahneSpace.x2),
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
    final already = context.t(K.adminRewardAlready);
    final taken = context.t(K.adminRewardRankTaken);
    await runAdminAction(context, () async {
      final outcome = await repository.grantReward(
        kind,
        period.periodKey,
        userId: c.userId,
        coins: coins,
      );
      // Sunucu ödül VERMEDİYSE "Kaydedildi" denmez: neden söylenir.
      return switch (outcome) {
        AdminGrantOutcome.granted => null,
        AdminGrantOutcome.alreadyRewarded => already,
        AdminGrantOutcome.rankTaken => taken,
      };
    }, reload);
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
