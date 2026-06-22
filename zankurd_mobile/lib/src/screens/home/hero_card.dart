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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF4F1EB8), Color(0xFFE94560)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
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
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.radio_button_checked,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isKu ? 'Jûra Zindî Vekirî' : 'Canlı Oda Açık',
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
              const SizedBox(height: 14),
              Text(
                isKu
                    ? 'Bi hevalan re\npêşbikeve'
                    : 'Arkadaşlarınla\ncanlı yarış',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isKu
                    ? 'Jûrekê ava bike an bi kodê bikeve. Pirs, skor û rêzbendî bi awayekî zindî nû dibin.'
                    : 'Oda kur veya kodla katıl. Sorular, skorlar ve sıralama canlı güncellenir.',
                style: const TextStyle(color: Color(0xFFE0D0FF), fontSize: 13),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 340;
                  final createButton = _HeroActionButton(
                    label: loading
                        ? (isKu ? 'Tê Vekirin...' : 'Açılıyor...')
                        : (isKu ? 'Jûr Ava Bike' : 'Oda Kur'),
                    icon: Icons.add_circle_outline,
                    primary: true,
                    onPressed: loading ? null : onCreateRoom,
                  );
                  final joinButton = _HeroActionButton(
                    label: isKu ? 'Bi Kodê Bikeve' : 'Kodla Katıl',
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
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onQuickMatch,
                icon: const Icon(Icons.bolt, size: 17),
                label: Text(isKu ? 'Tenê pratîk bike' : 'Tek başına pratik'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
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

class _HeroActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final background = primary
        ? Colors.white
        : Colors.white.withValues(alpha: 0.16);
    final foreground = primary ? const Color(0xFF7C3AED) : Colors.white;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.48),
        disabledForegroundColor: const Color(
          0xFF7C3AED,
        ).withValues(alpha: 0.72),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
