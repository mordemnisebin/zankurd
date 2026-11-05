import 'package:flutter/material.dart';

import '../../utils/number_format.dart';

import '../../data/admin_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/admin.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';
import 'admin_widgets.dart';

/// Kullanıcılar ve şikâyetler (2.2): şikâyet edilen oyuncular; uyar /
/// engelle / askıya al ve kısıtı kaldır. Şikâyet edenin kimliği
/// gösterilmez (taciz riski: bkz. `2026-07-31_chat_moderation.sql`).
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key, required this.repository});

  final AdminRepository repository;

  /// "Askıya al" varsayılan süresi (gün).
  static const int suspendDays = 7;

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: context.t(K.adminUsersTitle),
      children: [
        AdminLoader<List<AdminUserReport>>(
          load: repository.loadUserReports,
          builder: (context, reports, reload) {
            if (reports.isEmpty) {
              return AdminEmpty(context.t(K.adminEmptyUsers));
            }
            return Column(
              children: [
                for (final report in reports) ...[
                  _UserCard(
                    report: report,
                    repository: repository,
                    reload: reload,
                  ),
                  const SizedBox(height: SahneSpace.cardGap),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.report,
    required this.repository,
    required this.reload,
  });

  final AdminUserReport report;
  final AdminRepository repository;
  final Future<void> Function() reload;

  String _stateLabel(BuildContext context) => switch (report.state) {
    AdminUserState.ok => context.t(K.adminStateOk),
    AdminUserState.warned => context.t(K.adminStateWarned),
    AdminUserState.blocked => context.t(K.adminStateBlocked),
    AdminUserState.suspended => context.t(K.adminStateSuspended, {
      'days': '${groupThousands(report.suspendedDays)}',
    }),
  };

  Widget _action(
    BuildContext context,
    String keyName,
    String label,
    IconData icon,
    AdminUserAction action, {
    int days = 0,
  }) => SahneButton.secondary(
    key: ValueKey('admin-user-$keyName-${report.userId}'),
    label: label,
    icon: icon,
    onPressed: () async {
      final ok = await adminConfirm(
        context,
        body: context.t(K.adminConfirmUserAction, {
          'name': report.name,
          'action': label,
        }),
        confirmLabel: label,
        destructive: action != AdminUserAction.lift,
      );
      if (!ok || !context.mounted) return;
      await runAdminAction(
        context,
        () => repository.moderateUser(report.userId, action, days: days),
        reload,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Uyarılmış oyuncu oyunda KISITLI değildir (sunucu `user_is_restricted`
    // yalnız engel/askıyı sayar): daha ağır önlem hâlâ sunulur, "kısıtı
    // kaldır" ise uyarıyı silmek için yine vardır (W8, alan 8 #7).
    final restricted =
        report.state == AdminUserState.blocked ||
        report.state == AdminUserState.suspended;
    final warned = report.state == AdminUserState.warned;
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SahneAvatar(initial: report.name.characters.first),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                    Text(
                      context.t(K.adminReportsAbout, {
                        'n': '${groupThousands(report.reportCount)}',
                      }),
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  ],
                ),
              ),
              SahneBadge(
                label: _stateLabel(context),
                tone: restricted ? SahneBadgeTone.race : SahneBadgeTone.soon,
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x3),
          Text(
            context.t(K.adminReportReason, {'reason': report.reason}),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            children: [
              if (!restricted) ...[
                if (!warned)
                  _action(
                    context,
                    'warn',
                    context.t(K.adminWarn),
                    AppIcons.triangleExclamation,
                    AdminUserAction.warn,
                  ),
                _action(
                  context,
                  'suspend',
                  context.t(K.adminSuspend),
                  AppIcons.clock,
                  AdminUserAction.suspend,
                  days: AdminUsersScreen.suspendDays,
                ),
                _action(
                  context,
                  'block',
                  context.t(K.adminBlock),
                  AppIcons.lock,
                  AdminUserAction.block,
                ),
              ],
              if (restricted || warned)
                _action(
                  context,
                  'lift',
                  context.t(K.adminLiftRestriction),
                  AppIcons.arrowRotateLeft,
                  AdminUserAction.lift,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
