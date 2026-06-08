import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.page,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: AppTheme.page,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Uygulama'),
          _SettingTile(
            icon: Icons.notifications_outlined,
            iconColor: AppTheme.green,
            title: 'Bildirimler',
            subtitle: 'Turnuva ve oyun bildirimleri',
            trailing: Switch.adaptive(
              value: _notificationsEnabled,
              activeColor: AppTheme.green,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
          ),
          _SettingTile(
            icon: Icons.volume_up_outlined,
            iconColor: const Color(0xFF4059AD),
            title: 'Ses Efektleri',
            subtitle: 'Doğru/yanlış ses efektleri',
            trailing: Switch.adaptive(
              value: _soundEnabled,
              activeColor: AppTheme.green,
              onChanged: (v) => setState(() => _soundEnabled = v),
            ),
          ),
          _SettingTile(
            icon: Icons.vibration_outlined,
            iconColor: const Color(0xFFBD7B2B),
            title: 'Titreşim',
            subtitle: 'Dokunsal geri bildirim',
            trailing: Switch.adaptive(
              value: _vibrationEnabled,
              activeColor: AppTheme.green,
              onChanged: (v) {
                setState(() => _vibrationEnabled = v);
                if (v) HapticFeedback.lightImpact();
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Hakkında'),
          _SettingTile(
            icon: Icons.info_outline,
            iconColor: AppTheme.muted,
            title: 'Uygulama Sürümü',
            subtitle: '1.0.0',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppTheme.muted,
            title: 'Gizlilik Politikası',
            subtitle: 'Verilerinizin nasıl kullanıldığı',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
            onTap: () => _showPrivacyDialog(context),
          ),
          _SettingTile(
            icon: Icons.description_outlined,
            iconColor: AppTheme.muted,
            title: 'Kullanım Koşulları',
            subtitle: 'Hizmet şartları',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: 'Hesap'),
          _SettingTile(
            icon: Icons.delete_outline,
            iconColor: AppTheme.red,
            title: 'Hesabı Sil',
            subtitle: 'Tüm verilerini kalıcı olarak sil',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
            onTap: () => _showDeleteDialog(context),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'ZanKurd · Pêşbirka Kurmancî\nv1.0.0',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gizlilik Politikası'),
        content: const SingleChildScrollView(
          child: Text(
            'ZanKurd uygulaması, quiz deneyiminizi kişiselleştirmek için oyuncu adı, puan ve maç geçmişinizi güvenli sunucularda saklar. Üçüncü taraflarla paylaşılmaz. Hesabınızı istediğiniz zaman silebilirsiniz.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Tüm puan ve geçmiş verileriniz silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Spin Wheel — günlük çark
// ─────────────────────────────────────────────

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _spinning = false;
  bool _done = false;
  int? _prize;

  static const List<int> _prizes = [50, 100, 25, 200, 75, 10, 150, 500];
  static const List<Color> _colors = [
    AppTheme.green, Color(0xFF4059AD), AppTheme.red, Color(0xFFBD7B2B),
    Color(0xFF008891), AppTheme.brown, Color(0xFF9C27B0), Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.decelerate);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning || _done) return;
    final segment = Random().nextInt(_prizes.length);
    _prize = _prizes[segment];

    setState(() => _spinning = true);
    // Rotate to the winning segment
    final targetAngle = (2 * pi * 3) + (segment / _prizes.length) * 2 * pi;
    _anim = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.decelerate),
    );
    _ctrl.forward(from: 0).then((_) {
      if (mounted) setState(() { _spinning = false; _done = true; });
      HapticFeedback.mediumImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.page,
      appBar: AppBar(
        title: const Text('Günlük Çark'),
        backgroundColor: AppTheme.page,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              _done ? '🎉 Tebrikler!' : 'Günlük şansını dene!',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              _done ? '$_prize coin kazandın!' : 'Çarkı çevirerek coin kazan.',
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 32),
            // Pointer
            const Icon(Icons.arrow_drop_down, size: 48, color: AppTheme.red),
            const SizedBox(height: -12),
            // Wheel
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Transform.rotate(
                angle: _anim.value,
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: _WheelPainter(prizes: _prizes, colors: _colors),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_done)
              SizedBox(
                width: 180,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _spinning ? null : _spin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  icon: _spinning
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.rotate_right),
                  label: Text(_spinning ? 'Dönüyor...' : 'Çevir!', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(16)),
                child: Text('🪙 $_prize Coin Hesabına Eklendi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Geri Dön'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.prizes, required this.colors});
  final List<int> prizes;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / prizes.length;

    for (var i = 0; i < prizes.length; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * segmentAngle - pi / 2,
        segmentAngle,
        true,
        paint,
      );

      // Draw divider lines
      final linePaint = Paint()..color = Colors.white..strokeWidth = 2;
      final lineEnd = Offset(
        center.dx + radius * cos(i * segmentAngle - pi / 2),
        center.dy + radius * sin(i * segmentAngle - pi / 2),
      );
      canvas.drawLine(center, lineEnd, linePaint);

      // Draw text
      final textAngle = (i + 0.5) * segmentAngle - pi / 2;
      final textPos = Offset(
        center.dx + radius * 0.65 * cos(textAngle),
        center.dy + radius * 0.65 * sin(textAngle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${prizes[i]}🪙',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(textPos.dx, textPos.dy);
      canvas.rotate(textAngle + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Center circle
    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(center, 16, Paint()..color = AppTheme.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
