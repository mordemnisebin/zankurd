import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class RoomActions extends StatelessWidget {
  const RoomActions({
    required this.loading,
    required this.isKu,
    required this.onCreateRoom,
    required this.onJoinRoom,
    super.key,
  });

  final bool loading;
  final bool isKu;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GradientButton(
            label: loading
                ? (isKu ? 'Tê Vekirin...' : 'Açılıyor...')
                : (isKu ? 'Odeyek Ava Bike' : 'Oda Kur'),
            icon: Icons.add_circle_outline,
            gradient: AppTheme.accentGradient,
            onTap: onCreateRoom,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GradientButton(
            label: isKu ? 'Bi Kodê Tevlî Bibe' : 'Kodla Katıl',
            icon: Icons.meeting_room_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            onTap: onJoinRoom,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
