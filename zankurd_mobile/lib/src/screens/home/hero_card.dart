import 'package:flutter/material.dart';
import '../../widgets/shimmer_glow.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.isKu,
    required this.loading,
    required this.onCreateRoom,
    required this.onJoinRoom,
    required this.onQuickMatch,
    super.key,
  });

  final bool isKu;
  final bool loading;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback onQuickMatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4C3A), Color(0xFF0A291F), Color(0xFF1E5F47)],
          stops: [0.0, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(16), // AppRadius.lg
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F4C3A).withValues(alpha: 0.35),
            offset: const Offset(0, 10),
            blurRadius: 28,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.08),
            offset: const Offset(0, 18),
            blurRadius: 36,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekoratif daireler
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4ADE80,
                                  ).withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isKu ? 'Odeya Zindî Vekirî' : 'Canlı Oda Açık',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                isKu
                    ? 'Bi hevalan re\npêşbikeve'
                    : 'Arkadaşlarınla\ncanlı yarış',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isKu
                    ? 'Odeyekê ava bike an bi kodê tevlî bibe. Pirs, skor û rêzbendî bi awayekî zindî nû dibin.'
                    : 'Oda kur veya kodla katıl. Sorular, skorlar ve sıralama canlı güncellenir.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 340;
                  final createButton = _HeroActionButton(
                    label: loading
                        ? (isKu ? 'Tê Vekirin...' : 'Açılıyor...')
                        : (isKu ? 'Odeyek Ava Bike' : 'Oda Kur'),
                    icon: Icons.add_circle_outline,
                    primary: true,
                    onPressed: loading ? null : onCreateRoom,
                  );
                  final joinButton = _HeroActionButton(
                    label: isKu ? 'Bi Kodê Tevlî Bibe' : 'Kodla Katıl',
                    icon: Icons.meeting_room_outlined,
                    primary: false,
                    onPressed: onJoinRoom,
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        createButton,
                        const SizedBox(height: 10),
                        joinButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: createButton),
                      const SizedBox(width: 10),
                      Expanded(child: joinButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: onQuickMatch,
                  icon: const Icon(Icons.bolt, size: 17),
                  label: Text(isKu ? 'Tenê pratîk bike' : 'Tek başına pratik'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const ShimmerGlow(),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.primary
        ? Colors.white
        : Colors.white.withValues(alpha: 0.12);
    final foreground = widget.primary ? const Color(0xFF0F4C3A) : Colors.white;
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16), // AppRadius.lg
            border: widget.primary
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.1,
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
