import 'package:flutter/material.dart';

import '../data/local_data_service.dart';
import '../data/zankurd_repository.dart';
import '../theme/app_theme.dart';
import 'main_scaffold.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueAnonymously() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Lütfen bir oyuncu adı gir.');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Ad en az 2 karakter olmalı.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final local = await LocalDataService.getInstance();
      await local.savePlayerName(name);
      await local.markLaunchDone();
      await widget.repository.ensureProfile().catchError((_) {});
      await widget.repository.updateProfileName(name).catchError((_) {});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScaffold(repository: widget.repository),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScaffold(repository: widget.repository),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.green,
      body: SafeArea(
        child: Column(
          children: [
            // Top brand section
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'ZK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'ZanKurd',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pêşbirka Kurmancî',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Feature pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: ['Seviye Sistemi', 'Canlı Odalar', 'Skor Tablosu', 'Günlük Quiz']
                          .map((f) => _FeaturePill(label: f))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom auth form
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Başlamak için adını gir',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bu ad skor tablosunda görünecek.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 24,
                    decoration: InputDecoration(
                      hintText: 'Oyuncu adın...',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      errorText: _error,
                      counterText: '',
                    ),
                    onSubmitted: (_) => _continueAnonymously(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _continueAnonymously,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _loading ? 'Hazırlanıyor...' : 'Oyuna Başla',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Üye olmadan devam ediyorsun. İlerleme bu cihazda saklanır.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
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

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
