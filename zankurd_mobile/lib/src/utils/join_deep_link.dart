import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/room.dart' show isSupportedRoomCode;

/// Web ve paylaşım `https://www.zankurd.com/join/{code}` yolunu açar.
///
/// ## İki kod biçimi, çakışmaz
///
/// * Oda kodu: 6 rakam (örn. `482913`). Eski odalarda `ZK-` + 10 onaltılık
///   karakter (daha eskilerde 4 karakter); onlar `ZK` ile başlar.
/// * Meydan okuma kodu (arkadaşa sırayla düello): `D` + 8 karakter,
///   alfabe `23456789ABCDEFGHJKMNPQRSTUVWXYZ` ([isChallengeCode]).
///
/// Ayrım bağımsız yollardan garantidir: yeni oda kodu yalnız rakamdır, meydan
/// okuma kodu `D` ile başlar (rakamla başlayan kod hiçbir zaman `D…` değildir);
/// eski kodlarda ayrıca önek (`ZK` ≠ `D`), uzunluk (9 ≠ 13/7) ve alfabe
/// (meydan okumada `0 1 O I L` yok). Sunucudaki CHECK aynı regex'i taşır
/// (`supabase/2026-10-13_friend_challenge.sql`).
class JoinDeepLink {
  JoinDeepLink._();

  static String? pendingCode;

  static final RegExp _challengePattern = RegExp(r'^D[2-9A-HJKMNP-Z]{8}$');

  /// [code] bir meydan okuma kodu mu (büyük/küçük harf ve çevre boşluğu
  /// önemsiz)? Oda kodları ASLA `true` döndürmez.
  static bool isChallengeCode(String? code) {
    if (code == null) return false;
    return _challengePattern.hasMatch(code.trim().toUpperCase());
  }

  static String shareUrl(String code) =>
      'https://www.zankurd.com/join/${code.trim().toUpperCase()}';

  /// Evrensel bağlantının (iOS applinks, Android App Links) kabul edildiği
  /// alan adları. Platform zaten yalnız bunları uygulamaya yönlendirir;
  /// süzgeç, başka bir yoldan (özel şema, test, gelecekte eklenen bir
  /// giriş) gelen yabancı alan adlı bir `/join/` yolunun davet sayılmasını
  /// önler.
  static const _trustedHosts = {'zankurd.com', 'www.zankurd.com'};

  /// `/join/<kod>` yolundan kodu çıkarır; kod bir oda ya da meydan okuma
  /// kodu biçiminde DEĞİLSE `null` döner.
  ///
  /// Eskiden her `/join/<metin>` büyük harfe çevrilip doğrudan
  /// `join_room_by_code` RPC'sine gidiyordu: bozuk ya da uydurma bir
  /// bağlantı sunucuya boşuna istek ve oyuncuya anlamsız bir "oda
  /// bulunamadı" hatası üretiyordu. [anyHost] yalnız web içindir: web
  /// sürümünde adres, uygulamayı sunan sayfanın kendisidir.
  static String? parse(String? route, {bool anyHost = false}) {
    if (route == null || route.isEmpty || route == '/') return null;
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    if (!anyHost &&
        uri.hasAuthority &&
        !_trustedHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2 || segs.first != 'join') return null;
    final code = segs[1].trim().toUpperCase();
    if (isChallengeCode(code) || isSupportedRoomCode(code)) return code;
    return null;
  }

  /// Yol bir `/join/...` yolu mu (kod geçerli olsun olmasın)?
  static bool _isJoinPath(String route) {
    final segs = Uri.tryParse(
      route,
    )?.pathSegments.where((s) => s.isNotEmpty).toList();
    return segs != null && segs.isNotEmpty && segs.first == 'join';
  }

  static bool _webUriConsumed = false;

  static String? consumeInitialRoute() {
    pendingCode ??= parse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
    // Web: Flutter varsayılan olarak hash URL stratejisi kullanır; tarayıcıda
    // `/join/KOD` yolu `defaultRouteName`e DÜŞMEZ (her zaman `/`). Bağlantıyı
    // tarayıcının gerçek adresinden bir kez okuruz; böylece uygulaması
    // olmayan arkadaş bağlantıyı tarayıcıdan açıp meydan okumayı (ya da
    // odayı) kabul edebilir.
    if (pendingCode == null && kIsWeb && !_webUriConsumed) {
      _webUriConsumed = true;
      pendingCode = parse(Uri.base.toString(), anyHost: true);
    }
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
    // Geçersiz kodlu bir `/join/` yolu da "işlendi" sayılır: `false`
    // dönersek `WidgetsApp` yolu `pushNamed` ile dener ve Crashlytics'e
    // sahte bir "Could not find a generator for route" hatası düşer
    // (bkz. [JoinDeepLinkScope]).
    if (code == null) return _isJoinPath(route);
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
    _webUriConsumed = false;
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
