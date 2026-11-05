import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/admin_repository.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../widgets/sahne/sahne.dart';
import 'admin_home_screen.dart';

/// Ayarlar'daki "Yönetim" girişi. YALNIZ [AdminRepository.isAdmin] `true`
/// dönerse çizilir; sağlayıcı yoksa (üretimde yönetici deposu kayıtlı
/// değildir) ya da çağrı hata verirse hiçbir şey çizmez.
///
/// Bu yalnız vitrin kapısıdır, güvenlik değil: ekranın arkasındaki her
/// RPC sunucuda `auth.uid()` ile yeniden denetlenir.
class AdminEntryRow extends StatefulWidget {
  const AdminEntryRow({super.key});

  @override
  State<AdminEntryRow> createState() => _AdminEntryRowState();
}

class _AdminEntryRowState extends State<AdminEntryRow> {
  AdminRepository? _repository;
  Future<bool>? _isAdmin;
  String? _userId;

  /// Oturumdaki hesabın kimliği; oturum sağlayıcısı yoksa (izole widget
  /// testi) `null`. Dinlenir: hesap değişince yetki YENİDEN sorulur, önceki
  /// hesabın "yönetici" cevabı yeni hesaba kalmaz (W8, alan 8 #27).
  String? _sessionUserId() {
    try {
      return Provider.of<AuthProvider>(context).currentUser?.id;
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AdminRepository.maybeOf(context);
    final userId = _sessionUserId();
    if (!identical(repository, _repository) || userId != _userId) {
      _repository = repository;
      _userId = userId;
      _isAdmin = repository?.isAdmin().catchError((Object _) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    final future = _isAdmin;
    if (repository == null || future == null) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SahneSectionHeader(title: context.t(K.adminEntry)),
            SahneListGroup(
              children: [
                SahneListRow.icon(
                  key: const ValueKey('settings-admin-entry'),
                  icon: AppIcons.shieldHalved,
                  role: SahneRole.gold,
                  title: context.t(K.adminEntry),
                  subtitle: context.t(K.adminEntrySub),
                  chevron: true,
                  onTap: () => Navigator.of(
                    context,
                  ).push(AppRoute.to(AdminHomeScreen(repository: repository))),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
