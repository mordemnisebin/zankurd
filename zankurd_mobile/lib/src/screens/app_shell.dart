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
import 'sign_in_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
    super.key,
  });

  final ZanKurdRepository repository;
  final ConnectivityMonitor? connectivityMonitor;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _onboardingSeenKey = 'zankurd.onboarding.seen';
  static const _profileNameCompletedKey = 'zankurd.profileName.completed';

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

  // Çevrimdışı durum izleme
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  late final ScrollController _homeScrollController;
  late final ScrollController _profileScrollController;

  @override
  void initState() {
    super.initState();
    _homeScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
    _initConnectivity();
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
    }
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() => _isOffline = results.contains(ConnectivityResult.none));
  }

  @override
  void dispose() {
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

    if (_checkingOnboarding) {
      return const Scaffold(body: BrandedLoaderCenter());
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    if (!authProvider.isAuthenticated) {
      _profileCheckStarted = false;
      return const SignInScreen();
    }

    if (!_profileCheckStarted) {
      _profileCheckStarted = true;
      _checkingProfileName = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfileNameState();
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

  Future<void> _loadProfileNameState() async {
    setState(() => _checkingProfileName = true);
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool(_profileNameCompletedKey) == true;

    // Bu kapı yalnız oyuncunun adı başarıyla kaydettiğini belirten yerel
    // bayrağa dayanır. İsim, HomeScreen'in arka plan akışında zenginleşir;
    // ağdaki yeniden denemeler başlangıç rotasını veya tam ekranı bekletemez.
    if (!mounted) return;
    setState(() {
      _profileNameComplete = completed;
      _checkingProfileName = false;
    });
  }

  Future<void> _completeProfileName() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_profileNameCompletedKey, true);
    if (!mounted) return;
    setState(() {
      _profileNameComplete = true;
      _profileCheckStarted = true;
    });
  }
}
