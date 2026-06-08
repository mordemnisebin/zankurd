import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/leaderboard_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _loading = true;
  String? _currentName;
  LeaderboardEntry? _stats;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final name = await widget.repository.getProfileName();
      final stats = await widget.repository.getPlayerStats();
      if (mounted) {
        setState(() {
          _currentName = name;
          _nameController.text = name;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == _currentName) return;

    setState(() => _saving = true);

    try {
      await widget.repository.updateProfileName(newName);
      if (mounted) {
        setState(() {
          _currentName = newName;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güncelleme hatası oluştu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Oyuncu Adı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Adını gir...',
                            filled: true,
                            fillColor: AppTheme.page,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Kaydet'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İstatistiklerim',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_stats == null)
                          const Text(
                            'Henüz çevrimiçi oyun geçmişin yok.\nBir odaya katıl veya oluştur.',
                            style: TextStyle(color: AppTheme.muted),
                          )
                        else
                          Column(
                            children: [
                              _StatRow(
                                title: 'Sıralama',
                                value: '#${_stats!.rank}',
                              ),
                              const Divider(),
                              _StatRow(
                                title: 'Toplam Puan',
                                value: '${_stats!.totalScore}',
                              ),
                              const Divider(),
                              _StatRow(
                                title: 'En İyi Seri',
                                value: '${_stats!.bestStreak}',
                              ),
                              const Divider(),
                              _StatRow(
                                title: 'Oynanan Oyun',
                                value: '${_stats!.roomsPlayed}',
                              ),
                            ],
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.green,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
