import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Uzak backend (Supabase) bu oturumda gerçekten açıldı mı?
///
/// ## Kusur
///
/// 2026-09-06: `main()` Supabase 4 sn'de açılmazsa sahte
/// `AuthProvider.test(authenticated: true)` ile "ZanKurd Oyuncusu"
/// oturumu basıyordu. Cihaz online olsa bile oda/liderlik/arkadaş
/// sahte veriyle doluyordu. Bu bayrak o kipi durdurur: sosyal yüzey
/// kilitlenir, kullanıcıya dürüst bant gösterilir.
///
/// 2026-10-01: Aynı bayrak ikinci bir kusur üretiyordu. `bootStep`
/// Supabase başlatmasına taktığı 4 sn'lik sınır AŞILDIĞINDA karar
/// (`reachable: false`) OTURUM BOYUNCA kesinleşiyordu ve bir daha hiç
/// denenmiyordu. Soğuk açılışta başlatma yarışı (Firebase, RevenueCat,
/// soru bankası ve tercih yüklemeleri tek çekirdekte), uykudan yeni
/// uyanmış cihazda DNS/kuyruk gecikmesi ya da zayıf ağ 4 sn'yi rahat
/// geçebildiği için uygulama "Sunucuya ulaşılamadı" bandıyla açılıp
/// oda kurma/kodla katıl/liderlik yüzeyini kilitliyordu; kapatıp
/// açmak yetiyordu, çünkü ikinci denemede sınır aşılmıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Kusur bozuk bir yolda değil, İŞLEYEN bir yoldaydı: bant doğru
/// çiziliyordu, kilit doğru kalkıyordu (yalnızca elle yeniden
/// açılışta) ve hata da üretilmiyordu — `bootStep` zaman aşımını
/// [ErrorReporter]'a yazıyor ama "karar geri alınamaz" diyen bir şey
/// yoktu. Hiçbir test yavaş başlatmayı (zaman aşımı → sonradan
/// başarılı deneme) kurmuyordu; erişilebilirlik testleri hep sabit
/// `reachable:` değerleriyle başlıyordu, yani bayrağın bir kez
/// yanlış kaldığı senaryo hiçbir beklentinin altında kalmıyordu.
///
/// ## Sözleşme
///
/// Zaman aşımı artık GEÇİCİDİR. [probe] arka planda üstel geri
/// çekilmeyle (2, 4, 8, 16, 32, 60 sn — bkz. [defaultRetrySchedule])
/// yeniden denenir; ayrıca iki elle tetik daha vardır: uygulama ön
/// plana dönünce ([AppLifecycleState.resumed]) ve kullanıcı sunucu
/// gerektiren bir eyleme bastığında — ikisi de [retryNow] çağırır.
/// İlk başarılı deneme [reachable]i `true` yapar, dinleyicileri
/// haberdar eder ve bandı kaldırır; boot'da çevrimdışı kalmış
/// uygulama ise [onUpgradeRequest] ile uzak oturuma geçirilir
/// (bkz. `main()`).
///
/// Ağ GERÇEKTEN yoksa probe her denemede başarısız olur, kilit yerinde
/// kalır: gerçek çevrimdışı davranış değişmez.
class RemoteAvailability extends ChangeNotifier {
  /// Varsayılan geri çekilme: 2 → 4 → 8 → 16 → 32 → 60 sn.
  ///
  /// Liste biterse son eleman (60 sn) tekrarlanır; amaç sabit aralıkla
  /// sonsuz ağa bağlanmak değil, geçici bir yavaşlamayı birkaç dakikada
  /// bir yoklamaktır.
  static const List<Duration> defaultRetrySchedule = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
    Duration(seconds: 60),
  ];

  /// Açılış kararı (veya sonraki yoklama) ne diyorsa onu taşır.
  ///
  /// `reachable:` adı korunur (çağrı alanları değişmesin); üç özel alan
  /// için ise `this._x` yazılamaz (özel adlandırılmış parametre olamaz),
  /// bu yüzden doğrudan atama lint'i satır sonunda bastırılır.
  RemoteAvailability({
    required bool reachable,
    Future<bool> Function()? probe,
    Duration probeTimeout = const Duration(seconds: 4),
    List<Duration> retrySchedule = defaultRetrySchedule,
    this.onUpgradeRequest,
    this.isUpgradeSafe,
  }) : _reachable = reachable, // ignore: prefer_initializing_formals
       _probe = probe, // ignore: prefer_initializing_formals
       _probeTimeout = probeTimeout, // ignore: prefer_initializing_formals
       _retrySchedule = retrySchedule.isEmpty
           ? defaultRetrySchedule
           : retrySchedule;

  final Future<bool> Function()? _probe;
  final Duration _probeTimeout;
  final List<Duration> _retrySchedule;

  /// Boot kararı çevrimdışı kalmışken uzak başlatma sonunda başarılı
  /// olursa çağrılır (`main`de uygulamayı uzak oturumla yeniden kurar).
  ///
  /// Bir kez tükenebilir: tüketildikten sonra nesne nullptr'ye çekilir,
  /// aynı kurtarma iki kez tetiklenemez.
  VoidCallback? onUpgradeRequest;

  /// [onUpgradeRequest]'in ne zaman güvenli olduğu — `main` rota
  /// kökteyken (üstünde açık ekran yokken) true döndürür.
  bool Function()? isUpgradeSafe;

  bool _reachable;
  Timer? _retryTimer;
  int _retryStep = 0;
  bool _probing = false;
  bool _disposed = false;
  bool _upgradePending = false;

  bool get reachable => _reachable;

  /// Oda, 1v1, liderlik, arkadaş, turnuva bu kipte çalışmaz.
  bool get socialLocked => !reachable;

  /// Arka plan geriçekilmesi ya da elle deneme çalışıyor mu?
  /// (Testler ve tanılama için.)
  bool get retrying => _probing || _retryTimer != null;

  /// Uzak başlatma gerçekten başarılı oldu mu — boot kararı olsun ya da
  /// olmasın. Değişim yoksa dinleyiciler uyandırılmaz.
  void update(bool reachable) {
    if (_disposed) return;
    if (_reachable == reachable) {
      // Kilit hâlâ düşmemiş: denemeyi sürdür (ör. bağlantı kopuşu).
      if (!reachable) _ensureRetryScheduled();
      return;
    }
    _reachable = reachable;
    if (reachable) {
      _retryStep = 0;
      _cancelRetryTimer();
    } else {
      _ensureRetryScheduled();
    }
    notifyListeners();
  }

  /// Açılış kararı çevrimdışıysa arka plan geriçekilmeyi başlatır.
  ///
  /// [probe] yoksa (Supabase yapılandırması yok) ya da zaten
  /// çevrimiçiysek yapacak bir şey yoktur.
  void startRetries() {
    if (_disposed || _probe == null || _reachable) return;
    _ensureRetryScheduled();
  }

  /// Tek seferlik, hemen deneme: ön plana dönüş, kullanıcı eylemi ve
  /// bağlantı dönüşü bu yolu kullanır.
  ///
  /// [reachable] true ise zaten ulaşılır durumdadır; ağ yoksa probe
  /// başarısız olur ve arka plan geriçekilmesi kendi takviminde sürer.
  Future<bool> retryNow() async {
    if (_disposed || _probe == null) return _reachable;
    if (_reachable) return true;
    if (_probing) return _reachable;
    _cancelRetryTimer();
    return _attempt();
  }

  /// Uzak oturuma geçiş kök rota boşaldığında (ör. kullanıcı geri
  /// döndüğünde, uygulama ön plana çıktığında) yeniden denenir.
  void considerUpgradeNow() => _considerUpgrade();

  Future<bool> _attempt() async {
    final probe = _probe;
    if (probe == null || _disposed) return _reachable;
    if (_reachable) return true;
    if (_probing) return _reachable;
    _probing = true;
    var ok = false;
    try {
      // Zaman aşımı `Future.timeout` ile: probe asılı kalsa bile deneme
      // biter ve bir sonraki geri çekilme planlanır. `bootStep`in aksine
      // buradaki AŞIM karar değildir, yalnızca bir denemenin sonudur.
      ok = await probe().timeout(_probeTimeout);
    } catch (_) {
      // Ağ yok, zaman aşımı, yapılandırma hatası — hepsi "henüz ulaşılamadı".
      // Her denemenin hatayı [ErrorReporter]'a yazması çevrimdışı
      // cihazda dakikada bir hata yağmuru demek olurdu; bu yüzden
      // başarısız probe sessizdir, kararı [reachable] yansıtır.
      ok = false;
    }
    _probing = false;
    if (_disposed) return ok;
    if (ok) {
      _retryStep = 0;
      _cancelRetryTimer();
      update(true);
      _requestUpgrade();
    } else {
      if (_retryStep < _retrySchedule.length - 1) _retryStep += 1;
      _ensureRetryScheduled();
    }
    return ok;
  }

  void _ensureRetryScheduled() {
    if (_disposed || _probe == null || _reachable || _probing) return;
    if (_retryTimer != null) return;
    final index = _retryStep < _retrySchedule.length
        ? _retryStep
        : _retrySchedule.length - 1;
    _retryTimer = Timer(_retrySchedule[index], () {
      _retryTimer = null;
      unawaited(_attempt());
    });
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _requestUpgrade() {
    if (onUpgradeRequest == null) return;
    _upgradePending = true;
    _considerUpgrade();
  }

  void _considerUpgrade() {
    if (_disposed || !_upgradePending) return;
    final request = onUpgradeRequest;
    if (request == null) return;
    final safe = isUpgradeSafe;
    if (safe != null && !safe()) return;
    _upgradePending = false;
    onUpgradeRequest = null;
    isUpgradeSafe = null;
    request();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRetryTimer();
    super.dispose();
  }

  /// Sağlayıcı yoksa kilit yok — izole widget testleri kırılmaz.
  ///
  /// Build DIŞINDA kullanılır (dinleme yapmaz).
  static bool socialLockedIn(BuildContext context) {
    final availability = read(context);
    return availability?.socialLocked ?? false;
  }

  /// [socialLockedIn]in build sürümü: `reachable` değiştiğinde çizim
  /// yenilenir, böylece kalkan bant ve açılan düğmeler beklemek zorunda
  /// kalmaz.
  static bool socialLockedWatch(BuildContext context) =>
      watch(context)?.socialLocked ?? false;

  /// Sağlayıcı varsa nesneyi, yoksa `null` — izole widget testleri
  /// `ProviderNotFoundException` görmez.
  static RemoteAvailability? read(BuildContext context) {
    try {
      return Provider.of<RemoteAvailability>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Build sırasında dinleyerek okur. Yalnız bir build metodu içinde
  /// çağrılabilir.
  static RemoteAvailability? watch(BuildContext context) {
    try {
      return Provider.of<RemoteAvailability>(context);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
