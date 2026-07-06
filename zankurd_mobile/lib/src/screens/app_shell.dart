import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/coach_mark.dart';
import 'categories_tab.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'learning_screen.dart';
import 'onboarding_screen.dart';
import 'profile_name_gate_screen.dart';
import 'profile_screen.dart';
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
  final GlobalKey _categoriesNavKey = GlobalKey();
  final GlobalKey _learningNavKey = GlobalKey();
  final GlobalKey _leaderboardNavKey = GlobalKey();
  final GlobalKey _profileNavKey = GlobalKey();
  final ValueNotifier<int> _homeRefresh = ValueNotifier<int>(0);
  final ValueNotifier<int> _profileRefresh = ValueNotifier<int>(0);
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;
  bool _checkingProfileName = false;
  bool _profileNameComplete = false;
  String? _profileName;
  bool _profileCheckStarted = false;

  late final ScrollController _homeScrollController;
  late final ScrollController _categoriesScrollController;
  late final ScrollController _leaderboardScrollController;
  late final ScrollController _learningScrollController;
  late final ScrollController _profileScrollController;

  @override
  void initState() {
    super.initState();
    _homeScrollController = ScrollController();
    _categoriesScrollController = ScrollController();
    _leaderboardScrollController = ScrollController();
    _learningScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _categoriesScrollController.dispose();
    _leaderboardScrollController.dispose();
    _learningScrollController.dispose();
    _profileScrollController.dispose();
    _homeRefresh.dispose();
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (!_profileNameComplete) {
      return ProfileNameGateScreen(
        repository: widget.repository,
        initialName: _profileName,
        onCompleted: _completeProfileName,
      );
    }

    return Stack(
      children: [
        _buildScaffold(context, ku),
        if (_showNavTour)
          CoachMarkOverlay(
            isKu: ku,
            onFinished: _finishNavTour,
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
                targetKey: _categoriesNavKey,
                icon: Icons.grid_view_rounded,
                titleKu: 'Kategorî',
                titleTr: 'Kategoriler',
                descriptionKu:
                    'Hemû mijar (Ziman, Çand, Dîrok...) li vir bi asteyên cuda hatine rêzkirin.',
                descriptionTr:
                    'Tüm konular (Ziman, Çand, Dîrok...) burada seviyelere ayrılmış halde.',
              ),
              CoachMarkStep(
                targetKey: _learningNavKey,
                icon: Icons.school_rounded,
                titleKu: 'Xwendin',
                titleTr: 'Öğren',
                descriptionKu:
                    'Kurmancî gav bi gav, dersên kurt û mînakên rastîn bi vir hîn bibe.',
                descriptionTr:
                    'Kurmancîyi adım adım, kısa derslerle ve gerçek örneklerle burada öğren.',
              ),
              CoachMarkStep(
                targetKey: _leaderboardNavKey,
                icon: Icons.leaderboard_rounded,
                titleKu: 'Pêşbaz',
                titleTr: 'Liderlik',
                descriptionKu:
                    'Rêza xwe ya di nav lîstikvanên din de li vir bibîne.',
                descriptionTr:
                    'Diğer oyuncular arasındaki sıralamanı burada görürsün.',
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
          ),
          CategoriesTab(
            repository: widget.repository,
            scrollController: _categoriesScrollController,
          ),
          LearningScreen(repository: widget.repository),
          LeaderboardScreen(
            repository: widget.repository,
            scrollController: _leaderboardScrollController,
          ),
          ProfileScreen(
            repository: widget.repository,
            refreshSignal: _profileRefresh,
            scrollController: _profileScrollController,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            if (_tab == i) {
              final controller = switch (i) {
                0 => _homeScrollController,
                1 => _categoriesScrollController,
                2 => _learningScrollController,
                3 => _leaderboardScrollController,
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
              icon: KeyedSubtree(
                key: _categoriesNavKey,
                child: const Icon(Icons.grid_view_outlined),
              ),
              selectedIcon: const Icon(Icons.grid_view),
              label: ku ? 'Kategorî' : 'Kategoriler',
            ),
            NavigationDestination(
              icon: KeyedSubtree(
                key: _learningNavKey,
                child: const Icon(Icons.school_outlined),
              ),
              selectedIcon: const Icon(Icons.school),
              label: ku ? 'Xwendin' : 'Öğren',
            ),
            NavigationDestination(
              icon: KeyedSubtree(
                key: _leaderboardNavKey,
                child: const Icon(Icons.leaderboard_outlined),
              ),
              selectedIcon: const Icon(Icons.leaderboard),
              label: ku ? 'Pêşbaz' : 'Liderlik',
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
    );
  }

  Future<void> _loadProfileNameState() async {
    setState(() => _checkingProfileName = true);
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool(_profileNameCompletedKey) == true;
    String? name;
    try {
      name = await widget.repository.getProfileName();
    } catch (_) {
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
    } catch (_) {}
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
    if (preferences.getBool(_navTourSeenKey) == true) return;
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
  }
}
