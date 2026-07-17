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

    return Stack(
      key: _shellStackKey,
      children: [
        _buildScaffold(context, ku),
        if (_showNavTour)
          CoachMarkOverlay(
            isKu: ku,
            onFinished: _finishNavTour,
            ancestorKey: _shellStackKey,
            steps: [
              CoachMarkStep(
                targetKey: _homeNavKey,
                icon: Icons.home_rounded,
                titleKu: 'Sereke',
                titleTr: 'Ana Sayfa',
                descriptionKu:
                    'Vir e ku tu dest pê dikî: yariyên zû, xelatên rojane û misyonên te li vir in.',
                descriptionTr:
                    'Buradan başlarsın: hızlı oyunlar, günlük ödüller ve görevlerin burada.',
              ),
              CoachMarkStep(
                targetKey: _playNavKey,
                icon: Icons.sports_esports_rounded,
                titleKu: 'Bilîze',
                titleTr: 'Yarış',
                descriptionKu: 'Hemû pêşbirktî û lîstikên te li vir in.',
                descriptionTr:
                    'Günlük yarışma, 1v1, oda ve turnuvaların merkezi.',
              ),
              CoachMarkStep(
                targetKey: _profileNavKey,
                icon: Icons.person_rounded,
                titleKu: 'Profîl',
                titleTr: 'Profil',
                descriptionKu:
                    'Rozet, hevalên te, Turnuva û mîhengên te hemû li vir in.',
                descriptionTr:
                    'Rozetlerin, arkadaşların, Turnuva ve ayarların hepsi burada.',
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context, bool ku) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            repository: widget.repository,
            displayName: _profileName,
            scrollController: _homeScrollController,
            refreshSignal: _homeRefresh,
            onOpenLearning: () => Navigator.of(
              context,
            ).push(AppRoute.to(LearningScreen(repository: widget.repository))),
            onOpenPlay: () => setState(() => _tab = 2),
          ),
          CategoriesTab(repository: widget.repository),
          PlayHubScreen(repository: widget.repository),
          LeaderboardScreen(
            repository: widget.repository,
            refreshSignal: _leaderboardRefresh,
          ),
          ProfileScreen(
            repository: widget.repository,
            refreshSignal: _profileRefresh,
            scrollController: _profileScrollController,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          backgroundColor: AppTheme.surfaceColor(context),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          elevation: 4,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.1,
              color: selected ? AppTheme.brandOrange : null,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: selected ? 26 : 24,
              color: selected
                  ? AppTheme.brandOrange
                  : AppTheme.textMutedColor(context),
            );
          }),
          // Sekme kimlik renkleri içerik header'larında yaşar; bottom nav
          // her sekmede sabit brandOrange kullanır.
          indicatorColor: AppTheme.brandOrange.withValues(alpha: 0.14),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          overlayColor: WidgetStateProperty.all(
            AppTheme.brandOrange.withValues(alpha: 0.06),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppTheme.borderColor(context).withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) {
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
              } else {
                if (i == 0) _homeRefresh.value++;
                if (i == 3) _leaderboardRefresh.value++;
                if (i == 4) _profileRefresh.value++;
                setState(() => _tab = i);
              }
            },
            destinations: [
              NavigationDestination(
                icon: KeyedSubtree(
                  key: _homeNavKey,
                  child: const Icon(Icons.home_outlined),
                ),
                selectedIcon: const Icon(Icons.home),
                label: ku ? 'Sereke' : 'Ana Sayfa',
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(Icons.grid_view_rounded),
                label: ku ? 'Kategorî' : 'Kategori',
              ),
              NavigationDestination(
                icon: KeyedSubtree(
                  key: _playNavKey,
                  child: const Icon(Icons.sports_esports_outlined),
                ),
                selectedIcon: const Icon(Icons.sports_esports),
                label: ku ? 'Pêşbazî' : 'Yarış',
              ),
              NavigationDestination(
                icon: const Icon(Icons.emoji_events_outlined),
                selectedIcon: const Icon(Icons.emoji_events),
                // "Lîstik" Kurmancî'de "oyun" demek; sıralama sekmesi "Rêz".
                label: ku ? 'Rêz' : 'Liderlik',
              ),
              NavigationDestination(
                icon: KeyedSubtree(
                  key: _profileNavKey,
                  child: const Icon(Icons.person_outline),
                ),
                selectedIcon: const Icon(Icons.person),
                label: ku ? 'Profîl' : 'Profil',
              ),
            ],
          ),
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
