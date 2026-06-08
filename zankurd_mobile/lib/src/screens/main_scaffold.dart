import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/zankurd_repository.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'level_screen.dart';
import 'profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({required this.repository, super.key});
  final ZanKurdRepository repository;
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _tabIndex = 0;

  late final List<Widget> _tabs = [
    HomeScreen(repository: widget.repository),
    _CategoriesTab(repository: widget.repository),
    LeaderboardScreen(repository: widget.repository),
    ProfileScreen(repository: widget.repository),
  ];

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Ana Sayfa'),
    (Icons.apps_rounded, Icons.apps_outlined, 'Kategoriler'),
    (Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Skor'),
    (Icons.person_rounded, Icons.person_outlined, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: IndexedStack(index: _tabIndex, children: _tabs),
        bottomNavigationBar: _FloatingNavBar(
          selectedIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          items: _items,
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2EAF0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            height: 60,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A2332).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = i == selectedIndex;
                final (activeIcon, inactiveIcon, label) = items[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? activeIcon : inactiveIcon,
                            color: selected ? Colors.white : const Color(0xFF4A5568),
                            size: 22,
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab({required this.repository});
  final ZanKurdRepository repository;
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  List<String> _categories = [];
  bool _loading = true;

  static const List<_CatMeta> _meta = [
    _CatMeta('Ziman', Icons.translate_rounded, [Color(0xFF1AA366), Color(0xFF22C87A)], '📖', 'Kurmancî dil bilgisi'),
    _CatMeta('Çand', Icons.diversity_3_rounded, [Color(0xFF4059AD), Color(0xFF6B7FD4)], '🎭', 'Kürt kültürü'),
    _CatMeta('Dîrok', Icons.account_balance_rounded, [Color(0xFFE74C3C), Color(0xFFFF6B6B)], '🏛️', 'Tarih'),
    _CatMeta('Edebiyat', Icons.menu_book_rounded, [Color(0xFFF59E0B), Color(0xFFFBBF24)], '📚', 'Edebiyat'),
    _CatMeta('Cografya', Icons.public_rounded, [Color(0xFF8B5CF6), Color(0xFFA78BFA)], '🗺️', 'Coğrafya'),
    _CatMeta('Muzîk', Icons.music_note_rounded, [Color(0xFF0891B2), Color(0xFF22D3EE)], '🎵', 'Müzik'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cats = await widget.repository.loadCategories();
      if (mounted) setState(() { _categories = cats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _categories = widget.repository.categories; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kategoriler', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 2),
                        const Text(
                          'Hangi konuda kendini test etmek istersin?',
                          style: TextStyle(color: AppTheme.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _categories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.88,
                      ),
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final meta = i < _meta.length
                            ? _meta[i]
                            : _CatMeta(cat, Icons.category_rounded,
                                [AppTheme.primary, AppTheme.primaryLight], '❓', '');
                        return _CategoryCard(
                          category: cat,
                          meta: meta,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LevelScreen(
                              repository: widget.repository,
                              category: cat,
                            ),
                          )),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatMeta {
  const _CatMeta(this.name, this.icon, this.gradient, this.emoji, this.subtitle);
  final String name;
  final IconData icon;
  final List<Color> gradient;
  final String emoji;
  final String subtitle;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.meta,
    required this.onTap,
  });
  final String category;
  final _CatMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: meta.gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: meta.gradient.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -15,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.emoji, style: const TextStyle(fontSize: 36)),
                  const Spacer(),
                  Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.subtitle.isEmpty ? '5 seviye' : meta.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '5 Seviye →',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



