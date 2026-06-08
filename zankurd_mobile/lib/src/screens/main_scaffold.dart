import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.green.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.green),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: AppTheme.green),
            label: 'Kategoriler',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events, color: AppTheme.green),
            label: 'Skor',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.green),
            label: 'Profil',
          ),
        ],
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
    _CatMeta('Ziman', Icons.translate_outlined, AppTheme.green, 'Kurmancî dilbilgisi ve kelime bilgisi'),
    _CatMeta('Çand', Icons.diversity_3_outlined, Color(0xFF4059AD), 'Kürt kültürü ve gelenekleri'),
    _CatMeta('Dîrok', Icons.account_balance_outlined, AppTheme.red, 'Tarih ve olaylar'),
    _CatMeta('Edebiyat', Icons.menu_book_outlined, Color(0xFFBD7B2B), 'Şiir, roman ve yazarlar'),
    _CatMeta('Cografya', Icons.public_outlined, AppTheme.brown, 'Coğrafya ve ülkeler'),
    _CatMeta('Muzîk', Icons.music_note_outlined, Color(0xFF008891), 'Müzik ve sanat'),
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
      backgroundColor: AppTheme.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategoriler',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Her kategori 5 seviyeye ayrıldı',
                    style: TextStyle(color: AppTheme.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _categories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final meta = i < _meta.length ? _meta[i] : _CatMeta(cat, Icons.category_outlined, AppTheme.green, '');
                        return _CategoryCard(
                          category: cat,
                          icon: meta.icon,
                          color: meta.color,
                          subtitle: meta.subtitle,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LevelScreen(
                                repository: widget.repository,
                                category: cat,
                              ),
                            ),
                          ),
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
  const _CatMeta(this.name, this.icon, this.color, this.subtitle);
  final String name;
  final IconData icon;
  final Color color;
  final String subtitle;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  final String category;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const Spacer(),
              Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle.isEmpty ? '5 seviye' : subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '5 Seviye',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
