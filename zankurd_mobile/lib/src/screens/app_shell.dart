import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'categories_tab.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'sign_in_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ku = context.isKu;

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
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: ku ? 'Sereke' : 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_outlined),
              activeIcon: const Icon(Icons.grid_view),
              label: ku ? 'Kategorî' : 'Kategoriler',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.leaderboard_outlined),
              activeIcon: const Icon(Icons.leaderboard),
              label: ku ? 'Pêşderçûn' : 'Liderlik',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: ku ? 'Profîl' : 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
