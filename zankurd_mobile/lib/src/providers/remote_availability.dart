import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Uzak backend (Supabase) bu oturumda gerçekten açıldı mı?
///
/// 2026-09-06: `main()` Supabase 4 sn'de açılmazsa sahte
/// `AuthProvider.test(authenticated: true)` ile "ZanKurd Oyuncusu"
/// oturumu basıyordu. Cihaz online olsa bile oda/liderlik/arkadaş
/// sahte veriyle doluyordu. Bu bayrak o kipi durdurur: sosyal yüzey
/// kilitlenir, kullanıcıya dürüst bant gösterilir.
class RemoteAvailability extends ChangeNotifier {
  RemoteAvailability({required this.reachable});

  final bool reachable;

  /// Oda, 1v1, liderlik, arkadaş, turnuva bu kipte çalışmaz.
  bool get socialLocked => !reachable;

  /// Sağlayıcı yoksa kilit yok — izole widget testleri kırılmaz.
  static bool socialLockedIn(BuildContext context) {
    try {
      return Provider.of<RemoteAvailability>(
        context,
        listen: false,
      ).socialLocked;
    } on ProviderNotFoundException {
      return false;
    }
  }
}
