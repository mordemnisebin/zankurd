import '../utils/profile_tab_request.dart';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sync_manager.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/async_duel.dart';
import '../models/room.dart';
import '../models/room_invite.dart';
import '../providers/auth_provider.dart';
import '../providers/remote_availability.dart';
import '../providers/repository_holder.dart';
import '../data/offline_zankurd_repository.dart';
import '../widgets/sahne/sahne.dart';
import '../services/notification_service.dart';
import '../services/notification_sync.dart';
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
import '../services/foreground_push_center.dart';
import '../services/push_messaging_gateway.dart';
import '../services/push_tap_router.dart';
import '../services/social_push_prompt.dart';
import '../services/room_result_presentation.dart';
import '../services/push_token_sync.dart';
import 'async_duel/async_duel_inbox.dart';
import 'async_duel/async_duel_play_screen.dart';
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

  /// Geç kurtarmada depo bu nesne üzerinden değişir ([_repository]).
  /// Sağlayıcı yoksa null kalır — izole widget testleri aynı ağırlıkta.
  RepositoryHolder? _repositoryHolder;
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
    ProfileTabRequest.pending.addListener(_onProfileTabRequest);
    _foregroundPushSub = ForegroundPushCenter.events.listen(
      _refreshForForegroundPush,
    );
    SocialPushPrompt.tokenSync = widget.pushTokenSync;
    _homeScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
    _initConnectivity();
    unawaited(widget.pushTokenSync?.sync());
    unawaited(NotificationService.syncStreakWarning());
    unawaited(NotificationSync.run(_repository));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rota kontrolünden ÖNCE okunmalı: rota aynıysa erken dönüldüğünde
    // depo takası hiç izlenmezdi.
    _repositoryHolder = RepositoryHolder.read(context);
    // Sosyal kilit kalkınca bekleyen davet kodu açılır. Kabuğun kendi
    // çizimi buna güvenilir şekilde uyanmaz (bant yalnız alt ağaçta
    // izliyor), bu yüzden doğrudan dinlenir.
    final availability = RemoteAvailability.read(context);
    if (!identical(availability, _availability)) {
      _availability?.removeListener(_onAvailabilityChanged);
      _availability = availability;
      availability?.addListener(_onAvailabilityChanged);
    }
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
    if (reconnected) {
      _wakeRoomResumeForCurrentUser();
      // Yerel ağ geri geldiyse uzak başlatma da artık tamamlanmış
      // olabilir: arkadaki geri çekilmeyi (2 sn ve sonrası) beklemeden
      // hemen yokla. Başarısızsa takvim kendi yolunda sürer.
      _retryRemoteAvailability();
    }
    if (!transitioned) return;
    // Bağlantı koptuğunda sosyal kilit dürüstçe kapanır; bağlantı
    // dönünce kilit yalnız depo ölü değilse açılır. Ölü depo =
    // çevrimdışı açılışın `Offline` deposu — Mock testlerde canlı
    // backend yerine geçtiği için kilit sayılmaz.
    try {
      context.read<RemoteAvailability>().update(
        !nextOffline && _repository is! OfflineZanKurdRepository,
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
      // Seri uyarısı tek atıştır: öne gelişte bir sonraki akşama yeniden kurulur.
      // Önce saat dilimi tazelenir (seyahat): uyarı yeni dilimde kurulsun.
      unawaited(() async {
        await NotificationService.instance?.refreshTimeZone();
        await NotificationService.syncStreakWarning();
      }());
      unawaited(NotificationSync.run(_repository));
      // Ön plana dönüşte görünen sekme tazelenir. Ana ekranın düello kartı
      // yalnız tazeleme işareti (`_homeRefresh`) değişince yeniden okur;
      // uygulama arka plandayken biten bir düello (rakip oynadı, bildirim
      // geldi) kullanıcı uygulamayı açınca eski haliyle görünüyordu.
      // Üstte bir sayfa (maç, sonuç) açıksa dokunulmaz: o sayfaya dönülünce
      // sayfa gözlemcisi zaten tazeler.
      if (_shellIsTopRoute) _refreshVisibleTab();
      // Arkaya atılmış bir deneme ön plana dönüşle tazelenir: kullanıcı
      // uygulamayı açtığında "sunucuya ulaşılamadı" bandı, bir sonraki
      // geriçekilmeyi (60 sn'ye kadar) beklemeden kalkabilir.
      _retryRemoteAvailability();
      _considerRemoteUpgrade();
    }
  }

  /// Uzak ulaşılabiliğer yoklaması — sağlayıcı yoksa sessizce yok sayılır
  /// (izole widget testleri).
  void _retryRemoteAvailability() {
    final availability = RemoteAvailability.read(context);
    if (availability == null) return;
    unawaited(availability.retryNow());
  }

  /// Boot'da çevrimdışı kalan oturumun uzak oturumla yeniden kurulması
  /// için kalan tek koşul: üstünde açık rota kalmamış olması (kökteyiz).
  void _considerRemoteUpgrade() =>
      RemoteAvailability.read(context)?.considerUpgradeNow();

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
    // Maç sürerken gelen davet bağlantısı da burada, kabuk yeniden en
    // üstteyken açılır.
    if (_pendingJoinCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpenJoinCode());
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
    // Kabuk yeniden kök: üstteki ekran kapandı, yani ertelenmiş uzak
    // oturum yeniden kurulumu artık güvenlidir.
    _considerRemoteUpgrade();
  }

  RemoteAvailability? _availability;

  void _onAvailabilityChanged() {
    if (_pendingJoinCode == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpenJoinCode());
  }

  @override
  void dispose() {
    _availability?.removeListener(_onAvailabilityChanged);
    appRouteObserver.unsubscribe(this);
    appPageRouteObserver.unsubscribe(_tabRefreshAware);
    WidgetsBinding.instance.removeObserver(this);
    JoinDeepLink.incoming.removeListener(_onIncomingJoinLink);
    PushTapRouter.pending.removeListener(_onPushTapTarget);
    ProfileTabRequest.pending.removeListener(_onProfileTabRequest);
    unawaited(_foregroundPushSub?.cancel());
    if (identical(SocialPushPrompt.tokenSync, widget.pushTokenSync)) {
      SocialPushPrompt.tokenSync = null;
    }
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
    // Okuma başarısız olursa (bozuk depo) yükleyici sonsuza dek kalmasın:
    // güvenli varsayılan, tanıtımı göstermektir.
    var show = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      show = preferences.getBool(_onboardingSeenKey) != true;
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'onboarding state load failed',
      );
    }
    if (!mounted) return;
    setState(() {
      _showOnboarding = show;
      _checkingOnboarding = false;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_onboardingSeenKey, true);
    } catch (error, stack) {
      // Yazılamasa da kullanıcıyı tanıtımda kilitleme; bellekte ilerle.
      ErrorReporter.record(
        error,
        stack,
        reason: 'onboarding flag write failed',
      );
    }
    AnalyticsService.instance.logOnboardingCompleted();
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  bool _wasAuthenticated = false;

  /// Oturumlu → oturumsuz GEÇİŞİNDE kabuğun üstündeki rotaları kapatır.
  ///
  /// Hesap silme ya da uzaktan oturum kapanması giriş ekranını kabuğun
  /// YERİNE çizer; üstteki Ayarlar gibi itilmiş rotalar yığında kalır ve
  /// kullanıcı giriş yerine takılı bir sayfaya bakardı (bkz.
  /// `test/app_shell_signed_out_pops_routes_test.dart`). Yalnız geçiş
  /// tetikler: hiç girmemiş kullanıcının açtığı Kayıt ol gibi sayfalara
  /// dokunulmaz.
  void _popRoutesWhenSignedOut(bool authenticated) {
    final wasAuthenticated = _wasAuthenticated;
    _wasAuthenticated = authenticated;
    if (!wasAuthenticated || authenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shellRoute = _shellRoute;
      if (shellRoute == null) return;
      Navigator.of(context).popUntil((route) => identical(route, shellRoute));
    });
  }

  /// Etkin depo.
  ///
  /// Geç kurtarmada [RepositoryHolder] değişir; sağlayıcı yoksa (izole
  /// widget testleri) kurucuda verilen [AppShell.repository] kalır.
  ZanKurdRepository get _repository =>
      _repositoryHolder?.repository ?? widget.repository;

  @override
  Widget build(BuildContext context) {
    // Depo takasını izle: geç kurtarmada holder değişince kabuk yeniden
    // çizilir ve [_repository] yeni depoyu okur. Rota yığını bozulmaz.
    _repositoryHolder = RepositoryHolder.watch(context);
    final authProvider = context.watch<AuthProvider>();
    final ku = context.isKu;
    _syncRoomResumeAccount(
      authProvider.isAuthenticated
          ? _normalizedUserId(_repository.currentUserId)
          : null,
    );
    _popRoutesWhenSignedOut(authProvider.isAuthenticated);

    if (_checkingOnboarding) {
      return const Scaffold(body: BrandedLoaderCenter());
    }

    // Kurtarma kapısı tanıtımdan ÖNCE: sıfırlama bağlantısını yeni bir
    // tarayıcıda açan kişi önce örnek sorularla karşılaşıyordu (2026-10-23).
    if (authProvider.needsPasswordRecovery) {
      return const PasswordRecoveryScreen();
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

    final activeUserId = _repository.currentUserId;
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
        repository: _repository,
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
    // `watch`: uzak kurtarma (arka plan geriçekilmesi) başardığında bant
    // kendiliğinden kalkar; `socialLockedIn` (dinlemeyen) yalnız bir
    // sonraki tesadüfi çizimde kalkardı.
    final remoteLocked = RemoteAvailability.socialLockedWatch(context);
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
    return RemoteAvailability.socialLockedWatch(context) || _isOffline;
  }

  /// Kabuk kapıları (onboarding, giriş, isim) geçildi ve davet bağlantıları
  /// işlenebilir.
  bool _joinDeepLinkScheduled = false;

  /// Açılmayı bekleyen davet kodu. Kod YALNIZ açılırken silinir: kabuk
  /// sosyal kilitteyken (sunucuya erişilemiyor) ya da üstünde bir maç/lobi
  /// açıkken kod kaybolmaz, uygun an gelince ([_scheduleJoinDeepLink] her
  /// çizimde, [didPopNext] dönüşte) açılır.
  String? _pendingJoinCode;
  bool _joinConsumeQueued = false;

  void _scheduleJoinDeepLink() {
    if (!_joinDeepLinkScheduled) {
      _joinDeepLinkScheduled = true;
      // Soğuk açılış bağlantısı bir kez okunur ve bekleyen koda alınır.
      _pendingJoinCode ??= JoinDeepLink.consumeInitialRoute();
    }
    if (_pendingJoinCode == null && JoinDeepLink.incoming.value == null) {
      return;
    }
    if (_joinConsumeQueued) return;
    _joinConsumeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinConsumeQueued = false;
      _tryOpenJoinCode();
    });
  }

  /// Bekleyen kodu, koşullar uygunsa açar; değilse bekletir.
  ///
  /// ## Kusur
  ///
  /// Soğuk açılışta sosyal yüzeyler kilitliyse (`socialLockedIn`) eski kod
  /// erken dönüyordu ama `_joinDeepLinkScheduled` doğru kaldığı için bir daha
  /// hiç denenmiyordu: kilit kalktığında davet sessizce kayboluyordu. Sıcak
  /// açılışta ise kod, üstte canlı bir maç ya da lobi varken bile rotayı
  /// üstüne itiyordu (bildirim dokunuşu bunu zaten bekliyordu). Hatalar da
  /// yalnız ErrorReporter'a gidiyordu; oyuncu bağlantıya dokunup hiçbir şey
  /// olmadığını görüyordu.
  void _tryOpenJoinCode() {
    if (!mounted || !_joinDeepLinkScheduled) return;
    _pendingJoinCode ??= JoinDeepLink.takeIncoming();
    final code = _pendingJoinCode;
    if (code == null) return;
    if (RemoteAvailability.socialLockedIn(context)) return;
    if (!_shellIsTopRoute) return;
    _pendingJoinCode = null;
    unawaited(_openJoinCode(code));
  }

  /// Uygulama açıkken gelen davet (sıcak açılış). Bağlantıyı
  /// `MaterialApp`in üstündeki [JoinDeepLinkScope] yakalar ve
  /// [JoinDeepLink.incoming] kanalına koyar; kabuk buradan tüketir.
  ///
  /// Kabuk henüz ana arayüze ulaşmadıysa (açılış, giriş, isim kapısı) kod
  /// kanalda bekler; ana arayüz kurulunca [_scheduleJoinDeepLink] alır.
  void _onIncomingJoinLink() => _tryOpenJoinCode();

  /// `/join/<kod>` bağlantısının iki türü: `D…` meydan okuma kodu ya da
  /// `ZK-…` oda kodu ([JoinDeepLink.isChallengeCode] ikisini kesin ayırır).
  Future<void> _openJoinCode(String code) {
    if (JoinDeepLink.isChallengeCode(code)) {
      return _acceptChallengeAndOpen(code);
    }
    return _joinOnlineRoomAndOpen(code);
  }

  /// Meydan okumayı kabul edip 7 soruluk oyun ekranını açar. Kabul
  /// (`accept_async_duel_challenge`), hesabı olmayan misafir için oturumu da
  /// kendisi açar; hatalar (süresi dolmuş, başkası almış, kendi bağlantım…)
  /// oyun ekranında dürüst, yerelleştirilmiş bir metinle ve "Kapat" ile
  /// gösterilir — çıkmaz sokak yok.
  Future<void> _acceptChallengeAndOpen(String code) async {
    try {
      _selectTab(1);
      if (!mounted) return;
      await Navigator.of(context).push(
        AppRoute.to(
          AsyncDuelPlayScreen(
            repository: _repository,
            entry: AsyncDuelEntry.acceptChallenge(code),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'challenge deep link failed');
      if (mounted) _showJoinFailure(asyncDuelStartErrorMessage(context, error));
    }
  }

  /// [code] ile oda katılımını dener, başarılıysa [RoomScreen] açar.
  ///
  /// Soğuk açılış (`_tryOpenJoinCode`) ve sıcak açılış
  /// (`didPushRouteInformation`) aynı katılma gövdesini paylaşır; ikisinin
  /// farkı yalnız KODUN NEREDEN geldiğidir.
  Future<void> _joinOnlineRoomAndOpen(String code) async {
    try {
      final room = await _repository.joinOnlineRoom(code);
      if (!mounted) return;
      await Navigator.of(context).push(
        AppRoute.to(RoomScreen(repository: _repository, initialRoom: room)),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'join deep link failed');
      // Oda katılma menüsüyle AYNI hata metinleri (dolu oda, başka odada,
      // bulunamadı ...): bağlantıya dokunup hiçbir şey olmaması yerine
      // sebep söylenir.
      if (mounted) _showJoinFailure(context.t(joinRoomErrorKey(error)));
    }
  }

  void _showJoinFailure(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
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

  StreamSubscription<ForegroundPush>? _foregroundPushSub;

  /// Uygulama açıkken gelen push'un ilgili yüzeyini tazeler: arkadaşlık
  /// isteği/kabulü → Sıralama (arkadaş rozeti) ve Yarış; oda daveti → Ana
  /// ("Odaya davet" kartı); düello → Yarış ("Düellolarım"). Bant iletiyi
  /// gösterir, bu ise ardındaki sayacı bayat bırakmaz.
  void _refreshForForegroundPush(ForegroundPush push) {
    if (!mounted) return;
    switch (push.kind) {
      case 'friend_request' || 'friend_accept':
        _leaderboardRefresh.value++;
        _playRefresh.value++;
      case 'room_invite':
        _homeRefresh.value++;
      case 'async_duel_invite' || 'async_duel_turn' || 'async_duel_result':
        _playRefresh.value++;
    }
  }

  /// Kabuğun üstünde bir sayfa ya da diyalog (ör. canlı bir oda maçı) açık
  /// mı? Açıksa bildirim hedefi BEKLER: arkadaşlar ekranını bir maçın üstüne
  /// itmek, arkada sayacı işleyen oyunu oyuncunun elinden alırdı. Hedef
  /// kabuğa dönülünce ([didPopNext]) uygulanır.
  bool get _shellIsTopRoute => ModalRoute.of(context)?.isCurrent ?? true;

  void _applyPushTapTarget(PushTapTarget target) {
    switch (target) {
      case PushTapTarget.home:
        _selectTab(0);
      case PushTapTarget.playTab:
        _selectTab(1);
      case PushTapTarget.duelInbox:
        _selectTab(1);
        unawaited(
          Navigator.of(
            context,
          ).push(AppRoute.to(AsyncDuelListScreen(repository: _repository))),
        );
      case PushTapTarget.roomInvite:
        unawaited(_openRoomInviteFromPush());
      case PushTapTarget.friends:
        _selectTab(2);
        unawaited(
          Navigator.of(
            context,
          ).push(AppRoute.to(FriendsScreen(repository: _repository))),
        );
    }
  }

  /// `room_invite` bildirimine dokunuş: tek bekleyen davet varsa kabul edilip
  /// mevcut oda katılma yolundan girilir (bağlantıyla gelen davetle aynı
  /// davranış); birden çoksa ya da hiç yoksa Ana ekran açılır, "Odaya davet"
  /// kartı orada bekler. Süresi dolmuş davet sessiz kalmaz.
  Future<void> _openRoomInviteFromPush() async {
    _selectTab(0);
    try {
      final invites = await _repository.loadMyRoomInvites(throwOnError: true);
      if (!mounted || invites.length != 1) {
        if (mounted) _homeRefresh.value++;
        return;
      }
      final code = await _repository.respondRoomInvite(
        invites.single.id,
        accept: true,
      );
      if (code == null || !mounted) return;
      await _joinOnlineRoomAndOpen(code);
    } on RoomInviteException catch (error) {
      if (mounted) {
        _showJoinFailure(
          context.t(
            error.reason == RoomInviteFailure.expired
                ? K.roomInviteExpired
                : K.roomInviteFailed,
          ),
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite push tap');
      if (mounted) _showJoinFailure(context.t(K.roomInviteFailed));
    }
  }

  Widget _buildTab(BuildContext context, int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => LearnHomeScreen(
        repository: _repository,
        scrollController: _homeScrollController,
        refreshSignal: _homeRefresh,
        onOpenLearning: () async {
          await Navigator.of(
            context,
          ).push(AppRoute.to(LearningScreen(repository: _repository)));
        },
        onOpenPlay: () => _selectTab(1),
      ),
      1 => PlayHubScreen(repository: _repository, refreshSignal: _playRefresh),
      2 => LeaderboardScreen(
        repository: _repository,
        refreshSignal: _leaderboardRefresh,
        isVisible: () => _tab == 2,
        onOpenPlay: () => _selectTab(1),
      ),
      3 => ProfileScreen(
        repository: _repository,
        refreshSignal: _profileRefresh,
        scrollController: _profileScrollController,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// Arkadaşlar ekranındaki misafir daveti "Hesabını kaydet" diyor: Profil
  /// sekmesi (kaydetme satırının yeri) açılır.
  void _onProfileTabRequest() {
    if (mounted) _selectTab(3);
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
  /// işi "ana sayfa" değil öğrenmedir. Yarış sekmesi maketteki gibi
  /// çapraz kılıç (Lucide `swords`): sekme oyun değil karşılaşmadır.
  static const _learnIcon = AppIcons.bookOpen;
  static const _playIcon = AppIcons.swords;
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
    final decoration = BoxDecoration(
      color: t.nav,
      border: Border(top: BorderSide(color: t.line)),
    );
    // İki dilli etiket (2026-10-20): her sekme adının altında öbür dildeki
    // adı, 10/12 ([SahneBilingualLabel.compact]). `NavigationDestination`
    // yalnız düz metin etiket alır; küçük satır çubuğun altındaki ayrı bir
    // sırada, her sekmenin tam altında durur ve dokunulunca aynı sekmeyi
    // açar. Ekran okuyucu yalnız asıl adı okur. Büyük yazıda (10 → 15'i
    // aşınca) satır hiç çizilmez: çubuk uzar ve sekme adlarıyla yarışırdı.
    final seconds = [for (final key in _navLabelKeys) context.secondLabel(key)];
    final showSeconds =
        seconds.any((label) => label != null) &&
        MediaQuery.textScalerOf(context).scale(10) <= 15;
    if (!showSeconds) {
      return DecoratedBox(
        decoration: decoration,
        child: _buildNavigationBar(context),
      );
    }
    // Küçük satır asıl adın hemen altına otursun: çubuk 64 yerine 60
    // (ikon plaketi 32 + 4 + ad 20 = 56 yine sığar), altında 12'lik sıra.
    // Toplam 72: ana sayfada ilk konu satırı 390×844'te ilk ekranda kalır
    // (bekçi: `manzara_seridi_test.dart`).
    final bar = _buildNavigationBar(context, height: 60);
    return DecoratedBox(
      decoration: decoration,
      child: SafeArea(
        top: false,
        // Üst dolgu da silinir: `NavigationBar` kendi `SafeArea`sıyla durum
        // çubuğu payını (iPhone'da ~62) ekliyordu; iki dilli satır açıkken
        // çubuk 60 yerine 122 çiziliyor, içerik üstünde boş bir bantta
        // kesiliyordu (2026-10-22 simülatör, bekçi: nav_yukseklik_test).
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bar,
              Row(
                key: const ValueKey('nav-second-labels'),
                children: [
                  for (var i = 0; i < seconds.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: () => _selectTab(i),
                        child: SizedBox(
                          height: 12,
                          child: seconds[i] == null
                              ? null
                              : Center(
                                  child: SahneBilingualLabel(
                                    seconds[i]!,
                                    compact: true,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Alt sekmelerin metin anahtarları, sekme sırasıyla.
  static const _navLabelKeys = [
    K.navLearn,
    K.navPlay,
    K.navLeaderboard,
    K.navProfile,
  ];

  /// Sekme etiketlerini sekme genişliğine SIĞACAK kadar küçültür.
  ///
  /// 2026-10-29 iPhone 17 Pro turu: Kurmancî "Rûpela sereke" ~100 pt'lik
  /// sekmeyi tam dolduruyor, sol ekran kenarına 7 px kalıyordu. Etiket
  /// `NavigationDestination`da düz metindir (ölçeklenmez); bu yüzden dört
  /// etiketin en uzunu ölçülür ve gerekirse yazı puntosu, her yandan 8 pt
  /// pay kalacak biçimde küçülür (en çok beşte birine kadar; gerçek yazı tipinde buna inilmez). Yazı ölçeği büyükse
  /// ölçüm de büyük hâliyle yapılır.
  Widget _withFittedNavLabels(BuildContext context, Widget bar) {
    // Bütçe çubuğun GERÇEK genişliğinden ve gerçek sekme sayısından gelir
    // (eskiden ekran genişliği / 4): yatay güvenli alan (yatay telefon, çentik)
    // düşülür.
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = MediaQuery.paddingOf(context);
        final barWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final usable = (barWidth - pad.left - pad.right).clamp(
          0.0,
          double.infinity,
        );
        return _fitLabels(context, bar, usable / _navLabelKeys.length);
      },
    );
  }

  Widget _fitLabels(BuildContext context, Widget bar, double slot) {
    final theme = Theme.of(context);
    final base = theme.navigationBarTheme.labelTextStyle?.resolve({});
    if (base == null) return bar;
    final available = slot - 16;
    final scaler = MediaQuery.textScalerOf(context);
    final clamped = scaler.clamp(maxScaleFactor: 1.3);
    var widest = 0.0;
    for (final key in _navLabelKeys) {
      final painter = TextPainter(
        text: TextSpan(
          text: context.t(key),
          style: base.copyWith(
            fontFamily: base.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: clamped,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    if (widest <= available || widest <= 0) return bar;
    // %6 güvenlik payı: ölçüm ile NavigationBar'ın kendi yerleşimi arasında
    // küçük fark kalır; etiket ikinci satıra KIRILMAMALI.
    final factor = (available / widest * 0.94).clamp(0.2, 1.0);
    final baseSize = base.fontSize ?? 12;
    return Theme(
      data: theme.copyWith(
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => theme.navigationBarTheme.labelTextStyle
                ?.resolve(states)
                ?.copyWith(fontSize: baseSize * factor),
          ),
        ),
      ),
      child: bar,
    );
  }

  Widget _buildNavigationBar(BuildContext context, {double? height}) {
    return _withFittedNavLabels(context, _navigationBar(context, height));
  }

  Widget _navigationBar(BuildContext context, double? height) {
    return NavigationBar(
      height: height,
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
    );
  }

  Future<void> _loadProfileNameState(String? userId) async {
    setState(() => _checkingProfileName = true);
    final offlineMode = context.read<AuthProvider>().isOfflineMode;
    var completed = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _profileNameCompletionKey(userId, offlineMode: offlineMode);
      completed = key != null && preferences.getBool(key) == true;
    } catch (error, stack) {
      // Okunamazsa kapı gösterilir (güvenli varsayılan); yükleyici kapanır.
      ErrorReporter.record(error, stack, reason: 'profile name state failed');
    }

    // Bu kapı yalnız oyuncunun adı başarıyla kaydettiğini belirten yerel
    // ve kullanıcıya özel bayrağa dayanır. Global bir bayrak hesap değişiminde
    // yeni oyuncunun kapısını atlatır ve aynı varsayılan adı 1v1 kimliğine
    // taşır. İsim, HomeScreen'in arka plan akışında zenginleşir; ağdaki
    // yeniden denemeler başlangıç rotasını veya tam ekranı bekletemez.
    if (!mounted || _repository.currentUserId != userId) return;
    setState(() {
      _profileNameComplete = completed;
      _checkingProfileName = false;
    });
  }

  Future<void> _completeProfileName() async {
    final offlineMode = context.read<AuthProvider>().isOfflineMode;
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _profileNameCompletionKey(
        _repository.currentUserId,
        offlineMode: offlineMode,
      );
      if (key != null) await preferences.setBool(key, true);
    } catch (error, stack) {
      // Yazılamasa da kullanıcıyı içeride kilitleme; bellekte ilerle.
      ErrorReporter.record(error, stack, reason: 'profile name flag failed');
    }
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
      final snapshot = await _repository.loadMyResumableRoom();
      if (!_continueRoomResumeOrDefer(userId, epoch)) return;

      if (snapshot != null && snapshot.room.status != RoomStatus.finished) {
        Widget destination;
        switch (snapshot.room.status) {
          case RoomStatus.lobby:
            destination = RoomScreen(
              repository: _repository,
              initialRoom: snapshot.room,
            );
          case RoomStatus.active:
            final questions = await _repository.loadRoomQuestions(
              snapshot.room,
            );
            if (questions.isEmpty) {
              throw StateError('Resumable online room has no questions.');
            }
            if (!_continueRoomResumeOrDefer(userId, epoch)) return;
            destination = QuizScreen(
              repository: _repository,
              room: snapshot.room,
              questions: questions,
              // Kalabalık oda 1v1 düello yolunu kullanmaz (oda türü
              // `snapshot.room`dan okunur).
              is1v1: !snapshot.room.isCrowd,
              resumeSnapshot: snapshot,
            );
          case RoomStatus.finished:
            return;
        }
        _scheduleRoomResumeRoute(userId, epoch, snapshot.room, destination);
        return;
      }

      errorReason = 'app_shell_pending_room_result';
      final pending = await _repository.loadMyPendingRoomResult();
      if (!_continueRoomResumeOrDefer(userId, epoch)) return;
      if (pending == null) {
        _roomResumeCheckedUsers.add(userId);
        return;
      }
      // Odadan KENDİ isteğiyle ayrılan oyuncunun bekleyen sonucu yoktur.
      // Sunucu kalabalık odada ayrılana da son durumu döndürüyordu; oda
      // sonradan bitince (kimi zaman bir dakika sonra, uygulama başka
      // sekmedeyken) "0 puan" sonuç ekranı kendiliğinden açılıyordu (iki
      // simülatör turu, 2026-10-21). Ayrılan oyuncuya sonuç sunulmaz.
      if (pendingResultOwnerLeft(pending, userId)) {
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
          repository: _repository,
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
        _normalizedUserId(_repository.currentUserId) == userId;
  }

  bool _isCurrentRoomResumeIdentity(String userId, int epoch) {
    return mounted &&
        _roomResumeEpoch == epoch &&
        _roomResumeAccountUserId == userId &&
        _normalizedUserId(_repository.currentUserId) == userId;
  }

  bool _isValidPendingRoomResult(RoomResultSnapshot snapshot, String userId) {
    final roomId = snapshot.room.id?.trim();
    return roomId != null &&
        roomId.isNotEmpty &&
        snapshot.ownPlayerId.trim() == userId &&
        snapshot.room.status == RoomStatus.finished &&
        snapshot.endedReason.trim().toLowerCase() == 'completed' &&
        snapshot.forfeitedBy == null &&
        roomResultHasValidPlayers(snapshot, userId);
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

/// Bekleyen oda sonucunda sonuç sahibi odadan ayrılmış mı?
@visibleForTesting
bool pendingResultOwnerLeft(RoomResultSnapshot snapshot, String userId) {
  for (final player in snapshot.room.players) {
    if (player.id == userId) return player.left;
  }
  return false;
}
