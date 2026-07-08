import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';

class ProfileNameGateScreen extends StatefulWidget {
  const ProfileNameGateScreen({
    required this.repository,
    required this.onCompleted,
    this.initialName,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? initialName;
  final VoidCallback onCompleted;

  @override
  State<ProfileNameGateScreen> createState() => _ProfileNameGateScreenState();
}

class _ProfileNameGateScreenState extends State<ProfileNameGateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = _isDefaultName(widget.initialName)
        ? ''
        : widget.initialName;
    _controller = TextEditingController(text: initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final name = _controller.text.trim();
    setState(() => _saving = true);
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      widget.onCompleted();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile name gate failed');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Navê lîstikê nehat tomar kirin. Dîsa biceribîne.',
              'Oyuncu adı kaydedilemedi. Tekrar dene.',
            ),
          ),
        ),
      );
    }
  }

  static bool _isDefaultName(String? name) {
    final value = name?.trim();
    return value == null ||
        value.isEmpty ||
        value == 'ZanKurd Oyuncusu' ||
        value == 'ZanKurd Lîstikvan';
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final isDark = !AppTheme.isLight(context);

    return Scaffold(
      body: Column(
        children: [
          // ── Hero Alanı (üst ~45%) ──────────────────────────────────
          Expanded(
            flex: 45,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF0A1F17), Color(0xFF163E30)]
                      : const [Color(0xFF0F2C21), Color(0xFF1A4E3B)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo kartı
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/zankurd.webp',
                          width: 80,
                          height: 34,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const Spacer(),
                      // Hoşgeldin başlığı
                      Text(
                        ku ? 'Xweş hatî ZanKurd!' : 'ZanKurd\'a Hoş Geldin!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ku
                            ? 'Hîn bibe, pêş bike û bi hevalan re bêhna xwe bide.'
                            : 'Öğren, gelişin ve arkadaşlarınla eğlen.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 3 değer maddesi
                      _HeroValueRow(
                        icon: Icons.emoji_events_rounded,
                        color: AppTheme.gold,
                        text: ku
                            ? 'Lîstikê û serlêderên bibike'
                            : 'Oyunları tamamla, ödül kazan',
                      ),
                      const SizedBox(height: 8),
                      _HeroValueRow(
                        icon: Icons.people_rounded,
                        color: const Color(0xFF81C784),
                        text: ku
                            ? 'Bi hevalan re pêşbikeve'
                            : 'Arkadaşlarınla yarış',
                      ),
                      const SizedBox(height: 8),
                      _HeroValueRow(
                        icon: Icons.local_fire_department_rounded,
                        color: AppTheme.primaryGradientStart,
                        text: ku
                            ? 'Zincîra xwe biparêze'
                            : 'Serini koru, zincirini devam ettir',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Form Alanı (alt ~55%) ──────────────────────────────────
          Expanded(
            flex: 55,
            child: Container(
              color: AppTheme.isLight(context) ? AppTheme.lightBg : AppTheme.bg,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            ku
                                ? 'Navê te di lîstikê de çi be?'
                                : 'Oyundaki adın ne olsun?',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ku
                                ? 'Ev nav di tabloya pêşderçûnê û odeyên serhêl de xuya dibe.'
                                : 'Bu ad liderlik tablosunda ve çevrimiçi odalarda görünecek.',
                            style: TextStyle(
                              color: AppTheme.textMutedColor(context),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            key: const ValueKey('player-name-field'),
                            controller: _controller,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: ku ? 'Mînak: Zelal' : 'Örn: Zelal',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                            validator: (value) {
                              final name = value?.trim() ?? '';
                              if (name.length < 2) {
                                return ku
                                    ? 'Nav divê herî kêm 2 tîp be'
                                    : 'Ad en az 2 karakter olmalı';
                              }
                              if (name.length > 24) {
                                return ku
                                    ? 'Nav divê herî zêde 24 tîp be'
                                    : 'Ad en fazla 24 karakter olmalı';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                ku ? 'Dest Pê Bike' : 'Oyuna Başla',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero alanındaki değer maddeleri satırı.
class _HeroValueRow extends StatelessWidget {
  const _HeroValueRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
