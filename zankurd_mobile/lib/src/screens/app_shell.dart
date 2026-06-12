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

  int _tab = 0;
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
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
      return const SignInScreen();
    }

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(repository: widget.repository),
          CategoriesTab(repository: widget.repository),
          LeaderboardScreen(repository: widget.repository),
          ProfileScreen(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
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
}
