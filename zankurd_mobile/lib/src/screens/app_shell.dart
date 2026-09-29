import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sync_manager.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room.dart';
import '../providers/auth_provider.dart';
import '../providers/remote_availability.dart';
import '../data/offline_zankurd_repository.dart';
import '../widgets/sahne/sahne.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/join_deep_link.dart';
import '../widgets/branded_loader.dart';
import '../widgets/offline_banner.dart';
import 'learn_home_screen.dart';
import 'leaderboard_screen.dart';
import 'learning_screen.dart';
import 'onboarding_screen.dart';
import '../services/analytics_service.dart';
import '../services/push_tap_router.dart';
import '../services/push_token_sync.dart';
import 'friends_screen.dart';
import 'password_recovery_screen.dart';
import 'profile_name_gate_screen.dart';
import 'profile_screen.dart';
import 'play_hub_screen.dart';
import 'quiz_screen.dart';
import 'room_result_recovery_screen.dart';
import 'room_screen.dart';
import 'sign_in_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

typedef AppShellErrorRecorder =
    void Function(Object error, StackTrace stack, {String? reason});

class AppShell extends StatefulWidget {
  /// Masaüstü/tablet gezinmesine (NavigationRail) geçiş eşiği.
  ///
  /// Sabit olarak dışa açılıyor çünkü `ResponsiveWrapper.maxContentWidth`
  /// bunun ÜSTÜNDE kalmak zorunda: içerik sınırı bu eşiğin altına inerse
  /// kabuk hiçbir zaman geniş moda geçemez ve NavigationRail ölü kod olur.
  /// `test/tablet_layout_test.dart` bu ilişkiyi sabitler.
  static const double desktopNavBreakpoint = 768;

  const AppShell({
    required this.repository,
    this.connectivityMonitor,
    this.errorRecorder,
    this.pushTokenSync,
    super.key,
  });

  final ZanKurdRepository repository;
  final ConnectivityMonitor? connectivityMonitor;
  final PushTokenSync? pushTokenSync;

  /// Üretimde [ErrorReporter.record] kullanılır. Testlerde yalnız hata
  /// kaydının gerçekleştiğini gözlemlemek için değiştirilebilir.
  final AppShellErrorRecorder? errorRecorder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, RouteAware {
  static const _onboardingSeenKey = 'zankurd.onboarding.seen';

  /// İsim kapısının tamamlandığını belirten, KULLANICIYA ÖZEL bayrağın ön eki.
  ///
  /// Eski global anahtar (`zankurd.profileName.completed`, ön ek yok) bilerek
  /// okunmuyor ve bilerek devralınmıyor. Bunun görünür bir bedeli var: bu
  /// sürüme güncelleyen ve kapıyı çoktan geçmiş her kurulum, kapıyı bir kez
  /// daha görecek. Bedel bilinçli olarak kabul edildi.
  ///
  /// Devralmanın maliyeti daha yüksek çünkü eski bayrak CİHAZA aitti,
  /// kullanıcıya değil: hesap değiştiren ikinci oyuncu kapıyı hiç görmeden
  /// geçiyor ve aynı varsayılan adı kendi 1v1 kimliğine taşıyordu. Kapıyı
  /// tam olarak bunu durdurmak için kullanıcıya bağladık; "yalnız bir kez,
  /// yalnız ilk gördüğüm kullanıcı için devral" gibi bir geçiş yolu da aynı
  /// deliği geri açar, çünkü güncelleme anında oturum kapalıysa ilk giren
  /// kişi bir başkası olabilir.
  ///
  /// Geri dönen kullanıcı için kapı ucuzdur: alan sunucudaki adla kendi
  /// kendine dolar ve tek dokunuşla geçilir. Bir kez sorulan soru,
  /// sessizce yanlış kimliğe yazılan addan iyidir (2026-08-03 kararı).
  static const _profileNameCompletedKeyPrefix =
      'zankurd.profileName.completed.';

  // Açılış sekmesi Öğren'dir (index 0). Bu iki satır birlikte okunmalı:
  // `_visitedTabs` yalnız *ziyaret edilmiş* sekmeleri taşır ve `_buildTab`
  // ziyaret edilmemiş sekme için `SizedBox.shrink()` döndürür. Başlangıç
  // kümesine ikinci bir sekme eklenirse (ör. `{0, 1}`) o sekmenin ekranı
  // kullanıcı hiç dokunmadan kurulur — pahalı sekmeleri ilk ziyarete
  // erteleyen lazy-mount kazancı sessizce kaybolur. Bu yüzden küme
  // daima yalnız açılış sekmesini içerir.
  int _tab = 0;
  final Set<int> _visitedTabs = {0};

  final GlobalKey _homeNavKey = GlobalKey();
  final GlobalKey _playNavKey = GlobalKey();
  final GlobalKey _profileNavKey = GlobalKey();
  final ValueNotifier<int> _homeRefresh = ValueNotifier<int>(0);

  /// Sekme tazelemesini SAYFA geçişlerine bağlayan dinleyici.
  late final _TabRefreshRouteAware _tabRefreshAware = _TabRefreshRouteAware(
    onReturnedToShell: _refreshVisibleTab,
  );
  final ValueNotifier<int> _leaderboardRefresh = ValueNotifier<int>(0);
  final ValueNotifier<int> _profileRefresh = ValueNotifier<int>(0);

  /// Yarış sekmesinin tazelemesi: "Düellolarım" listesi, sonuç ekranından
  /// ya da yeni bir düellodan dönünce görülme/rakip durumunu yeniden çeker.
  final ValueNotifier<int> _playRefresh = ValueNotifier<int>(0);
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;
  bool _checkingProfileName = false;
  bool _profileNameComplete = false;
  bool _profileCheckStarted = false;
  String? _profileCheckedUserId;

  // Açılıştaki oda geri yükleme ana ekranı bekletmez. Başarılı bir sorgu
  // kullanıcı başına bir kez yapılır; geçici ağ hatası ise ancak bağlantı
  // gerçekten gidip geri geldiğinde yeniden denenir.
  final Set<String> _roomResumeCheckedUsers = {};
  final Set<String> _roomResumeAwaitingReconnectUsers = {};
  final Set<String> _roomResumeRetryWhenVisibleUsers = {};
  final Set<String> _roomResumeRejectedUsers = {};
  final Map<String, int> _roomResumeScheduledEpochs = {};
  final Map<String, int> _roomResumeInFlightEpochs = {};
  final Map<String, int> _roomResumeRouteScheduledEpochs = {};
  ModalRoute<dynamic>? _shellRoute;
  String? _roomResumeAccountUserId;
  int _roomResumeEpoch = 0;
  ({int epoch, String roomId, String userId})? _ownedRoomResumeRoute;

  // Çevrimdışı durum izleme
  bool _isOffline = false;
  bool _connectivityKnown = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  late final ScrollController _homeScrollController;
  late final ScrollController _profileScrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    JoinDeepLink.incoming.addListener(_onIncomingJoinLink);
    PushTapRouter.pending.addListener(_onPushTapTarget);
    _homeScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
    _initConnectivity();
    unawaited(widget.pushTokenSync?.sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<dynamic>(context);
    if (identical(route, _shellRoute)) return;
    final previous = _shellRoute;
    if (previous != null) {
      appRouteObserver.unsubscribe(this);
      appPageRouteObserver.unsubscribe(_tabRefreshAware);
    }
    _shellRoute = route;
    if (route != null) {
      appRouteObserver.subscribe(this, route);
      // Sekme tazelemesi AYRI bir dinleyiciye ve YALNIZ sayfa gözlemcisine
      // bağlı. Kabuğun kendisini ikinci gözlemciye de abone etmek olmazdı:
      // her gözlemci kendi dinleyici tablosunu tutar, sayfadan her dönüşte
      // `didPopNext` iki kez çalışır ve tur dönüşü iki tazeleme yapardı.
      if (route is PageRoute<dynamic>) {
        appPageRouteObserver.subscribe(_tabRefreshAware, route);
      }
    }
  }

  Future<void> _initConnectivity() async {
    try {
      await _refreshConnectivity();
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'app_shell_initial_connectivity',
      );
    }
    try {
      _connectivitySub = _connectivityMonitor.onConnectivityChanged.listen(
        _applyConnectivityResults,
        onError: (Object error, StackTrace stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'app_shell_connectivity_listener',
          );
        },
      );
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'app_shell_connectivity_listener',
      );
    }
  }

  ConnectivityMonitor get _connectivityMonitor {
    final monitor = widget.connectivityMonitor;
    if (monitor != null) return monitor;
    return PluginConnectivityMonitor();
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivityMonitor.checkConnectivity();
      _applyConnectivityResults(results);
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'app_shell_connectivity_check',
      );
      // Bağlantı eklentisinin kendisi yoksa uygulama eskisi gibi çevrimiçi
      // varsayımıyla açılır. Oda sorgusu hata verirse ayrıca raporlanır ve
      // ana ekran yine kullanılabilir kalır.
      if (mounted && !_connectivityKnown) {
        setState(() => _connectivityKnown = true);
      }
    }
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    if (!mounted) return;
    final nextOffline = results.contains(ConnectivityResult.none);
    // Boot okuması anlık görüntüyü EZMEZ: ilk okuma snapshot'tır —
    // sunucusuz açılışın kilidi (`reachable: false`) ve çevrimiçi
    // açılışın kilitsizliği ilk bağlantı raporuyla değişmemeli.
    // Yalnız sonraki GEÇİŞLER canlı yayılır.
    final isFirstRead = !_connectivityKnown;
    final transitioned = !isFirstRead && _isOffline != nextOffline;
    final reconnected = _connectivityKnown && _isOffline && !nextOffline;
    setState(() {
      _isOffline = nextOffline;
      _connectivityKnown = true;
    });
    if (reconnected) _wakeRoomResumeForCurrentUser();
    if (!transitioned) return;
    // Bağlantı koptuğunda sosyal kilit dürüstçe kapanır; bağlantı
    // dönünce kilit yalnız depo ölü değilse açılır. Ölü depo =
    // çevrimdışı açılışın `Offline` deposu — Mock testlerde canlı
    // backend yerine geçtiği için kilit sayılmaz.
    try {
      context.read<RemoteAvailability>().update(
        !nextOffline && widget.repository is! OfflineZanKurdRepository,
      );
    } on ProviderNotFoundException {
      // Yalıtık widget testleri — sağlayıcı yok, kilit main() değerinde kalır.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wakeRoomResumeForCurrentUser();
      unawaited(widget.pushTokenSync?.sync());
    }
  }

  @override
  void didPushNext() {
    final userId = _roomResumeAccountUserId;
    if (userId == null) return;
    final owned = _ownedRoomResumeRoute;
    if (owned != null &&
        owned.userId == userId &&
        owned.epoch == _roomResumeEpoch) {
      return;
    }
    if (_roomResumeInFlightEpochs[userId] == _roomResumeEpoch) {
      _roomResumeRetryWhenVisibleUsers.add(userId);
    }
  }

  @override
  void didPopNext() {
    // Kabuk yeniden en üstte: arkada (ör. bir maç sürerken) gelen bildirim
    // hedefi uygulanır. Bir sonraki kareye ertelenir: bu geri çağrı gezgin
    // geri gitmeyi işlerken (kilitliyken) gelir ve oradan sayfa itmek
    // onay hatasıyla düşer. Aşağıdaki oda devamı dalı erken dönebildiği
    // için en başta planlanır.
    if (_pushTapScheduled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _consumePushTapTarget(),
      );
    }
    // Kabuğun üstüne itilmiş HERHANGİ bir rotadan dönüldü — diyalog ve alt
    // sayfa dâhil. Burada yalnız oda devamı uyandırılır.
    //
    // Sekme tazelemesi bilerek burada DEĞİL: bu geri çağrı açılır pencereler
    // için de çalışır ve tazelemeyi buraya koymak, iptal edilen bir
    // diyalogdan sonra profil ekranını iskelete döndürüyordu. Tazeleme
    // `_TabRefreshRouteAware` içinde ve yalnız sayfa geçişlerinde.
    //
    // ## Kusur
    //
    // Ana ekran turu `await Navigator.push(QuizScreen)` ile açıp dönüşte
    // tazeliyordu. Ama quiz ekranı sonuç ekranını `pushReplacement` ile
    // açıyor ve `pushReplacement` ESKİ rotanın `popped` future'ını o anda
    // tamamlar — yani "dönüş" tazelemesi, oyuncu daha sonuç ekranındayken
    // çalışıyordu. Tur ödülleri (XP, zincir, günün doğruları) sonuç
    // ekranında yazıldığı için tazeleme onlardan ÖNCE geliyor; oyuncu geri
    // dönünce ana ekranda tur öncesinin sayılarını görüyordu. Ölçüldü
    // (2026-08-12, iPhone SE): 4/10 doğru bir turdan sonra XP 130'da
    // kaldı, sekmeye basılınca 230 oldu.
    //
    // Sessizdi çünkü tazeleme kodu VARDI ve doğru görünüyordu; yanlış olan
    // çağrılma ANIydı ve hiçbir test iki rotalı (quiz → sonuç) dönüşü
    // kurmuyordu.
    final owned = _ownedRoomResumeRoute;
    if (owned != null) {
      _ownedRoomResumeRoute = null;
      if (owned.userId == _roomResumeAccountUserId &&
          owned.epoch == _roomResumeEpoch) {
        return;
      }
    }
    _retryRoomResumeWhenVisible();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    appPageRouteObserver.unsubscribe(_tabRefreshAware);
    WidgetsBinding.instance.removeObserver(this);
    JoinDeepLink.incoming.removeListener(_onIncomingJoinLink);
    PushTapRouter.pending.removeListener(_onPushTapTarget);
    _connectivitySub?.cancel();
    _homeScrollController.dispose();
    _profileScrollController.dispose();
    _homeRefresh.dispose();
    _leaderboardRefresh.dispose();
    _playRefresh.dispose();
    _profileRefresh.dispose();
    super.dispose();
  }

  Future<void> _loadOnboardingState() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showOnboarding = preferences.getBool(_onboardingSeenKey) != true;
      _checkingOnboarding = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingSeenKey, true);
    AnalyticsService.instance.logOnboardingCompleted();
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ku = context.isKu;
    _syncRoomResumeAccount(
      authProvider.isAuthenticated
          ? _normalizedUserId(widget.repository.currentUserId)
          : null,
    );

    if (_checkingOnboarding) {
      return const Scaffold(body: BrandedLoaderCenter());
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    if (!authProvider.isAuthenticated) {
      _profileCheckStarted = false;
      _profileCheckedUserId = null;
      return Scaffold(
        body: Column(
          children: [
            _statusBanner(context),
            // Kabuktaki düzeltmenin aynısı: bant görünürken üst güvenli
            // alanı o karşılar; giriş ekranı onu ikinci kez eklemesin.
            Expanded(
              child: _statusBannerVisible(context)
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: const SignInScreen(),
                    )
                  : const SignInScreen(),
            ),
          ],
        ),
      );
    }

    // Kurtarma bağlantısı da normal bir oturum açar. Bu kapı olmadan
    // kullanıcı doğrudan Home'a düşüyor ve parolası eski hâliyle
    // kalıyordu — "parolamı unuttum" hiçbir şeyi kurtarmıyordu
    // (2026-08-06 denetimi).
    //
    // İtilmiş bir rota yerine build kapısı olması bilinçli: geri tuşu
    // ya da web'de tarayıcı geri düğmesi kurtarmayı atlayamasın.
    if (authProvider.needsPasswordRecovery) {
      return const PasswordRecoveryScreen();
    }

    final activeUserId = widget.repository.currentUserId;
    if (_profileCheckedUserId != activeUserId) {
      _profileCheckedUserId = activeUserId;
      _profileCheckStarted = false;
      _profileNameComplete = false;
    }

    if (!_profileCheckStarted) {
      _profileCheckStarted = true;
      _checkingProfileName = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfileNameState(activeUserId);
      });
    }

    if (_checkingProfileName) {
      return const Scaffold(body: BrandedLoaderCenter());
    }

    if (!_profileNameComplete) {
      return ProfileNameGateScreen(
        repository: widget.repository,
        onCompleted: _completeProfileName,
      );
    }

    final resumableUserId = _normalizedUserId(activeUserId);
    if (resumableUserId != null) {
      _scheduleRoomResumeCheck(resumableUserId);
    }
    _scheduleJoinDeepLink();
    _schedulePushTapTarget();

    // Web'de tarayıcı Geri kök rotayı (AppShell, splash sonrası tek rota)
    // pop edince beyaz boş sayfa oluşuyordu (2026-07-19 canlı denetim P1).
    // Kök rota hiç pop edilmez; geri, ana sekmeye düşer. Mobilde ana
    // sekmedeyken sistem geri normal çıkış yapar.
    return PopScope(
      canPop: !kIsWeb && _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab != 0) setState(() => _tab = 0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildScaffold(context, ku, constraints.maxWidth),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, bool ku, double width) {
    // 2026-07-22 canlı UX denetimi: tablet iki sütun düzeni
    final isDesktop = width >= AppShell.desktopNavBreakpoint;

    final body = IndexedStack(
      index: _tab,
      children: List.generate(4, (index) => _buildTab(context, index)),
    );

    // Sekme içeriği durum çubuğunun ALTINA girmez.
    //
    // Kusur: sekmeler `SafeArea` olmadan çiziliyordu. Ekranlar kendi üst
    // dolgularını verdiği için ilk kare doğru görünüyor, ama liste
    // kaydırıldığında kartlar durum çubuğunun ve Dynamic Island'ın altından
    // geçiyordu: ana ekranda "Ders yolu" başlığı saatin ve adacığın arkasında
    // kayboluyordu (2026-08-16 simülatör taraması, iPhone 17).
    //
    // `SafeArea` iç içe geçtiğinde katlanmaz — dıştaki dolguyu tüketir ve
    // içeridekiler sıfır görür; bu yüzden ekranların kendi dolguları iki
    // katına çıkmaz. Alt taraf `bottomNavigationBar`ın işi olduğu için
    // dışarıda bırakıldı.
    final rawContent = SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width >= 1200
                ? 1140
                : (width >= AppShell.desktopNavBreakpoint ? 920 : 800),
          ),
          child: body,
        ),
      ),
    );

    // Kusur: bant (`OfflineBanner`) görünürken üst güvenli alanı KENDİSİ
    // karşılıyor — dekorasyonu (renk/kenarlık) `SafeArea`SINI dıştan sarar,
    // yani durum çubuğunun ardına kadar uzanır ve okunaklı satırı onun
    // altına iter (bkz. `offline_banner.dart`). Yukarıdaki `rawContent`
    // bunu BİLMEDEN aynı boşluğu ikinci kez ekliyordu: bant + durum çubuğu
    // yüksekliği kadar boş, dokunulmamış bir şerit oluşuyor; `Expanded`
    // sabit yükseklik verdiği için kaydırılan içerik de altta o kadarlık
    // kısmı kırpılıyordu (2026-09-27 simülatör turu). `MediaQuery.
    // removePadding` ile üst boşluğu bu alt ağaçta sıfırlıyoruz; bant
    // görünmüyorken DOKUNMUYORUZ çünkü o zaman tek karşılayıcı budur.
    final statusBannerVisible = _statusBannerVisible(context);
    final content = statusBannerVisible
        ? MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: rawContent,
          )
        : rawContent;

    if (isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            _statusBanner(context),
            Expanded(
              child: Row(
                children: [
                  _buildNavRail(context, ku),
                  VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: SahneTokens.of(context).line,
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _statusBanner(context),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, ku),
    );
  }

  Widget _statusBanner(BuildContext context) {
    final remoteLocked = RemoteAvailability.socialLockedIn(context);
    if (remoteLocked) {
      return OfflineBanner(
        isOffline: true,
        label: context.t(K.serverUnreachableTitle),
        onRetry: null,
      );
    }
    return OfflineBanner(isOffline: _isOffline, onRetry: _refreshConnectivity);
  }

  /// `_statusBanner` ile AYNI koşul: kilit modu (sunucuya hiç ulaşılamıyor)
  /// ya da yerel ağ kaybı. İkisi ayrışırsa bant görünürlüğüyle üst boşluk
  /// düzeltmesi de ayrışır — bkz. `_buildScaffold`teki `rawContent` yorumu.
  bool _statusBannerVisible(BuildContext context) {
    return RemoteAvailability.socialLockedIn(context) || _isOffline;
  }

  bool _joinDeepLinkScheduled = false;

  void _scheduleJoinDeepLink() {
    if (_joinDeepLinkScheduled) return;
    _joinDeepLinkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeJoinDeepLink());
    });
  }

  Future<void> _consumeJoinDeepLink() async {
    if (!mounted) return;
    if (RemoteAvailability.socialLockedIn(context)) return;
    final code =
        JoinDeepLink.consumeInitialRoute() ?? JoinDeepLink.takeIncoming();
    if (code == null) return;
    await _joinOnlineRoomAndOpen(code);
  }

  /// Uygulama açıkken gelen davet (sıcak açılış). Bağlantıyı
  /// `MaterialApp`in üstündeki [JoinDeepLinkScope] yakalar ve
  /// [JoinDeepLink.incoming] kanalına koyar; kabuk buradan tüketir.
  ///
  /// Kabuk henüz ana arayüze ulaşmadıysa (açılış, giriş, isim kapısı) kod
  /// kanalda bekler; ana arayüz kurulunca [_consumeJoinDeepLink] alır.
  /// Sosyal yüzeyler kilitliyken (sunucuya erişilemiyor) davet yok sayılır —
  /// soğuk açılıştaki sözleşmeyle aynı.
  void _onIncomingJoinLink() {
    if (!mounted || !_joinDeepLinkScheduled) return;
    if (JoinDeepLink.incoming.value == null) return;
    if (RemoteAvailability.socialLockedIn(context)) {
      JoinDeepLink.takeIncoming();
      return;
    }
    final code = JoinDeepLink.takeIncoming();
    if (code == null) return;
    unawaited(_joinOnlineRoomAndOpen(code));
  }

  /// [code] ile oda katılımını dener, başarılıysa [RoomScreen] açar.
  ///
  /// Soğuk açılış (`_consumeJoinDeepLink`) ve sıcak açılış
  /// (`didPushRouteInformation`) aynı katılma gövdesini paylaşır; ikisinin
  /// farkı yalnız KODUN NEREDEN geldiğidir.
  Future<void> _joinOnlineRoomAndOpen(String code) async {
    try {
      final room = await widget.repository.joinOnlineRoom(code);
      if (!mounted) return;
      await Navigator.of(context).push(
        AppRoute.to(
          RoomScreen(repository: widget.repository, initialRoom: room),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'join deep link failed');
    }
  }

  bool _pushTapScheduled = false;

  /// [JoinDeepLink] ile AYNI desen: kabuk kapıları (onboarding/giriş/isim)
  /// geçilip bu noktaya ulaşıldığında bir kez planlanır ve bekleyen bildirim
  /// hedefini bir sonraki karede tüketir.
  void _schedulePushTapTarget() {
    if (_pushTapScheduled) return;
    _pushTapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumePushTapTarget(),
    );
  }

  /// Soğuk açılışta (`getInitialMessage`) ya da kabuk henüz hazır değilken
  /// gelmiş bir dokunuşu tüketir — hedef [PushTapRouter.pending]de bekliyor
  /// olabilir, dinleyici onu kabuk hazır olmadan önce görüp yok saymış olsa
  /// bile burada `take()` ile yakalanır.
  void _consumePushTapTarget() {
    if (!mounted || !_shellIsTopRoute) return;
    final target = PushTapRouter.take();
    if (target == null) return;
    _applyPushTapTarget(target);
  }

  /// Uygulama açıkken gelen bildirim dokunuşu (sıcak açılış). Kabuk henüz
  /// [_schedulePushTapTarget]e ulaşmadıysa hedef kanalda bekler; sonradan
  /// [_consumePushTapTarget] alır.
  void _onPushTapTarget() {
    if (!mounted || !_pushTapScheduled || !_shellIsTopRoute) return;
    if (PushTapRouter.pending.value == null) return;
    final target = PushTapRouter.take();
    if (target == null) return;
    _applyPushTapTarget(target);
  }

  /// Kabuğun üstünde bir sayfa ya da diyalog (ör. canlı bir oda maçı) açık
  /// mı? Açıksa bildirim hedefi BEKLER: arkadaşlar ekranını bir maçın üstüne
  /// itmek, arkada sayacı işleyen oyunu oyuncunun elinden alırdı. Hedef
  /// kabuğa dönülünce ([didPopNext]) uygulanır.
  bool get _shellIsTopRoute => ModalRoute.of(context)?.isCurrent ?? true;

  void _applyPushTapTarget(PushTapTarget target) {
    switch (target) {
      case PushTapTarget.playTab:
        _selectTab(1);
      case PushTapTarget.friends:
        _selectTab(2);
        unawaited(
          Navigator.of(
            context,
          ).push(AppRoute.to(FriendsScreen(repository: widget.repository))),
        );
    }
  }

  Widget _buildTab(BuildContext context, int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => LearnHomeScreen(
        repository: widget.repository,
        scrollController: _homeScrollController,
        refreshSignal: _homeRefresh,
        onOpenLearning: () async {
          await Navigator.of(
            context,
          ).push(AppRoute.to(LearningScreen(repository: widget.repository)));
        },
        onOpenPlay: () => _selectTab(1),
      ),
      1 => PlayHubScreen(
        repository: widget.repository,
        refreshSignal: _playRefresh,
      ),
      2 => LeaderboardScreen(
        repository: widget.repository,
        refreshSignal: _leaderboardRefresh,
        isVisible: () => _tab == 2,
      ),
      3 => ProfileScreen(
        repository: widget.repository,
        refreshSignal: _profileRefresh,
        scrollController: _profileScrollController,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int i) {
    if (_tab == i) {
      final controller = switch (i) {
        0 => _homeScrollController,
        3 => _profileScrollController,
        _ => null,
      };
      if (controller != null && controller.hasClients) {
        controller.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    _refreshVisibleTab(i);
    setState(() {
      _visitedTabs.add(i);
      _tab = i;
    });
  }

  /// [tab] (verilmezse görünen sekme) için tazeleme sinyalini tetikler.
  void _refreshVisibleTab([int? tab]) {
    final i = tab ?? _tab;
    if (i == 0) _homeRefresh.value++;
    if (i == 1) _playRefresh.value++;
    if (i == 2) _leaderboardRefresh.value++;
    if (i == 3) _profileRefresh.value++;
  }

  /// Sekme simgeleri (Lucide). Öğren kitap, Sıralama kupa (maket).
  ///
  /// 2026-09-29 Şahnê: Öğren sekmesi ev yerine açık kitap taşır — sekmenin
  /// işi "ana sayfa" değil öğrenmedir. Yarış sekmesinin maketteki simgesi
  /// Lucide `swords`; `AppIcons`ta henüz yok, o gelene dek oyun kolu kalır.
  static const _learnIcon = AppIcons.bookOpen;
  static const _playIcon = AppIcons.gamepad;
  static const _leaderboardIcon = AppIcons.trophy;
  static const _profileIcon = AppIcons.user;

  /// Geniş ekran rayı: alt gezinmeyle aynı Şahnê dili — seçili sekme Ray
  /// (`s3`) plaketi + birincil metin; seçili olmayan üçüncül metin. Turuncu
  /// yok: turuncu ekranın tek birincil eylemidir, gezinme değil.
  Widget _buildNavRail(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    return NavigationRail(
      selectedIndex: _tab,
      onDestinationSelected: _selectTab,
      labelType: NavigationRailLabelType.all,
      backgroundColor: t.nav,
      selectedLabelTextStyle: SahneType.caption.copyWith(
        color: t.tx,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: SahneType.caption.copyWith(color: t.tx3),
      selectedIconTheme: IconThemeData(color: t.tx, size: 24),
      unselectedIconTheme: IconThemeData(color: t.tx3, size: 24),
      indicatorColor: t.s3,
      indicatorShape: SahneShape.m,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(_learnIcon),
          selectedIcon: KeyedSubtree(
            key: _homeNavKey,
            child: const Icon(_learnIcon),
          ),
          label: Text(context.t(K.navLearn)),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(key: _playNavKey, child: const Icon(_playIcon)),
          selectedIcon: const Icon(_playIcon),
          label: Text(context.t(K.navPlay)),
        ),
        NavigationRailDestination(
          icon: const Icon(_leaderboardIcon),
          selectedIcon: const Icon(_leaderboardIcon),
          label: Text(context.t(K.navLeaderboard)),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _profileNavKey,
            child: const Icon(_profileIcon),
          ),
          selectedIcon: const Icon(_profileIcon),
          label: Text(context.t(K.navProfile)),
        ),
      ],
    );
  }

  /// Alt gezinme (A iskeletinin tabanı: 64 + güvenli alan).
  ///
  /// 2026-09-29 Şahnê: görünüş tümüyle temadan gelir
  /// (`navigationBarTheme`: Şev zemini, seçili sekme Ray plaketi M pah +
  /// birincil metin, seçili olmayan üçüncül metin). Eskiden burada ikinci
  /// bir tema kuruluyordu — terrakota gösterge, stadyum biçimi, bulanık
  /// gölge — ve seçili sekme açık/koyu temada iki ayrı görünüşe
  /// bürünüyordu. Artık her yerde TEK görünüş; üstte yalnız 1 px çizgi.
  Widget _buildBottomNav(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        // Sekme hedefleri dile bağımlı metinle değil, sabit anahtarla
        // bulunur — etiketler ("Yarış") ekran içeriğinde de geçebiliyor.
        destinations: [
          NavigationDestination(
            key: const ValueKey('nav-learn'),
            icon: const Icon(_learnIcon),
            selectedIcon: KeyedSubtree(
              key: _homeNavKey,
              child: const Icon(_learnIcon),
            ),
            label: context.t(K.navLearn),
          ),
          NavigationDestination(
            key: const ValueKey('nav-play'),
            icon: KeyedSubtree(key: _playNavKey, child: const Icon(_playIcon)),
            selectedIcon: const Icon(_playIcon),
            label: context.t(K.navPlay),
          ),
          NavigationDestination(
            key: const ValueKey('nav-leaderboard'),
            icon: const Icon(_leaderboardIcon),
            selectedIcon: const Icon(_leaderboardIcon),
            label: context.t(K.navLeaderboard),
          ),
          NavigationDestination(
            key: const ValueKey('nav-profile'),
            icon: KeyedSubtree(
              key: _profileNavKey,
              child: const Icon(_profileIcon),
            ),
            selectedIcon: const Icon(_profileIcon),
            label: context.t(K.navProfile),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProfileNameState(String? userId) async {
    setState(() => _checkingProfileName = true);
    final offlineMode = context.read<AuthProvider>().isOfflineMode;
    final preferences = await SharedPreferences.getInstance();
    final key = _profileNameCompletionKey(userId, offlineMode: offlineMode);
    final completed = key != null && preferences.getBool(key) == true;

    // Bu kapı yalnız oyuncunun adı başarıyla kaydettiğini belirten yerel
    // ve kullanıcıya özel bayrağa dayanır. Global bir bayrak hesap değişiminde
    // yeni oyuncunun kapısını atlatır ve aynı varsayılan adı 1v1 kimliğine
    // taşır. İsim, HomeScreen'in arka plan akışında zenginleşir; ağdaki
    // yeniden denemeler başlangıç rotasını veya tam ekranı bekletemez.
    if (!mounted || widget.repository.currentUserId != userId) return;
    setState(() {
      _profileNameComplete = completed;
      _checkingProfileName = false;
    });
  }

  Future<void> _completeProfileName() async {
    final offlineMode = context.read<AuthProvider>().isOfflineMode;
    final preferences = await SharedPreferences.getInstance();
    final key = _profileNameCompletionKey(
      widget.repository.currentUserId,
      offlineMode: offlineMode,
    );
    if (key != null) await preferences.setBool(key, true);
    if (!mounted) return;
    setState(() {
      _profileNameComplete = true;
      _profileCheckStarted = true;
    });
  }

  String? _profileNameCompletionKey(
    String? userId, {
    required bool offlineMode,
  }) {
    final normalized = userId?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return '$_profileNameCompletedKeyPrefix$normalized';
    }
    if (offlineMode) {
      return '${_profileNameCompletedKeyPrefix}offline-local';
    }
    return null;
  }

  void _scheduleRoomResumeCheck(String userId) {
    final epoch = _roomResumeEpoch;
    if (!_canCheckRoomResume(userId, epoch) ||
        _roomResumeScheduledEpochs[userId] == epoch) {
      return;
    }

    _roomResumeScheduledEpochs[userId] = epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_roomResumeScheduledEpochs[userId] != epoch) return;
      _roomResumeScheduledEpochs.remove(userId);
      if (!_canCheckRoomResume(userId, epoch)) return;
      _roomResumeRetryWhenVisibleUsers.remove(userId);
      _roomResumeInFlightEpochs[userId] = epoch;
      unawaited(_loadRoomResume(userId, epoch));
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool _canCheckRoomResume(String userId, int epoch) {
    if (!_isCurrentRoomResumeUser(userId, epoch) ||
        _roomResumeCheckedUsers.contains(userId) ||
        _roomResumeInFlightEpochs[userId] == epoch ||
        _roomResumeAwaitingReconnectUsers.contains(userId) ||
        _roomResumeRouteScheduledEpochs[userId] == epoch) {
      return false;
    }
    return true;
  }

  Future<void> _loadRoomResume(String userId, int epoch) async {
    var errorReason = 'app_shell_room_resume';
    try {
      final snapshot = await widget.repository.loadMyResumableRoom();
      if (!_continueRoomResumeOrDefer(userId, epoch)) return;

      if (snapshot != null && snapshot.room.status != RoomStatus.finished) {
        Widget destination;
        switch (snapshot.room.status) {
          case RoomStatus.lobby:
            destination = RoomScreen(
              repository: widget.repository,
              initialRoom: snapshot.room,
            );
          case RoomStatus.active:
            final questions = await widget.repository.loadRoomQuestions(
              snapshot.room,
            );
            if (questions.isEmpty) {
              throw StateError('Resumable online room has no questions.');
            }
            if (!_continueRoomResumeOrDefer(userId, epoch)) return;
            destination = QuizScreen(
              repository: widget.repository,
              room: snapshot.room,
              questions: questions,
              is1v1: true,
              resumeSnapshot: snapshot,
            );
          case RoomStatus.finished:
            return;
        }
        _scheduleRoomResumeRoute(userId, epoch, snapshot.room, destination);
        return;
      }

      errorReason = 'app_shell_pending_room_result';
      final pending = await widget.repository.loadMyPendingRoomResult();
      if (!_continueRoomResumeOrDefer(userId, epoch)) return;
      if (pending == null) {
        _roomResumeCheckedUsers.add(userId);
        return;
      }
      if (!_isValidPendingRoomResult(pending, userId)) {
        _roomResumeCheckedUsers.add(userId);
        _roomResumeRejectedUsers.add(userId);
        throw const FormatException('Pending room result is malformed.');
      }
      _scheduleRoomResumeRoute(
        userId,
        epoch,
        pending.room,
        RoomResultRecoveryScreen(
          repository: widget.repository,
          snapshot: pending,
          expectedUserId: userId,
        ),
      );
    } catch (error, stack) {
      if (_isCurrentRoomResumeIdentity(userId, epoch) &&
          !_roomResumeCheckedUsers.contains(userId)) {
        _roomResumeAwaitingReconnectUsers.add(userId);
      }
      (widget.errorRecorder ?? ErrorReporter.record)(
        error,
        stack,
        reason: errorReason,
      );
    } finally {
      if (_roomResumeInFlightEpochs[userId] == epoch) {
        _roomResumeInFlightEpochs.remove(userId);
      }
      if (_isCurrentRoomResumeUser(userId, epoch) &&
          _roomResumeRetryWhenVisibleUsers.contains(userId)) {
        _retryRoomResumeWhenVisible();
      }
    }
  }

  void _scheduleRoomResumeRoute(
    String userId,
    int epoch,
    GameRoom room,
    Widget destination,
  ) {
    final roomId = room.id?.trim();
    if (roomId == null || roomId.isEmpty) {
      throw const FormatException('Recovery room id is missing.');
    }
    _roomResumeRouteScheduledEpochs[userId] = epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_roomResumeRouteScheduledEpochs[userId] != epoch) return;
      _roomResumeRouteScheduledEpochs.remove(userId);
      if (!_isCurrentRoomResumeUser(userId, epoch)) {
        if (_isCurrentRoomResumeIdentity(userId, epoch)) {
          _roomResumeRetryWhenVisibleUsers.add(userId);
        }
        return;
      }
      _roomResumeCheckedUsers.add(userId);
      _ownedRoomResumeRoute = (epoch: epoch, roomId: roomId, userId: userId);
      Navigator.of(context).push(AppRoute.to(destination));
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool _continueRoomResumeOrDefer(String userId, int epoch) {
    if (_isCurrentRoomResumeUser(userId, epoch)) return true;
    if (_isCurrentRoomResumeIdentity(userId, epoch)) {
      _roomResumeRetryWhenVisibleUsers.add(userId);
    }
    return false;
  }

  bool _isCurrentRoomResumeUser(String userId, int epoch) {
    if (!_isCurrentRoomResumeIdentity(userId, epoch) ||
        !_connectivityKnown ||
        _isOffline ||
        _checkingOnboarding ||
        _showOnboarding ||
        _checkingProfileName ||
        !_profileNameComplete ||
        _shellRoute?.isCurrent != true) {
      return false;
    }
    return context.read<AuthProvider>().isAuthenticated &&
        _normalizedUserId(widget.repository.currentUserId) == userId;
  }

  bool _isCurrentRoomResumeIdentity(String userId, int epoch) {
    return mounted &&
        _roomResumeEpoch == epoch &&
        _roomResumeAccountUserId == userId &&
        _normalizedUserId(widget.repository.currentUserId) == userId;
  }

  bool _isValidPendingRoomResult(RoomResultSnapshot snapshot, String userId) {
    final roomId = snapshot.room.id?.trim();
    final playerIds = snapshot.room.players
        .map((player) => player.id?.trim() ?? '')
        .toList(growable: false);
    return roomId != null &&
        roomId.isNotEmpty &&
        snapshot.ownPlayerId.trim() == userId &&
        snapshot.room.status == RoomStatus.finished &&
        snapshot.endedReason.trim().toLowerCase() == 'completed' &&
        snapshot.forfeitedBy == null &&
        playerIds.length == 2 &&
        playerIds.every((id) => id.isNotEmpty) &&
        playerIds.toSet().length == 2 &&
        playerIds.where((id) => id == userId).length == 1;
  }

  void _syncRoomResumeAccount(String? userId) {
    if (_roomResumeAccountUserId == userId) return;
    _roomResumeAccountUserId = userId;
    _roomResumeEpoch++;
    if (userId == null) return;
    _roomResumeCheckedUsers.remove(userId);
    _roomResumeAwaitingReconnectUsers.remove(userId);
    _roomResumeRejectedUsers.remove(userId);
    _roomResumeRetryWhenVisibleUsers.add(userId);
  }

  void _wakeRoomResumeForCurrentUser() {
    final userId = _roomResumeAccountUserId;
    if (userId == null || _ownedRoomResumeRoute != null) return;
    if (_shellRoute?.isCurrent != true) {
      _roomResumeRetryWhenVisibleUsers.add(userId);
      return;
    }
    if (_roomResumeRejectedUsers.contains(userId) ||
        _roomResumeInFlightEpochs[userId] == _roomResumeEpoch) {
      return;
    }
    _roomResumeCheckedUsers.remove(userId);
    _roomResumeAwaitingReconnectUsers.remove(userId);
    _roomResumeRetryWhenVisibleUsers.remove(userId);
    _scheduleRoomResumeCheck(userId);
  }

  void _retryRoomResumeWhenVisible() {
    final userId = _roomResumeAccountUserId;
    if (userId == null ||
        _roomResumeRejectedUsers.contains(userId) ||
        !_roomResumeRetryWhenVisibleUsers.contains(userId) ||
        _roomResumeInFlightEpochs[userId] == _roomResumeEpoch ||
        _shellRoute?.isCurrent != true) {
      return;
    }
    _roomResumeRetryWhenVisibleUsers.remove(userId);
    _roomResumeCheckedUsers.remove(userId);
    _roomResumeAwaitingReconnectUsers.remove(userId);
    _scheduleRoomResumeCheck(userId);
  }

  String? _normalizedUserId(String? userId) {
    final normalized = userId?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// Kabuğa SAYFA geçişiyle dönüldüğünü bildiren küçük dinleyici.
///
/// Ayrı bir nesne olması şart. Kabuk durumu iki gözlemciye birden abone
/// olsaydı her gözlemci kendi dinleyici tablosunu tuttuğu için `didPopNext`
/// sayfadan her dönüşte iki kez çalışır, yani tur dönüşü iki tazeleme
/// yapardı.
class _TabRefreshRouteAware extends RouteAware {
  _TabRefreshRouteAware({required this.onReturnedToShell});

  final VoidCallback onReturnedToShell;

  @override
  void didPopNext() => onReturnedToShell();
}
