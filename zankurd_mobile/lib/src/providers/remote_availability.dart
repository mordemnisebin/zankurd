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
  // Açık adlandırılmış parametre korunur (`reachable:`); alan adı
  // farklı olduğu için initializing formal kullanılamaz.
  // ignore: prefer_initializing_formals
  RemoteAvailability({required bool reachable}) : _reachable = reachable;

  bool _reachable;

  bool get reachable => _reachable;

  /// Canlı güncelleme — değişim yoksa dinleyiciler uyandırılmaz.
  void update(bool reachable) {
    if (_reachable == reachable) return;
    _reachable = reachable;
    notifyListeners();
  }

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
