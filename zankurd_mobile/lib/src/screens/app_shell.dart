import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/branded_loader.dart';
import '../widgets/coach_mark.dart';
import 'categories_tab.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'learning_screen.dart';
import 'onboarding_screen.dart';
import 'profile_name_gate_screen.dart';
import 'profile_screen.dart';
import 'play_hub_screen.dart';
import 'sign_in_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _onboardingSeenKey = 'zankurd.onboarding.seen';
  static const _profileNameCompletedKey = 'zankurd.profileName.completed';
  static const _navTourSeenKey = 'zankurd.navTour.seen';

  int _tab = 0;
  final Set<int> _visitedTabs = {0};
  bool _showNavTour = false;

  final GlobalKey _homeNavKey = GlobalKey();
  final GlobalKey _playNavKey = GlobalKey();
  final GlobalKey _profileNavKey = GlobalKey();
  final GlobalKey _shellStackKey = GlobalKey();
  final ValueNotifier<int> _homeRefresh = ValueNotifier<int>(0);
  final ValueNotifier<int> _leaderboardRefresh = ValueNotifier<int>(0);
  final ValueNotifier<int> _profileRefresh = ValueNotifier<int>(0);
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;
  bool _checkingProfileName = false;
  bool _profileNameComplete = false;
  String? _profileName;
  bool _profileCheckStarted = false;

  late final ScrollController _homeScrollController;
  late final ScrollController _profileScrollController;

  @override
  void initState() {
    super.initState();
    _homeScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
  }

  @override
  void dispose() {
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
        initialName: _profileName,
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
        builder: (context, constraints) => Stack(
          key: _shellStackKey,
          children: [
            _buildScaffold(context, ku, constraints.maxWidth),
            if (_showNavTour)
              CoachMarkOverlay(
                isKu: ku,
                onFinished: _finishNavTour,
                ancestorKey: _shellStackKey,
                steps: [
                  CoachMarkStep(
                    targetKey: _homeNavKey,
                    icon: AppIcons.house,
                    titleKu: 'Sereke',
                    titleTr: 'Ana Sayfa',
                    descriptionKu:
                        'Vir e ku tu dest pê dikî: yariyên zû, xelatên rojane û misyonên te li vir in.',
                    descriptionTr:
                        'Buradan başlarsın: hızlı oyunlar, günlük ödüller ve görevlerin burada.',
                  ),
                  CoachMarkStep(
                    targetKey: _playNavKey,
                    icon: AppIcons.gamepad,
                    titleKu: 'Bilîze',
                    titleTr: 'Yarış',
                    descriptionKu: 'Hemû pêşbirktî û lîstikên te li vir in.',
                    descriptionTr:
                        'Günlük yarışma, 1v1, oda ve turnuvaların merkezi.',
                  ),
                  CoachMarkStep(
                    targetKey: _profileNavKey,
                    icon: AppIcons.user,
                    titleKu: 'Profîl',
                    titleTr: 'Profil',
                    descriptionKu:
                        'Rozet, hevalên te, kûpa û mîhengên te hemû li vir in.',
                    descriptionTr:
                        'Rozetlerin, arkadaşların, Turnuva ve ayarların hepsi burada.',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, bool ku, double width) {
    final isDesktop = width >= 768;

    final body = IndexedStack(
      index: _tab,
      children: List.generate(5, (index) => _buildTab(context, index)),
    );

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: body,
      ),
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildNavRail(context, ku),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: _buildBottomNav(context, ku),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => HomeScreen(
        repository: widget.repository,
        displayName: _profileName,
        scrollController: _homeScrollController,
        refreshSignal: _homeRefresh,
        onOpenLearning: () => Navigator.of(
          context,
        ).push(AppRoute.to(LearningScreen(repository: widget.repository))),
        onOpenPlay: () => _selectTab(2),
      ),
      1 => CategoriesTab(repository: widget.repository),
      2 => PlayHubScreen(repository: widget.repository),
      3 => LeaderboardScreen(
        repository: widget.repository,
        refreshSignal: _leaderboardRefresh,
      ),
      4 => ProfileScreen(
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
        4 => _profileScrollController,
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
    if (i == 3) _leaderboardRefresh.value++;
    if (i == 4) _profileRefresh.value++;
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
        fontWeight: FontWeight.w800,
        color: AppTheme.brandGreen,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.textMutedColor(context),
      ),
      selectedIconTheme: const IconThemeData(
        color: AppTheme.brandGreen,
        size: 28,
      ),
      unselectedIconTheme: IconThemeData(
        color: AppTheme.textMutedColor(context),
        size: 24,
      ),
      indicatorColor: AppTheme.brandGreen.withValues(alpha: 0.15),
      destinations: [
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _homeNavKey,
            child: const Icon(AppIcons.house),
          ),
          selectedIcon: const Icon(AppIcons.house),
          label: Text(ku ? 'Sereke' : 'Ana Sayfa'),
        ),
        NavigationRailDestination(
          icon: const Icon(AppIcons.tableCells),
          selectedIcon: const Icon(AppIcons.tableCells),
          label: Text(ku ? 'Kategorî' : 'Kategori'),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _playNavKey,
            child: const Icon(AppIcons.gamepad),
          ),
          selectedIcon: const Icon(AppIcons.gamepad),
          label: Text(ku ? 'Pêşbazî' : 'Yarış'),
        ),
        NavigationRailDestination(
          icon: const Icon(AppIcons.trophy),
          selectedIcon: const Icon(AppIcons.trophy),
          label: Text(ku ? 'Rêz' : 'Liderlik'),
        ),
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _profileNavKey,
            child: const Icon(AppIcons.user),
          ),
          selectedIcon: const Icon(AppIcons.user),
          label: Text(ku ? 'Profîl' : 'Profil'),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, bool ku) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppTheme.surfaceColor(context),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        elevation: 12,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final color = selected
              ? AppTheme.brandGreen
              : AppTheme.textMutedColor(context);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0.2,
            color: color,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final color = selected
              ? AppTheme.brandGreen
              : AppTheme.textMutedColor(context);
          return IconThemeData(size: selected ? 26 : 24, color: color);
        }),
        indicatorColor: AppTheme.brandGreen.withValues(alpha: 0.22),
        indicatorShape: const StadiumBorder(),
        overlayColor: WidgetStateProperty.all(
          AppTheme.brandGreen.withValues(alpha: 0.10),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          destinations: [
            NavigationDestination(
              icon: KeyedSubtree(
                key: _homeNavKey,
                child: const Icon(AppIcons.house),
              ),
              selectedIcon: const Icon(AppIcons.house),
              label: ku ? 'Sereke' : 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.tableCells),
              selectedIcon: const Icon(AppIcons.tableCells),
              label: ku ? 'Kategorî' : 'Kategori',
            ),
            NavigationDestination(
              icon: KeyedSubtree(
                key: _playNavKey,
                child: const Icon(AppIcons.gamepad),
              ),
              selectedIcon: const Icon(AppIcons.gamepad),
              label: ku ? 'Pêşbazî' : 'Yarış',
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.trophy),
              selectedIcon: const Icon(AppIcons.trophy),
              label: ku ? 'Rêz' : 'Liderlik',
            ),
            NavigationDestination(
              icon: KeyedSubtree(
                key: _profileNavKey,
                child: const Icon(AppIcons.user),
              ),
              selectedIcon: const Icon(AppIcons.user),
              label: ku ? 'Profîl' : 'Profil',
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
    String? name;
    try {
      name = await widget.repository.getProfileName();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'app_shell_preferences');
      name = null;
    }
    if (!mounted) return;
    setState(() {
      _profileName = name;
      _profileNameComplete = completed;
      _checkingProfileName = false;
    });
    if (completed) _maybeStartNavTour();
  }

  Future<void> _completeProfileName() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_profileNameCompletedKey, true);
    String? name;
    try {
      name = await widget.repository.getProfileName();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'app_shell_tour');
    }
    if (!mounted) return;
    setState(() {
      _profileName = name;
      _profileNameComplete = true;
      _profileCheckStarted = true;
    });
    _maybeStartNavTour();
  }

  Future<void> _maybeStartNavTour() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_navTourSeenKey) == true) {
      // Tur zaten görülmüş: seviye sınavını (gerekiyorsa) doğrudan sun.
      _maybePromptPlacement();
      return;
    }
    // Alt menü nav bar'ının ilk frame'de layout'ta olması için bir çerçeve
    // bekle; aksi halde GlobalKey.currentContext henüz null olur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showNavTour = true);
    });
  }

  Future<void> _finishNavTour() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_navTourSeenKey, true);
    if (!mounted) return;
    setState(() => _showNavTour = false);
    _maybePromptPlacement();
  }

  /// Seviye belirleme sınavı artık otomatik açılmaz.
  /// Manuel başlatma (ayarlar/menü) akışı başka yerde yönetilmelidir.
  Future<void> _maybePromptPlacement() async {
    // Bilerek boş bırakıldı.
    return;
  }
}
