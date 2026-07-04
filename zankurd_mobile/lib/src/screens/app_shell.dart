import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'categories_tab.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
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

  int _tab = 0;
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
  late final ScrollController _profileScrollController;

  @override
  void initState() {
    super.initState();
    _homeScrollController = ScrollController();
    _categoriesScrollController = ScrollController();
    _leaderboardScrollController = ScrollController();
    _profileScrollController = ScrollController();
    _loadOnboardingState();
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _categoriesScrollController.dispose();
    _leaderboardScrollController.dispose();
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
                2 => _leaderboardScrollController,
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
            } else {
              // Ana Sayfa ve Profil tabları IndexedStack içinde canlı kaldığı
              // için sekmeye her dönüşte ilgili verileri tazelemesi gerekir.
              if (i == 0) _homeRefresh.value++;
              if (i == 3) _profileRefresh.value++;
              setState(() => _tab = i);
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: ku ? 'Sereke' : 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: ku ? 'Kategorî' : 'Kategoriler',
            ),
            NavigationDestination(
              icon: const Icon(Icons.leaderboard_outlined),
              selectedIcon: const Icon(Icons.leaderboard),
              label: ku ? 'Pêşderçûn' : 'Liderlik',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
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
  }
}
