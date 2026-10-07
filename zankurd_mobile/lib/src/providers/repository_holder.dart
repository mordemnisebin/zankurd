import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';

/// Uygulama süresince TEK, ama DEĞİŞEBİLİR depo kaynağı.
///
/// ## Niçin var
///
/// Depo ve auth açılışta bir kez seçilir (`OfflineZanKurdRepository` ↔
/// `SupabaseZanKurdRepository`). Soğuk açılışta Supabase başlatması
/// zaman aşımına uğrarsa uygulama çevrimdışı açılır; ağ sonradan
/// gelince kurtarma çalışır. Bu kurtarma BİR ZAMANLAR kök widget'ı
/// farklı bir `key` ile yeniden `runApp` ederek yapılıyordu — oysa
/// `GlobalKey` ağaç sökülmeden eski `MaterialApp` elementini geri
/// alabildiği için (`FrameworkElement._retakeInactiveElement`) eski
/// rota yığını hiç değişmiyor ve açık rotalar ESKİ çevrimdışı depoyla
/// kalıyordu.
///
/// Artık ağaç tazelenmez: depo değeri bu sağlayıcıdan okunur ve
/// kurtarmada yalnız bu nesne değişir. `AppShell` gibi kabuk
/// ekranları her build'de [_repository]i okuduğu için yeni depo bir
/// sonraki çizimde devreye girer; rota yığını, navigator geçmişi ve
/// açık ekranlar bozulmaz.
///
/// `Provider<ZanKurdRepository>` artık bu nesneye `ProxyProvider` ile
/// bağlıdır, yani context üzerinden okuyanlar da aynı takası görür.
class RepositoryHolder extends ChangeNotifier {
  RepositoryHolder(this._repository);

  ZanKurdRepository _repository;

  ZanKurdRepository get repository => _repository;

  /// Depoyu değiştirir ve dinleyicileri uyarır. Aynı örneğe geçişte
  /// (kurtarma ikinci kez tetiklenirse) sessizce no-op'dur.
  void switchTo(ZanKurdRepository next) {
    if (identical(_repository, next)) return;
    _repository = next;
    notifyListeners();
  }

  /// Sağlayıcı yoksa `null` — izole widget testleri kırılmaz.
  ///
  /// Build DIŞINDA kullanılır (dinleme yapmaz).
  static RepositoryHolder? read(BuildContext context) {
    try {
      return Provider.of<RepositoryHolder>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Build sırasında dinleyerek okur. Yalnız bir build metodu içinde
  /// çağrılabilir; depo değiştiğinde kabuk yeniden çizilir.
  static RepositoryHolder? watch(BuildContext context) {
    try {
      return Provider.of<RepositoryHolder>(context);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
