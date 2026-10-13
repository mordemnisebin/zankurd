import 'package:flutter/widgets.dart';

/// Web ve paylaşım `https://www.zankurd.com/join/{code}` yolunu açar.
class JoinDeepLink {
  JoinDeepLink._();

  static String? pendingCode;

  static String shareUrl(String code) =>
      'https://www.zankurd.com/join/${code.trim().toUpperCase()}';

  static String? parse(String? route) {
    if (route == null || route.isEmpty || route == '/') return null;
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 2 && segs.first == 'join') {
      final code = segs[1].trim().toUpperCase();
      return code.isEmpty ? null : code;
    }
    return null;
  }

  static String? consumeInitialRoute() {
    pendingCode ??= parse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
    final code = pendingCode;
    pendingCode = null;
    return code;
  }

  /// Uygulama AÇIKKEN gelen davet kodu (sıcak açılış). [AppShell] dinler
  /// ve [takeIncoming] ile tüketir. Kabuk henüz kurulmamışsa (açılış
  /// ekranı, giriş) kod burada bekler; kabuk kurulunca işlenir.
  static final ValueNotifier<String?> incoming = ValueNotifier<String?>(null);

  static String? _lastOfferedCode;
  static DateTime? _lastOfferedAt;

  /// Aynı kodun platformdan kısa aralıkla ikinci kez gelmesi (Android'in
  /// öne getirilen etkinliğe intent'i yeniden yollaması) tek davet sayılır.
  /// Pencere bilerek kısa: oyuncu odadan çıkıp AYNI davete sonradan
  /// yeniden dokunabilmeli — kalıcı bir "bu bağlantı işlendi" kaydı onu
  /// sessizce yok sayardı.
  static const duplicateWindow = Duration(seconds: 3);

  /// [route] bir oda davetine çözülürse kodu [incoming]'e koyar ve `true`
  /// döner (bağlantı "işlendi"); değilse `false`.
  static bool offer(String route, {DateTime? now}) {
    final code = parse(route);
    if (code == null) return false;
    final at = now ?? DateTime.now();
    final lastAt = _lastOfferedAt;
    final duplicate =
        code == _lastOfferedCode &&
        lastAt != null &&
        at.difference(lastAt) < duplicateWindow;
    _lastOfferedCode = code;
    _lastOfferedAt = at;
    if (!duplicate) {
      // Aynı kod bekliyorken yeniden gelirse de dinleyici uyansın diye
      // önce boşaltılır (ValueNotifier aynı değerde bildirim yapmaz).
      incoming.value = null;
      incoming.value = code;
    }
    return true;
  }

  /// Bekleyen sıcak açılış kodunu alır ve kanalı boşaltır.
  static String? takeIncoming() {
    final code = incoming.value;
    if (code != null) incoming.value = null;
    return code;
  }

  /// Testler arası statik durumu sıfırlar.
  @visibleForTesting
  static void resetForTest() {
    pendingCode = null;
    incoming.value = null;
    _lastOfferedCode = null;
    _lastOfferedAt = null;
  }
}

/// Uygulama açıkken gelen `/join/<KOD>` bağlantısını yakalayan gözlemci.
///
/// ## Kusur
///
/// Uygulama `MaterialApp`i adlı-rota tablosu olmadan kurar. Uygulama
/// açıkken bir davet bağlantısına dokunulduğunda platform bunu
/// `didPushRouteInformation` ile bildirir; ilk dinleyen `WidgetsApp`in
/// kendi gözlemcisidir ve `Navigator.pushNamed('/join/KOD')` dener. Bu
/// deneme "Could not find a generator for route" ile düşer; bağlama
/// hatayı `FlutterError.reportError` ile raporlayıp bir sonraki gözlemciye
/// geçer. Davet sonunda işlense bile her dokunuş çökme raporlamasına
/// (Crashlytics) sahte bir hata düşürürdü.
///
/// ## Çözüm
///
/// Bu kapsam `MaterialApp`in ÜSTÜNDE durur. Gözlemciler kayıt sırasıyla
/// çağrılır ve üst widget'ın `initState`i alttakinden önce çalışır; yani
/// bu gözlemci `WidgetsApp`inkinden ÖNCE sorulur. Davet yolunu burada
/// yakalayıp `true` döndürünce `pushNamed` denemesi hiç yapılmaz. Davet
/// olmayan yollar (`false`) eskisi gibi `WidgetsApp`e bırakılır.
class JoinDeepLinkScope extends StatefulWidget {
  const JoinDeepLinkScope({required this.child, super.key});

  final Widget child;

  @override
  State<JoinDeepLinkScope> createState() => _JoinDeepLinkScopeState();
}

class _JoinDeepLinkScopeState extends State<JoinDeepLinkScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    return JoinDeepLink.offer(routeInformation.uri.toString());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
