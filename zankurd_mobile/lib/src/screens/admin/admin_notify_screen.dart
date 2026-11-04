import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/admin.dart';
import '../../widgets/sahne/sahne.dart';
import 'admin_widgets.dart';

/// Sahibe anlık bildirim (2.2): hangi olaylarda telefona bildirim geleceği.
/// Bildirimi sunucu üretir (`push_outbox`); bu ekran yalnız tercihi yazar.
/// Destek e-postaları bilerek buraya gömülmez (iletisim@ posta kutusu
/// telefonun Mail uygulamasına bağlanır).
class AdminNotifyScreen extends StatelessWidget {
  const AdminNotifyScreen({super.key, required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: context.t(K.adminNotifyTitle),
      children: [
        AdminNote(context.t(K.adminNotifyLead)),
        const SizedBox(height: SahneSpace.x3),
        AdminLoader<Map<AdminNotifyKind, bool>>(
          load: repository.loadNotifyPrefs,
          builder: (context, prefs, reload) {
            Widget row(AdminNotifyKind kind, String label) =>
                SahneListRow.plain(
                  title: label,
                  trailing: Switch(
                    key: ValueKey('admin-notify-${kind.name}'),
                    value: prefs[kind] ?? false,
                    onChanged: (value) => runAdminAction(
                      context,
                      () => repository.setNotifyPref(kind, value),
                      reload,
                    ),
                  ),
                );
            return SahneListGroup(
              children: [
                row(
                  AdminNotifyKind.suggestion,
                  context.t(K.adminNotifySuggestion),
                ),
                row(AdminNotifyKind.report, context.t(K.adminNotifyReport)),
              ],
            );
          },
        ),
        const SizedBox(height: SahneSpace.x4),
        AdminNote(context.t(K.adminNotifySupportInfo)),
      ],
    );
  }
}
