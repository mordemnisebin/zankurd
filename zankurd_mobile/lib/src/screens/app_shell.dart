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
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/branded_loader.dart';
import '../widgets/offline_banner.dart';
import 'learn_home_screen.dart';
import 'leaderboard_screen.dart';
import 'learning_screen.dart';
import 'onboarding_screen.dart';
import '../services/analytics_service.dart';
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
    super.key,
  });

  final ZanKurdRepository repository;
  final ConnectivityMonitor? connectivityMonitor;

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
  final ValueNotifier<int> _leaderboardRefresh = ValueNotifier<int>(0);
  final ValueNotifier<int> _profileRefresh = ValueNotifier<int>(0);
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
    _homeScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
    _initConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<dynamic>(context);
    if (identical(route, _shellRoute)) return;
    final previous = _shellRoute;
    if (previous != null) appRouteObserver.unsubscribe(this);
    _shellRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
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
    if (kIsWeb) return const AlwaysOnlineConnectivityMonitor();
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
    final reconnected = _connectivityKnown && _isOffline && !nextOffline;
    setState(() {
      _isOffline = nextOffline;
      _connectivityKnown = true;
    });
    if (reconnected) _wakeRoomResumeForCurrentUser();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wakeRoomResumeForCurrentUser();
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
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _homeScrollController.dispose();
    _profileScrollController.dispose();
    _homeRefresh.dispose();
    _leaderboardRefresh.dispose();
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
      return const SignInScreen();
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

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width >= 1200
              ? 1140
              : (width >= AppShell.desktopNavBreakpoint ? 920 : 800),
        ),
        child: body,
      ),
    );

    if (isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            OfflineBanner(isOffline: _isOffline, onRetry: _refreshConnectivity),
            Expanded(
              child: Row(
                children: [
                  _buildNavRail(context, ku),
                  const VerticalDivider(thickness: 1, width: 1),
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
          OfflineBanner(isOffline: _isOffline, onRetry: _refreshConnectivity),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, ku),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => LearnHomeScreen(
        repository: widget.repository,
        scrollController: _homeScrollController,
        refreshSignal: _homeRefresh,
        onOpenLearning: () => Navigator.of(
          context,
        ).push(AppRoute.to(LearningScreen(repository: widget.repository))),
        onOpenPlay: () => _selectTab(1),
      ),
      1 => PlayHubScreen(repository: widget.repository),
      2 => LeaderboardScreen(
        repository: widget.repository,
        refreshSignal: _leaderboardRefresh,
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

    if (i == 0) _homeRefresh.value++;
    if (i == 2) _leaderboardRefresh.value++;
    if (i == 3) _profileRefresh.value++;
    setState(() {
      _visitedTabs.add(i);
      _tab = i;
    });
  }

  Widget _buildNavRail(BuildContext context, bool ku) {
    return NavigationRail(
      selectedIndex: _tab,
      onDestinationSelected: _selectTab,
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.brand,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.textMutedColor(context),
      ),
      selectedIconTheme: const IconThemeData(color: AppTheme.brand, size: 28),
      unselectedIconTheme: IconThemeData(
        color: AppTheme.textMutedColor(context),
        size: 24,
      ),
      indicatorColor: AppTheme.brand.withValues(alpha: 0.15),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(AppIcons.house),
          selectedIcon: KeyedSubtree(
            key: _homeNavKey,
            child: const Icon(AppIcons.house),
          ),
          label: Text(context.t(K.navLearn)),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _playNavKey,
            child: const Icon(AppIcons.gamepad),
          ),
          selectedIcon: const Icon(AppIcons.gamepad),
          label: Text(context.t(K.navPlay)),
        ),
        NavigationRailDestination(
          icon: const Icon(AppIcons.trophy),
          selectedIcon: const Icon(AppIcons.trophy),
          label: Text(context.t(K.navLeaderboard)),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _profileNavKey,
            child: const Icon(AppIcons.user),
          ),
          selectedIcon: const Icon(AppIcons.user),
          label: Text(context.t(K.navProfile)),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, bool ku) {
    final surface = AppTheme.surfaceColor(context);
    final cta = AppTheme.primaryCtaColor(context);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 70,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final color = selected ? cta : AppTheme.textMutedColor(context);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0.15,
            color: color,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final color = selected ? cta : AppTheme.textMutedColor(context);
          return IconThemeData(size: selected ? 26 : 23, color: color);
        }),
        indicatorColor: cta.withValues(alpha: 0.18),
        indicatorShape: const StadiumBorder(),
        overlayColor: WidgetStateProperty.all(cta.withValues(alpha: 0.08)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          border: Border(
            top: BorderSide(
              color: AppTheme.borderColor(context).withValues(alpha: 0.55),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, -6),
              blurRadius: 18,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          // Sekme hedefleri dile bağımlı metinle değil, sabit anahtarla
          // bulunur — etiketler ("Yarış") ekran içeriğinde de geçebiliyor.
          destinations: [
            NavigationDestination(
              key: const ValueKey('nav-learn'),
              icon: const Icon(AppIcons.house),
              selectedIcon: KeyedSubtree(
                key: _homeNavKey,
                child: const Icon(AppIcons.house),
              ),
              label: context.t(K.navLearn),
            ),
            NavigationDestination(
              key: const ValueKey('nav-play'),
              icon: KeyedSubtree(
                key: _playNavKey,
                child: const Icon(AppIcons.gamepad),
              ),
              selectedIcon: const Icon(AppIcons.gamepad),
              label: context.t(K.navPlay),
            ),
            NavigationDestination(
              key: const ValueKey('nav-leaderboard'),
              icon: const Icon(AppIcons.trophy),
              selectedIcon: const Icon(AppIcons.trophy),
              label: context.t(K.navLeaderboard),
            ),
            NavigationDestination(
              key: const ValueKey('nav-profile'),
              icon: KeyedSubtree(
                key: _profileNavKey,
                child: const Icon(AppIcons.user),
              ),
              selectedIcon: const Icon(AppIcons.user),
              label: context.t(K.navProfile),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfileNameState(String? userId) async {
    setState(() => _checkingProfileName = true);
    final preferences = await SharedPreferences.getInstance();
    final key = _profileNameCompletionKey(userId);
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
    final preferences = await SharedPreferences.getInstance();
    final key = _profileNameCompletionKey(widget.repository.currentUserId);
    if (key != null) await preferences.setBool(key, true);
    if (!mounted) return;
    setState(() {
      _profileNameComplete = true;
      _profileCheckStarted = true;
    });
  }

  String? _profileNameCompletionKey(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return '$_profileNameCompletedKeyPrefix$normalized';
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
